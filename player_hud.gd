extends Control

signal action_slot_selected(slot_index: int, slot_data: Variant)

@onready var _hp_bar: ProgressBar = $HPContainer/HPRow/HPFrame/BarContainer/HPBar
@onready var _hp_label: Label = $HPContainer/HPRow/HPFrame/BarContainer/HPLabel
@onready var _hp_ghost: ProgressBar = $HPContainer/HPRow/HPFrame/BarContainer/HPGhost
@onready var _level_label: Label = $HPContainer/HPRow/LevelBadge/LvLabel
@onready var _xp_bar: ProgressBar = $HPContainer/XPBar
@onready var _xp_label: Label = $HPContainer/XPBar/XPLabel
@onready var _action_bar: HBoxContainer = $ActionBar

var _actions: Node
var _stamina_bar: ProgressBar
var _stamina_fade: Tween
var _feedback_tweens: Dictionary = {}

var _hp_tween: Tween
var _xp_tween: Tween
var _hp_ghost_tween: Tween
var _damage_vignette: TextureRect
var _vignette_tween: Tween

var _current_hp: int = 100
var _max_hp: int = 100

# Action Bar state
var _action_slots: Array[PanelContainer] = []
var _action_labels: Array[Label] = []
var _action_icons: Array[TextureRect] = []
var _action_data: Array = [null, null, null, null, null]
var _action_qtys: Array = [0, 0, 0, 0, 0]
var _selected_action_slot: int = -1
var _hovered_action_slot: int = -1

var _style_slot_normal: StyleBoxFlat
var _style_slot_hover: StyleBoxFlat
var _style_slot_selected: StyleBoxFlat
var _style_slot_selected_hover: StyleBoxFlat


func _ready() -> void:
	add_to_group("player_hud")
	_setup_damage_vignette()
	var ds := get_node_or_null("/root/DisplaySettings")
	if ds:
		ds.interface_settings_applied.connect(_on_interface_settings)
		_on_interface_settings()
	var player := get_tree().get_first_node_in_group("player")
	if player:
		_setup_stamina(player)
		_actions = player.action_bar
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_hp_changed)
		if player.has_signal("took_hit"):
			player.took_hit.connect(_on_player_hit)
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
	if _actions:
		_actions.updated.connect(_refresh_actions)
		_actions.used.connect(_on_action_used)
		_refresh_actions()
	# Atualiza a hotbar quando qualquer preview termina de gerar.
	if not Acquisitions.icon_ready.is_connected(_on_item_icon_ready):
		Acquisitions.icon_ready.connect(_on_item_icon_ready)


func _on_item_icon_ready(_item: ItemData) -> void:
	_refresh_actions()


func _on_interface_settings() -> void:
	var ds := get_node_or_null("/root/DisplaySettings")
	if ds:
		visible = ds.hud_visible


func _setup_stamina(player: Node) -> void:
	_stamina_bar = ProgressBar.new()
	_stamina_bar.name = "StaminaBar"
	_stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_bar.show_percentage = false
	_stamina_bar.step = 0.0
	add_child(_stamina_bar)
	_stamina_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_stamina_bar.offset_left = -150.0
	_stamina_bar.offset_right = 150.0
	_stamina_bar.offset_top = -179.0
	_stamina_bar.offset_bottom = -169.0
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.06, 0.08, 0.06, 0.85)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.45, 0.8, 0.25)
	_stamina_bar.add_theme_stylebox_override("background", background)
	_stamina_bar.add_theme_stylebox_override("fill", fill)
	_stamina_bar.max_value = player.max_stamina
	_stamina_bar.value = player.stamina
	_stamina_bar.modulate.a = 0.0 if player.stamina >= player.max_stamina else 1.0
	player.stamina_changed.connect(_on_stamina_changed)


