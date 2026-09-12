extends Camera3D
## Segue o Player com X/Z instantâneos e Y suavizado: escadas, rampas e
## plataformas não dão mais solavanco vertical. Rotação nunca muda.

## Quanto maior, mais rápida a transição vertical (5 ≈ suave sem atraso).
@export var vertical_smooth_speed: float = 5.0

var _target: Node3D = null
var _offset := Vector3(12.0, 12.8, 12.0)


func _ready() -> void:
	top_level = true
	_target = get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(_target):
		_offset = global_position - _target.global_position
		global_position = _target.global_position + _offset


func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player") as Node3D
		if not is_instance_valid(_target):
			return
	var want: Vector3 = _target.global_position + _offset
	var p := global_position
	p.x = want.x
	p.z = want.z
	p.y = lerpf(p.y, want.y, 1.0 - exp(-vertical_smooth_speed * delta))
	global_position = p
