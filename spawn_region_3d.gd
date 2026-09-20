class_name SpawnRegion3D
extends Node3D
## Volume invisível e configurável usado pelo gerenciador de spawn.

@export var enabled := true
@export var size := Vector3(12.0, 4.0, 12.0)
@export_range(0, 100, 1) var max_alive := 3
@export_range(0.0, 100.0, 0.1) var weight := 1.0
@export var enemy_scenes: Array[PackedScene] = []


func random_world_point(random: RandomNumberGenerator) -> Vector3:
	var half_size := size * 0.5
	var local_point := Vector3(
		random.randf_range(-half_size.x, half_size.x),
		random.randf_range(-half_size.y, half_size.y),
		random.randf_range(-half_size.z, half_size.z)
	)
	return to_global(local_point)


func contains_world_point(point: Vector3, margin: float = 0.0) -> bool:
	var local_point := to_local(point)
	var half_size := size * 0.5 + Vector3.ONE * margin
	return (
		absf(local_point.x) <= half_size.x
		and absf(local_point.y) <= half_size.y
		and absf(local_point.z) <= half_size.z
	)


func pick_enemy_scene(random: RandomNumberGenerator) -> PackedScene:
	if enemy_scenes.is_empty():
		return null
	return enemy_scenes[random.randi_range(0, enemy_scenes.size() - 1)]
