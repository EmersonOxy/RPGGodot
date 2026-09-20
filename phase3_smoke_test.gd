extends SceneTree

class Actor extends Node3D:
	var is_dead := false
	var health := 100
	var selected_enemy: Node3D
	var camera_target: Node3D
	func get_locked_target() -> Node3D:
		return camera_target if is_instance_valid(camera_target) and not is_dead else null

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var keybinds := root.get_node_or_null("Keybinds")
	if keybinds:
		keybinds.reset_all("user://phase3_smoke_reset.cfg")
	var world := Actor.new()
	root.add_child(world)
	var player := Actor.new()
	world.add_child(player)
	var inventory: Node = load("res://inventory.gd").new()
	inventory.name = "Inventory"
	player.add_child(inventory)
	var actions: Node = load("res://action_bar.gd").new()
	player.add_child(actions)
	var hud: Control = load("res://player_hud.tscn").instantiate()
	world.add_child(hud)
	hud._actions = actions
	actions.updated.connect(hud._refresh_actions)
	var item: ItemData = load("res://items/pocao_vida.tres").duplicate()
	item.icon = GradientTexture2D.new()
	inventory.add_item(item, 3)
	actions.assign_item(0, item)
	check(hud._action_counts[0].visible and hud._action_counts[0].text == "x3", "Hotbar shows quantity")
	inventory.consume_one(item)
	check(hud._action_counts[0].text == "x2", "Hotbar updates on consumption")
	inventory.consume_one(item)
	check(not hud._action_counts[0].visible, "Single item matches inventory convention")
	inventory.consume_one(item)
	check(actions.get_item(0) == null and not hud._action_counts[0].visible, "Empty slot clears count")
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 19
	world.add_child(camera)
	camera.position = Vector3(8, 12, 8)
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	var enemy := Actor.new()
	enemy.add_to_group("enemies")
	world.add_child(enemy)
	enemy.position = Vector3(2, 0, 0)
	world.selected_enemy = enemy
	var lock_on: Node = load("res://target_lock.gd").new()
	player.add_child(lock_on)
	check(InputMap.has_action("toggle_target_lock"), "Lock action registered")
	await physics_frame
	var lock_key := InputEventKey.new()
	lock_key.physical_keycode = KEY_T
	lock_key.pressed = true
	check(lock_key.is_action_pressed("toggle_target_lock"), "Physical T matches lock action")
	Input.parse_input_event(lock_key)
	Input.flush_buffered_events()
	await process_frame
	check(lock_on.get_target() == enemy, "Acquire selected target")
	var alt_key := InputEventKey.new()
	alt_key.keycode = KEY_ALT
	alt_key.alt_pressed = true
	alt_key.pressed = true
	check(alt_key.is_action_pressed("hold_target_facing"), "Alt matches facing action")
	Input.parse_input_event(alt_key)
	Input.flush_buffered_events()
	await process_frame
	check(lock_on.get_facing_direction().is_equal_approx(Vector3(2, 0, 0)), "Held Alt faces locked target")
	alt_key.pressed = false
	alt_key.alt_pressed = false
	Input.parse_input_event(alt_key)
	Input.flush_buffered_events()
	await process_frame
	check(lock_on.get_facing_direction() == Vector3.ZERO, "Released Alt clears facing")
	lock_on._process(0.0)
	check(lock_on._marker.visible, "White marker visible")
	check(lock_on._marker is Node2D and lock_on._marker.get_parent() is CanvasLayer, "Marker renders as screen overlay")
	check(lock_on._marker.position.is_equal_approx(camera.unproject_position(enemy.global_position + Vector3.UP * 0.9)), "Marker tracks body center")
	var right_enemy := Actor.new()
	right_enemy.add_to_group("enemies")
	world.add_child(right_enemy)
	right_enemy.position = enemy.position + camera.global_basis.x * 3.0
	var switch_key := InputEventKey.new()
	switch_key.physical_keycode = KEY_E
	switch_key.pressed = true
	Input.parse_input_event(switch_key)
	Input.flush_buffered_events()
	await process_frame
	check(lock_on.get_target() == right_enemy, "E switches to screen-right enemy")
	check(not lock_on.switch_target(1) and lock_on.get_target() == right_enemy, "No candidate keeps current lock")
	check(lock_on.switch_target(-1) and lock_on.get_target() == enemy, "Switch left returns to original enemy")
	right_enemy.health = 0
	check(not lock_on.switch_target(1), "Cannot switch to dead enemy")
	right_enemy.free()
	var dummy: Node3D = load("res://enemy_dummy.tscn").instantiate()
	var player_script = load("res://player.gd")
	var player_probe: Node3D = player_script.new()
	check(dummy.attack_range < player_probe.attack_range, "Dummy attack distance permits retaliation")
	for mode in ["mouse", "wasd", "hybrid"]:
		player_probe._movement_input_mode = mode
		check(player_probe.allows_mouse_movement() == (mode != "wasd"), "Mouse movement mode: " + mode)
		check(player_probe.allows_keyboard_movement() == (mode != "mouse"), "Keyboard movement mode: " + mode)
	player_probe._movement_input_mode = "wasd"
	player_probe.set_destination(Vector3.ONE)
	player_probe.approach_enemy(enemy)
	check(player_probe.approach_target == null, "WASD blocks click-to-approach")
	var settings := root.get_node("DisplaySettings")
	check(settings.sanitize({"movement_input_mode": "invalid"}).movement_input_mode == "hybrid", "Invalid settings use hybrid default")
	var config_path := "user://movement_smoke_%d.cfg" % Time.get_ticks_usec()
	var values: Dictionary = settings.get_settings()
	values.movement_input_mode = "wasd"
	check(settings._save_values(values, config_path) == OK and settings.read_settings(config_path).movement_input_mode == "wasd", "Movement mode persists independently")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
	dummy.free()
	player_probe.free()
	lock_on.toggle()
	check(lock_on.get_target() == null, "Toggle releases target")
	lock_on.toggle()
	enemy.position.x = 19
	check(lock_on.get_target() == null, "Distance releases target")
	enemy.position.x = 2
	lock_on.toggle()
	enemy.health = 0
	check(lock_on.get_target() == null, "Death releases target")
	enemy.health = 100
	lock_on.toggle()
	enemy.free()
	check(lock_on.get_target() == null, "Removed target handled safely")
	# Sem alvo travado, Alt mira na direção do cursor.
	var aim_cursor: Vector2 = camera.unproject_position(Vector3(6, 0, -3))
	var aim_dir: Vector3 = lock_on._direction_to_mouse(aim_cursor)
	check(aim_dir.y == 0.0 and aim_dir.is_equal_approx(Vector3(6, 0, -3)), "Mouse direction points at ground under cursor")
	alt_key.pressed = true
	alt_key.alt_pressed = true
	Input.parse_input_event(alt_key)
	Input.flush_buffered_events()
	await process_frame
	var held_dir: Vector3 = lock_on.get_facing_direction()
	check(not held_dir.is_zero_approx() and held_dir.y == 0.0, "Alt without target faces the cursor")
	alt_key.pressed = false
	alt_key.alt_pressed = false
	Input.parse_input_event(alt_key)
	Input.flush_buffered_events()
	await process_frame
	check(lock_on.get_facing_direction() == Vector3.ZERO, "Releasing Alt clears mouse facing")
	# Camera focus is a temporary layer over the player's selected zoom.
	player.add_to_group("player")
	var focus_target := Actor.new()
	world.add_child(focus_target)
	focus_target.position = Vector3(4, 0, 0)
	var follow: Camera3D = load("res://camera_follow.gd").new()
	follow.projection = Camera3D.PROJECTION_ORTHOGONAL
	follow.transform = camera.transform
	world.add_child(follow)
	follow.set_process(false)
	follow.set_zoom_index(5, true)
	var basis_before := follow.global_basis
	player.camera_target = focus_target
	follow._lock_follow_enabled = true
	for frame in 90:
		follow._process(1.0 / 60.0)
	check(is_equal_approx(follow.size, 16.435), "Lock zooms in 13.5 percent")
	check(follow._lock_focus.x > 1.5 and follow.global_basis == basis_before, "Lock shifts focus without rotation")
	follow._lock_follow_enabled = false
	for frame in 120:
		follow._process(1.0 / 60.0)
	check(is_equal_approx(follow.size, 19.0) and follow._lock_focus == Vector3.ZERO, "Free camera restores base zoom and focus")
	follow._lock_follow_enabled = true
	follow.set_zoom_index(0, true)
	for frame in 90:
		follow._process(1.0 / 60.0)
	check(follow.size >= 6.0, "Focus zoom respects minimum")
	follow.set_zoom_index(6)
	for frame in 90:
		follow._process(1.0 / 60.0)
	check(is_equal_approx(follow.size, 19.895), "Scroll changes zoom base during lock")
	focus_target.free()
	for frame in 120:
		follow._process(1.0 / 60.0)
	check(is_equal_approx(follow.size, 23.0) and follow._lock_focus == Vector3.ZERO, "Lost target returns to updated zoom base")
	var rect: Rect2 = follow.get_viewport().get_visible_rect()
	var probe: Vector2 = rect.get_center() + Vector2(rect.size.x * 0.25, rect.size.y * 0.25)
	var corner: Vector2 = follow._compute_mouse_shift(probe)
	check(corner.x > 0.0 and corner.y < 0.0, "Bottom-right cursor shifts camera right and down")
	var aspect := rect.size.x / rect.size.y
	check(is_equal_approx(corner.x, follow.size * aspect * follow.MOUSE_SHIFT_FRACTION * 0.5), "Horizontal shift spans aspect fraction")
	check(is_equal_approx(absf(corner.y), follow.size * follow.MOUSE_SHIFT_FRACTION * 0.5), "Vertical shift spans size fraction")
	check(follow._compute_mouse_shift(rect.get_center()) == Vector2.ZERO, "Centered cursor is neutral")
	check(follow._compute_mouse_shift(rect.position - Vector2(5, 5)) == Vector2.ZERO, "Cursor outside viewport is neutral")
	follow._mouse_offset = corner * 2.0
	for frame in 90:
		follow._process(1.0 / 60.0)
	check(follow._mouse_offset == follow._compute_mouse_shift(follow.get_viewport().get_mouse_position()), "Offset converges to cursor target")
	player.is_dead = true
	for frame in 120:
		follow._process(1.0 / 60.0)
	check(follow._mouse_offset == Vector2.ZERO, "Dead player returns camera to center")
	player.is_dead = false
	check(follow.global_basis == basis_before and is_equal_approx(follow.size, 23.0), "Mouse shift never changes zoom or rotation")
	world.free()
	await process_frame
	print("PHASE3_SMOKE: ", failures, " failures")
	quit(0 if failures == 0 else 1)
