extends SceneTree
## Focused headless check: --headless --fixed-fps 60 --script res://loot_label_test.gd
const MANAGER = preload("res://loot_label_manager.gd")
const LOOT_PATH := "res://world_loot.tscn"
var checks := 0
var failures := 0
var manager: Node
var camera: Camera3D
var scene: Node3D
var loots: Array[Node3D] = []

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func entry(id: int, rect: Rect2) -> Dictionary:
	return {"id": id, "rect": rect, "order": rect.get_center(), "world": Vector3.ZERO, "target": 0.0}

func clear_layout(entries: Array) -> bool:
	for a in entries.size():
		var ra: Rect2 = entries[a].rect
		ra.position.y += entries[a].target
		for b in range(a + 1, entries.size()):
			var rb: Rect2 = entries[b].rect
			rb.position.y += entries[b].target
			if ra.intersects(rb):
				return false
	return true

func add_loot(point: Vector3, title: String) -> Node3D:
	var loot: Node3D = load(LOOT_PATH).instantiate()
	var data := ItemData.new()
	data.display_name = title
	loot.item = data
	loot.position = point
	scene.add_child(loot)
	loot._kill_spawn_tweens()
	loot.set_process(false)
	manager.register_loot(loot)
	loots.append(loot)
	return loot

func settle(frames: int = 40) -> void:
	for frame in frames:
		for loot in loots:
			loot._process(1.0 / 60.0)
		manager._process(1.0 / 60.0)

func labels_clear() -> bool:
	for a in loots.size():
		for b in range(a + 1, loots.size()):
			if loots[a].get_label_screen_rect(camera).intersects(loots[b].get_label_screen_rect(camera)):
				return false
	return true

func check_corner_physics() -> void:
	await physics_frame
	await physics_frame
	for loot in loots:
		var rect: Rect2 = loot.get_label_screen_rect(camera)
		for fraction in [Vector2(0.02, 0.02), Vector2(0.98, 0.02), Vector2(0.02, 0.98), Vector2(0.98, 0.98)]:
			var point: Vector2 = rect.position + rect.size * fraction
			var origin := camera.project_ray_origin(point)
			var ray := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(point) * 100.0, 16)
			ray.collide_with_areas = true
			ray.collide_with_bodies = false
			var excluded: Array[RID] = []
			for other in loots:
				if other != loot:
					excluded.append(other.area.get_rid())
			ray.exclude = excluded
			var hit := scene.get_world_3d().direct_space_state.intersect_ray(ray)
			check(not hit.is_empty() and hit.collider == loot.area, "Physical corners cover resized label at zoom %s" % camera.size)

