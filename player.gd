extends CharacterBody3D

const COMBAT_TEXT = preload("res://floating_combat_text.gd")

signal health_changed(current: int, maximum: int)
signal xp_changed(current: int, maximum: int)
signal level_up(new_level: int)
signal died
signal stats_changed
signal attack_executed(target: Node3D, interval: float)
signal manual_attack_requested(world_point: Vector3)
signal took_hit

var weapon_drawn: bool:
	get:
		var visual := get_node_or_null("Visual")
		return visual != null and visual.is_weapon_in_hand()
var unarmed_damage: int = 5
const ATTACK_DAMAGE: int = 20
const ATTACK_INTERVAL: float = 1.0
const HIT_ATTACK_LOCK: float = 0.12
const MANUAL_ATTACK_BUFFER: float = 0.25
const MOVEMENT_SPEED_SCALE: float = 0.85
const ARMED_MOVEMENT_SCALE: float = 0.80

@export var speed: float = 4.0
@export var gravity: float = 20.0
@export_range(0.8, 10.0) var attack_range: float = 1.5
@export var base_max_health: int = 100
@export var base_attack_damage: int = ATTACK_DAMAGE
@export var base_armor: int = 0
@export var base_strength: int = 10
@export var base_dexterity: int = 10
@export var base_intelligence: int = 10
var max_health: int = 100
var attack_damage: int = ATTACK_DAMAGE
var armor: int = 0
var strength: int = 10
var dexterity: int = 10
var intelligence: int = 10
var equipment_bonuses: Dictionary = {}
var equipment: Node
var action_bar: Node
@export var manual_move_speed: float = 4.0
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var inventory: Node = $Inventory
var health: int = 100
var is_dead: bool = false
var approach_target: Node3D = null
var attack_cooldown: float = 0.0
var attack_hit_resolved: bool = false
var _manual_attack_click: Variant = null
var hit_attack_lock_timer: float = 0.0
var _buffered_attack_point: Variant = null
var _manual_attack_buffer_timer: float = 0.0
var hit_recovery_timer: float = 0.0
var run_multiplier: float = 1.5
var collect_target: Node3D = null
@export var pickup_range: float = 1.75
var COLLECT_RANGE: float = 1.75
var level: int = 1
var xp: int = 0
var max_xp: int = 100

enum MoveMode { CLICK_MOVE, MANUAL_MOVE }
var move_mode: MoveMode = MoveMode.CLICK_MOVE
var is_moving: bool = false
var move_direction: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group("player")
	equipment = preload("res://equipment.gd").new()
	equipment.name = "Equipment"
	add_child(equipment)
	equipment.changed.connect(recalculate_stats)
	action_bar = preload("res://action_bar.gd").new()
	action_bar.name = "ActionBar"
	add_child(action_bar)
	_equip_starting_items()
	recalculate_stats()
	health = max_health

func _equip_starting_items() -> void:
	var starting_sword := load("res://items/espada_gasta.tres") as ItemData
	if starting_sword:
		equipment._items[ItemData.EquipmentSlot.WEAPON] = starting_sword
		equipment.changed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("manual_attack") and not event.is_echo():
		if is_dead or get_tree().paused or get_viewport().gui_is_dragging() or get_viewport().gui_get_hovered_control() != null:
			return
		_manual_attack_click = get_viewport().get_mouse_position()
		get_viewport().set_input_as_handled()
	if not is_dead and event.is_action_pressed("toggle_weapon") and not event.is_echo():
		$Visual.toggle_weapon()

func recalculate_stats() -> void:
	equipment_bonuses = equipment.get_bonuses()
		
	attack_damage = maxi(0, base_attack_damage + equipment_bonuses.attack_damage)
	armor = maxi(0, base_armor + equipment_bonuses.armor)
	strength = base_strength + equipment_bonuses.strength
	dexterity = base_dexterity + equipment_bonuses.dexterity
	intelligence = base_intelligence + equipment_bonuses.intelligence
	max_health = maxi(1, base_max_health + equipment_bonuses.max_health)
	health = mini(health, max_health)
	stats_changed.emit()
	health_changed.emit(health, max_health)

