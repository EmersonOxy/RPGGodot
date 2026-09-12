extends Control
## Pause Menu: só cuida dos próprios botões. Pausa/despausa e ESC global
## ficam no UIManager (Node pai).

@onready var _manager: Node = get_parent()
@onready var _settings_box: Control = $Center/Panel/Margin/VBox/SettingsBox


func _ready() -> void:
	hide()
	$Center/Panel/Margin/VBox/BtnResume.pressed.connect(_on_resume_pressed)
	$Center/Panel/Margin/VBox/BtnSettings.pressed.connect(_on_settings_pressed)
	$Center/Panel/Margin/VBox/BtnQuit.pressed.connect(_on_quit_pressed)


func _on_resume_pressed() -> void:
	get_tree().paused = false
	_manager.close_menu("pause")


func _on_settings_pressed() -> void:
	_settings_box.visible = not _settings_box.visible


func _on_quit_pressed() -> void:
	get_tree().quit()