func run() -> void:
	var chain := [entry(1, Rect2(0, 0, 60, 20)), entry(2, Rect2(50, 0, 60, 20)), entry(3, Rect2(100, 0, 60, 20))]
	MANAGER.resolve_layout(chain)
	check(chain[0].cluster == chain[1].cluster and chain[1].cluster == chain[2].cluster, "Transitive A-B-C cluster")
	check(clear_layout(chain), "Transitive cluster placement")
	var crossing: Array = [entry(99, Rect2(0, 60, 180, 20))]
	for i in 7:
		crossing.append(entry(i, Rect2(0, 180, 140 + i * 5, 20)))
	MANAGER.resolve_layout(crossing)
	check(clear_layout(crossing), "Stack clears a previously separate cluster")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12873
	for sample in 20:
		var entries: Array = []
		for i in 30:
			entries.append(entry(i, Rect2(rng.randf_range(0, 600), rng.randf_range(0, 400), rng.randf_range(30, 240), rng.randf_range(15, 50))))
		MANAGER.resolve_layout(entries)
		check(clear_layout(entries), "Mixed rectangle sizes %d" % sample)

	# Instantiate the real loot scene in a lightweight world (no inventory previews).
	scene = Node3D.new()
	root.add_child(scene)
	current_scene = scene
	manager = MANAGER.new()
	manager.name = "LootLabelManager"
	scene.add_child(manager)
	manager.set_process(false)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 19.0
	scene.add_child(camera)
	camera.position = Vector3(10, 12, 10)
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	var first := add_loot(Vector3.ZERO, "Poção")
	check(first._backing_mesh.mesh.material.billboard_keep_scale, "Backing billboard preserves inherited zoom and spawn scale")
	settle()
	check(first._stacking_root.position == Vector3.ZERO, "Single item keeps exact base position")
	for i in 5:
		add_loot(Vector3.ZERO, "Espada %d de nome longo" % i if i % 2 == 0 else "Anel %d" % i)
	settle()
	check(labels_clear(), "Six real nameplates separate")
	var stable: Array[Vector3] = []
	for loot in loots:
		stable.append(loot._stacking_root.position)
	settle(90)
	for i in loots.size():
		check(stable[i] == loots[i]._stacking_root.position, "Stationary layout has no drift %d" % i)
	for aspect in [Camera3D.KEEP_HEIGHT, Camera3D.KEEP_WIDTH]:
		camera.keep_aspect = aspect
		for zoom in [6.0, 19.0, 27.0]:
			camera.size = zoom
			settle()
			check(labels_clear(), "Zoom %s, aspect %s" % [zoom, aspect])
			var base: Vector3 = first.get_label_base_position()
			var measured := camera.unproject_position(base).y - camera.unproject_position(base + camera.global_basis.y).y
			var pixels: float = root.get_visible_rect().size.y if aspect == Camera3D.KEEP_HEIGHT else root.get_visible_rect().size.x
			check(absf(measured - pixels / zoom) < 0.02, "Orthographic size represents full span")
			check(first.global_position == Vector3.ZERO and first.visual_root.scale == Vector3.ONE, "Stacking leaves body and model transform intact")
			for loot in loots:
				var rect: Rect2 = loot.get_label_screen_rect(camera)
				check(manager.get_loot_at_screen_position(rect.get_center()) == loot, "Visible plate resolves to its own item")
				check(loot._label_collision.global_position.is_equal_approx(loot._backing_mesh.global_position), "Hitbox matches backing position")
				check(loot._label_collision.global_basis.is_equal_approx(camera.global_basis), "Hitbox matches billboard orientation")
				check(is_equal_approx(loot.get_label_width(), loot._label_width * zoom / 19.0), "Zoom width matches ratio; default unchanged")
				check(is_equal_approx(loot._label_shape.size.y, 0.58 * zoom / 19.0), "Collision height follows zoom")
				for fraction in [Vector2(0.02, 0.02), Vector2(0.98, 0.02), Vector2(0.02, 0.98), Vector2(0.98, 0.98)]:
					check(manager.get_loot_at_screen_position(rect.position + rect.size * fraction) == loot, "All corners intercept before terrain at every zoom")
				loot.set_label_hover(true, true)
				check(loot._is_hovered, "Picked label activates existing hover")
				loot.set_label_hover(false, false)
			await check_corner_physics()
	for frame in 120:
		camera.size = 6.0 + 21.0 * (0.5 - 0.5 * cos(float(frame) / 119.0 * TAU))
		settle(1)
		check(labels_clear(), "Existing coincident pile remains clear during continuous zoom")
	camera.size = 27.0
	settle()
	# Removal must release registry references and allow compacting.
	var removed: Node3D = loots.pop_at(2)
	var removed_id: int = removed.get_instance_id()
	removed.free()
	settle()
	check(not manager._records.has(removed_id) and labels_clear(), "Removing a middle item compacts without stale references")
	# Reparented/scaled loot still has correct base position and pixel displacement.
	first.rotation.y = 0.5
	first.scale = Vector3.ONE * 1.2
	settle()
	check(labels_clear(), "Parent rotation and scale respected")
	var base_before: Vector3 = first.get_label_base_position()
	first.apply_stack_offset(Vector3(0, 2, 0), 1.0)
	check(first.get_label_base_position().is_equal_approx(base_before), "Base geometry independent of stacking transform")
	settle()
	# Check actual physics picking near the corners of the visible nameplates.
	await physics_frame
	await physics_frame
	for loot in loots:
		var rect: Rect2 = loot.get_label_screen_rect(camera)
		for fraction in [Vector2(0.1, 0.1), Vector2(0.9, 0.9), Vector2(0.5, 0.5)]:
			var point: Vector2 = rect.position + rect.size * fraction
			var origin := camera.project_ray_origin(point)
			var ray := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(point) * 100.0, 16)
			ray.collide_with_areas = true
			ray.collide_with_bodies = false
			check(manager.get_loot_at_screen_position(point) == loot, "Screen picking ignores intervening model hitboxes")
			# Isolate the target plate's geometry. Other items' body cylinders may
			# occlude it in 3D, which is why main.gd gives screen labels priority.
			var excluded: Array[RID] = []
			for other in loots:
				if other != loot:
					excluded.append(other.area.get_rid())
			ray.exclude = excluded
			var hit := scene.get_world_3d().direct_space_state.intersect_ray(ray)
			check(not hit.is_empty() and hit.collider == loot.area, "Physics hitbox covers plate corner/center")
	# Spawn tween uses label transform; manager waits until its growth completes.
	var spawned := add_loot(Vector3.ZERO, "Novo item")
	spawned.play_spawn(Vector3.UP, Vector3.ZERO, 0.2, 0.1)
	check(not spawned.is_label_ready(), "Falling loot excluded from layout")
	for frame in 60:
		await process_frame
		settle(1)
		if spawned._label_fade != null and spawned._label_fade.is_running():
			check(not spawned.is_label_ready(), "Growing label excluded from layout")
			check(is_equal_approx(spawned._label_shape.size.x, spawned._label_width * spawned.label.scale.x * camera.size / 19.0), "Spawn hitbox follows independent zoom and animated scale")
	settle()
	check(spawned.is_label_ready() and labels_clear(), "Spawn integrates after growth")
	check(spawned.label.scale.is_equal_approx(Vector3.ONE) and is_equal_approx(spawned.get_label_width(), spawned._label_width * camera.size / 19.0), "Spawn ends at current non-default zoom size")
	var packed: Node = load("res://main.tscn").instantiate()
	check(packed.has_node("LootLabelManager"), "Main scene includes manager")
	# Use the actual scene camera transform, not a look_at approximation.
	var follow: Camera3D = packed.get_node("Player/Camera3D")
	var original_transform := follow.transform
	follow.get_parent().remove_child(follow)
	packed.free()
	var target := Node3D.new()
	target.add_to_group("player")
	scene.add_child(target)
	scene.add_child(follow)
	follow.set_process(false)
	follow.make_current()
	follow.set_zoom_index(5, true)
	check(follow.transform.is_equal_approx(original_transform), "Default preserves actual scene camera transform")
	for aspect in [Camera3D.KEEP_HEIGHT, Camera3D.KEEP_WIDTH]:
		follow.keep_aspect = aspect
		follow.set_zoom_index(5, true)
		var expected := follow.unproject_position(target.global_position)
		for index in [0, 7, 5]:
			follow.set_zoom_index(index, true)
			check(follow.unproject_position(target.global_position).distance_to(expected) < 0.02, "Immediate min/max/default preserves focus")
		for index in [0, 7, 0, 5]:
			follow.set_zoom_index(index)
			for frame in 100:
				follow._process(1.0 / 60.0)
				check(follow.unproject_position(target.global_position).distance_to(expected) < 0.02, "Continuous zoom has no focal drift")
		check(follow.transform.is_equal_approx(original_transform), "Zoom never changes physical distance or rotation")
	follow.play_hit_impulse(Vector3.RIGHT)
	follow._process(0.01)
	check(follow._hit_time > 0.0, "Hit impulse remains active")
	follow._process(0.2)
	check(is_zero_approx(follow.h_offset) and is_zero_approx(follow.v_offset), "Hit impulse returns to reference composition")
	scene.free()
	await process_frame
	print("LOOT_LABEL_TEST: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
