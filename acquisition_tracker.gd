extends Node
## Registro compartilhado de aquisições: alimenta a notificação de coleta e a
## marcação de itens novos no inventário.

signal acquired(item: ItemData, qty: int)
signal icon_ready(item: ItemData)

var _new_items: Dictionary = {}

func register_acquisition(item: ItemData, qty: int) -> void:
	if item == null or qty <= 0:
		return
	_new_items[item] = true
	acquired.emit(item, qty)

func is_new(item: ItemData) -> bool:
	return item != null and _new_items.get(item, false)

func clear_new(item: ItemData) -> void:
	if item != null and _new_items.has(item):
		_new_items.erase(item)

func clear_all_new() -> void:
	_new_items.clear()
