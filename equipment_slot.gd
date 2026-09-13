extends "res://inventory_slot.gd"

@export var equipment_slot: ItemData.EquipmentSlot = ItemData.EquipmentSlot.NONE
@export var slot_label: String = ""
var _equipment: Node

var _drag_feedback: Node

func _ready() -> void:
	_drag_feedback = preload("res://slot_drag_feedback.gd").new()
	add_child(_drag_feedback)

func _notification(what: int) -> void:
	if not is_instance_valid(_drag_feedback):
		return
	if what == NOTIFICATION_DRAG_BEGIN:
		_drag_feedback.begin_drag()
	elif what == NOTIFICATION_DRAG_END:
		_drag_feedback.end_drag()



func setup_equipment(component: Node) -> void:
	_equipment = component
	_equipment.changed.connect(_update_visual)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_update_visual()

func _update_visual() -> void:
	_display_item(_equipment.get_item(equipment_slot), 1)
	if _item == null:
		_label.text = slot_label
	if is_visible_in_tree() and get_global_rect().has_point(get_global_mouse_position()):
		_on_mouse_exited()
		_on_mouse_entered()

func _get_drag_data(_at_position: Vector2) -> Variant:
	if _equipment == null or _item == null or get_tree().paused or _equipment.get_parent().is_dead:
		return null
	_on_mouse_exited()
	var preview := Label.new()
	preview.text = _item.display_name
	preview.add_theme_font_size_override("font_size", 22)
	preview.add_theme_color_override("font_outline_color", Color.BLACK)
	preview.add_theme_constant_override("outline_size", 6)
	set_drag_preview(preview)
	return {"kind": "equipment_item", "equipment": _equipment, "slot": equipment_slot, "item": _item}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return _equipment != null and _equipment.can_accept(data, equipment_slot)

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(at_position, data):
		_equipment.equip_from_bag(data, equipment_slot)

