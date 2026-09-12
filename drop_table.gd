extends Resource

@export var entries: Array[Dictionary] = []


func roll() -> Array:
	var total_weight := 0.0
	for entry in entries:
		total_weight += entry.get("weight", 1.0)
	if total_weight <= 0.0:
		return []
	var roll_val := randf() * total_weight
	var cumulative := 0.0
	for entry in entries:
		cumulative += entry.get("weight", 1.0)
		if roll_val <= cumulative:
			var min_c: int = entry.get("min_count", 1)
			var max_c: int = entry.get("max_count", 1)
			var count := randi_range(min_c, max_c)
			return [{"item": entry["item"], "count": count}]
	return []


func add_entry(item, weight: float = 1.0, min_count: int = 1, max_count: int = 1) -> void:
	entries.append({"item": item, "weight": weight, "min_count": min_count, "max_count": max_count})
