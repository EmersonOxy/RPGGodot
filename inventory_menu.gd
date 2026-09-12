extends Control

@export var slide_duration := 0.25
var _inventory: Node
var _is_open := false
var _fade_tween: Tween
var _slots: Array[Control] = []
var _open_left := 0.0
var _open_right := 0.0
var _dropper: Node
@onready var _panel: Control = $Panel
@onready var _bag_slots: Control = $Panel/Margin/VBox/BagSlots

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_open_left = _panel.offset_left
	_open_right = _panel.offset_right
	_dropper = preload("res://inventory_dropper.gd").new()
	_dropper.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_dropper)
	if _bag_slots.get_child_count() != 20:
		push_warning("InventoryMenu: esperados exatamente 20 slots em BagSlots.")
	_inventory = _find_inventory()
	for index in range(20):
		var slot := _bag_slots.get_node_or_null("Slot%02d" % (index + 1)) as Control
		if slot == null or not slot.has_method("setup"):
			push_warning("InventoryMenu: Slot%02d ausente ou sem script." % (index + 1))
			continue
		_slots.append(slot)
		if _inventory != null:
			slot.setup(_inventory, index)

func _find_inventory() -> Node:
	var player := get_tree().get_first_node_in_group("player")
	return player.get_node_or_null("Inventory") if player else null

func toggle() -> void:
	if _is_open: close()
	else: open()

func open() -> void:
	_is_open = true
	if _fade_tween: _fade_tween.kill()
	if not visible:
		var width := _panel.size.x
		_panel.offset_left = _open_left + width
		_panel.offset_right = _open_right + width
		modulate.a = 0.0
	show()
	_animate_panel(_open_left, _open_right, 1.0)

func close() -> void:
	_is_open = false
	if _fade_tween: _fade_tween.kill()
	_animate_panel(_open_left + _panel.size.x, _open_right + _panel.size.x, 0.0)
	_fade_tween.chain().tween_callback(hide)
	var tooltip_node := get_tree().get_first_node_in_group("item_tooltip")
	if tooltip_node: tooltip_node.hide_tooltip()

func _animate_panel(left: float, right: float, alpha: float) -> void:
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(_panel, "offset_left", left, slide_duration)
	_fade_tween.tween_property(_panel, "offset_right", right, slide_duration)
	_fade_tween.tween_property(self, "modulate:a", alpha, slide_duration)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN and _is_open:
		mouse_filter = Control.MOUSE_FILTER_STOP
	elif what == NOTIFICATION_DRAG_END:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return _is_open and not get_tree().paused and data is Dictionary and data.get("kind") == "inventory_item" and data.get("inventory") == _inventory and not _inventory.get_parent().is_dead and not _panel.get_global_rect().has_point(to_global_point(at_position)) and _inventory.matches_slot(data.index, data.item, data.quantity)

func to_global_point(point: Vector2) -> Vector2:
	return get_global_transform() * point

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(at_position, data):
		_dropper.request_drop(data)
