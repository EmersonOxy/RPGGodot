extends "res://inventory_slot.gd"

@export var equipment_slot: ItemData.EquipmentSlot = ItemData.EquipmentSlot.NONE
@export var slot_label: String = ""
var _equipment: Node
var _last_item: ItemData = null

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
	# Atualiza o slot quando o preview do item equipado terminar de gerar.
	if not Acquisitions.icon_ready.is_connected(_on_item_icon_ready):
		Acquisitions.icon_ready.connect(_on_item_icon_ready)
	_update_visual()

func _on_item_icon_ready(_item: ItemData) -> void:
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
	# Polimento visual: pop de assentamento quando um item é equipado.
	if item != _last_item:
		_last_item = item
		if item != null:
			_pop_settle()

func _pop_settle() -> void:
	pivot_offset = size * 0.5
	scale = Vector2.ONE * 1.1
	modulate.a = 0.85
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

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

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.shift_pressed:
			_unequip_to_bag()
			accept_event()

func _unequip_to_bag() -> void:
	if _equipment == null or _item == null or get_tree().paused or _equipment.get_parent().is_dead:
		return
	var data := {"kind": "equipment_item", "equipment": _equipment, "slot": equipment_slot, "item": _item}
	if _equipment.can_unequip(data, 0):
		_equipment.unequip_to_bag(data, 0)
	elif _equipment.inventory.find_space(_item) == Vector2i(-1, -1):
		var scene := get_tree().current_scene
		if scene and scene.has_method("show_notification"):
			scene.show_notification("Sem espaço no inventário para desequipar")
