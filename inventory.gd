extends Node

signal updated

const COLS := 10
const ROWS := 6
var _grid: Array = []
var _placements: Array[Dictionary] = []

func _ready() -> void:
	_init_grid()

func _init_grid() -> void:
	_grid.clear()
	for x in range(COLS):
		var col := []
		for y in range(ROWS):
			col.append(null)
		_grid.append(col)

func get_all_placements() -> Array[Dictionary]:
	return _placements

func get_placement_at(pos: Vector2i) -> Dictionary:
	if pos.x < 0 or pos.x >= COLS or pos.y < 0 or pos.y >= ROWS:
		return {}
	var p = _grid[pos.x][pos.y]
	if p == null:
		return {}
	return p as Dictionary

func can_place_at(item: ItemData, origin: Vector2i) -> bool:
	if item == null: return false
	var size: Vector2i = item.inventory_size
	if origin.x < 0 or origin.y < 0 or origin.x + size.x > COLS or origin.y + size.y > ROWS:
		return false
	for x in range(origin.x, origin.x + size.x):
		for y in range(origin.y, origin.y + size.y):
			if _grid[x][y] != null:
				return false
	return true

func place_at(item: ItemData, origin: Vector2i, qty: int = 1) -> bool:
	if not can_place_at(item, origin):
		return false
	var placement = {"item": item, "origin": origin, "quantity": qty}
	var size: Vector2i = item.inventory_size
	for x in range(origin.x, origin.x + size.x):
		for y in range(origin.y, origin.y + size.y):
			_grid[x][y] = placement
	_placements.append(placement)
	updated.emit()
	return true

func remove_placement(placement: Dictionary) -> bool:
	if placement.is_empty() or not _placements.has(placement):
		return false
	var item: ItemData = placement.item
	var origin: Vector2i = placement.origin
	var size: Vector2i = item.inventory_size
	for x in range(origin.x, origin.x + size.x):
		for y in range(origin.y, origin.y + size.y):
			_grid[x][y] = null
	_placements.erase(placement)
	updated.emit()
	return true

func move_placement(placement: Dictionary, new_origin: Vector2i) -> bool:
	if placement.is_empty() or not _placements.has(placement): return false
	var item: ItemData = placement.item
	var old_origin: Vector2i = placement.origin
	if old_origin == new_origin: return true
	
	var size: Vector2i = item.inventory_size
	for x in range(old_origin.x, old_origin.x + size.x):
		for y in range(old_origin.y, old_origin.y + size.y):
			_grid[x][y] = null
			
	if can_place_at(item, new_origin):
		for x in range(new_origin.x, new_origin.x + size.x):
			for y in range(new_origin.y, new_origin.y + size.y):
				_grid[x][y] = placement
		placement.origin = new_origin
		updated.emit()
		return true
	else:
		for x in range(old_origin.x, old_origin.x + size.x):
			for y in range(old_origin.y, old_origin.y + size.y):
				_grid[x][y] = placement
		return false

func find_space(item: ItemData) -> Vector2i:
	if item == null: return Vector2i(-1, -1)
	for y in range(ROWS):
		for x in range(COLS):
			if can_place_at(item, Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func can_add(item: ItemData, qty: int = 1) -> bool:
	if item == null: return false
	if item.stackable:
		var capacity = 0
		for p in _placements:
			if p.item == item:
				capacity += maxi(0, item.max_stack - p.quantity)
		if capacity >= qty:
			return true
	return find_space(item) != Vector2i(-1, -1)

func add_item(item: ItemData, qty: int = 1) -> bool:
	if not can_add(item, qty):
		return false
	var remaining = qty
	if item.stackable:
		for p in _placements:
			if remaining <= 0: break
			if p.item == item:
				var space = item.max_stack - p.quantity
				var to_add = mini(remaining, space)
				if to_add > 0:
					p.quantity += to_add
					remaining -= to_add
	
	while remaining > 0:
		var pos = find_space(item)
		if pos == Vector2i(-1, -1):
			break
		var to_add = mini(remaining, item.max_stack) if item.stackable else 1
		place_at(item, pos, to_add)
		remaining -= to_add
	
	updated.emit()
	return remaining == 0

func count_item(item: ItemData) -> int:
	var count = 0
	for p in _placements:
		if same_item_type(p.item, item):
			count += p.quantity
	return count

func consume_one(item: ItemData) -> bool:
	for p in _placements:
		if same_item_type(p.item, item) and p.quantity > 0:
			p.quantity -= 1
			if p.quantity == 0:
				remove_placement(p)
			else:
				updated.emit()
			return true
	return false

func same_item_type(first: ItemData, second: ItemData) -> bool:
	return first != null and second != null and ((not first.id.is_empty() and first.id == second.id) or first == second)

func place_equipment(destination: int, item: ItemData) -> bool:
	# Ignore destination, just place it where it fits
	var pos = find_space(item)
	if pos == Vector2i(-1, -1):
		return false
	return place_at(item, pos, 1)

func exchange_equipment(placement: Dictionary, item: ItemData, quantity: int, previous: ItemData) -> bool:
	if previous != null:
		var pos = find_space(previous)
		if pos == Vector2i(-1, -1):
			return false
		place_at(previous, pos, 1)
	if not placement.is_empty():
		placement.quantity -= 1
		if placement.quantity <= 0:
			remove_placement(placement)
		else:
			updated.emit()
	return true
