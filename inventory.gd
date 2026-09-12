extends Node

signal updated

const SLOTS := 20
var _slots: Array[Dictionary] = []


func _ready() -> void:
	_slots.resize(SLOTS)
	for i in SLOTS:
		_slots[i] = {"item": null, "quantity": 0}


func add_item(item, quantity: int = 1) -> bool:
	if not can_add(item, quantity):
		return false
	var remaining := quantity
	if item.stackable:
		for i in SLOTS:
			if remaining <= 0:
				break
			if _slots[i]["item"] == item:
				var space: int = item.max_stack - _slots[i]["quantity"]
				var to_add: int = mini(remaining, space)
				if to_add > 0:
					_slots[i]["quantity"] += to_add
					remaining -= to_add
	while remaining > 0:
		var placed := false
		for i in SLOTS:
			if _slots[i]["item"] == null:
				var to_add: int = mini(remaining, item.max_stack) if item.stackable else 1
				_slots[i]["item"] = item
				_slots[i]["quantity"] = to_add
				remaining -= to_add
				placed = true
				break
		if not placed:
			break
	updated.emit()
	return remaining == 0


func get_slot_count() -> int:
	return SLOTS


func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= SLOTS:
		return {"item": null, "quantity": 0}
	return _slots[index]


func is_full() -> bool:
	for i in SLOTS:
		if _slots[i]["item"] == null:
			return false
		if _slots[i]["item"].stackable and _slots[i]["quantity"] < _slots[i]["item"].max_stack:
			return false
	return true


func total_items() -> int:
	var count := 0
	for i in SLOTS:
		if _slots[i]["item"] != null:
			count += 1
	return count

# A inclusão é atômica: falhar nunca modifica parte de uma pilha.
func can_add(item, quantity: int) -> bool:
	if item == null or quantity <= 0:
		return false
	var capacity := 0
	for slot in _slots:
		if slot.item == null:
			capacity += maxi(1, item.max_stack) if item.stackable else 1
		elif item.stackable and slot.item == item:
			capacity += maxi(0, item.max_stack - slot.quantity)
	return capacity >= quantity

func matches_slot(index: int, item, quantity: int) -> bool:
	return index >= 0 and index < SLOTS and _slots[index].item == item and _slots[index].quantity == quantity and quantity > 0

func move_item(source: int, destination: int) -> bool:
	if source < 0 or source >= SLOTS or destination < 0 or destination >= SLOTS or _slots[source].item == null:
		return false
	if source == destination:
		return true
	var from_slot := _slots[source]
	var to_slot := _slots[destination]
	if to_slot.item == from_slot.item and from_slot.item.stackable:
		var amount := mini(from_slot.quantity, maxi(0, from_slot.item.max_stack - to_slot.quantity))
		if amount == 0:
			return false
		to_slot.quantity += amount
		from_slot.quantity -= amount
		if from_slot.quantity == 0:
			_slots[source] = {"item": null, "quantity": 0}
	else:
		_slots[source] = to_slot
		_slots[destination] = from_slot
	updated.emit()
	return true

func remove_slot(index: int, item, quantity: int) -> bool:
	if not matches_slot(index, item, quantity):
		return false
	_slots[index] = {"item": null, "quantity": 0}
	updated.emit()
	return true
