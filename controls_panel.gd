@tool
extends PanelContainer
## Entries read InputMap. Fallbacks mirror inputs handled directly by existing scripts.
@export var entries: Array[Dictionary] = [
	{"actions": ["move_forward", "move_left", "move_backward", "move_right"], "description": "Mover"},
	{"actions": ["run"], "description": "Correr"},
	{"actions": ["toggle_weapon"], "description": "Sacar / guardar arma"},
	{"actions": [], "mouse": MOUSE_BUTTON_LEFT, "description": "Mover / selecionar / interagir"},
	{"actions": ["manual_attack"], "description": "Atacar"},
	{"actions": ["toggle_target_lock"], "description": "Travar / destravar alvo"},
	{"actions": ["hold_target_facing"], "description": "Segurar: mirar no alvo/cursor"},
	{"actions": ["target_lock_left", "target_lock_right"], "description": "Trocar alvo: esquerda / direita"},
	{"actions": [], "mouse": MOUSE_BUTTON_WHEEL_UP, "description": "Zoom"},
	{"actions": ["toggle_inventory"], "description": "Inventário"},
	{"actions": ["toggle_pause"], "description": "Menu / pausa"},
]
const KEY_ICONS := {
	KEY_W: preload("res://assets/SimpleKeys/SimpleKeys/Classic/Light/Single PNGs/W.png"),
	KEY_A: preload("res://assets/SimpleKeys/SimpleKeys/Classic/Light/Single PNGs/A.png"),
	KEY_S: preload("res://assets/SimpleKeys/SimpleKeys/Classic/Light/Single PNGs/S.png"),
	KEY_D: preload("res://assets/SimpleKeys/SimpleKeys/Classic/Light/Single PNGs/D.png"),
	KEY_SHIFT: preload("res://assets/SimpleKeys/SimpleKeys/Classic/Light/Single PNGs/SHIFT.png"),
	KEY_X: preload("res://assets/SimpleKeys/SimpleKeys/Classic/Light/Single PNGs/X.png"),
	KEY_I: preload("res://assets/SimpleKeys/SimpleKeys/Classic/Light/Single PNGs/I.png"),
}
var _settings: Node
var _inventory: Control

func _ready() -> void:
	refresh_controls()
	if Engine.is_editor_hint():
		return
	# Destaque visual reduzido: dicas discretas no canto.
	modulate = Color(1, 1, 1, 0.72)
	_settings = get_node("/root/DisplaySettings")
	_settings.interface_settings_applied.connect(_update_visibility)
	_settings.interface_settings_applied.connect(refresh_controls)
	var keybinds := get_node_or_null("/root/Keybinds")
	if keybinds:
		keybinds.keybinds_applied.connect(refresh_controls)
	refresh_controls()
	_update_visibility()
	_bind_inventory.call_deferred()

func _bind_inventory() -> void:
	var scene := get_tree().current_scene
	if scene:
		_inventory = scene.get_node_or_null("Interface/UIManager/InventoryMenu") as Control
		if _inventory:
			_inventory.visibility_changed.connect(_update_visibility)
	_update_visibility()

func _update_visibility() -> void:
	visible = _settings.show_controls and not (is_instance_valid(_inventory) and _inventory.visible)

func binding_events(entry: Dictionary) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	for action in entry.get("actions", []):
		var events: Array = []
		if Engine.is_editor_hint():
			events = ProjectSettings.get_setting("input/" + action, {}).get("events", [])
		elif InputMap.has_action(action):
			events = InputMap.action_get_events(action)
		for event in events:
			if event is InputEventKey or event is InputEventMouseButton:
				result.append(event)
	if result.is_empty() and entry.has("key"):
		var event := InputEventKey.new()
		event.keycode = entry.key
		result.append(event)
	if result.is_empty() and entry.has("mouse"):
		var event := InputEventMouseButton.new()
		event.button_index = entry.mouse
		result.append(event)
	return result

func refresh_controls() -> void:
	var rows := get_node_or_null("Margin/Rows")
	if not rows:
		return
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	for entry in entries:
		var movement_mode: String = _settings.movement_input_mode if is_instance_valid(_settings) else "hybrid"
		if movement_mode == "mouse" and "move_forward" in entry.get("actions", []):
			continue
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		rows.add_child(row)
		var bindings := HBoxContainer.new()
		bindings.custom_minimum_size.x = 94
		bindings.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bindings.add_theme_constant_override("separation", 2)
		row.add_child(bindings)
		var events := binding_events(entry)
		for event in events:
			_add_binding(bindings, event)
		if events.is_empty():
			_add_text(bindings, "—")
		var description := Label.new()
		description.text = entry.get("description", "")
		if movement_mode == "wasd" and entry.get("mouse", -1) == MOUSE_BUTTON_LEFT:
			description.text = "Selecionar / coletar perto"
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(description)

func _add_binding(parent: Control, event: InputEvent) -> void:
	if event is InputEventKey:
		var key: int = event.physical_keycode if event.physical_keycode else event.keycode
		if KEY_ICONS.has(key) and not (event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed):
			var icon := TextureRect.new()
			icon.texture = KEY_ICONS[key]
			icon.custom_minimum_size = Vector2(icon.texture.get_width() * 1.25, 20)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(icon)
		else:
			_add_text(parent, "Esc" if key == KEY_ESCAPE else event.as_text().replace(" - Physical", "").replace(" (Physical)", ""))
	elif event is InputEventMouseButton:
		var labels := {MOUSE_BUTTON_LEFT: "Mouse Esq.", MOUSE_BUTTON_RIGHT: "Mouse Dir.", MOUSE_BUTTON_MIDDLE: "Mouse Meio", MOUSE_BUTTON_WHEEL_UP: "Scroll", MOUSE_BUTTON_WHEEL_DOWN: "Scroll"}
		_add_text(parent, labels.get(event.button_index, event.as_text()))

func _add_text(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate = Color(0.68, 0.72, 0.8)
	parent.add_child(label)
