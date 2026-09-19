extends Control
class_name InventoryGridUI

const CELL_SIZE := 36
const SPACING := 2

var inventory: Node
var _bg_grid: GridContainer
var _items_parent: Control
var _drag_ghost: ColorRect
var _item_rects: Dictionary = {}
var _prev_snapshot: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(10 * CELL_SIZE + 9 * SPACING, 6 * CELL_SIZE + 5 * SPACING)
	
	_bg_grid = GridContainer.new()
	_bg_grid.columns = 10
	_bg_grid.add_theme_constant_override("h_separation", SPACING)
	_bg_grid.add_theme_constant_override("v_separation", SPACING)
	_bg_grid.set_anchors_preset(PRESET_FULL_RECT)
	add_child(_bg_grid)
	
	for i in range(60):
		var cell = Panel.new()
		cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.1, 0.6)
		style.corner_radius_top_left = 3
		style.corner_radius_top_right = 3
		style.corner_radius_bottom_left = 3
		style.corner_radius_bottom_right = 3
		cell.add_theme_stylebox_override("panel", style)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg_grid.add_child(cell)
		
	_items_parent = Control.new()
	_items_parent.set_anchors_preset(PRESET_FULL_RECT)
	_items_parent.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_items_parent)

	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("Inventory"):
		inventory = player.get_node("Inventory")
		inventory.updated.connect(refresh)
		refresh()
	# Reage quando qualquer preview termina de gerar (fonte única de ícones).
	if not Acquisitions.icon_ready.is_connected(_on_item_icon_ready):
		Acquisitions.icon_ready.connect(_on_item_icon_ready)

func _on_item_icon_ready(_item: ItemData) -> void:
	refresh()

