extends Node

const LOOT_SCENE := preload("res://world_loot.tscn")
var _pending: Dictionary = {}

func request_drop(data: Dictionary) -> void:
	if _pending.is_empty():
		_pending = data.duplicate()

func _physics_process(_delta: float) -> void:
	if _pending.is_empty():
		return
	var data := _pending
	_pending = {}
	var inventory: Node = data.get("inventory")
	if not is_instance_valid(inventory):
		return
	var player: CharacterBody3D = inventory.get_parent()
	if player.is_dead or get_tree().paused or not inventory.matches_slot(data.index, data.item, data.quantity):
		return
	var point := _find_surface(player)
	if point.is_empty():
		get_tree().current_scene.show_notification("Sem espaço seguro para soltar o item")
		return
	var loot := LOOT_SCENE.instantiate()
	loot.item = data.item
	loot.quantity = data.quantity
	get_tree().current_scene.add_child(loot)
	loot.global_position = point.position + Vector3.UP * 0.04
	if not inventory.remove_slot(data.index, data.item, data.quantity):
		loot.queue_free()

func _find_surface(player: CharacterBody3D) -> Dictionary:
	var space := player.get_world_3d().direct_space_state
	for index in range(16):
		var angle := index * TAU / 16.0
		var center := player.global_position + Vector3(cos(angle), 0, sin(angle)) * 0.85
		var ray := PhysicsRayQueryParameters3D.create(center + Vector3.UP * 0.65, center + Vector3.DOWN * 0.65, 3)
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or not hit.collider.is_in_group("walkable") or hit.normal.y < 0.7:
			continue
		var side := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.5, hit.position + Vector3.UP * 0.5, 3)
		if not space.intersect_ray(side).is_empty():
			continue
		var shape := SphereShape3D.new()
		shape.radius = 0.2
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform.origin = hit.position + Vector3.UP * 0.25
		query.collision_mask = 2 | 16
		if space.intersect_shape(query).is_empty():
			return hit
	return {}
