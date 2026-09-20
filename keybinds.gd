extends Node
## Gerenciador global de remapeamento de teclas com persistência em user://keybinds.cfg.

signal keybinds_applied

const CONFIG_PATH := "user://keybinds.cfg"
const SECTION := "binds"

const ACTIONS: Array[Dictionary] = [
	{"action": "move_forward", "label": "Mover — frente"},
	{"action": "move_backward", "label": "Mover — trás"},
	{"action": "move_left", "label": "Mover — esquerda"},
	{"action": "move_right", "label": "Mover — direita"},
	{"action": "run", "label": "Correr"},
	{"action": "toggle_weapon", "label": "Sacar / guardar arma"},
	{"action": "manual_attack", "label": "Atacar"},
	{"action": "toggle_target_lock", "label": "Travar / destravar alvo"},
	{"action": "hold_target_facing", "label": "Segurar: mirar no alvo/cursor"},
	{"action": "target_lock_left", "label": "Trocar alvo — esquerda"},
	{"action": "target_lock_right", "label": "Trocar alvo — direita"},
	{"action": "toggle_inventory", "label": "Inventário"},
	{"action": "hold_inventory", "label": "Inventário (segurar)"},
	{"action": "toggle_hud", "label": "Mostrar / esconder HUD"},
	{"action": "toggle_pause", "label": "Menu / pausa"},
	{"action": "action_slot_1", "label": "Atalho de item 1"},
	{"action": "action_slot_2", "label": "Atalho de item 2"},
	{"action": "action_slot_3", "label": "Atalho de item 3"},
	{"action": "action_slot_4", "label": "Atalho de item 4"},
	{"action": "action_slot_5", "label": "Atalho de item 5"},
]

const RESERVED_MOUSE := [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]

var _defaults: Dictionary = {}


func _ready() -> void:
	for entry in ACTIONS:
		var action: String = entry.action
		var events: Array[InputEvent] = []
		for event in InputMap.action_get_events(action):
			events.append(event.duplicate())
		_defaults[action] = events
	load_binds(CONFIG_PATH)


func action_label(action: String) -> String:
	for entry in ACTIONS:
		if entry.action == action:
			return entry.label
	return action


func event_to_data(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"kind": "key", "physical": event.physical_keycode, "keycode": event.keycode, "ctrl": event.ctrl_pressed, "alt": event.alt_pressed, "shift": event.shift_pressed, "meta": event.meta_pressed}
	if event is InputEventMouseButton:
		return {"kind": "mouse", "button": event.button_index}
	return {"kind": "none"}


func data_to_event(data: Dictionary) -> InputEvent:
	match data.get("kind", "none"):
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = int(data.get("physical", 0))
			key.keycode = int(data.get("keycode", 0))
			key.ctrl_pressed = bool(data.get("ctrl", false))
			key.alt_pressed = bool(data.get("alt", false))
			key.shift_pressed = bool(data.get("shift", false))
			key.meta_pressed = bool(data.get("meta", false))
			return key
		"mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = int(data.get("button", 0))
			return mouse
	return null


func event_matches(event: InputEvent, data: Dictionary) -> bool:
	if data.get("kind") == "key" and event is InputEventKey:
		var physical := int(data.get("physical", 0))
		var keycode := int(data.get("keycode", 0))
		var key_match := false
		if physical != 0:
			key_match = event.physical_keycode == physical
		elif keycode != 0:
			key_match = event.keycode == keycode
		if not key_match:
			return false
		return event.ctrl_pressed == bool(data.get("ctrl", false)) and event.alt_pressed == bool(data.get("alt", false)) and event.shift_pressed == bool(data.get("shift", false)) and event.meta_pressed == bool(data.get("meta", false))
	if data.get("kind") == "mouse" and event is InputEventMouseButton:
		return event.button_index == int(data.get("button", 0))
	return false


func find_conflict(action: String, event: InputEvent) -> String:
	var data := event_to_data(event)
	for entry in ACTIONS:
		var other: String = entry.action
		if other == action or not InputMap.has_action(other):
			continue
		for existing in InputMap.action_get_events(other):
			if event_matches(existing, data):
				return other
	return ""


func bind(action: String, event: InputEvent, path: String = CONFIG_PATH) -> Dictionary:
	if not InputMap.has_action(action):
		return {"ok": false, "conflict": ""}
	if event is InputEventMouseButton and event.button_index in RESERVED_MOUSE:
		return {"ok": false, "conflict": "reserved"}
	var conflict := find_conflict(action, event)
	if conflict != "":
		return {"ok": false, "conflict": conflict}
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	var error := save_binds(path)
	keybinds_applied.emit()
	return {"ok": error == OK, "conflict": ""}


func unbind(action: String, path: String = CONFIG_PATH) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	save_binds(path)
	keybinds_applied.emit()


func reset_action(action: String, path: String = CONFIG_PATH) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	for event in _defaults.get(action, []):
		InputMap.action_add_event(action, event)
	save_binds(path)
	keybinds_applied.emit()


func reset_all(path: String = CONFIG_PATH) -> void:
	for entry in ACTIONS:
		InputMap.action_erase_events(entry.action)
		for event in _defaults.get(entry.action, []):
			InputMap.action_add_event(entry.action, event)
	save_binds(path)
	keybinds_applied.emit()


func load_binds(path: String = CONFIG_PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for entry in ACTIONS:
		var action: String = entry.action
		var data: Variant = cfg.get_value(SECTION, action, null)
		if not (data is Dictionary) or data.get("kind", "none") == "none":
			continue
		var event := data_to_event(data)
		if event == null:
			continue
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, event)


func save_binds(path: String = CONFIG_PATH) -> Error:
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(path):
		cfg.load(path)
	for entry in ACTIONS:
		var action: String = entry.action
		var events := InputMap.action_get_events(action)
		cfg.set_value(SECTION, action, event_to_data(events[0]) if not events.is_empty() else {"kind": "none"})
	return cfg.save(path)


func get_binding_text(action: String) -> String:
	if not InputMap.has_action(action):
		return "—"
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "—"
	var event: InputEvent = events[0]
	if event is InputEventKey:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key == KEY_ESCAPE:
			return "Esc"
		return event.as_text().replace(" - Physical", "").replace(" (Physical)", "")
	if event is InputEventMouseButton:
		var labels := {MOUSE_BUTTON_RIGHT: "Mouse Dir.", MOUSE_BUTTON_MIDDLE: "Mouse Meio"}
		return labels.get(event.button_index, event.as_text())
	return "—"
