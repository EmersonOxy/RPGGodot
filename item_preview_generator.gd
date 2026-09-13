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
	
	cam.position = Vector3(0, 0, 1.2)
	if item.id == "espada_gasta" or item.id == "espada_ferro":
		cam.position = Vector3(0.0, 0.4, 0.8)
	cam.look_at(Vector3.ZERO)
	
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
	
	var img = vp.get_texture().get_image()
	var tex = ImageTexture.create_from_image(img)
	item.icon = tex
	item.remove_meta("generating_icon")
	
	vp.queue_free()
	callback.call(tex)
