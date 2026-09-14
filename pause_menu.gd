extends Control
## Pause Menu: gerencia a tela de pausa e a navegação para o menu de configurações de vídeo.

@onready var _manager: Node = get_parent()
@onready var _title: Label = $Center/Panel/Margin/VBox/Title
@onready var _btn_resume: Button = $Center/Panel/Margin/VBox/BtnResume
@onready var _btn_settings: Button = $Center/Panel/Margin/VBox/BtnSettings
@onready var _btn_main_menu: Button = $Center/Panel/Margin/VBox/BtnMainMenu
@onready var _btn_quit: Button = $Center/Panel/Margin/VBox/BtnQuit
@onready var _settings_box: VideoSettings = $Center/Panel/Margin/VBox/SettingsBox


func _ready() -> void:
	hide()
	_btn_resume.pressed.connect(_on_resume_pressed)
	_btn_settings.pressed.connect(_on_settings_pressed)
	_btn_quit.pressed.connect(_on_quit_pressed)
	if _settings_box:
		_settings_box.closed.connect(_on_settings_closed)
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if not visible:
		_settings_box.load_from_settings()
		reset_view()


func _on_resume_pressed() -> void:
	get_tree().paused = false
	if _manager and _manager.has_method("close_menu"):
		_manager.close_menu("pause")
	else:
		hide()


func _on_settings_pressed() -> void:
	_open_settings()


func _open_settings() -> void:
	_btn_resume.hide()
	_btn_settings.hide()
	_btn_main_menu.hide()
	_btn_quit.hide()
	_title.text = "CONFIGURAÇÕES"
	if _settings_box:
		_settings_box.load_from_settings()
		_settings_box.show()


func _on_settings_closed() -> void:
	if _settings_box:
		_settings_box.hide()
	_title.text = "PAUSADO"
	_btn_resume.show()
	_btn_settings.show()
	_btn_main_menu.show()
	_btn_quit.show()


func _on_quit_pressed() -> void:
	get_tree().quit()


func reset_view() -> void:
	if _settings_box and _settings_box.visible:
		_settings_box.hide()
	if _title:
		_title.text = "PAUSADO"
	if _btn_resume:
		_btn_resume.show()
	if _btn_settings:
		_btn_settings.show()
	if _btn_main_menu:
		_btn_main_menu.show()
	if _btn_quit:
		_btn_quit.show()
