extends CharacterBody3D

signal died(enemy: Node3D)

enum State { IDLE, CHASE, ATTACK, RETURN }

@export var max_health: int = 100
@export_range(0.8, 10.0) var attack_range: float = 2.0
@export var attack_damage: int = 10
@export_range(0.1, 10.0) var attack_interval: float = 1.5
@export var aggro_range: float = 8.0
@export var leash_range: float = 15.0
@export var move_speed: float = 2.5
@export var gravity: float = 20.0
@export var drop_table: Resource
@export var enemy_name: String = "Dummy"
var health: int = 100
var is_selected := false
var attack_cooldown: float = 0.0
var target: Node3D = null
var state: State = State.IDLE
var home_position: Vector3

@onready var selection_indicator: MeshInstance3D = $SelectionIndicator
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var _health_bar_3d: Node3D = $EnemyHealthBar


func _ready() -> void:
	health = max_health
	attack_cooldown = 0.0
	home_position = global_position
	target = get_tree().get_first_node_in_group("player") as Node3D
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	set_collision_mask_value(3, true)
	set_collision_mask_value(4, true)
	set_selected(false)
	if _health_bar_3d:
		_health_bar_3d.setup(max_health, enemy_name)
	if drop_table == null:
		drop_table = _create_default_drop_table()


func _create_default_drop_table() -> Resource:
	var dt = load("res://drop_table.gd").new()
	var pocao := load("res://items/pocao_vida.tres")
	var espada := load("res://items/espada_gasta.tres")
	var frag := load("res://items/fragmento_antigo.tres")
	dt.add_entry(pocao, 5.0, 1, 2)
	dt.add_entry(espada, 3.0, 1, 1)
	dt.add_entry(frag, 2.0, 1, 3)
	return dt


func set_selected(value: bool) -> void:
	is_selected = value
	selection_indicator.visible = value
	if _health_bar_3d:
		_health_bar_3d.set_selected(value)


func take_damage(amount: int) -> void:
	if health <= 0 or amount <= 0:
		return
	health = maxi(0, health - amount)
	if _health_bar_3d:
		_health_bar_3d.update_hp(health, max_health)
		_health_bar_3d.set_in_combat(true)
	if health == 0:
		set_selected(false)
		collision_layer = 0
		_drop_loot()
		hide()
		died.emit(self)
		queue_free()


func _drop_loot() -> void:
	if drop_table == null:
		return
	var rolls = drop_table.roll()
	for drop in rolls:
		var item_data = drop["item"]
		var count: int = drop["count"]
		for i in count:
			var loot_scene := preload("res://world_loot.tscn")
			var loot: Node3D = loot_scene.instantiate()
			loot.item = item_data
			var offset := Vector3(randf_range(-0.5, 0.5), 0.0, randf_range(-0.5, 0.5))
			loot.position = _find_surface_position(global_position + offset)
			var scene_root := get_tree().current_scene
			if scene_root == null:
				scene_root = get_parent()
				while scene_root.get_parent() != null and scene_root.get_parent() != get_tree().root:
					scene_root = scene_root.get_parent()
			scene_root.add_child(loot)


func _find_surface_position(pos: Vector3) -> Vector3:
	var origin := pos + Vector3.UP * 50.0
	var end := pos + Vector3.DOWN * 50.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result:
		return result.position + Vector3.UP * 0.15
	return pos + Vector3.UP * 0.15


func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	if health <= 0:
		return
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node3D
		if not is_instance_valid(target):
			move_and_slide()
			return
	_update_state()
	match state:
		State.IDLE:
			_stop()
		State.CHASE:
			_chase(delta)
		State.ATTACK:
			_attack()
		State.RETURN:
			_return_home(delta)
	move_and_slide()


func _update_state() -> void:
	var player_alive: bool = not ("is_dead" in target and target.is_dead)
	var distance_to_player := global_position.distance_to(target.global_position)
	var leashed := home_position.distance_to(target.global_position) > leash_range
	match state:
		State.IDLE:
			if not player_alive or leashed:
				return
			if _is_target_in_range():
				state = State.ATTACK
			elif distance_to_player <= aggro_range:
				state = State.CHASE
		State.CHASE:
			if not player_alive or leashed:
				state = State.RETURN
			elif _is_target_in_range():
				state = State.ATTACK
		State.ATTACK:
			if not player_alive or leashed:
				state = State.RETURN
			elif not _is_target_in_range():
				state = State.CHASE
		State.RETURN:
			if player_alive and not leashed and distance_to_player <= aggro_range:
				if _is_target_in_range():
					state = State.ATTACK
				else:
					state = State.CHASE
			elif _is_home_reached():
				state = State.IDLE


func _stop() -> void:
	if not navigation_agent.is_navigation_finished():
		navigation_agent.target_position = global_position


func _chase(delta: float) -> void:
	if navigation_agent.target_position.distance_to(target.global_position) > 0.25:
		navigation_agent.target_position = target.global_position
	_follow_path(delta)


func _attack() -> void:
	_stop()
	if attack_cooldown > 0.0:
		return
	if not target.has_method("take_damage"):
		return
	attack_cooldown = attack_interval
	target.take_damage(attack_damage)


func _return_home(delta: float) -> void:
	if navigation_agent.target_position != home_position:
		navigation_agent.target_position = home_position
	_follow_path(delta)


func _follow_path(delta: float) -> void:
	if NavigationServer3D.map_get_iteration_id(navigation_agent.get_navigation_map()) <= 0:
		return
	if navigation_agent.is_navigation_finished():
		return
	var next_point := navigation_agent.get_next_path_position()
	var direction := next_point - global_position
	direction.y = 0.0
	if direction.length() > 0.01:
		var movement := direction.normalized() * minf(move_speed, direction.length() / delta)
		velocity.x = movement.x
		velocity.z = movement.z

	elif not navigation_agent.is_navigation_finished() and (next_point - global_position).length() > 0.15:
		var to_target := navigation_agent.target_position - global_position
		to_target.y = 0.0
		if to_target.length() > 0.2:
			var advance := to_target.normalized() * minf(move_speed, to_target.length() / delta)
			velocity.x = advance.x
			velocity.z = advance.z


func _is_home_reached() -> bool:
	var flat := Vector2(global_position.x, global_position.z).distance_to(Vector2(home_position.x, home_position.z))
	return flat < 0.4 and absf(global_position.y - home_position.y) < 0.6


func _is_target_in_range() -> bool:
	if not is_instance_valid(target):
		return false
	var difference := target.global_position - global_position
	if difference.length() > attack_range or absf(difference.y) > 0.35:
		return false
	var origin := global_position + Vector3.UP * 0.9
	var end := target.global_position + Vector3.UP * 0.9
	var query := PhysicsRayQueryParameters3D.create(origin, end, 3)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