func use_consumable(item: ItemData) -> bool:
	if is_dead or health <= 0 or health >= max_health or item == null or item.item_type != ItemData.ItemType.CONSUMABLE or item.equipment_slot != ItemData.EquipmentSlot.NONE or item.heal_amount <= 0:
		return false
	if not inventory.consume_one(item):
		return false
	health = mini(max_health, health + item.heal_amount)
	health_changed.emit(health, max_health)
	return true


func gain_xp(amount: int) -> void:
	xp += amount
	while xp >= max_xp:
		xp -= max_xp
		level += 1
		max_xp = _xp_for_level(level)
		level_up.emit(level)
	xp_changed.emit(xp, max_xp)


func _xp_for_level(lvl: int) -> int:
	return 80 + (lvl - 1) * 20


func set_destination(point: Vector3) -> void:
	if is_dead:
		return
	move_mode = MoveMode.CLICK_MOVE
	approach_target = null
	_set_collect_target(null)
	if NavigationServer3D.map_get_iteration_id(navigation_agent.get_navigation_map()) > 0:
		navigation_agent.target_position = point


func approach_enemy(enemy: Node3D) -> void:
	if is_dead:
		return
	set_destination(enemy.global_position)
	approach_target = enemy
	_set_collect_target(null)


func approach_loot(loot: Node3D) -> void:
	if is_dead or not is_instance_valid(loot):
		return
	var dist := global_position.distance_to(loot.global_position)
	if dist <= pickup_range:
		if loot.has_method("try_pickup"):
			if loot.try_pickup(inventory):
				_set_collect_target(null)
				return
	set_destination(loot.global_position)
	_set_collect_target(loot)
	approach_target = null


func _set_collect_target(new_target: Node3D) -> void:
	if is_instance_valid(collect_target) and collect_target != new_target:
		if collect_target.has_method("set_targeted"):
			collect_target.set_targeted(false)
	collect_target = new_target
	if is_instance_valid(collect_target):
		if collect_target.has_method("set_targeted"):
			collect_target.set_targeted(true)


func stop_approach() -> void:
	approach_target = null
	_set_collect_target(null)
	if is_dead:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	set_destination(global_position)
	velocity.x = 0.0
	velocity.z = 0.0


func _enter_manual_mode() -> void:
	move_mode = MoveMode.MANUAL_MOVE
	approach_target = null
	_set_collect_target(null)
	if NavigationServer3D.map_get_iteration_id(navigation_agent.get_navigation_map()) > 0:
		navigation_agent.target_position = global_position


func get_movement_speed_multiplier() -> float:
	return MOVEMENT_SPEED_SCALE * (ARMED_MOVEMENT_SCALE if weapon_drawn else 1.0)


func _manual_move(manual_input: Vector2) -> void:
	var fwd := Vector3(0.0, 0.0, -1.0)
	var right := Vector3(1.0, 0.0, 0.0)
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		fwd = -cam.global_transform.basis.z
		fwd.y = 0.0
		right = cam.global_transform.basis.x
		right.y = 0.0
		fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3(0.0, 0.0, -1.0)
		right = right.normalized() if right.length() > 0.01 else Vector3(1.0, 0.0, 0.0)
	var direction := right * manual_input.x - fwd * manual_input.y
	if direction.length() > 1.0:
		direction = direction.normalized()
		
	var running = Input.is_action_pressed("run")
	var current_speed = manual_move_speed * get_movement_speed_multiplier() * (run_multiplier if running else 1.0)
	
	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed

	is_moving = true
	move_direction = direction.normalized()


