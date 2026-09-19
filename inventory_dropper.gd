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
	var kind: String = data.get("kind", "")
	var player: CharacterBody3D = null
	
	if kind == "inventory_item":
		var inventory: Node = data.get("inventory")
		if not is_instance_valid(inventory):
			return
		player = inventory.get_parent() as CharacterBody3D
		if data.get("placement") == null or not inventory.get_all_placements().has(data.placement):
			return
	elif kind == "equipment_item":
		var eq: Node = data.get("equipment")
		if not is_instance_valid(eq):
			return
		player = eq.get_parent() as CharacterBody3D
		var slot = data.get("slot")
		if eq.get_item(slot) != data.item:
			return
	else:
		return
		
	if player == null or player.is_dead or get_tree().paused:
		return
		
	var point := _find_surface(player)
	if point.is_empty():
		get_tree().current_scene.show_notification("Sem espaço seguro para soltar o item")
		return
		
	var loot := LOOT_SCENE.instantiate()
	loot.item = data.item
	loot.quantity = data.get("quantity", 1)
	get_tree().current_scene.add_child(loot)
	var target: Vector3 = point.position + Vector3.UP * 0.04
	# Drop manual: arco curto e discreto saindo do personagem.
	loot.play_spawn(player.global_position + Vector3.UP * 0.55, target, 0.15, 0.28)
	
	if kind == "inventory_item":
		var inventory: Node = data.get("inventory")
		if not inventory.remove_placement(data.placement):
			loot.queue_free()
	elif kind == "equipment_item":
		var eq = data.get("equipment")
		var slot = data.get("slot")
		eq._items.erase(slot)
		eq.changed.emit()

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