func refresh() -> void:
	for c in _items_parent.get_children():
		c.queue_free()
	_item_rects.clear()
	
	if not inventory: return
	
	var snapshot := {}
	for p in inventory.get_all_placements():
		snapshot[p] = {"origin": p.origin, "quantity": p.quantity}
	
	for p in inventory.get_all_placements():
		var item_rect = TextureRect.new()
		item_rect.name = p.item.id
		if p.item.icon != null:
			item_rect.texture = p.item.icon
		item_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		item_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var origin: Vector2i = p.origin
		var size: Vector2i = p.item.inventory_size
		item_rect.position = Vector2(origin.x * (CELL_SIZE + SPACING), origin.y * (CELL_SIZE + SPACING))
		item_rect.size = Vector2(size.x * CELL_SIZE + (size.x - 1) * SPACING, size.y * CELL_SIZE + (size.y - 1) * SPACING)
		
		var bg = Panel.new()
		bg.set_anchors_preset(PRESET_FULL_RECT)
		_apply_item_border(bg, p.item, Acquisitions.is_new(p.item))
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_rect.add_child(bg)
		bg.show_behind_parent = true
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		if p.item.icon == null:
			if p.item.world_scene != null and not p.item.has_meta("generating_icon"):
				p.item.set_meta("generating_icon", true)
				ItemPreviewGenerator.generate_preview(p.item, self, func(_tex): refresh())
			# Placeholder neutro: nunca o nome do item espremido no slot.
			var placeholder := ColorRect.new()
			placeholder.color = Color(0.45, 0.45, 0.48, 0.5)
			placeholder.set_anchors_preset(PRESET_CENTER)
			placeholder.offset_left = -10
			placeholder.offset_top = -10
			placeholder.offset_right = 10
			placeholder.offset_bottom = 10
			placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			item_rect.add_child(placeholder)
		
		if p.quantity > 1:
			var qty_label = Label.new()
			qty_label.text = "x%d" % p.quantity
			qty_label.set_anchors_preset(PRESET_BOTTOM_RIGHT)
			qty_label.offset_left = -20
			qty_label.offset_top = -20
			qty_label.offset_right = -2
			qty_label.offset_bottom = -2
			qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			qty_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			qty_label.add_theme_font_size_override("font_size", 12)
			qty_label.add_theme_color_override("font_color", Color.WHITE)
			qty_label.add_theme_color_override("font_outline_color", Color.BLACK)
			qty_label.add_theme_constant_override("outline_size", 4)
			item_rect.add_child(qty_label)
			item_rect.set_meta("qty_label", qty_label)
		
		item_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		item_rect.mouse_entered.connect(_on_item_hovered.bind(item_rect))
		var script = GDScript.new()
		script.source_code = """
extends TextureRect
var placement: Dictionary
var inventory: Node
var border_panel: Panel
var owner_grid: Node
func _get_drag_data(at_position: Vector2) -> Variant:
	var data = {"kind": "inventory_item", "inventory": inventory, "placement": placement, "item": placement.item, "quantity": placement.quantity}
	# Preview do próprio item com o footprint real (células x células).
	var s: Vector2i = placement.item.inventory_size
	var cell: float = owner_grid.CELL_SIZE if owner_grid != null else 36.0
	var gap: float = owner_grid.SPACING if owner_grid != null else 2.0
	var preview := PanelContainer.new()
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.08, 0.07, 0.05, 0.9)
	pstyle.corner_radius_top_left = 4
	pstyle.corner_radius_top_right = 4
	pstyle.corner_radius_bottom_left = 4
	pstyle.corner_radius_bottom_right = 4
	preview.add_theme_stylebox_override("panel", pstyle)
	preview.custom_minimum_size = Vector2(s.x * cell + (s.x - 1) * gap, s.y * cell + (s.y - 1) * gap)
	preview.size = preview.custom_minimum_size
	if texture != null:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 4
		icon.offset_top = 4
		icon.offset_right = -4
		icon.offset_bottom = -4
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.add_child(icon)
	else:
		var name_label := Label.new()
		name_label.text = placement.item.display_name
		name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_outline_color", Color.BLACK)
		name_label.add_theme_constant_override("outline_size", 4)
		preview.add_child(name_label)
	if placement.quantity > 1:
		var qty_label := Label.new()
		qty_label.text = "x%d" % placement.quantity
		qty_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		qty_label.offset_left = -30
		qty_label.offset_top = -18
		qty_label.offset_right = -3
		qty_label.offset_bottom = -2
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		qty_label.add_theme_font_size_override("font_size", 11)
		qty_label.add_theme_color_override("font_color", Color(1, 1, 0.8))
		qty_label.add_theme_color_override("font_outline_color", Color.BLACK)
		qty_label.add_theme_constant_override("outline_size", 4)
		preview.add_child(qty_label)
	preview.modulate = Color(1, 1, 1, 0.9)
	set_drag_preview(preview)
	# Oculta o item de origem para não duplicar o visual durante o arraste.
	visible = false
	Acquisitions.clear_new(placement.item)
	if is_instance_valid(border_panel) and is_instance_valid(owner_grid):
		owner_grid.restyle_border(border_panel, placement.item, false)
	return data
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		visible = true
func _process(_delta: float) -> void:
	# Auto-restauração caso o evento de fim de drag não chegue até aqui.
	if not visible and not get_viewport().gui_is_dragging():
		visible = true
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and event.shift_pressed:
			owner_grid.request_equip(placement)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.shift_pressed:
			owner_grid.request_drop(placement)
			accept_event()
"""
		script.reload()
		item_rect.set_script(script)
		item_rect.set("placement", p)
		item_rect.set("inventory", inventory)
		item_rect.set("border_panel", bg)
		item_rect.set("owner_grid", self)
		
		_items_parent.add_child(item_rect)
		_item_rects[p] = item_rect
	
	# Polimento visual: pop de assentamento para itens novos/movidos e pulse
	# do contador quando a pilha cresce. A lógica de posição já está aplicada.
	for p in snapshot:
		var prev: Variant = _prev_snapshot.get(p, null)
		var rect: Control = _item_rects.get(p, null)
		if rect == null or not is_instance_valid(rect):
			continue
		if prev == null or prev.origin != snapshot[p].origin:
			_pop_rect(rect)
		elif snapshot[p].quantity > prev.quantity:
			var qty: Control = rect.get_meta("qty_label")
			if qty:
				_pulse_label(qty)
	_prev_snapshot = snapshot


