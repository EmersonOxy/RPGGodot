extends Node

signal changed

var _items: Dictionary = {}
@onready var inventory: Node = get_parent().get_node("Inventory")

func get_item(slot: int) -> ItemData:
	return _items.get(slot)

func can_equip(item: ItemData, slot: int) -> bool:
	return item != null and slot > ItemData.EquipmentSlot.NONE and slot <= ItemData.EquipmentSlot.AMULET and item.equipment_slot == slot and item.item_type != ItemData.ItemType.CONSUMABLE and item.item_type != ItemData.ItemType.MATERIAL

func can_accept(data: Variant, slot: int) -> bool:
	if get_tree().paused or get_parent().is_dead or not data is Dictionary:
		return false
	if data.get("kind") != "inventory_item" or data.get("inventory") != inventory:
		return false
	if not inventory.matches_slot(data.get("index", -1), data.get("item"), data.get("quantity", 0)):
		return false
	if not can_equip(data.item, slot):
		return false
	# Uma troca exige espaço antes de remover o novo item, conforme a regra da bolsa cheia.
	return get_item(slot) == null or inventory.can_add(get_item(slot), 1)

func equip_from_bag(data: Variant, slot: int) -> bool:
	if not can_accept(data, slot):
		return false
	var previous := get_item(slot)
	# Nenhum sinal é emitido entre as duas alterações: observadores veem a transação completa.
	if not inventory.exchange_equipment(data.index, data.item, data.quantity, previous):
		return false
	_items[slot] = data.item
	changed.emit()
	inventory.updated.emit()
	return true

func can_unequip(data: Variant, destination: int) -> bool:
	return not get_tree().paused and not get_parent().is_dead and data is Dictionary and data.get("kind") == "equipment_item" and data.get("equipment") == self and data.get("item") != null and get_item(data.get("slot", 0)) == data.item and destination >= 0 and destination < inventory.get_slot_count() and inventory.get_slot(destination).item == null

func unequip_to_bag(data: Variant, destination: int) -> bool:
	if not can_unequip(data, destination):
		return false
	if not inventory.place_equipment(destination, data.item):
		return false
	_items.erase(data.slot)
	changed.emit()
	inventory.updated.emit()
	return true

func get_bonuses() -> Dictionary:
	var result := {}
	for stat in ItemData.BONUS_LABELS:
		result[stat] = 0
		for item in _items.values():
			result[stat] += item.get(stat + "_bonus")
	return result
