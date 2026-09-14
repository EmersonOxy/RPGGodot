extends VBoxContainer

const CURSORS = preload("res://cursor_catalog.gd")
@onready var cursor_option: OptionButton = $Grid/CursorOption
@onready var controls_option: CheckButton = $Grid/ControlsOption
@onready var status: Label = $Hint
var settings: Node

func _ready() -> void:
	settings = get_node("/root/DisplaySettings")
	for style in CURSORS.STYLES:
		cursor_option.add_item(style.label)
	_sync()
	cursor_option.item_selected.connect(_on_cursor_selected)
	controls_option.toggled.connect(_on_controls_toggled)
	settings.interface_settings_applied.connect(_sync)

func _sync() -> void:
	cursor_option.select(CURSORS.index_for(settings.cursor_style))
	controls_option.set_pressed_no_signal(settings.show_controls)

func _on_cursor_selected(index: int) -> void:
	_save(CURSORS.STYLES[index].id, settings.show_controls)

func _on_controls_toggled(enabled: bool) -> void:
	_save(settings.cursor_style, enabled)

func _save(style_id: String, enabled: bool) -> void:
	var error: Error = settings.apply_interface_settings(style_id, enabled)
	status.text = "Interface: alterações salvas imediatamente." if error == OK else "Não foi possível salvar a interface (%d)." % error
	_sync()
