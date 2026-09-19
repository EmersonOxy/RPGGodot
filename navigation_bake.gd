extends SceneTree
## Rebuild after editing level geometry:
## Godot --headless --path . --script res://navigation_bake.gd

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: Node3D = load("res://main.tscn").instantiate()
	var region: NavigationRegion3D = scene.get_node("NavigationRegion3D")
	scene.remove_child(region)
	region.owner = null
	root.add_child(region)
	var old_count := region.navigation_mesh.get_polygon_count()
	region.bake_navigation_mesh(false)
	var new_count := region.navigation_mesh.get_polygon_count()
	if new_count == 0:
		push_error("Bake produced no polygons; not saving.")
		scene.free()
		region.free()
		quit(1)
		return
	var error := ResourceSaver.save(region.navigation_mesh, "res://world_navigation.tres")
	if error != OK:
		push_error("Could not save navigation: %s" % error)
		scene.free()
		region.free()
		quit(1)
		return
	for frame in 12:
		await physics_frame
	var map := region.get_navigation_map()
	print("BAKE: ", old_count, " -> ", new_count, " polygons; map iteration=", NavigationServer3D.map_get_iteration_id(map))
	var ground := NavigationServer3D.map_get_closest_point(map, Vector3(23, 0, 10))
	for body in region.get_node("Props").get_children():
		if not str(body.name).begins_with("Plataforma") and not str(body.name).begins_with("Ponte") and not str(body.name).begins_with("Rampa"):
			continue
		var collider: CollisionShape3D = body.get_node("CollisionShape3D")
		var local_top := Vector3.ZERO
		if collider.shape is BoxShape3D:
			local_top.y = collider.shape.size.y * 0.5
		elif collider.shape is ConvexPolygonShape3D:
			# The level's wedge ramps have a planar slope through their bounds center.
			var points: PackedVector3Array = collider.shape.points
			var bounds := AABB(points[0], Vector3.ZERO)
			for point in points:
				bounds = bounds.expand(point)
			local_top = bounds.get_center()
		var surface := collider.global_transform * local_top
		var nearest := NavigationServer3D.map_get_closest_point(map, surface)
		var path := NavigationServer3D.map_get_path(map, ground, nearest, true)
		var reachable := not path.is_empty() and path[path.size() - 1].distance_to(nearest) < 0.25
		print(body.name, ": surface=", surface, " nav=", nearest, " gap=", surface.distance_to(nearest), " connected_to_ground=", reachable)
	scene.free()
	region.free()
	quit()
