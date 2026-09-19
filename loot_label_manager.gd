extends Node
## One screen-space layout pass; never moves loot bodies or their model roots.

const PADDING_PX := 3.0
const GAP_PX := 4.0
const SMOOTH_SPEED := 28.0
const SNAP_PX := 0.05

# Reuse records across frames; IDs also let us remove freed references safely.
var _records: Dictionary = {}
var _visible: Array = []
var _camera: Camera3D

func _ready() -> void:
	process_priority = 100 # After the camera and individual loot visibility updates.
	add_to_group("loot_label_manager")
	# Handles saved loot instances that entered the tree before this manager.
	for loot in get_tree().get_nodes_in_group("loot"):
		if loot.has_method("is_label_ready") and loot.get_viewport() == get_viewport():
			register_loot(loot)

func register_loot(loot: Node) -> void:
	var id := loot.get_instance_id()
	if not _records.has(id):
		_records[id] = {"id": id, "loot": loot, "offset": 0.0, "target": 0.0}

func unregister_loot(loot: Node) -> void:
	_records.erase(loot.get_instance_id())

func _process(delta: float) -> void:
	_camera = get_viewport().get_camera_3d() # Also handles switching active cameras.
	_visible.clear()
	for id in _records.keys():
		var record: Dictionary = _records[id]
		if not is_instance_valid(record.loot):
			_records.erase(id)
			continue
		var loot: Node = record.loot
		if not loot.is_inside_tree() or loot.is_queued_for_deletion():
			_records.erase(id)
			continue
		record.target = 0.0
		if _camera == null or not loot.is_label_ready() or not loot.is_label_visible():
			continue
		var base: Vector3 = loot.get_label_base_position()
		if _camera.is_position_behind(base):
			continue
		var rect: Rect2 = loot.get_label_screen_rect(_camera, false)
		if not rect.intersects(get_viewport().get_visible_rect()):
			continue
		record.rect = rect
		record.world = base
		# Camera-relative ordering without translation: zoom/follow cannot reorder ties.
		record.order = Vector2(_camera.global_basis.x.dot(base), -_camera.global_basis.y.dot(base)).snapped(Vector2.ONE * 0.00001)
		_visible.append(record)
	resolve_layout(_visible)
	var weight := 1.0 - exp(-SMOOTH_SPEED * delta)
	for record in _records.values():
		var loot: Node = record.loot
		var offset := lerpf(record.offset, record.target, weight)
		if absf(offset - float(record.target)) <= SNAP_PX:
			offset = record.target
		record.offset = offset
		var displacement := Vector3.ZERO
		if _camera != null and not is_zero_approx(offset):
			var base: Vector3 = loot.get_label_base_position()
			var screen := _camera.unproject_position(base)
			var depth := -(_camera.get_camera_transform().affine_inverse() * base).z
			# Orthographic KEEP_HEIGHT: one pixel = size / viewport_height (not 2*size).
			# project_position also respects KEEP_WIDTH, perspective and camera offsets.
			displacement = _camera.project_position(screen + Vector2(0.0, offset), depth) - _camera.project_position(screen, depth)
		loot.apply_stack_offset(displacement, 1.0)
	_update_hover()

static func resolve_layout(entries: Array) -> void:
	entries.sort_custom(_comes_before)
	var parents: Array[int] = []
	for i in entries.size():
		parents.append(i)
	for a in entries.size():
		var ra: Rect2 = entries[a].rect
		for b in range(a + 1, entries.size()):
			var rb: Rect2 = entries[b].rect
			if ra.grow(PADDING_PX).intersects(rb.grow(PADDING_PX)):
				var root_a := _find_root(parents, a)
				var root_b := _find_root(parents, b)
				parents[root_b] = root_a
	var stack_tops: Dictionary = {}
	var placed: Array[Rect2] = [] # Descending bottom edge, maintained by insertion.
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var root := _find_root(parents, i)
		entry.cluster = root
		var rect: Rect2 = entry.rect
		if stack_tops.has(root):
			rect.position.y = minf(rect.position.y, stack_tops[root] - GAP_PX - rect.size.y)
		# Check every already placed plate, including OTHER clusters. Monotonic upward
		# placement plus descending bottoms needs only one scan, with no re-collisions.
		for obstacle in placed:
			if rect.end.x + PADDING_PX <= obstacle.position.x or rect.position.x - PADDING_PX >= obstacle.end.x:
				continue
			if rect.position.y < obstacle.end.y + GAP_PX and rect.end.y > obstacle.position.y - GAP_PX:
				rect.position.y = obstacle.position.y - GAP_PX - rect.size.y
		entry.target = rect.position.y - entry.rect.position.y
		stack_tops[root] = rect.position.y
		var index := 0
		while index < placed.size() and placed[index].end.y > rect.end.y:
			index += 1
		placed.insert(index, rect)

static func _comes_before(a: Dictionary, b: Dictionary) -> bool:
	if a.order.y != b.order.y:
		return a.order.y > b.order.y
	if a.order.x != b.order.x:
		return a.order.x > b.order.x
	var wa: Vector3 = a.world
	var wb: Vector3 = b.world
	if wa != wb:
		if wa.y != wb.y:
			return wa.y < wb.y
		if wa.x != wb.x:
			return wa.x < wb.x
		return wa.z < wb.z
	return a.id < b.id

static func _find_root(parents: Array[int], index: int) -> int:
	while parents[index] != index:
		parents[index] = parents[parents[index]]
		index = parents[index]
	return index

func get_loot_at_screen_position(point: Vector2) -> Node3D:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var picked: Node3D = null
	for record in _records.values():
		if not is_instance_valid(record.loot):
			continue
		var loot: Node3D = record.loot
		if loot.is_queued_for_deletion() or not loot.is_label_visible():
			continue
		if camera.is_position_behind(loot.get_label_base_position()):
			continue
		if loot.get_label_screen_rect(camera).has_point(point):
			if picked == null or loot.get_instance_id() < picked.get_instance_id():
				picked = loot
	return picked

func _update_hover() -> void:
	var picked: Node3D = null
	if get_viewport().gui_get_hovered_control() == null and not get_viewport().gui_is_dragging():
		picked = get_loot_at_screen_position(get_viewport().get_mouse_position())
	for record in _records.values():
		if record.loot != picked:
			record.loot.set_label_hover(false, picked != null)
	# The visible label has priority over the body hitbox of a different item.
	if picked != null:
		picked.set_label_hover(true, true)
