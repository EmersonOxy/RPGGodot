extends Node

const MENU_PAUSE := "pause"
const MENU_INVENTORY := "inventory"

var _menus := {}
var _hold_opened := false


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
	var player := get_tree().get_first_node_in_group("player")
	if player and player.is_dead and not player.death_sequence_finished:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("toggle_pause"):
		if is_open(MENU_PAUSE) or get_tree().paused:
			_resume_game()
		else:
			_pause_game()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("toggle_hud"):
		var ds := get_node_or_null("/root/DisplaySettings")
		if ds:
			ds.apply_interface_settings(ds.cursor_style, ds.show_controls, not ds.hud_visible, ds.cursor_size)
		get_viewport().set_input_as_handled()
	# Tab segurado abre o inventário; soltar fecha.
	if event.is_action_pressed("hold_inventory") and not event.is_echo():
		if get_tree().paused:
			_hold_opened = false
		elif not is_open(MENU_INVENTORY):
			_open_inventory()
			_hold_opened = true
		get_viewport().set_input_as_handled()
	elif event.is_action_released("hold_inventory"):
		if _hold_opened and not get_tree().paused:
			_close_inventory()
		_hold_opened = false
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("toggle_inventory"):
		_toggle_inventory()
		get_viewport().set_input_as_handled()


func _toggle_inventory() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.is_dead:
		return
	if get_tree().paused:
		return
	var inv = _menus[MENU_INVENTORY]
	if inv.has_method("toggle"):
		inv.toggle()
	elif inv.visible:
		inv.hide()
	else:
		inv.show()


func _open_inventory() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.is_dead:
		return
	var inv = _menus[MENU_INVENTORY]
	if inv.has_method("open"):
		inv.open()
	elif not inv.visible:
		inv.show()


func _close_inventory() -> void:
	var inv = _menus[MENU_INVENTORY]
	if inv.has_method("close"):
		inv.close()
	elif inv.visible:
		inv.hide()


func _pause_game() -> void:
	get_tree().paused = true
	open_menu(MENU_PAUSE)


func _resume_game() -> void:
	get_tree().paused = false
	close_menu(MENU_PAUSE)