func _setup_damage_vignette() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.72, 1.0])
	gradient.colors = PackedColorArray([Color(0.8, 0.0, 0.0, 0.0), Color(0.7, 0.0, 0.0, 0.12), Color(0.7, 0.0, 0.0, 0.85)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 128
	texture.height = 128
	_damage_vignette = TextureRect.new()
	_damage_vignette.name = "DamageVignette"
	_damage_vignette.texture = texture
	_damage_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_damage_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_vignette.modulate.a = 0.0
	add_child(_damage_vignette)

func _on_player_hit() -> void:
	if _damage_vignette == null:
		return
	if _vignette_tween:
		_vignette_tween.kill()
	_damage_vignette.modulate.a = 0.9
	_vignette_tween = create_tween()
	_vignette_tween.tween_property(_damage_vignette, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_stamina_changed(current: float, maximum: float) -> void:
	var was_full := _stamina_bar.value >= _stamina_bar.max_value
	var is_full := current >= maximum
	_stamina_bar.max_value = maximum
	_stamina_bar.value = current
	if was_full == is_full:
		return
	if _stamina_fade:
		_stamina_fade.kill()
	_stamina_fade = create_tween()
	if is_full:
		_stamina_fade.tween_interval(0.6)
	_stamina_fade.tween_property(_stamina_bar, "modulate:a", 0.0 if is_full else 1.0, 0.2)


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
			slot.setup(_actions, idx)
			slot.mouse_entered.connect(_on_action_slot_mouse_entered.bind(idx))
			slot.mouse_exited.connect(_on_action_slot_mouse_exited.bind(idx))
			slot.gui_input.connect(_on_action_slot_gui_input.bind(idx))

			var lbl := slot.get_node_or_null("Slot%dLabel" % i) as Label
			_action_labels.append(lbl)
			if lbl:
				lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

			var icon := TextureRect.new()
			icon.name = "ItemIcon"
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.visible = false
			slot.add_child(icon)
			_action_icons.append(icon)

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
	var item: ItemData = _actions.get_item(slot_idx) if _actions else null
	var tip := get_tree().get_first_node_in_group("item_tooltip")
	if tip and item:
		tip.show_tooltip_with_qty(item, _actions.inventory.count_item(item), _action_slots[slot_idx].get_global_rect())

func _on_action_slot_mouse_exited(slot_idx: int) -> void:
	if _hovered_action_slot == slot_idx:
		_hovered_action_slot = -1
	_update_slot_style(slot_idx)

	var tooltip_node := get_tree().get_first_node_in_group("item_tooltip")
	if tooltip_node:
		tooltip_node.hide_tooltip()


func _on_action_slot_gui_input(event: InputEvent, slot_idx: int) -> void:
	if not event is InputEventMouseButton or not event.pressed or get_tree().paused or _actions == null or _actions.get_parent().is_dead:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_actions.clear_slot(slot_idx)
	elif event.button_index == MOUSE_BUTTON_LEFT:
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
	if _actions == null:
		return
	if data == null:
		_actions.clear_slot(slot_idx)
	elif data is ItemData:
		_actions.assign_item(slot_idx, data)

func get_action_slot_data(slot_idx: int) -> Variant:
	return _actions.get_item(slot_idx) if _actions else null

func clear_action_slot(slot_idx: int) -> void:
	set_action_slot_data(slot_idx, null)

func _refresh_actions() -> void:
	for i in _action_slots.size():
		var new_item: ItemData = _actions.get_item(i)
		var old_item: ItemData = _action_data[i]
		var new_qty: int = _actions.inventory.count_item(new_item) if new_item else 0
		var old_qty: int = _action_qtys[i]
		_action_data[i] = new_item
		_action_qtys[i] = new_qty
		_update_slot_display(i)
		# Polimento visual: pop ao equipar na barra e pulse quando a pilha cresce.
		if new_item != null and new_item != old_item:
			_pop_action_slot(i)
		elif new_item != null and new_qty > old_qty:
			_pulse_action_label(i)
	if _hovered_action_slot >= 0:
		var tip := get_tree().get_first_node_in_group("item_tooltip")
		if tip:
			tip.hide_tooltip()
		_on_action_slot_mouse_entered(_hovered_action_slot)


func _pop_action_slot(slot_idx: int) -> void:
	var slot := _action_slots[slot_idx]
	slot.pivot_offset = slot.size * 0.5
	slot.scale = Vector2.ONE * 1.1
	slot.modulate.a = 0.85
	var tween := slot.create_tween()
	tween.set_parallel(true)
	tween.tween_property(slot, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(slot, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _pulse_action_label(slot_idx: int) -> void:
	var label := _action_labels[slot_idx]
	if label.has_meta("pop_tween") and label.get_meta("pop_tween") != null:
		(label.get_meta("pop_tween") as Tween).kill()
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE * 1.15
	var tween := label.create_tween()
	label.set_meta("pop_tween", tween)
	tween.tween_property(label, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _update_slot_display(slot_idx: int) -> void:
	var item: ItemData = _actions.get_item(slot_idx)
	var label := _action_labels[slot_idx]
	var icon: TextureRect = _action_icons[slot_idx] if slot_idx < _action_icons.size() else null
	label.add_theme_font_size_override("font_size", 13 if item else 17)
	if item != null and item.icon != null:
		# Com ícone, o slot mostra apenas número e quantidade (sem o nome).
		label.text = "%d\nx%d" % [slot_idx + 1, _actions.inventory.count_item(item)]
		# Ícone compartilhado com o inventário: ocupa a metade superior do slot.
		icon.texture = item.icon
		icon.visible = true
		icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		icon.offset_left = 6
		icon.offset_top = 4
		icon.offset_right = -6
		icon.offset_bottom = 0
		label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	else:
		label.text = "%d\n%s\nx%d" % [slot_idx + 1, item.display_name.left(6), _actions.inventory.count_item(item)] if item else str(slot_idx + 1)
		icon.visible = false
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if item != null:
			_ensure_item_icon(item)
	_update_slot_style(slot_idx)


func _ensure_item_icon(item: ItemData) -> void:
	if item.icon != null or item.world_scene == null or item.has_meta("generating_icon"):
		return
	item.set_meta("generating_icon", true)
	ItemPreviewGenerator.generate_preview(item, self, func(_tex): _refresh_actions())

func _on_action_used(index: int) -> void:
	select_action_slot(index)
	if _feedback_tweens.has(index):
		_feedback_tweens[index].kill()
	var slot := _action_slots[index]
	slot.modulate = Color(1.7, 1.5, 0.8)
	var tween := create_tween()
	_feedback_tweens[index] = tween
	tween.tween_property(slot, "modulate", Color.WHITE, 0.25)

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
	if not is_visible_in_tree() or get_tree().paused or _actions == null or event.is_echo():
		return
	for i in 5:
		if event.is_action_pressed("action_slot_%d" % (i + 1)):
			_actions.use_slot(i)
			get_viewport().set_input_as_handled()
			return

func _on_hp_changed(current: int, maximum: int) -> void:
	var old_hp := _current_hp
	_current_hp = current
	_max_hp = maximum
	_hp_bar.max_value = maximum
	_hp_ghost.max_value = maximum
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
