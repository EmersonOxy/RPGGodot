extends CharacterBody3D

signal health_changed(current: int, maximum: int)
signal xp_changed(current: int, maximum: int)
signal level_up(new_level: int)
signal died

const ATTACK_DAMAGE: int = 20
const ATTACK_INTERVAL: float = 1.0

@export var speed: float = 4.0
@export var gravity: float = 20.0
@export_range(0.8, 10.0) var attack_range: float = 1.5
@export var max_health: int = 100
@export var manual_move_speed: float = 4.0
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var inventory: Node = $Inventory
var health: int = 100
var is_dead: bool = false
var approach_target: Node3D = null
var attack_cooldown: float = 0.0
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
	health = max_health


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
	velocity.x = direction.x * manual_move_speed
	velocity.z = direction.z * manual_move_speed

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
		return

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
			var next_point := navigation_agent.get_next_path_position()
			var direction := next_point - global_position
			direction.y = 0.0
			if direction.length() > 0.01:
				var movement := direction.normalized() * minf(speed, direction.length() / delta)
				velocity.x = movement.x
				velocity.z = movement.z

			elif (next_point - global_position).length() > 0.15:
				var to_target := navigation_agent.target_position - global_position
				to_target.y = 0.0
				if to_target.length() > 0.2:
					var advance := to_target.normalized() * minf(speed, to_target.length() / delta)
					velocity.x = advance.x
					velocity.z = advance.z
			_update_anim_state()

	move_and_slide()
	_update_anim_state()

	if is_in_attack_range() and approach_target.is_selected and attack_cooldown <= 0.0:
		attack_cooldown = ATTACK_INTERVAL
		var hp_before: int = approach_target.health
		approach_target.take_damage(ATTACK_DAMAGE)
		# Dar XP por matar
		if is_instance_valid(approach_target) and hp_before <= ATTACK_DAMAGE:
			gain_xp(25)
		elif not is_instance_valid(approach_target):
			gain_xp(25)

	if collect_target != null:
		_try_collect()


func take_damage(amount: int) -> void:
	if is_dead or health <= 0 or amount <= 0:
		return
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
