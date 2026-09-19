extends Node3D
signal sword_swing(target: Node3D)
signal attack_voice
signal hit_animation_started
signal death_animation_finished
var _death_clip: StringName = &""
## One visual controller. Movement, damage values and recovery remain in Player.
enum WeaponState { NO_WEAPON, SHEATHED, DRAWING, DRAWN, SHEATHING }

@export var turn_speed := 12.0
@export var blend_time := 0.15
@export var unarmed_walk_playback := 1.50
@export var unarmed_run_playback := 1.70
@export var armed_walk_playback := 2.25
@export var armed_run_playback := 1.224
@export_range(0.1, 4.0) var armed_attack_playback := 1.50
@export_range(0.1, 4.0) var unarmed_attack_playback := 1.25

@onready var body: CharacterBody3D = get_parent() as CharacterBody3D
@onready var animation_player: AnimationPlayer = $Model/AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
var weapon_state := WeaponState.NO_WEAPON
var _weapon_event_applied := false
var _equipped_item: ItemData
var sword_socket: Node3D
var back_socket: Node3D
var _graph: AnimationNodeBlendTree
var _shots: Dictionary = {}
var _attack_target: WeakRef
var _manual_attack_direction := Vector3.ZERO
var _attack_pending := false
var _dead := false
var moving := false
var _blend_speed := 0.0
var _armed_blend := 0.0
var _idle_time := 0.0
var _idle_delay := 10.0
var _last_long_idle := -1
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_physics_priority = 10
	_rng.randomize()
	animation_player.stop()
	_graph = animation_tree.tree_root.duplicate(true)
	animation_tree.tree_root = _graph
	animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	animation_tree.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	animation_tree.process_physics_priority = 20
	animation_tree.active = true
	animation_tree.animation_finished.connect(_on_animation_finished)
	animation_tree.set("parameters/Life/transition_request", "Alive")
	sword_socket = find_child("SwordSocket", true, false)
	back_socket = find_child("BackSwordSocket", true, false)
	body.attack_executed.connect(_on_attack_executed)
	body.manual_attack_requested.connect(_on_manual_attack_requested)
	body.took_hit.connect(_on_took_hit)
	body.died.connect(_on_died)
	_connect_equipment.call_deferred()
	_reset_idle_timer()

func _connect_equipment() -> void:
	body.equipment.changed.connect(_refresh_equipment)
	_refresh_equipment()

func is_weapon_in_hand() -> bool:
	if weapon_state == WeaponState.DRAWING:
		return _weapon_event_applied
	if weapon_state == WeaponState.SHEATHING:
		return not _weapon_event_applied
	return weapon_state == WeaponState.DRAWN

func _refresh_equipment() -> void:
	var equipped: ItemData = body.equipment.get_item(ItemData.EquipmentSlot.WEAPON)
	if equipped != _equipped_item:
		_equipped_item = equipped
		_cancel_shot("Weapon")
		_cancel_shot("Attack")
		_cancel_shot("Hit")
		_cancel_long_idle()
		_attack_pending = false
		body.attack_hit_resolved = true
		_weapon_event_applied = false
		weapon_state = WeaponState.SHEATHED if equipped else WeaponState.NO_WEAPON
	_refresh_swords()

func _refresh_swords() -> void:
	var has_weapon := weapon_state != WeaponState.NO_WEAPON
	sword_socket.visible = has_weapon and is_weapon_in_hand()
	back_socket.visible = has_weapon and not is_weapon_in_hand()

func toggle_weapon() -> void:
	if _dead or _shots.has("Attack") or _shots.has("Hit"):
		return
	if weapon_state not in [WeaponState.SHEATHED, WeaponState.DRAWN]:
		return
	_cancel_long_idle()
	_weapon_event_applied = false
	var drawing := weapon_state == WeaponState.SHEATHED
	weapon_state = WeaponState.DRAWING if drawing else WeaponState.SHEATHING
	var clip := ("Draw" if drawing else "Sheathe") + str(_rng.randi_range(1, 2))
	_start_shot("Weapon", clip)

# Track path is '..' relative to Model: it resolves to this Visual, never Main.
func _on_draw_sheathe_event() -> void:
	if _dead or _weapon_event_applied or not _shots.has("Weapon"):
		return
	if weapon_state not in [WeaponState.DRAWING, WeaponState.SHEATHING]:
		return
	_weapon_event_applied = true
	_refresh_swords()

