extends Node

signal updated
signal used(index: int)

# Entradas tipadas por kind permitem acrescentar habilidades posteriormente.
var _entries: Array = [null, null, null, null, null]
@onready var inventory: Node = get_parent().get_node("Inventory")

func _ready() -> void:
	inventory.updated.connect(_on_inventory_updated)

func get_item(index: int) -> ItemData:
	if index < 0 or index >= _entries.size() or _entries[index] == null:
		return null
	return _entries[index].item

func assign_item(index: int, item: ItemData) -> bool:
	if index < 0 or index >= _entries.size() or item == null or item.item_type != ItemData.ItemType.CONSUMABLE or item.equipment_slot != ItemData.EquipmentSlot.NONE or inventory.count_item(item) == 0:
		return false
	# Uma identidade de item ocupa somente um atalho, mesmo com recursos/stacks distintos.
	for i in _entries.size():
		if inventory.same_item_type(get_item(i), item):
			_entries[i] = null
	_entries[index] = {"kind": "item", "item": item}
	updated.emit()
	return true

func assign_first_free(item: ItemData) -> bool:
	if item == null or item.item_type != ItemData.ItemType.CONSUMABLE or item.equipment_slot != ItemData.EquipmentSlot.NONE or inventory.count_item(item) == 0:
		return false
	# Já atribuído a algum atalho? Mantém como está.
	for i in _entries.size():
		if inventory.same_item_type(get_item(i), item):
			return true
	for i in _entries.size():
		if _entries[i] == null:
			return assign_item(i, item)
	return false

func clear_slot(index: int) -> void:
	if index >= 0 and index < _entries.size():
		_entries[index] = null
		updated.emit()

func can_accept(data: Variant) -> bool:
	if get_tree().paused or get_parent().is_dead or not data is Dictionary:
		return false
	var item = data.get("item")
	if not item is ItemData or item.item_type != ItemData.ItemType.CONSUMABLE or item.equipment_slot != ItemData.EquipmentSlot.NONE:
		return false
	if data.get("kind") == "inventory_item":
		return data.get("inventory") == inventory and data.get("placement") != null and inventory.get_all_placements().has(data.placement)
	return data.get("kind") == "action_item" and data.get("action_bar") == self and get_item(data.get("index", -1)) == item and inventory.count_item(item) > 0

func accept_drop(index: int, data: Variant) -> bool:
	if index < 0 or index >= _entries.size() or not can_accept(data):
		return false
	return assign_item(index, data.item)

func use_slot(index: int) -> bool:
	if get_tree().paused or not get_parent().use_consumable(get_item(index)):
		return false
	used.emit(index)
	return true

func _on_inventory_updated() -> void:
	for i in _entries.size():
		var item := get_item(i)
		if item != null and inventory.count_item(item) == 0:
			_entries[i] = null
	updated.emit()
