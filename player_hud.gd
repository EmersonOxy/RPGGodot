extends Control

signal action_slot_selected(slot_index: int, slot_data: Variant)

@onready var _hp_bar: ProgressBar = $HPContainer/HPRow/HPFrame/BarContainer/HPBar
@onready var _hp_label: Label = $HPContainer/HPRow/HPFrame/BarContainer/HPLabel
@onready var _hp_ghost: ProgressBar = $HPContainer/HPRow/HPFrame/BarContainer/HPGhost
@onready var _level_label: Label = $HPContainer/HPRow/LevelBadge/LvLabel
@onready var _xp_bar: ProgressBar = $HPContainer/XPBar
@onready var _xp_label: Label = $HPContainer/XPBar/XPLabel
@onready var _action_bar: HBoxContainer = $ActionBar

var _hp_tween: Tween
var _xp_tween: Tween
var _hp_ghost_tween: Tween

var _current_hp: int = 100
var _max_hp: int = 100

# Action Bar state
var _action_slots: Array[PanelContainer] = []
var _action_labels: Array[Label] = []
var _action_data: Array = [null, null, null, null, null]
var _selected_action_slot: int = -1
var _hovered_action_slot: int = -1

var _style_slot_normal: StyleBoxFlat
var _style_slot_hover: StyleBoxFlat
var _style_slot_selected: StyleBoxFlat
var _style_slot_selected_hover: StyleBoxFlat


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_hp_changed)
		if player.has_signal("xp_changed"):
			player.xp_changed.connect(_on_xp_changed)
		if player.has_signal("level_up"):
			player.level_up.connect(_on_level_up)
		# Init values
		_max_hp = player.max_health
		_current_hp = player.health
		_hp_bar.max_value = _max_hp
		_hp_bar.value = _current_hp
		_hp_ghost.max_value = _max_hp
		_hp_ghost.value = _current_hp
		_hp_label.text = "%d / %d" % [_current_hp, _max_hp]
		_level_label.text = str(player.level)

	_setup_action_bar()


func _setup_action_bar() -> void:
	_create_action_slot_styles()
	_action_slots.clear()
	_action_labels.clear()

	if _action_bar:
		_action_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for i in range(1, 6):
		var slot := _action_bar.get_node_or_null("Slot%d" % i) as PanelContainer if _action_bar else null
		if slot:
			_action_slots.append(slot)
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
			slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

			var idx := i - 1
			slot.mouse_entered.connect(_on_action_slot_mouse_entered.bind(idx))
			slot.mouse_exited.connect(_on_action_slot_mouse_exited.bind(idx))
			slot.gui_input.connect(_on_action_slot_gui_input.bind(idx))

			var lbl := slot.get_node_or_null("Slot%dLabel" % i) as Label
			_action_labels.append(lbl)
			if lbl:
				lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

			_update_slot_style(idx)


func _create_action_slot_styles() -> void:
	_style_slot_normal = StyleBoxFlat.new()
	_style_slot_normal.bg_color = Color(0.05, 0.04, 0.03, 0.85)
	_style_slot_normal.border_color = Color(0.3, 0.25, 0.12, 1)
	_style_slot_normal.border_width_left = 1
	_style_slot_normal.border_width_top = 1
	_style_slot_normal.border_width_right = 1
	_style_slot_normal.border_width_bottom = 1
	_style_slot_normal.corner_radius_top_left = 3
	_style_slot_normal.corner_radius_top_right = 3
	_style_slot_normal.corner_radius_bottom_left = 3
	_style_slot_normal.corner_radius_bottom_right = 3

	_style_slot_hover = _style_slot_normal.duplicate()
	_style_slot_hover.bg_color = Color(0.12, 0.10, 0.07, 0.95)
	_style_slot_hover.border_color = Color(0.75, 0.65, 0.25, 1)
	_style_slot_hover.border_width_left = 2
	_style_slot_hover.border_width_top = 2
	_style_slot_hover.border_width_right = 2
	_style_slot_hover.border_width_bottom = 2

	_style_slot_selected = _style_slot_normal.duplicate()
	_style_slot_selected.bg_color = Color(0.18, 0.14, 0.07, 0.98)
	_style_slot_selected.border_color = Color(1.0, 0.85, 0.3, 1)
	_style_slot_selected.border_width_left = 2
	_style_slot_selected.border_width_top = 2
	_style_slot_selected.border_width_right = 2
	_style_slot_selected.border_width_bottom = 2

	_style_slot_selected_hover = _style_slot_selected.duplicate()
	_style_slot_selected_hover.bg_color = Color(0.24, 0.18, 0.09, 1.0)
	_style_slot_selected_hover.border_color = Color(1.0, 0.95, 0.5, 1)
	_style_slot_selected_hover.border_width_left = 3
	_style_slot_selected_hover.border_width_top = 3
	_style_slot_selected_hover.border_width_right = 3
	_style_slot_selected_hover.border_width_bottom = 3


