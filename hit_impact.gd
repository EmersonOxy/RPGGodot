extends Node3D
## Small warm-white sparks at confirmed contact; no textures or physics bodies.

static func spawn(parent: Node, point: Vector3, armed: bool) -> void:
	if not is_instance_valid(parent):
		return
	var effect := Node3D.new()
	effect.name = "HitImpact"
	parent.add_child(effect)
	effect.global_position = point
	var camera := effect.get_viewport().get_camera_3d()
	if camera:
		effect.global_basis = camera.global_basis
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.91, 0.7, 1.0)
	var count := 7 if armed else 4
	var radius := 0.28 if armed else 0.16
	var lifetime := 0.16
	var tween := effect.create_tween().set_parallel(true)
	for index in count:
		var angle := TAU * float(index) / float(count) + randf_range(-0.15, 0.15)
		var direction := Vector3(cos(angle), sin(angle), 0.0)
		var spark := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.10 if armed else 0.06, 0.018, 0.018)
		spark.mesh = mesh
		spark.material_override = material
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spark.rotation.z = angle
		effect.add_child(spark)
		tween.tween_property(spark, "position", direction * radius * randf_range(0.7, 1.2), lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "scale", Vector3.ONE * 0.05, lifetime)
	tween.tween_property(material, "albedo_color:a", 0.0, lifetime)
	tween.chain().tween_callback(effect.queue_free)
