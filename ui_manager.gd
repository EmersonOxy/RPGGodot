extends Node

const MENU_PAUSE := "pause"
const MENU_INVENTORY := "inventory"

var _menus := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_menus[MENU_PAUSE] = get_node("PauseMenu")
	_menus[MENU_INVENTORY] = get_node("InventoryMenu")
	close_all_menus()


func open_menu(menu_name: String) -> void:
	if _menus.has(menu_name):
		(_menus[menu_name] as Control).show()


func close_menu(menu_name: String) -> void:
	if _menus.has(menu_name):
		(_menus[menu_name] as Control).hide()


func close_all_menus() -> void:
	for menu_name in _menus:
		close_menu(menu_name)


func is_open(menu_name: String) -> bool:
	if _menus.has(menu_name):
		return (_menus[menu_name] as Control).visible
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("toggle_pause"):
		if is_open(MENU_PAUSE) or get_tree().paused:
			_resume_game()
		else:
			_pause_game()
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I:
			_toggle_inventory()
			get_viewport().set_input_as_handled()


func _toggle_inventory() -> void:
	if get_tree().paused:
		return
	var inv = _menus[MENU_INVENTORY]
	if inv.has_method("toggle"):
		inv.toggle()
	elif inv.visible:
		inv.hide()
	else:
		inv.show()


func _pause_game() -> void:
	get_tree().paused = true
	open_menu(MENU_PAUSE)


func _resume_game() -> void:
	get_tree().paused = false
	close_menu(MENU_PAUSE)
