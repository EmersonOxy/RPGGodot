extends VBoxContainer
## Seção "CONTROLES" do menu de configurações: remapeamento de teclas com detecção de conflitos.

@onready var _grid: GridContainer = $Scroll/Grid
@onready var _hint: Label = $Hint

var _kb: Node
var _rows: Dictionary = {}
var _listening_action := ""
var _listening_button: Button


func _ready() -> void:
	_kb = get_node_or_null("/root/Keybinds")
	_build_rows()
	if _kb:
		_kb.keybinds_applied.connect(_refresh_all)
	_refresh_all()


func _build_rows() -> void:
	if not _kb:
		return
	for entry in _kb.ACTIONS:
		var action: String = entry.action
		var label := Label.new()
		label.text = entry.label
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(label)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var bind_button := Button.new()
		bind_button.custom_minimum_size = Vector2(150, 32)
		bind_button.text = "—"
		bind_button.pressed.connect(_on_bind_pressed.bind(action, bind_button))
		row.add_child(bind_button)
		var reset_button := Button.new()
		reset_button.custom_minimum_size = Vector2(64, 32)
		reset_button.text = "Padrão"
		reset_button.tooltip_text = "Restaurar tecla padrão"
		reset_button.pressed.connect(_on_reset_pressed.bind(action))
		row.add_child(reset_button)
		_grid.add_child(row)
		_rows[action] = bind_button
	var all_label := Label.new()
	all_label.text = "Todos os atalhos"
	_grid.add_child(all_label)
	var all_button := Button.new()
	all_button.custom_minimum_size = Vector2(150, 32)
	all_button.text = "Restaurar padrões"
	all_button.pressed.connect(_on_reset_all_pressed)
	_grid.add_child(all_button)


func _on_bind_pressed(action: String, button: Button) -> void:
	if _listening_action == action:
		_cancel_listening()
		_hint.text = "Remapeamento cancelado."
		return
	_cancel_listening()
	_listening_action = action
	_listening_button = button
	button.disabled = true
	button.text = "Pressione uma tecla..."
	_hint.text = "Pressione a nova tecla ou botão do mouse. Esc ou botão direito cancela."


func _on_reset_pressed(action: String) -> void:
	_cancel_listening()
	if _kb:
		_kb.reset_action(action)
		_refresh_row(action)
		_hint.text = "Atalho padrão restaurado para %s." % _kb.action_label(action)


func _on_reset_all_pressed() -> void:
	_cancel_listening()
	if _kb:
		_kb.reset_all()
		_refresh_all()
		_hint.text = "Todos os atalhos restaurados para o padrão."


func _cancel_listening() -> void:
	_listening_action = ""
	if _listening_button and is_instance_valid(_listening_button):
		_listening_button.disabled = false
	_listening_button = null
	_refresh_all()


func _key_event(source: InputEventKey) -> InputEventKey:
	var key := InputEventKey.new()
	if source.physical_keycode != 0:
		key.physical_keycode = source.physical_keycode
	else:
		key.keycode = source.keycode
	key.ctrl_pressed = source.ctrl_pressed
	key.alt_pressed = source.alt_pressed
	key.shift_pressed = source.shift_pressed
	key.meta_pressed = source.meta_pressed
	return key


func _handle_result(result: Dictionary) -> void:
	if result.get("ok", false):
		var action := _listening_action
		_cancel_listening()
		_refresh_row(action)
		_hint.text = "Atalho atualizado e salvo."
	else:
		var conflict: String = result.get("conflict", "")
		if conflict == "reserved":
			_hint.text = "Botão reservado para movimento/seleção; escolha outro."
		elif conflict != "":
			_hint.text = "Conflito: tecla já usada por %s. Pressione outra." % _kb.action_label(conflict)
		else:
			_hint.text = "Não foi possível salvar o atalho."


func _unhandled_input(event: InputEvent) -> void:
	if _listening_action == "":
		return
	if event is InputEventKey:
		if event.echo:
			return
		if event.physical_keycode == KEY_ESCAPE:
			_cancel_listening()
			_hint.text = "Remapeamento cancelado."
			get_viewport().set_input_as_handled()
			return
		_handle_result(_kb.bind(_listening_action, _key_event(event)))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_listening()
			_hint.text = "Remapeamento cancelado."
			get_viewport().set_input_as_handled()
			return
		if event.button_index in _kb.RESERVED_MOUSE:
			_hint.text = "Botão reservado para movimento/seleção; escolha outro."
			get_viewport().set_input_as_handled()
			return
		_handle_result(_kb.bind(_listening_action, event.duplicate()))
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton:
		_hint.text = "Controles de jogo não são suportados nesta versão."
		get_viewport().set_input_as_handled()


func _refresh_row(action: String) -> void:
	if _kb and _rows.has(action):
		_rows[action].text = _kb.get_binding_text(action)


func _refresh_all() -> void:
	for action in _rows:
		_refresh_row(action)
