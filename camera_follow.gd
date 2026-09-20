extends Camera3D
## Segue o Player com X/Z instantâneos e Y suavizado: escadas, rampas e
## plataformas não dão mais solavanco vertical. Rotação nunca muda.
## Suporta zoom ortográfico suave com níveis discretos estilo Project Zomboid.

const ZOOM_LEVELS: Array[float] = [6.0, 8.0, 10.0, 12.0, 15.0, 19.0, 23.0, 27.0]
const DEFAULT_ZOOM_INDEX: int = 5
const REFERENCE_CAMERA_SIZE: float = ZOOM_LEVELS[DEFAULT_ZOOM_INDEX]

## Quanto maior, mais rápida a transição vertical (5 ≈ suave sem atraso).
@export var vertical_smooth_speed: float = 5.0
## Velocidade de interpolação do zoom ortográfico.
@export var zoom_smooth_speed: float = 10.0

var _target: Node3D = null
var _offset := Vector3(12.0, 12.8, 12.0)
var _zoom_index: int = DEFAULT_ZOOM_INDEX
var _target_size: float = ZOOM_LEVELS[DEFAULT_ZOOM_INDEX]
var _scroll_enabled := true
var _hit_time := 0.0
var _hit_offset := Vector2.ZERO
const HIT_DURATION := 0.12
const LOCK_ZOOM_MULTIPLIER := 0.865
const LOCK_FOCUS_SPEED := 6.0
var _lock_follow_enabled := true
var _lock_active := false
var _lock_focus := Vector3.ZERO
const PAN_MAX_DISTANCE := 4.0 # World units in the camera plane; not user-configurable.
const PAN_SMOOTH_SPEED := 12.0
var _pan_dragging := false
var _pan_goal := Vector2.ZERO
var _pan_offset := Vector2.ZERO


func play_hit_impulse(direction: Vector3, strength: float = 1.0) -> void:
	var screen_direction := Vector2(direction.dot(global_basis.x), direction.dot(global_basis.y))
	if screen_direction.length_squared() < 0.001:
		screen_direction = Vector2(0.5, 1.0)
	_hit_offset = screen_direction.normalized() * size * 0.010 * clampf(strength, 0.0, 1.0)
	_hit_time = HIT_DURATION


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
	if ds:
		_lock_follow_enabled = ds.lock_camera_follow
		ds.interface_settings_applied.connect(func(): _lock_follow_enabled = ds.lock_camera_follow)

	_target_size = ZOOM_LEVELS[_zoom_index]
	size = _target_size
	_update_projection_offsets()


func _process(delta: float) -> void:
	_hit_time = maxf(0.0, _hit_time - delta)
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
	_update_lock_focus(delta)
	_update_pan(delta)

	# Interpolação suave do Camera3D.size entre os níveis de zoom
	var effective_size := _effective_target_size()
	if not is_equal_approx(size, effective_size):
		size = lerpf(size, effective_size, 1.0 - exp(-zoom_smooth_speed * delta))
		if absf(size - effective_size) < 0.01:
			size = effective_size
	_update_projection_offsets()

func _effective_target_size() -> float:
	return maxf(ZOOM_LEVELS[0], _target_size * LOCK_ZOOM_MULTIPLIER) if _lock_active else _target_size

func _update_lock_focus(delta: float) -> void:
	var locked: Node3D = null
	if _lock_follow_enabled and is_instance_valid(_target) and _target.has_method("get_locked_target"):
		locked = _target.get_locked_target()
	_lock_active = is_instance_valid(locked)
	var desired := Vector3.ZERO
	if _lock_active:
		# Shift partway toward the enemy, limiting how far the player leaves the focus.
		desired = (locked.global_position - _target.global_position) * 0.4
		desired = desired.limit_length(minf(4.0, _effective_target_size() * 0.2))
	_lock_focus = _lock_focus.lerp(desired, 1.0 - exp(-LOCK_FOCUS_SPEED * delta))
	if _lock_focus.distance_squared_to(desired) < 0.000001:
		_lock_focus = desired


func _update_projection_offsets() -> void:
	# Scale the off-axis composition with the orthographic span, not camera distance.
	# At the reference zoom this correction is exactly zero. Keep hit shake additive.
	var ratio_delta := size / REFERENCE_CAMERA_SIZE - 1.0
	var axes := global_basis.orthonormalized()
	var hit_weight := pow(_hit_time / HIT_DURATION, 2.0)
	h_offset = _offset.dot(axes.x) * ratio_delta + _lock_focus.dot(axes.x) + _pan_offset.x + _hit_offset.x * hit_weight
	v_offset = _offset.dot(axes.y) * ratio_delta + _lock_focus.dot(axes.y) + _pan_offset.y + _hit_offset.y * hit_weight

func _pan_blocked() -> bool:
	if get_tree().paused or not is_instance_valid(_target) or _target.get("is_dead") == true or get_viewport().gui_is_dragging():
		return true
	var inventory := _target.get_parent().get_node_or_null("Interface/UIManager/InventoryMenu")
	return (inventory != null and inventory.get("_is_open") == true) or get_viewport().gui_get_hovered_control() != null

func _cancel_pan() -> void:
	_pan_dragging = false
	_pan_goal = Vector2.ZERO

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_pan()

func _input(event: InputEvent) -> void:
	# Release must reach us even over GUI. Motion never moves the player.
	if event.is_action_released("camera_pan"):
		_cancel_pan()
	elif event is InputEventMouseMotion and _pan_dragging:
		if _pan_blocked():
			_cancel_pan()
		else:
			_drag_pan(event.relative)
			get_viewport().set_input_as_handled()

func _drag_pan(relative: Vector2) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var span := viewport_size.y if keep_aspect == KEEP_HEIGHT else viewport_size.x
	var units_per_pixel := size / maxf(span, 1.0)
	_pan_goal = (_pan_goal + Vector2(-relative.x, relative.y) * units_per_pixel).limit_length(PAN_MAX_DISTANCE)

func _update_pan(delta: float) -> void:
	if _pan_dragging and (_pan_blocked() or not Input.is_action_pressed("camera_pan")):
		_cancel_pan()
	_pan_offset = _pan_offset.lerp(_pan_goal, 1.0 - exp(-PAN_SMOOTH_SPEED * delta))
	if _pan_offset.distance_squared_to(_pan_goal) < 0.000001:
		_pan_offset = _pan_goal


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_pan"):
		if not _pan_blocked():
			_pan_dragging = true
			_pan_goal = _pan_offset
			get_viewport().set_input_as_handled()
		return
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
		size = _effective_target_size()
		_update_projection_offsets()


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