func _pop_rect(rect: Control) -> void:
	if rect.has_meta("pop_tween") and rect.get_meta("pop_tween") != null:
		(rect.get_meta("pop_tween") as Tween).kill()
	rect.pivot_offset = rect.size * 0.5
	rect.scale = Vector2.ONE * 1.08
	rect.modulate.a = 0.85
	var tween := rect.create_tween()
	rect.set_meta("pop_tween", tween)
	tween.set_parallel(true)
	tween.tween_property(rect, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(rect, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _pulse_label(label: Control) -> void:
	if label.has_meta("pop_tween") and label.get_meta("pop_tween") != null:
		(label.get_meta("pop_tween") as Tween).kill()
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE * 1.15
	var tween := label.create_tween()
	label.set_meta("pop_tween", tween)
	tween.tween_property(label, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _apply_item_border(panel: Panel, item: ItemData, is_new: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.14, 0.1, 0.95) if is_new else Color(0.12, 0.11, 0.09, 0.9)
	# Estado normal não tem moldura; apenas itens novos ganham borda dourada.
	var width := 2 if is_new else 0
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.border_color = Color(1.0, 0.85, 0.3, 1.0)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	panel.add_theme_stylebox_override("panel", style)


func restyle_border(panel: Panel, item: ItemData, is_new: bool) -> void:
	if is_instance_valid(panel):
		_apply_item_border(panel, item, is_new)


func _on_item_hovered(item_rect: Control) -> void:
	if not is_instance_valid(item_rect):
		return
	var placement: Dictionary = item_rect.get("placement")
	if placement.is_empty():
		return
	var item: ItemData = placement.item
	if not Acquisitions.is_new(item):
		return
	Acquisitions.clear_new(item)
	var border_panel: Panel = item_rect.get("border_panel")
	restyle_border(border_panel, item, false)


func request_equip(placement: Dictionary) -> void:
	if placement.is_empty() or not is_instance_valid(inventory):
		return
	var item: ItemData = placement.item
	if item == null:
		return
	var player := inventory.get_parent()
	if item.item_type == ItemData.ItemType.CONSUMABLE:
		var action_bar: Node = player.get_node_or_null("ActionBar")
		if action_bar and action_bar.has_method("assign_first_free"):
			action_bar.assign_first_free(item)
	elif player.get("equipment") != null and player.equipment.can_equip(item, item.equipment_slot):
		var data := {"kind": "inventory_item", "inventory": inventory, "placement": placement, "item": item, "quantity": placement.quantity}
		player.equipment.equip_from_bag(data, item.equipment_slot)


func request_drop(placement: Dictionary) -> void:
	if placement.is_empty() or not is_instance_valid(inventory):
		return
	var data := {"kind": "inventory_item", "inventory": inventory, "placement": placement, "item": placement.item, "quantity": placement.quantity}
	var scene := get_tree().current_scene
	if scene == null:
		return
	var menu := scene.get_node_or_null("Interface/UIManager/InventoryMenu")
	if menu and menu.has_method("request_drop"):
		menu.request_drop(data)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY: return false
	var item = data.get("item") as ItemData
	if not item: return false
	var origin = _get_grid_pos(at_position)
	
	if _drag_ghost == null:
		_drag_ghost = ColorRect.new()
		_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_drag_ghost)
		
	var size = item.inventory_size
	_drag_ghost.size = Vector2(size.x * CELL_SIZE + (size.x - 1) * SPACING, size.y * CELL_SIZE + (size.y - 1) * SPACING)
	_drag_ghost.position = Vector2(origin.x * (CELL_SIZE + SPACING), origin.y * (CELL_SIZE + SPACING))
	
	var can = false
	if data.get("kind") == "inventory_item" and data.get("placement") != null:
		var p = data.placement
		var original_origin = p.origin
		inventory._placements.erase(p)
		for x in range(original_origin.x, original_origin.x + size.x):
			for y in range(original_origin.y, original_origin.y + size.y):
				inventory._grid[x][y] = null
				
		can = inventory.can_place_at(item, origin)
		
		for x in range(original_origin.x, original_origin.x + size.x):
			for y in range(original_origin.y, original_origin.y + size.y):
				inventory._grid[x][y] = p
		inventory._placements.append(p)
	else:
		can = inventory.can_place_at(item, origin)
		
	_drag_ghost.color = Color(0, 1, 0, 0.3) if can else Color(1, 0, 0, 0.3)
	
	return can

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _drag_ghost:
		_drag_ghost.queue_free()
		_drag_ghost = null
		
	var origin = _get_grid_pos(at_position)
	if data.get("kind") == "inventory_item":
		inventory.move_placement(data.placement, origin)
	elif data.get("kind") == "equipment_item":
		var eq = data.equipment
		var slot = data.slot
		if inventory.can_place_at(data.item, origin):
			# Usamos place_at diretamente, depois removemos do equipment.
			inventory.place_at(data.item, origin, 1)
			eq._items.erase(slot)
			eq.changed.emit()
			inventory.updated.emit()

func _process(_delta: float) -> void:
	# Nunca deixa o ghost de validade preso após o fim/cancelamento do drag.
	if _drag_ghost and not get_viewport().gui_is_dragging():
		_drag_ghost.queue_free()
		_drag_ghost = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if _drag_ghost:
			_drag_ghost.queue_free()
			_drag_ghost = null

func _get_grid_pos(local_pos: Vector2) -> Vector2i:
	var x = floori(local_pos.x / (CELL_SIZE + SPACING))
	var y = floori(local_pos.y / (CELL_SIZE + SPACING))
	return Vector2i(clamp(x, 0, 9 - (1 - 1)), clamp(y, 0, 5 - (1 - 1)))
