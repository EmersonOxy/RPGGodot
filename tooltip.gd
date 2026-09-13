extends PanelContainer

const RARITY_COLORS := {
	0: Color(0.88, 0.88, 0.85),   # COMMON - cinza claro / branco
	1: Color(0.25, 0.90, 0.30),   # UNCOMMON - verde vivo
	2: Color(0.30, 0.55, 1.00),   # RARE - azul evidente
	3: Color(0.72, 0.30, 1.00),   # EPIC - roxo evidente
	4: Color(1.00, 0.65, 0.08),   # LEGENDARY - dourado / laranja
}

@onready var _name_label: Label = $VBox/NameLabel
@onready var _type_label: Label = $VBox/TypeLabel
@onready var _rarity_label: Label = $VBox/RarityLabel
@onready var _desc_label: Label = $VBox/DescLabel
@onready var _qty_label: Label = $VBox/QtyLabel


func _ready() -> void:
	add_to_group("item_tooltip")
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ignore_mouse_recursive(self)


func _ignore_mouse_recursive(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse_recursive(child)


func show_tooltip(item, target = null) -> void:
	if item == null:
		hide()
		return
	_populate(item)
	_qty_label.visible = false
	show()
	_position_at_target(target)


func show_tooltip_with_qty(item, quantity: int, target = null) -> void:
	if item == null:
		hide()
		return
	_populate(item)
	_qty_label.text = "Quantidade: %d" % quantity
	_qty_label.visible = true
	show()
	_position_at_target(target)


func _populate(item) -> void:
	_name_label.text = item.display_name
	_type_label.text = item.get_type_name() if item.has_method("get_type_name") else ""
	_rarity_label.text = item.get_rarity_name() if item.has_method("get_rarity_name") else ""
	_desc_label.text = item.description if "description" in item else ""
	var bonuses: String = item.get_bonus_text()
	if not bonuses.is_empty():
		_desc_label.text += "\n" + bonuses

	var rarity_idx: int = item.rarity if "rarity" in item else 0
	var rarity_color: Color = RARITY_COLORS.get(rarity_idx, RARITY_COLORS[0])
	_rarity_label.add_theme_color_override("font_color", rarity_color)
	_name_label.add_theme_color_override("font_color", rarity_color.lightened(0.2))


func hide_tooltip() -> void:
	hide()


func _position_at(pos: Vector2) -> void:
	_position_at_target(pos)


func _position_at_target(target: Variant) -> void:
	reset_size()
	var tip_size := get_combined_minimum_size()
	if tip_size.x <= 0 or tip_size.y <= 0:
		tip_size = size
	if tip_size.x < 300:
		tip_size.x = 300

	var viewport_size := get_viewport_rect().size
	var margin := 10.0
	var x: float = 0.0
	var y: float = 0.0

	if target is Rect2:
		var slot_rect: Rect2 = target
		var space_right := viewport_size.x - (slot_rect.position.x + slot_rect.size.x)
		var space_left := slot_rect.position.x

		# Se o slot estiver na metade direita da tela, abre para a esquerda
		# evitando totalmente cobrir o slot e prevenindo qualquer loop de hover/flicker
		if slot_rect.position.x + slot_rect.size.x * 0.5 > viewport_size.x * 0.5:
			if space_left >= tip_size.x + margin:
				x = slot_rect.position.x - tip_size.x - margin
			else:
				x = maxf(margin, slot_rect.position.x - tip_size.x - margin)
		else:
			# Slot na metade esquerda: abre para a direita
			if space_right >= tip_size.x + margin:
				x = slot_rect.position.x + slot_rect.size.x + margin
			else:
				x = slot_rect.position.x + slot_rect.size.x + margin

		y = slot_rect.position.y
	elif target is Vector2:
		var pos: Vector2 = target
		if pos.x > viewport_size.x * 0.5:
			x = pos.x - tip_size.x - margin
		else:
			x = pos.x + margin
		y = pos.y
	else:
		var mouse_pos := get_global_mouse_position()
		if mouse_pos.x > viewport_size.x * 0.5:
			x = mouse_pos.x - tip_size.x - margin
		else:
			x = mouse_pos.x + margin
		y = mouse_pos.y

	# Clamping seguro dentro da viewport
	x = clampf(x, margin, maxf(margin, viewport_size.x - tip_size.x - margin))
	y = clampf(y, margin, maxf(margin, viewport_size.y - tip_size.y - margin))

	global_position = Vector2(x, y)
