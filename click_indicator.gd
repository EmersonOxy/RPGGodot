extends Node3D

@export_range(0.2, 2.0) var size: float = 0.9
@export_range(0.2, 2.0) var duration: float = 0.65
@export var surface_offset: float = 0.03
@export var color := Color(0.75, 0.92, 1.0, 0.85)

@onready var ring: MeshInstance3D = $Ring
@onready var material: StandardMaterial3D = ring.material_override
var animation: Tween


func show_at(point: Vector3, normal: Vector3) -> void:
	if animation:
		animation.kill()
	# Orienta o plano do anel pela normal, inclusive na rampa.
	var surface_normal := normal.normalized()
	global_position = point + surface_normal * surface_offset
	global_basis = Basis(Quaternion(Vector3.UP, surface_normal))
	var final_scale := Vector3(size, size * 0.15, size)
	ring.scale = final_scale * 0.7
	material.albedo_color = color
	show()

	animation = create_tween().set_parallel(true)
	animation.tween_property(ring, "scale", final_scale, duration * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	animation.tween_property(material, "albedo_color:a", 0.0, duration * 0.8).set_delay(duration * 0.2)
	animation.chain().tween_callback(hide)