func _start_shot(action: String, clip: String) -> void:
	(_graph.get_node(action + "Clip") as AnimationNodeAnimation).animation = clip
	_shots[action] = clip
	animation_tree.set("parameters/" + action + "/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func _cancel_shot(action: String) -> void:
	if not _shots.has(action):
		return
	_shots.erase(action)
	animation_tree.set("parameters/" + action + "/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)

func _finish_actions() -> void:
	for action in _shots.keys():
		var path: String = "parameters/" + action + "/"
		if animation_tree.get(path + "request") == AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE or animation_tree.get(path + "active"):
			continue
		_shots.erase(action)
		if action == "Weapon":
			weapon_state = WeaponState.DRAWN if weapon_state == WeaponState.DRAWING else WeaponState.SHEATHED
			_weapon_event_applied = false
			_refresh_swords()
		elif action == "Attack":
			_attack_pending = false
		_reset_idle_timer()

func _interrupt_weapon() -> void:
	if not _shots.has("Weapon"):
		return
	var in_hand := is_weapon_in_hand()
	_cancel_shot("Weapon")
	weapon_state = WeaponState.DRAWN if in_hand else WeaponState.SHEATHED
	_weapon_event_applied = false
	_refresh_swords()

func _physics_process(delta: float) -> void:
	update_movement(body.get_real_velocity(), delta)

func update_movement(actual_velocity: Vector3, delta: float) -> void:
	if _dead:
		return
	_finish_actions()
	var planar := Vector3(actual_velocity.x, 0, actual_velocity.z)
	var speed := planar.length()
	moving = speed > (0.05 if moving else 0.10)
	var weight := 1.0 - exp(-3.0 * delta / maxf(blend_time, 0.01))
	# Keep the existing walk/run blend points; playback below follows actual speed.
	var gait_speed: float = speed / body.get_movement_speed_multiplier()
	_blend_speed = lerpf(_blend_speed, gait_speed if moving else 0.0, weight)
	_armed_blend = move_toward(_armed_blend, 1.0 if is_weapon_in_hand() else 0.0, delta / maxf(blend_time, 0.01))
	animation_tree.set("parameters/WeaponBlend/blend_amount", _armed_blend)
	for group in ["Unarmed", "Armed"]:
		animation_tree.set("parameters/" + group + "/blend_position", _blend_speed)
	var scales := [unarmed_walk_playback, unarmed_run_playback, armed_walk_playback, armed_run_playback]
	var paths := ["Unarmed/1", "Unarmed/2", "Armed/1", "Armed/2"]
	# Preserve gait tuning against the original movement scale; slowing travel
	# must not compound the separately requested animation speed reduction.
	var animation_speed: float = speed * 0.85 / body.MOVEMENT_SPEED_SCALE
	for i in 4:
		var reference := 4.0 if i % 2 == 0 else 6.0
		var rate := clampf(scales[i] * clampf(animation_speed / reference, 0.5, 1.5), 0.4, 4.0)
		animation_tree.set("parameters/" + paths[i] + "/Speed/scale", rate)
	if moving:
		_cancel_long_idle()
	elif weapon_state == WeaponState.DRAWN and _shots.is_empty():
		_idle_time += delta
		if _idle_time >= _idle_delay:
			_last_long_idle = _rng.randi_range(0, 1) if _last_long_idle < 0 else 1 - _last_long_idle
			_start_shot("LongIdle", "Long" + str(_last_long_idle + 1))
			_reset_idle_timer()
	else:
		_idle_time = 0.0
	var direction := planar
	if _shots.has("Attack") and _attack_pending:
		if not _manual_attack_direction.is_zero_approx():
			direction = _manual_attack_direction
		elif _attack_target:
			var target := _attack_target.get_ref() as Node3D
			if is_instance_valid(target):
				direction = target.global_position - body.global_position
				direction.y = 0
	if direction.length_squared() > 0.0025:
		var local_direction := body.global_basis.inverse() * direction
		rotation.y = lerp_angle(rotation.y, atan2(local_direction.x, local_direction.z), 1.0 - exp(-turn_speed * delta))

func _reset_idle_timer() -> void:
	_idle_time = 0.0
	_idle_delay = _rng.randf_range(8.0, 12.0)

func get_footstep_interval() -> float:
	# Match the walk/run blend and TimeScale values already driving the legs.
	var run_weight := clampf((_blend_speed - 4.0) / 2.0, 0.0, 1.0)
	var frequencies: Array[float] = []
	for group in ["Unarmed", "Armed"]:
		var prefix := "Armed" if group == "Armed" else ""
		var walk_rate: float = animation_tree.get("parameters/" + group + "/1/Speed/scale")
		var run_rate: float = animation_tree.get("parameters/" + group + "/2/Speed/scale")
		var walk_length := animation_player.get_animation(prefix + "Walk").length
		var run_length := animation_player.get_animation(prefix + "Run").length
		frequencies.append(lerpf(walk_rate / maxf(walk_length, 0.01), run_rate / maxf(run_length, 0.01), run_weight))
	return 0.5 / maxf(lerpf(frequencies[0], frequencies[1], _armed_blend), 0.01)

func _cancel_long_idle() -> void:
	_cancel_shot("LongIdle")
	_idle_time = 0.0

func _on_attack_executed(target: Node3D, _interval: float) -> void:
	# No queue: an ongoing action owns its clip until its end/interruption.
	if not can_start_manual_attack():
		return
	_cancel_shot("Hit")
	_cancel_long_idle()
	_attack_target = weakref(target) if is_instance_valid(target) else null
	if is_instance_valid(target):
		_manual_attack_direction = Vector3.ZERO
	_attack_pending = true
	var armed := is_weapon_in_hand()
	animation_tree.set("parameters/AttackSpeed/scale", armed_attack_playback if armed else unarmed_attack_playback)
	_start_shot("Attack", "ArmedAttack" if armed else "Attack" + str(_rng.randi_range(1, 3)))

func _on_attack_impact() -> void:
	if _dead or not _attack_pending or not _shots.has("Attack"):
		return
	_attack_pending = false
	if is_weapon_in_hand():
		var sound_target: Node3D = null
		if not _manual_attack_direction.is_zero_approx():
			sound_target = body._find_manual_attack_target(_manual_attack_direction)
		elif _attack_target:
			sound_target = _attack_target.get_ref() as Node3D
			if is_instance_valid(sound_target):
				var direction := (sound_target.global_position - body.global_position).normalized()
				if not body._can_hit_manually(sound_target, direction):
					sound_target = null
		sword_swing.emit(sound_target)
	attack_voice.emit()
	if not _manual_attack_direction.is_zero_approx():
		body._on_attack_impact(null, _manual_attack_direction)
		return
	# Do not redirect a pending hit to a newly selected enemy.
	if _attack_target and _attack_target.get_ref() == body.approach_target:
		body._on_attack_impact()

func can_start_manual_attack() -> bool:
	return not _dead and body.hit_attack_lock_timer <= 0.0 and not _shots.has("Weapon") and not _shots.has("Attack")

func is_attack_movement_locked() -> bool:
	return not _dead and _shots.has("Attack")

func is_hit_movement_locked() -> bool:
	return not _dead and _shots.has("Hit")

func _on_manual_attack_requested(world_point: Vector3) -> void:
	var direction := world_point - body.global_position
	direction.y = 0.0
	if direction.is_zero_approx():
		direction = global_basis.z
		direction.y = 0.0
	_manual_attack_direction = direction.normalized()
	_on_attack_executed(null, 0.0)

func _on_took_hit() -> void:
	# Damage still applies, but visual feedback cannot cancel a committed attack.
	if _dead or _shots.has("Attack"):
		return
	_interrupt_weapon()
	_cancel_long_idle()
	if _shots.has("Hit"):
		return
	body.hit_attack_lock_timer = body.HIT_ATTACK_LOCK
	var clip := "ArmedHit" + str(_rng.randi_range(1, 2)) if is_weapon_in_hand() else "Hit" + str(_rng.randi_range(1, 4))
	_start_shot("Hit", clip)
	hit_animation_started.emit()

func _on_died() -> void:
	if _dead:
		return
	var armed := is_weapon_in_hand()
	_dead = true
	_attack_pending = false
	for action in _shots.keys():
		animation_tree.set("parameters/" + action + "/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	_shots.clear()
	_death_clip = "ArmedDeath" + str(_rng.randi_range(1, 2)) if armed else "Death"
	(_graph.get_node("DeathClip") as AnimationNodeAnimation).animation = _death_clip
	animation_tree.set("parameters/Life/transition_request", "Death")

func _on_animation_finished(animation: StringName) -> void:
	if _dead and animation == _death_clip:
		_death_clip = &""
		death_animation_finished.emit()
