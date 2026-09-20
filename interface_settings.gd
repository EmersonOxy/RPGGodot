extends VBoxContainer

const CURSORS = preload("res://cursor_catalog.gd")
@onready var cursor_option: OptionButton = $Grid/CursorOption
@onready var controls_option: CheckButton = $Grid/ControlsOption
@onready var status: Label = $Hint
var settings: Node
var _hud_option: CheckButton
var _cursor_size_slider: HSlider
var _movement_option: OptionButton
var _lock_camera_option: OptionButton
var _difficulty_option: OptionButton

func _ready() -> void:
	settings = get_node("/root/DisplaySettings")
	for style in CURSORS.STYLES:
		cursor_option.add_item(style.label)
	_build_extra_controls()
	_sync()
	cursor_option.item_selected.connect(_on_cursor_selected)
	controls_option.toggled.connect(_on_controls_toggled)
	settings.interface_settings_applied.connect(_sync)

func _build_extra_controls() -> void:
	var difficulty_label := Label.new()
	difficulty_label.text = "Dificuldade"
	$Grid.add_child(difficulty_label)
	_difficulty_option = OptionButton.new()
	_difficulty_option.name = "Difficulty"
	var difficulty := get_node("/root/Difficulty")
	for id in difficulty.ORDER:
		_difficulty_option.add_item(difficulty.get_label(id))
	$Grid.add_child(_difficulty_option)
	_difficulty_option.item_selected.connect(_on_difficulty_selected)
	var movement_label := Label.new()
	movement_label.text = "Movimentação"
	$Grid.add_child(movement_label)
	_movement_option = OptionButton.new()
	_movement_option.name = "MovementMode"
	for title in ["Mouse", "WASD", "Híbrido (mouse + WASD)"]:
		_movement_option.add_item(title)
	$Grid.add_child(_movement_option)
	_movement_option.item_selected.connect(_on_movement_selected)
	var camera_label := Label.new()
	camera_label.text = "Câmera ao travar alvo"
	$Grid.add_child(camera_label)
	_lock_camera_option = OptionButton.new()
	_lock_camera_option.name = "LockCameraMode"
	_lock_camera_option.add_item("Livre")
	_lock_camera_option.add_item("Acompanhar alvo (+ zoom suave)")
	$Grid.add_child(_lock_camera_option)
	_lock_camera_option.item_selected.connect(_on_lock_camera_selected)
	var hud_label := Label.new()
	hud_label.text = "Mostrar HUD"
	hud_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	$Grid.add_child(hud_label)
	_hud_option = CheckButton.new()
	_hud_option.button_pressed = true
	$Grid.add_child(_hud_option)
	_hud_option.toggled.connect(_on_hud_toggled)

	var size_label := Label.new()
	size_label.text = "Tamanho do cursor"
	size_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	$Grid.add_child(size_label)
	_cursor_size_slider = HSlider.new()
	_cursor_size_slider.min_value = 0.5
	_cursor_size_slider.max_value = 1.5
	_cursor_size_slider.step = 0.05
	_cursor_size_slider.custom_minimum_size = Vector2(220, 32)
	_cursor_size_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	$Grid.add_child(_cursor_size_slider)
	_cursor_size_slider.value_changed.connect(_on_cursor_size_changed)
	_cursor_size_slider.drag_ended.connect(_on_cursor_size_drag_ended)

func _sync() -> void:
	if _difficulty_option:
		var difficulty := get_node("/root/Difficulty")
		_difficulty_option.select(difficulty.ORDER.find(difficulty.current))
	if _lock_camera_option:
		_lock_camera_option.select(1 if settings.lock_camera_follow else 0)
	if _movement_option:
		_movement_option.select(settings.MOVEMENT_MODES.find(settings.movement_input_mode))
	cursor_option.select(CURSORS.index_for(settings.cursor_style))
	controls_option.set_pressed_no_signal(settings.show_controls)
	if _hud_option:
		_hud_option.set_pressed_no_signal(settings.hud_visible)
	if _cursor_size_slider:
		_cursor_size_slider.set_value_no_signal(settings.cursor_size)

func _on_cursor_selected(index: int) -> void:
	_save(CURSORS.STYLES[index].id, settings.show_controls, settings.hud_visible, settings.cursor_size)


func _on_difficulty_selected(index: int) -> void:
	var difficulty := get_node("/root/Difficulty")
	var error: Error = difficulty.set_difficulty(difficulty.ORDER[index])
	status.text = "Dificuldade: aplicada e salva." if error == OK else "Não foi possível salvar a dificuldade (%d)." % error
	_sync()

func _on_movement_selected(index: int) -> void:
	var error: Error = settings.apply_movement_mode(settings.MOVEMENT_MODES[index])
	status.text = "Movimentação: aplicada e salva." if error == OK else "Não foi possível salvar a movimentação (%d)." % error
	_sync()

func _on_lock_camera_selected(index: int) -> void:
	var error: Error = settings.apply_lock_camera_follow(index == 1)
	status.text = "Câmera: aplicada e salva." if error == OK else "Não foi possível salvar a câmera (%d)." % error
	_sync()

func _on_controls_toggled(enabled: bool) -> void:
	_save(settings.cursor_style, enabled, settings.hud_visible, settings.cursor_size)

func _on_hud_toggled(enabled: bool) -> void:
	_save(settings.cursor_style, settings.show_controls, enabled, settings.cursor_size)

func _on_cursor_size_changed(value: float) -> void:
	settings.set_cursor_size(value)

func _on_cursor_size_drag_ended(value_changed: bool) -> void:
	if value_changed:
		settings.save_settings()

func _save(style_id: String, controls_visible: bool, hud_visible_value: bool, cursor_size_value: float) -> void:
	var error: Error = settings.apply_interface_settings(style_id, controls_visible, hud_visible_value, cursor_size_value)
	status.text = "Interface: alterações salvas imediatamente." if error == OK else "Não foi possível salvar a interface (%d)." % error
	_sync()