func _on_action_slot_mouse_entered(slot_idx: int) -> void:
	_hovered_action_slot = slot_idx
	_update_slot_style(slot_idx)

	var data = _action_data[slot_idx] if slot_idx < _action_data.size() else null
	if data != null:
		var tooltip_node := get_tree().get_first_node_in_group("item_tooltip")
		if tooltip_node and slot_idx < _action_slots.size():
			var slot_rect := _action_slots[slot_idx].get_global_rect()
			if data is ItemData:
				tooltip_node.show_tooltip(data, slot_rect)
			elif data is Dictionary and data.has("item"):
				var qty: int = data.get("quantity", 1)
				if qty > 1:
					tooltip_node.show_tooltip_with_qty(data.item, qty, slot_rect)
				else:
					tooltip_node.show_tooltip(data.item, slot_rect)


func _on_action_slot_mouse_exited(slot_idx: int) -> void:
	if _hovered_action_slot == slot_idx:
		_hovered_action_slot = -1
	_update_slot_style(slot_idx)

	var tooltip_node := get_tree().get_first_node_in_group("item_tooltip")
	if tooltip_node:
		tooltip_node.hide_tooltip()


func _on_action_slot_gui_input(event: InputEvent, slot_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		toggle_action_slot_selection(slot_idx)
		get_viewport().set_input_as_handled()


func toggle_action_slot_selection(slot_idx: int) -> void:
	if _selected_action_slot == slot_idx:
		select_action_slot(-1)
	else:
		select_action_slot(slot_idx)


func select_action_slot(slot_idx: int) -> void:
	var old_selected := _selected_action_slot
	_selected_action_slot = slot_idx

	if old_selected >= 0 and old_selected < _action_slots.size():
		_update_slot_style(old_selected)
	if _selected_action_slot >= 0 and _selected_action_slot < _action_slots.size():
		_update_slot_style(_selected_action_slot)

	var data = _action_data[_selected_action_slot] if _selected_action_slot >= 0 and _selected_action_slot < _action_data.size() else null
	action_slot_selected.emit(_selected_action_slot, data)


func get_selected_action_slot() -> int:
	return _selected_action_slot


func set_action_slot_data(slot_idx: int, data: Variant) -> void:
	if slot_idx >= 0 and slot_idx < _action_data.size():
		_action_data[slot_idx] = data
		_update_slot_display(slot_idx)


func get_action_slot_data(slot_idx: int) -> Variant:
	if slot_idx >= 0 and slot_idx < _action_data.size():
		return _action_data[slot_idx]
	return null


func clear_action_slot(slot_idx: int) -> void:
	set_action_slot_data(slot_idx, null)


func _update_slot_display(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= _action_slots.size():
		return
	var data = _action_data[slot_idx]
	var lbl: Label = _action_labels[slot_idx] if slot_idx < _action_labels.size() else null
	if data == null:
		if lbl:
			lbl.text = str(slot_idx + 1)
	else:
		if data is ItemData:
			if lbl:
				lbl.text = "%d\n%s" % [slot_idx + 1, data.display_name.substr(0, 4)]
		elif data is Dictionary and data.has("name"):
			if lbl:
				lbl.text = "%d\n%s" % [slot_idx + 1, str(data.name).substr(0, 4)]


func _update_slot_style(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= _action_slots.size():
		return
	var slot := _action_slots[slot_idx]
	var lbl: Label = _action_labels[slot_idx] if slot_idx < _action_labels.size() else null

	var is_selected := (_selected_action_slot == slot_idx)
	var is_hovered := (_hovered_action_slot == slot_idx)

	var style: StyleBoxFlat
	var text_color: Color

	if is_selected and is_hovered:
		style = _style_slot_selected_hover
		text_color = Color(1.0, 0.95, 0.5, 1)
	elif is_selected:
		style = _style_slot_selected
		text_color = Color(1.0, 0.85, 0.35, 1)
	elif is_hovered:
		style = _style_slot_hover
		text_color = Color(0.85, 0.75, 0.45, 1)
	else:
		style = _style_slot_normal
		text_color = Color(0.45, 0.4, 0.3, 1)

	slot.add_theme_stylebox_override("panel", style)
	if lbl:
		lbl.add_theme_color_override("font_color", text_color)


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or get_tree().paused:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var idx := -1
		if event.keycode >= KEY_1 and event.keycode <= KEY_5:
			idx = event.keycode - KEY_1
		elif event.keycode >= KEY_KP_1 and event.keycode <= KEY_KP_5:
			idx = event.keycode - KEY_KP_1
		if idx >= 0 and idx < _action_slots.size():
			toggle_action_slot_selection(idx)
			get_viewport().set_input_as_handled()


func _on_hp_changed(current: int, maximum: int) -> void:
	var old_hp := _current_hp
	_current_hp = current
	_max_hp = maximum
	_hp_bar.max_value = maximum
	_hp_label.text = "%d / %d" % [current, maximum]

	if _hp_tween:
		_hp_tween.kill()
	if _hp_ghost_tween:
		_hp_ghost_tween.kill()

	if current < old_hp:
		# DANO: barra verde cai rápido, ghost fica no valor antigo e depois anima
		_hp_ghost.value = old_hp
		_hp_ghost.max_value = maximum
		# Barra verde cai rapidamente
		_hp_tween = create_tween()
		_hp_tween.tween_property(_hp_bar, "value", float(current), 0.1).set_ease(Tween.EASE_OUT)
		# Ghost espera 0.25s depois anima para o novo valor
		_hp_ghost_tween = create_tween()
		_hp_ghost_tween.tween_interval(0.25)
		_hp_ghost_tween.tween_property(_hp_ghost, "value", float(current), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	elif current > old_hp:
		# CURA: barra verde sobe suavemente, sem ghost
		_hp_ghost.value = current
		_hp_ghost.max_value = maximum
		_hp_tween = create_tween()
		_hp_tween.tween_property(_hp_bar, "value", float(current), 0.3).set_ease(Tween.EASE_OUT)
	else:
		_hp_bar.value = current
		_hp_ghost.value = current


func _on_xp_changed(current: int, maximum: int) -> void:
	_xp_bar.max_value = maximum
	_xp_label.text = "%d / %d" % [current, maximum]
	if _xp_tween:
		_xp_tween.kill()
	_xp_tween = create_tween()
	_xp_tween.tween_property(_xp_bar, "value", float(current), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_level_up(new_level: int) -> void:
	_level_label.text = str(new_level)
	# Flash no badge
	var badge := _level_label.get_parent()
	if badge is PanelContainer:
		var flash := create_tween()
		flash.tween_property(badge, "modulate", Color(1.5, 1.3, 0.5), 0.15)
		flash.tween_property(badge, "modulate", Color.WHITE, 0.3)


func set_level(value: int) -> void:
	_level_label.text = str(value)