func _update_anim_state() -> void:
	var planar := Vector2(velocity.x, velocity.z).length()
	is_moving = planar > 0.1
	if is_moving:
		move_direction = Vector3(velocity.x, 0.0, velocity.z).normalized()
	else:
		move_direction = Vector3.ZERO


func is_in_attack_range() -> bool:
	if is_dead:
		return false
	if not is_instance_valid(approach_target):
		return false
	var difference := approach_target.global_position - global_position
	if difference.length() > attack_range or absf(difference.y) > 0.35:
		return false
	var origin := global_position + Vector3.UP * 0.9
	var end := approach_target.global_position + Vector3.UP * 0.9
	var query := PhysicsRayQueryParameters3D.create(origin, end, 3)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _try_collect() -> void:
	if not is_instance_valid(collect_target):
		_set_collect_target(null)
		return
	var dist := global_position.distance_to(collect_target.global_position)
	if dist <= pickup_range:
		var loot := collect_target as StaticBody3D
		if loot and loot.has_method("try_pickup"):
			if loot.try_pickup(inventory):
				_set_collect_target(null)
			else:
				_set_collect_target(null)


func _physics_process(delta: float) -> void:
	hit_recovery_timer = maxf(0.0, hit_recovery_timer - delta)
	hit_attack_lock_timer = maxf(0.0, hit_attack_lock_timer - delta)
	_manual_attack_buffer_timer = maxf(0.0, _manual_attack_buffer_timer - delta)
	if _manual_attack_buffer_timer <= 0.0:
		_buffered_attack_point = null
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	if is_dead:
		move_and_slide()
		_update_anim_state()
		_manual_attack_click = null
		_buffered_attack_point = null
		return

	if _manual_attack_click != null:
		var point: Variant = _mouse_attack_point(_manual_attack_click)
		_manual_attack_click = null
		if point is Vector3:
			request_manual_attack(point)
	if _buffered_attack_point != null:
		_try_start_manual_attack(_buffered_attack_point)

	var map_ready := NavigationServer3D.map_get_iteration_id(navigation_agent.get_navigation_map()) > 0
	if approach_target != null:
		if not is_instance_valid(approach_target):
			stop_approach()
		elif map_ready and navigation_agent.target_position.distance_to(approach_target.global_position) > 0.25:
			navigation_agent.target_position = approach_target.global_position
	if collect_target != null:
		if not is_instance_valid(collect_target):
			_set_collect_target(null)
		elif map_ready and navigation_agent.target_position.distance_to(collect_target.global_position) > 0.25:
			navigation_agent.target_position = collect_target.global_position
	var manual_input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if manual_input.length() > 0.01:
		if move_mode != MoveMode.MANUAL_MOVE:
			_enter_manual_mode()
		_manual_move(manual_input)
	else:
		if move_mode == MoveMode.MANUAL_MOVE and map_ready:
			navigation_agent.target_position = global_position
		move_mode = MoveMode.CLICK_MOVE
		if map_ready and not is_in_attack_range() and not navigation_agent.is_navigation_finished():
			var running = Input.is_action_pressed("run")
			var current_speed = speed * get_movement_speed_multiplier() * (run_multiplier if running else 1.0)
			
			var next_point := navigation_agent.get_next_path_position()
			var direction := next_point - global_position
			direction.y = 0.0
			if direction.length() > 0.01:
				var movement := direction.normalized() * minf(current_speed, direction.length() / delta)
				velocity.x = movement.x
				velocity.z = movement.z

			elif (next_point - global_position).length() > 0.15:
				var to_target := navigation_agent.target_position - global_position
				to_target.y = 0.0
				if to_target.length() > 0.2:
					var advance := to_target.normalized() * minf(current_speed, to_target.length() / delta)
					velocity.x = advance.x
					velocity.z = advance.z
			_update_anim_state()

	move_and_slide()
	_update_anim_state()

	if _buffered_attack_point == null and is_in_attack_range() and approach_target.is_selected and attack_cooldown <= 0.0 and $Visual.can_start_manual_attack():
		attack_cooldown = ATTACK_INTERVAL
		attack_hit_resolved = false
		attack_executed.emit(approach_target, ATTACK_INTERVAL)

	if collect_target != null:
		_try_collect()


