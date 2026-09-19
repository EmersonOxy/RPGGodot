extends Control
## Notificações de itens coletados em pilha vertical, abaixo do centro da tela.
## Três posições: passada (acima, menor), principal (meio, maior) e futura
## (abaixo, menor). Ao vencer o tempo, a principal encolhe e sobe para passada,
## a futura cresce e sobe para principal, e a passada antiga some com fade.


class PartialOutline extends Control:
	## Trecho da borda externa do painel: acompanha as extremidades externas do
	## card (lateral, topo e base, com cantos arredondados à esquerda) e fecha
	## com uma linha vertical antes do início do texto. A referência de fim é o
	## retângulo real do ícone, não um valor fixo.
	var card: Control
	var icon: Control
	var border_color := Color.WHITE
	var corner_radius := 10.0
	var line_width := 1.0
	var close_offset := 24.0

	func _draw() -> void:
		var w := line_width
		var hw := w * 0.5
		var r := minf(corner_radius, minf(size.x, size.y) * 0.5)
		var end_x := r + 1.0
		if is_instance_valid(icon) and is_instance_valid(card):
			var origin := get_global_rect().position
			end_x = icon.get_global_rect().end.x - origin.x + close_offset
		end_x = clampf(end_x, r + 1.0, size.x)
		# Lateral esquerda externa, altura total do painel.
		draw_line(Vector2(hw, r), Vector2(hw, size.y - r), border_color, w)
		# Canto superior esquerdo e topo externo.
		draw_arc(Vector2(r, r), r - hw, PI, PI * 1.5, 16, border_color, w, true)
		draw_line(Vector2(r, hw), Vector2(end_x, hw), border_color, w)
		# Canto inferior esquerdo e base externa.
		draw_arc(Vector2(r, size.y - r), r - hw, PI * 0.5, PI, 16, border_color, w, true)
		draw_line(Vector2(r, size.y - hw), Vector2(end_x, size.y - hw), border_color, w)


const RARITY_COLORS := {
	0: Color(0.88, 0.88, 0.85),
	1: Color(0.25, 0.90, 0.30),
	2: Color(0.30, 0.55, 1.00),
	3: Color(0.72, 0.30, 1.00),
	4: Color(1.00, 0.65, 0.08),
}

# Keyframes (tempo, valor) do deslocamento lateral pelo inventário.
const SHIFT_KEYFRAMES := [
	[0.0, 0.0],
	[0.22, 0.05],
	[0.5, 0.78],
	[0.8, 1.03],
	[1.0, 1.0],
]

const CARD_SIZE := Vector2(316.0, 56.0)
const CARD_X := 8.0
const SLOT_Y := [8.0, 92.0, 176.0]  # passada, principal, futura
const SMALL_SCALE := 0.72
const SMALL_ALPHA := 0.55

@export var display_time := 1.2
@export var fade_duration := 0.2
@export var rise_duration := 0.55
@export var intro_delay := 0.25
@export var follow_speed := 14.0
@export var shift_margin := 16.0

var _queue: Array = []
var _cards: Array = []  # [passada, principal, futura]; entradas podem ser null
var _main_active := false
var _main_elapsed := 0.0
var _rising := false
var _inventory_menu: Control
var _corner_position := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = -356.0
	offset_right = -24.0
	offset_top = -540.0
	offset_bottom = -300.0
	_remember_corner.call_deferred()
	Acquisitions.acquired.connect(_on_acquired)
	_bind_inventory.call_deferred()


func _remember_corner() -> void:
	_corner_position = position


func _bind_inventory() -> void:
	if not is_inside_tree():
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	_inventory_menu = scene.get_node_or_null("Interface/UIManager/InventoryMenu") as Control


