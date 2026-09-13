extends PanelContainer

var action_bar: Node
var slot_index: int
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

func setup(component: Node, index: int) -> void:
	action_bar = component
	slot_index = index

func _get_drag_data(_at_position: Vector2) -> Variant:
	var item: ItemData = action_bar.get_item(slot_index)
	if item == null or get_tree().paused or action_bar.get_parent().is_dead:
		return null
	var tip := get_tree().get_first_node_in_group("item_tooltip")
	if tip:
		tip.hide_tooltip()
	var preview: Control
	if item.icon != null:
		var tex := TextureRect.new()
		tex.texture = item.icon
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var s: Vector2i = item.inventory_size
		tex.size = Vector2(s.x * 36 + (s.x - 1) * 2, s.y * 36 + (s.y - 1) * 2)
		tex.modulate = Color(1, 1, 1, 0.7)
		preview = tex
	else:
		var lbl := Label.new()
		lbl.text = item.display_name
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 6)
		preview = lbl
	set_drag_preview(preview)
	return {"kind": "action_item", "action_bar": action_bar, "index": slot_index, "item": item}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return action_bar != null and action_bar.can_accept(data)

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(at_position, data):
		action_bar.accept_drop(slot_index, data)
