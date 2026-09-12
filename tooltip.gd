extends PanelContainer

@onready var _name_label: Label = $VBox/NameLabel
@onready var _type_label: Label = $VBox/TypeLabel
@onready var _rarity_label: Label = $VBox/RarityLabel
@onready var _desc_label: Label = $VBox/DescLabel
@onready var _qty_label: Label = $VBox/QtyLabel


func _ready() -> void:
	add_to_group("item_tooltip")
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_tooltip(item, at_position: Vector2) -> void:
	_name_label.text = item.display_name
	_type_label.text = item.get_type_name()
	_rarity_label.text = item.get_rarity_name()
	_desc_label.text = item.description
	_qty_label.visible = false
	show()
	_position_at(at_position)


func show_tooltip_with_qty(item, quantity: int, at_position: Vector2) -> void:
	_name_label.text = item.display_name
	_type_label.text = item.get_type_name()
	_rarity_label.text = item.get_rarity_name()
	_desc_label.text = item.description
	_qty_label.text = "Quantidade: %d" % quantity
	_qty_label.visible = true
	show()
	_position_at(at_position)


func hide_tooltip() -> void:
	hide()


func _position_at(pos: Vector2) -> void:
	var viewport_size := get_viewport_rect().size
	var tooltip_size := size
	var x := pos.x
	var y := pos.y
	if x + tooltip_size.x > viewport_size.x:
		x = pos.x - tooltip_size.x
	if y + tooltip_size.y > viewport_size.y:
		y = pos.y - tooltip_size.y
	if x < 0:
		x = 0
	if y < 0:
		y = 0
	position = Vector2(x, y)
