extends Control

@export var fade_duration := 0.25
var _inventory: Node
var _is_open := false
var _fade_tween: Tween
var _slots: Array[Control] = []
var _dropper: Node
@onready var _panel: Control = $Panel
@onready var _bag_slots: Control = $Panel/Margin/VBox/BagSlots

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dropper = preload("res://inventory_dropper.gd").new()
	_dropper.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_dropper)
	_inventory = _find_inventory()
	if _inventory != null:
		var player := _inventory.get_parent()
		for slot in $Panel/Margin/VBox/EquipmentArea.get_children():
			if slot.has_method("setup_equipment"):
				slot.setup_equipment(player.equipment)
		player.stats_changed.connect(_update_stats)
		player.level_up.connect(func(_level): _update_stats())
		_update_stats()

func _update_stats() -> void:
	var player := _inventory.get_parent()
	var col := $Panel/Margin/VBox/CharRow/StatsCol
	col.get_node("LvBadge").text = "Nível %d" % player.level
	col.get_node("Str").text = "Força %d" % player.strength
	col.get_node("Agi").text = "Destreza %d" % player.dexterity
	col.get_node("Int").text = "Inteligência %d" % player.intelligence
	col.get_node("Armor").text = "Armadura %d" % player.armor
	col.get_node("Damage").text = "Dano %d" % player.attack_damage

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
		modulate.a = 0.0
	show()
	_animate_fade(1.0)

func close() -> void:
	_is_open = false
	if _fade_tween: _fade_tween.kill()
	_animate_fade(0.0)
	_fade_tween.tween_callback(hide)
	var tooltip_node := get_tree().get_first_node_in_group("item_tooltip")
	if tooltip_node: tooltip_node.hide_tooltip()

func _animate_fade(alpha: float) -> void:
	_fade_tween = create_tween()
	_fade_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(self, "modulate:a", alpha, fade_duration)
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN and _is_open:
		mouse_filter = Control.MOUSE_FILTER_STOP
	elif what == NOTIFICATION_DRAG_END:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

func _has_point(point: Vector2) -> bool:
	# Deixa o HUD receber o drop sem confundi-lo com descarte de loot no mundo.
	if _is_open and get_viewport().gui_is_dragging():
		var hud := get_tree().get_first_node_in_group("player_hud")
		if hud and hud.get_node("ActionBar").get_global_rect().has_point(to_global_point(point)):
			return false
	return Rect2(Vector2.ZERO, size).has_point(point)
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not _is_open or get_tree().paused or not data is Dictionary or _inventory.get_parent().is_dead or _panel.get_global_rect().has_point(to_global_point(at_position)):
		return false
	
	if data.get("kind") == "inventory_item":
		return data.get("inventory") == _inventory and data.get("placement") != null and _inventory.get_all_placements().has(data.placement)
	elif data.get("kind") == "equipment_item":
		return data.get("equipment") != null and data.get("item") != null and data.get("equipment").get_item(data.get("slot")) == data.get("item")
		
	return false

func to_global_point(point: Vector2) -> Vector2:
	return get_global_transform() * point

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(at_position, data):
		_dropper.request_drop(data)
