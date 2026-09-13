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
	var item = _equipment.get_item(equipment_slot)
	if item != null and item.icon == null and item.world_scene != null and not item.has_meta("generating_icon"):
		item.set_meta("generating_icon", true)
		ItemPreviewGenerator.generate_preview(item, self, func(_tex): _update_visual())
		
	_display_item(item, 1)
	if _item == null:
		_label.text = slot_label
	if is_visible_in_tree() and get_global_rect().has_point(get_global_mouse_position()):
		_on_mouse_exited()
		_on_mouse_entered()

func _get_drag_data(_at_position: Vector2) -> Variant:
	if _equipment == null or _item == null or get_tree().paused or _equipment.get_parent().is_dead:
		return null
	_on_mouse_exited()
	var preview: Control
	if _item.icon != null:
		var tex := TextureRect.new()
		tex.texture = _item.icon
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var s: Vector2i = _item.inventory_size
		tex.size = Vector2(s.x * 36 + (s.x - 1) * 2, s.y * 36 + (s.y - 1) * 2)
		tex.modulate = Color(1, 1, 1, 0.7)
		preview = tex
	else:
		var lbl := Label.new()
		lbl.text = _item.display_name
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 6)
		preview = lbl
	set_drag_preview(preview)
	return {"kind": "equipment_item", "equipment": _equipment, "slot": equipment_slot, "item": _item}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return _equipment != null and _equipment.can_accept(data, equipment_slot)

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(at_position, data):
		_equipment.equip_from_bag(data, equipment_slot)
