extends PanelContainer

var _item = null
var _slot_index: int = -1
var _inventory = null
@onready var _label: Label = $VBox/Label
@onready var _qty_label: Label = $VBox/QtyLabel


func setup(inventory, index: int) -> void:
	if is_instance_valid(_inventory) and _inventory.updated.is_connected(_update_visual):
		_inventory.updated.disconnect(_update_visual)
	_inventory = inventory
	_slot_index = index
	_inventory.updated.connect(_update_visual)
	_update_visual()
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)


func _update_visual() -> void:
	var slot = _inventory.get_slot(_slot_index)
	_display_item(slot.item, slot.quantity)
	if get_global_rect().has_point(get_global_mouse_position()) and is_visible_in_tree():
		_on_mouse_exited()
		_on_mouse_entered()

func _display_item(item: ItemData, qty: int) -> void:
	_item = item
	if _item:
		_label.text = _item.display_name
		_qty_label.text = "x%d" % qty if qty > 1 else ""
		_qty_label.visible = qty > 1
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.1, 0.07, 0.95)
		style.border_color = Color(0.5, 0.42, 0.2, 1)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 3
		style.corner_radius_top_right = 3
		style.corner_radius_bottom_left = 3
		style.corner_radius_bottom_right = 3
		add_theme_stylebox_override("panel", style)
	else:
		_label.text = ""
		_qty_label.text = ""
		_qty_label.visible = false
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.04, 0.03, 0.85)
		style.border_color = Color(0.22, 0.19, 0.12, 1)
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.corner_radius_top_left = 3
		style.corner_radius_top_right = 3
		style.corner_radius_bottom_left = 3
		style.corner_radius_bottom_right = 3
		add_theme_stylebox_override("panel", style)


func _on_mouse_entered() -> void:
	if _item:
		var tooltip_node := get_tree().get_first_node_in_group("item_tooltip")
		if tooltip_node:
			var slot = _inventory.get_slot(_slot_index) if _inventory else null
			var qty: int = slot["quantity"] if (slot and slot.has("quantity")) else 1
			if qty > 1:
				tooltip_node.show_tooltip_with_qty(_item, qty, get_global_rect())
			else:
				tooltip_node.show_tooltip(_item, get_global_rect())


func _on_mouse_exited() -> void:
	var tooltip_node := get_tree().get_first_node_in_group("item_tooltip")
	if tooltip_node:
		tooltip_node.hide_tooltip()

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not is_instance_valid(_inventory) or _item == null or get_tree().paused or _inventory.get_parent().is_dead:
		return null
	_on_mouse_exited()
	var amount: int = _inventory.get_slot(_slot_index).quantity
	var preview := Label.new()
	preview.text = "%s  x%d" % [_item.display_name, amount]
	preview.add_theme_font_size_override("font_size", 22)
	preview.add_theme_color_override("font_outline_color", Color.BLACK)
	preview.add_theme_constant_override("outline_size", 6)
	set_drag_preview(preview)
	return {"kind": "inventory_item", "inventory": _inventory, "index": _slot_index, "item": _item, "quantity": amount}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not is_instance_valid(_inventory):
		return false
	if data is Dictionary and data.get("kind") == "equipment_item" and is_instance_valid(_inventory):
		return _inventory.get_parent().equipment.can_unequip(data, _slot_index)
	return data is Dictionary and data.get("kind") == "inventory_item" and data.get("inventory") == _inventory and not get_tree().paused and not _inventory.get_parent().is_dead and _inventory.matches_slot(data.index, data.item, data.quantity)

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(at_position, data):
		if data.kind == "equipment_item":
			_inventory.get_parent().equipment.unequip_to_bag(data, _slot_index)
		else:
			_inventory.move_item(data.index, _slot_index)

