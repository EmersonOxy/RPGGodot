extends Node
class_name ItemPreviewGenerator

static func generate_preview(item: ItemData, parent_node: Node, callback: Callable) -> void:
	if item == null:
		return
	if item.icon != null:
		callback.call(item.icon)
		return
	if item.world_scene == null:
		callback.call(null)
		return
		
	var vp := SubViewport.new()
	vp.size = Vector2(128 * item.inventory_size.x, 128 * item.inventory_size.y)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	parent_node.add_child(vp)
	
	var cam := Camera3D.new()
	cam.environment = Environment.new()
	cam.environment.background_mode = Environment.BG_COLOR
	cam.environment.background_color = Color(0, 0, 0, 0)
	cam.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	cam.environment.ambient_light_color = Color(1, 1, 1)
	vp.add_child(cam)
	
	var light := DirectionalLight3D.new()
	vp.add_child(light)
	light.rotation_degrees = Vector3(-45, 45, 0)
	
	var model = item.world_scene.instantiate() as Node3D
	vp.add_child(model)
	
	model.scale = item.world_scale if item.world_scale != Vector3.ZERO else Vector3.ONE
	
	if item.inventory_size.y > item.inventory_size.x:
		# Rotating it to point upwards in the UI
		model.rotation = Vector3(PI/4, 0, PI/4)
	else:
		model.rotation = item.world_rotation
	
	await parent_node.get_tree().process_frame
	await parent_node.get_tree().process_frame
	
	# Enquadramento automático pelo AABB combinado real de todas as malhas:
	# independe da escala física do mundo e da origem do modelo importado.
	var combined := AABB()
	var has_bounds := false
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if mi is MeshInstance3D and mi.mesh != null and mi.visible:
			var world_aabb: AABB = mi.get_global_transform() * mi.mesh.get_aabb()
			if world_aabb.size.length_squared() <= 0.0001:
				continue
			if not has_bounds:
				combined = world_aabb
				has_bounds = true
			else:
				combined = combined.merge(world_aabb)
	
	if has_bounds:
		# Centraliza o modelo na origem.
		model.position = -combined.get_center()
		# Distância da câmera para a maior dimensão ocupar ~70% do viewport.
		var max_dim: float = maxf(combined.size.x, maxf(combined.size.y, combined.size.z))
		var half_fov := deg_to_rad(cam.fov) * 0.5
		var distance: float = (max_dim * 0.5) / maxf(tan(half_fov), 0.01) / 0.7
		cam.position = Vector3(0, 0, distance)
		cam.look_at(Vector3.ZERO)
		await parent_node.get_tree().process_frame
	
	var img = vp.get_texture().get_image()
	var tex = ImageTexture.create_from_image(img)
	item.icon = tex
	item.remove_meta("generating_icon")
	Acquisitions.icon_ready.emit(item)
	
	vp.queue_free()
	callback.call(tex)