func _spawn_card(entry: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.position = Vector2(CARD_X, SLOT_Y[2])
	card.pivot_offset = CARD_SIZE * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(0, 0, 0, 0.15)
	style.shadow_size = 10
	style.shadow_offset = Vector2(2, 4)
	card.add_theme_stylebox_override("panel", style)
	add_child(card)
	_build_card_content(card)
	card.set_meta("item", entry.item)
	card.set_meta("qty", entry.qty)
	_update_card(card, entry.item, entry.qty)
	return card


func _build_card_content(card: PanelContainer) -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	hbox.add_child(vbox)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	name_label.add_theme_constant_override("outline_size", 6)
	vbox.add_child(name_label)

	var qty_label := Label.new()
	qty_label.add_theme_font_size_override("font_size", 18)
	qty_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	qty_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	qty_label.add_theme_constant_override("outline_size", 5)
	qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(qty_label)

	card.set_meta("icon", icon)
	card.set_meta("name_label", name_label)
	card.set_meta("qty_label", qty_label)

	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(overlay)
	var outline := PartialOutline.new()
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outline.card = card
	outline.icon = icon
	overlay.add_child(outline)
	card.set_meta("outline", outline)


func _update_card(card: PanelContainer, item: ItemData, qty: int) -> void:
	var icon: TextureRect = card.get_meta("icon")
	if item.icon != null:
		icon.texture = item.icon
	else:
		var image := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
		image.fill(item.icon_color)
		icon.texture = ImageTexture.create_from_image(image)
	var name_label: Label = card.get_meta("name_label")
	name_label.text = item.display_name
	name_label.add_theme_color_override("font_color", RARITY_COLORS.get(item.rarity, RARITY_COLORS[0]))
	var qty_label: Label = card.get_meta("qty_label")
	qty_label.text = "×%d" % qty if qty > 1 else ""
	var outline: PartialOutline = card.get_meta("outline")
	var rarity_color: Color = RARITY_COLORS.get(item.rarity, RARITY_COLORS[0])
	rarity_color.a = 0.8
	outline.border_color = rarity_color
	outline.queue_redraw()


func _animate_card(card: PanelContainer, target_y: float, target_scale: float, target_alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "position:y", target_y, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE * target_scale, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate:a", target_alpha, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _fill_upcoming() -> void:
	if _cards.size() <= 2 or _cards[2] != null or _queue.is_empty():
		return
	var entry: Dictionary = _queue.pop_front()
	var card := _spawn_card(entry)
	_cards[2] = card
	card.modulate.a = 0.0
	card.scale = Vector2.ONE * SMALL_SCALE
	card.position = Vector2(CARD_X, SLOT_Y[2] + 20.0)
	var intro := create_tween()
	intro.set_parallel(true)
	intro.tween_property(card, "modulate:a", SMALL_ALPHA, fade_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro.tween_property(card, "position:y", SLOT_Y[2], fade_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _promote_upcoming() -> void:
	if not (_cards.size() > 2 and is_instance_valid(_cards[2])):
		return
	var card: PanelContainer = _cards[2]
	_cards[2] = null
	_cards[1] = card
	_rising = true
	var intro := create_tween()
	intro.tween_interval(intro_delay)
	intro.set_parallel(true)
	intro.tween_property(card, "position:y", SLOT_Y[1], rise_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro.tween_property(card, "scale", Vector2.ONE, rise_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro.tween_property(card, "modulate:a", 1.0, rise_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro.chain().tween_callback(_start_main)
	_fill_upcoming()


func _start_main() -> void:
	_rising = false
	_main_elapsed = 0.0
	_main_active = true
	_fill_upcoming()


func _advance_stack() -> void:
	_main_active = false
	var has_main: bool = _cards.size() > 1 and is_instance_valid(_cards[1])
	var has_next: bool = (_cards.size() > 2 and is_instance_valid(_cards[2])) or not _queue.is_empty()
	# A passada (acima) sai com fade.
	if _cards.size() > 0 and is_instance_valid(_cards[0]):
		var old_past: PanelContainer = _cards[0]
		_cards[0] = null
		var fade := create_tween()
		fade.tween_property(old_past, "modulate:a", 0.0, fade_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fade.tween_callback(old_past.queue_free)
	# A principal encolhe e sobe para passada, ou some se não há sucessora.
	if has_main:
		var old_main: PanelContainer = _cards[1]
		_cards[1] = null
		if has_next:
			_cards[0] = old_main
			_animate_card(old_main, SLOT_Y[0], SMALL_SCALE, SMALL_ALPHA, rise_duration)
		else:
			var fade := create_tween()
			fade.tween_property(old_main, "modulate:a", 0.0, fade_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			fade.tween_callback(old_main.queue_free)
	# A futura cresce e sobe para principal.
	if _cards.size() > 2 and is_instance_valid(_cards[2]):
		var next: PanelContainer = _cards[2]
		_cards[2] = null
		_cards[1] = next
		_animate_card(next, SLOT_Y[1], 1.0, 1.0, rise_duration)
		_main_elapsed = 0.0
		_main_active = true
	_fill_upcoming()
	_maybe_hide(fade_duration)


func _maybe_hide(delay: float) -> void:
	if _main_active or _rising or not _queue.is_empty():
		return
	if _cards.size() > 2 and is_instance_valid(_cards[2]):
		return
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_callback(func():
		if not _main_active and _queue.is_empty() and not _rising:
			hide()
			_cards = []
	)


func _on_acquired(item: ItemData, qty: int) -> void:
	# Empilha com a próxima pendente, com a principal (renovando o tempo) ou
	# com a futura já na tela.
	if not _queue.is_empty():
		var last: Dictionary = _queue[_queue.size() - 1]
		if last.item == item:
			last.qty += qty
			return
	elif _main_active and _cards.size() > 1 and is_instance_valid(_cards[1]) and _cards[1].get_meta("item") == item:
		_update_card(_cards[1], item, int(_cards[1].get_meta("qty")) + qty)
		_main_elapsed = 0.0
		return
	elif _cards.size() > 2 and is_instance_valid(_cards[2]) and _cards[2].get_meta("item") == item:
		_update_card(_cards[2], item, int(_cards[2].get_meta("qty")) + qty)
		return
	_queue.append({"item": item, "qty": qty})
	_ensure_stack()


func _ensure_stack() -> void:
	if _cards.is_empty():
		_cards = [null, null, null]
	if _cards.all(func(c): return c == null):
		# Primeira entrada: nasce já como principal, na hora da coleta.
		if _queue.is_empty():
			return
		var entry: Dictionary = _queue.pop_front()
		var card := _spawn_card(entry)
		_cards[1] = card
		card.modulate.a = 0.0
		card.scale = Vector2.ONE * SMALL_SCALE
		card.position = Vector2(CARD_X, SLOT_Y[1])
		show()
		_rising = true
		var intro := create_tween()
		intro.set_parallel(true)
		intro.tween_property(card, "modulate:a", 1.0, fade_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		intro.tween_property(card, "scale", Vector2.ONE, rise_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		intro.chain().tween_callback(_start_main)
		return
	_fill_upcoming()
	# Recuperação: se não há principal, promove a futura.
	if not _main_active and not _rising and _cards.size() > 2 and is_instance_valid(_cards[2]):
		_promote_upcoming()


func _process(delta: float) -> void:
	# Acompanha a aparição/movimento do inventário quadro a quadro.
	if is_instance_valid(_inventory_menu):
		var openness := 0.0
		if _inventory_menu.visible:
			openness = clampf(_inventory_menu.modulate.a, 0.0, 1.0)
		var shifted_x := _target_shifted_x()
		var k := _shift_keyframe_value(openness)
		var target_x := lerpf(_corner_position.x, shifted_x, k)
		var weight := 1.0 - exp(-follow_speed * delta)
		position.x = lerpf(position.x, target_x, weight)
	# Relógio da notificação principal.
	if _main_active:
		_main_elapsed += delta
		if _main_elapsed >= display_time:
			_advance_stack()


func _shift_keyframe_value(t: float) -> float:
	var keys := SHIFT_KEYFRAMES
	if t <= keys[0][0]:
		return keys[0][1]
	for i in range(1, keys.size()):
		var prev: Array = keys[i - 1]
		var next: Array = keys[i]
		if t <= next[0]:
			var local: float = (t - prev[0]) / maxf(next[0] - prev[0], 0.0001)
			var eased := smoothstep(0.0, 1.0, local)
			return lerpf(prev[1], next[1], eased)
	return keys[keys.size() - 1][1]


func _target_shifted_x() -> float:
	var panel_rect: Rect2 = _inventory_menu.get_node("Panel").get_global_rect()
	var my_rect := get_global_rect()
	if my_rect.size.x <= 0.0:
		return _corner_position.x
	return panel_rect.position.x - my_rect.size.x - shift_margin
