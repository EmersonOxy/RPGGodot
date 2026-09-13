extends Camera3D
## Segue o Player com X/Z instantâneos e Y suavizado: escadas, rampas e
## plataformas não dão mais solavanco vertical. Rotação nunca muda.
## Suporta zoom ortográfico suave com níveis discretos estilo Project Zomboid.

const ZOOM_LEVELS: Array[float] = [12.0, 15.0, 19.0, 23.0, 27.0]
const DEFAULT_ZOOM_INDEX: int = 2

## Quanto maior, mais rápida a transição vertical (5 ≈ suave sem atraso).
@export var vertical_smooth_speed: float = 5.0
## Velocidade de interpolação do zoom ortográfico.
@export var zoom_smooth_speed: float = 10.0

var _target: Node3D = null
var _offset := Vector3(12.0, 12.8, 12.0)
var _zoom_index: int = DEFAULT_ZOOM_INDEX
var _target_size: float = ZOOM_LEVELS[DEFAULT_ZOOM_INDEX]
var _scroll_enabled := true


func _ready() -> void:
	top_level = true
	add_to_group("game_camera")
	_target = get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(_target):
		_offset = global_position - _target.global_position
		global_position = _target.global_position + _offset

	var ds = get_node_or_null("/root/DisplaySettings")
	if ds and "default_zoom_index" in ds:
		_zoom_index = clampi(ds.default_zoom_index, 0, ZOOM_LEVELS.size() - 1)
		_scroll_enabled = ds.zoom_with_scroll
		ds.settings_applied.connect(func(): _scroll_enabled = ds.zoom_with_scroll)

	_target_size = ZOOM_LEVELS[_zoom_index]
	size = _target_size


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

	# Interpolação suave do Camera3D.size entre os níveis de zoom
	if not is_equal_approx(size, _target_size):
		size = lerpf(size, _target_size, 1.0 - exp(-zoom_smooth_speed * delta))
		if absf(size - _target_size) < 0.01:
			size = _target_size


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or not _scroll_enabled or get_viewport().gui_is_dragging():
		return
	if event is InputEventMouseButton and event.pressed:
		if _is_mouse_over_scroll_consumer():
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out()
			get_viewport().set_input_as_handled()


func zoom_in() -> void:
	# Aproxima: reduz size (índice menor)
	if _zoom_index > 0:
		_zoom_index -= 1
		_target_size = ZOOM_LEVELS[_zoom_index]


func zoom_out() -> void:
	# Afasta: aumenta size (índice maior)
	if _zoom_index < ZOOM_LEVELS.size() - 1:
		_zoom_index += 1
		_target_size = ZOOM_LEVELS[_zoom_index]


func set_zoom_index(idx: int, immediate: bool = false) -> void:
	_zoom_index = clampi(idx, 0, ZOOM_LEVELS.size() - 1)
	_target_size = ZOOM_LEVELS[_zoom_index]
	if immediate:
		size = _target_size


func get_zoom_index() -> int:
	return _zoom_index


func get_target_size() -> float:
	return _target_size


func _is_mouse_over_scroll_consumer() -> bool:
	var vp := get_viewport()
	if not vp:
		return false
	var tooltip := get_tree().get_first_node_in_group("item_tooltip") as Control
	if tooltip and tooltip.is_visible_in_tree() and tooltip.get_global_rect().has_point(vp.get_mouse_position()):
		return true
	var hovered := vp.gui_get_hovered_control()
	if not hovered or not hovered.is_visible_in_tree():
		return false
	var curr: Node = hovered
	while curr and curr is Control:
		if curr is ScrollContainer or curr is Tree or curr is ItemList:
			return true
		if curr.is_in_group("scroll_consume") or curr.is_in_group("ui_scroll_consumer"):
			return true
		if curr.name in ["Panel", "SettingsBox", "VideoSettings", "VideoSettingsMenu", "PauseMenu"]:
			return true
		if curr.name == "Panel" and curr.get_parent() and curr.get_parent().name == "InventoryMenu":
			return true
		curr = curr.get_parent()
	return true
