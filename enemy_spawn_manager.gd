class_name EnemySpawnManager
extends Node3D
## Mantém a população de inimigos dentro de volumes configuráveis.

@export var enabled := true
@export_range(0.1, 120.0, 0.1) var spawn_interval := 8.0
@export_range(0.0, 120.0, 0.1) var initial_delay := 3.0
@export_range(0, 100, 1) var global_max_alive := 7
@export_range(0.0, 100.0, 0.5) var minimum_player_distance := 10.0
@export_range(0.0, 200.0, 0.5) var maximum_player_distance := 35.0
@export_range(1, 50, 1) var placement_attempts := 12
@export_range(0.1, 5.0, 0.1) var navigation_tolerance := 2.0
@export_range(0.1, 5.0, 0.1) var clearance_radius := 0.8
@export var spawn_parent_path := NodePath("../Enemies")

var _timer := 0.0
var _random := RandomNumberGenerator.new()
var _player: Node3D
var _base_spawn_interval := 8.0
var _base_global_max_alive := 7


func _ready() -> void:
	_random.randomize()
	_base_spawn_interval = spawn_interval
	_base_global_max_alive = global_max_alive
	_apply_difficulty()
	var difficulty := get_node_or_null("/root/Difficulty")
	if difficulty != null:
		difficulty.difficulty_changed.connect(_on_difficulty_changed)
	_timer = initial_delay
	_player = get_tree().get_first_node_in_group("player") as Node3D


func _apply_difficulty() -> void:
	var difficulty := get_node_or_null("/root/Difficulty")
	if difficulty == null:
		spawn_interval = _base_spawn_interval
		global_max_alive = _base_global_max_alive
		return
	spawn_interval = _base_spawn_interval * difficulty.get_multiplier("spawn_interval")
	global_max_alive = maxi(1, roundi(_base_global_max_alive * difficulty.get_multiplier("max_enemies")))


func _on_difficulty_changed(_id: String) -> void:
	_apply_difficulty()
	_timer = minf(_timer, spawn_interval)


func _physics_process(delta: float) -> void:
	if not enabled or global_max_alive <= 0:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = spawn_interval
	try_spawn()


func try_spawn() -> Node3D:
	if not enabled or _living_enemy_count() >= global_max_alive:
		return null
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if not is_instance_valid(_player):
		return null
	var regions := _eligible_regions()
	while not regions.is_empty():
		var region := _pick_weighted_region(regions)
		var spawn_position: Variant = _find_spawn_position(region)
		if spawn_position != null:
			return _spawn_enemy(region, spawn_position)
		regions.erase(region)
	return null


func _eligible_regions() -> Array[SpawnRegion3D]:
	var result: Array[SpawnRegion3D] = []
	for node in get_tree().get_nodes_in_group("enemy_spawn_regions"):
		var region := node as SpawnRegion3D
		if region == null or not region.enabled or region.weight <= 0.0:
			continue
		if region.enemy_scenes.is_empty() or _region_enemy_count(region) >= region.max_alive:
			continue
		result.append(region)
	return result


func _pick_weighted_region(regions: Array[SpawnRegion3D]) -> SpawnRegion3D:
	var total_weight := 0.0
	for region in regions:
		total_weight += region.weight
	var roll := _random.randf_range(0.0, total_weight)
	for region in regions:
		roll -= region.weight
		if roll <= 0.0:
			return region
	return regions.back()


func _find_spawn_position(region: SpawnRegion3D) -> Variant:
	var navigation_map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(navigation_map) <= 0:
		return null
	for _attempt in placement_attempts:
		var sampled := region.random_world_point(_random)
		var point := NavigationServer3D.map_get_closest_point(navigation_map, sampled)
		if point.distance_to(sampled) > navigation_tolerance:
			continue
		if not region.contains_world_point(point, navigation_tolerance):
			continue
		var player_distance := point.distance_to(_player.global_position)
		if player_distance < minimum_player_distance:
			continue
		if maximum_player_distance > 0.0 and player_distance > maximum_player_distance:
			continue
		if _position_is_clear(point):
			return point
	return null


func _position_is_clear(point: Vector3) -> bool:
	var shape := SphereShape3D.new()
	shape.radius = clearance_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * clearance_radius)
	query.collision_mask = 9
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _spawn_enemy(region: SpawnRegion3D, position: Vector3) -> Node3D:
	var scene := region.pick_enemy_scene(_random)
	if scene == null:
		return null
	var enemy := scene.instantiate() as Node3D
	if enemy == null:
		return null
	var spawn_parent := get_node_or_null(spawn_parent_path)
	if spawn_parent == null:
		spawn_parent = get_parent()
	spawn_parent.add_child(enemy)
	enemy.global_position = position
	enemy.add_to_group("spawned_enemy")
	enemy.set_meta("spawn_region", region.get_path())
	return enemy


func _living_enemy_count() -> int:
	return get_tree().get_nodes_in_group("enemies").size()


func _region_enemy_count(region: SpawnRegion3D) -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("spawned_enemy"):
		if is_instance_valid(enemy) and enemy.get_meta("spawn_region", NodePath()) == region.get_path():
			count += 1
	return count