func take_damage(amount: int, damage_type: int = COMBAT_TEXT.DamageType.PLAYER_DAMAGE, is_critical: bool = false) -> void:
	if is_dead or health <= 0 or amount <= 0 or hit_recovery_timer > 0.0:
		return
	hit_recovery_timer = 0.25
	took_hit.emit()
	COMBAT_TEXT.show_damage_number(self, global_position + Vector3.UP * 1.6, mini(amount, health), damage_type, is_critical)
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	if health == 0:
		is_dead = true
		approach_target = null
		_set_collect_target(null)
		velocity.x = 0.0
		velocity.z = 0.0
		is_moving = false
		move_direction = Vector3.ZERO
		died.emit()

func _on_attack_impact(target: Node3D = null, manual_direction: Vector3 = Vector3.ZERO) -> void:
	if is_dead or attack_hit_resolved:
		return
	attack_hit_resolved = true
	
	if not manual_direction.is_zero_approx():
		target = _find_manual_attack_target(manual_direction)
	elif target == null:
		target = approach_target
	if not is_instance_valid(target):
		return
		
	var dist = global_position.distance_to(target.global_position)
	if dist > attack_range * 1.5:
		return
		
	var final_damage = attack_damage if weapon_drawn else unarmed_damage
	var hp_before: int = target.health
	target.take_damage(final_damage)
	
	if is_instance_valid(target) and hp_before <= final_damage:
		gain_xp(25)
	elif not is_instance_valid(target):
		gain_xp(25)


func request_manual_attack(world_point: Vector3) -> bool:
	if is_dead or get_tree().paused:
		return false
	# One slot: a newer click replaces the aim and expiry, never adds a queued attack.
	_buffered_attack_point = world_point
	_manual_attack_buffer_timer = MANUAL_ATTACK_BUFFER
	return _try_start_manual_attack(world_point)


func _try_start_manual_attack(world_point: Vector3) -> bool:
	if is_dead or get_tree().paused or attack_cooldown > 0.0 or not $Visual.can_start_manual_attack():
		return false
	_buffered_attack_point = null
	_manual_attack_buffer_timer = 0.0
	attack_cooldown = ATTACK_INTERVAL
	attack_hit_resolved = false
	manual_attack_requested.emit(world_point)
	return true


func _mouse_attack_point(screen_position: Vector2) -> Variant:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	# Environment only: enemies, loot and the Player cannot intercept the aiming ray.
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * camera.far, 3)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit.position
	# Empty sky/background still provides a horizontal aiming point at Player height.
	return Plane(Vector3.UP, global_position.y).intersects_ray(origin, direction)


func _find_manual_attack_target(direction: Vector3) -> Node3D:
	if _can_hit_manually(approach_target, direction):
		return approach_target
	var closest: Node3D = null
	var best_distance := INF
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if candidate is Node3D and _can_hit_manually(candidate, direction):
			var distance := global_position.distance_squared_to(candidate.global_position)
			if distance < best_distance:
				best_distance = distance
				closest = candidate
	return closest


func _can_hit_manually(target: Node3D, direction: Vector3) -> bool:
	if not is_instance_valid(target) or not target.is_in_group("enemies") or not target.has_method("take_damage") or target.get("health") == null or target.health <= 0:
		return false
	var difference := target.global_position - global_position
	if difference.length() > attack_range or absf(difference.y) > 0.35:
		return false
	difference.y = 0.0
	# A simple frontal cone; one target per impact. No weapon hitbox system.
	if not difference.is_zero_approx() and difference.normalized().dot(direction) < 0.5:
		return false
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.9, target.global_position + Vector3.UP * 0.9, 3)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
