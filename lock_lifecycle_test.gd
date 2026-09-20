extends SceneTree

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
		print("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in 4:
		await process_frame
	var player := scene.get_node_or_null("Player")
	var heavy := scene.get_node_or_null("Enemies/HeavyDummy")
	var lock_on := player.get_node_or_null("TargetLock")
	heavy.global_position = player.global_position + Vector3(1, 0, 0)
	lock_on.target = heavy
	check(player.get_locked_target() == heavy, "Locked target reachable")
	heavy.take_damage(999)
	check(player.get_locked_target() == null, "Killed target cleared immediately")
	for i in 60:
		await process_frame
	check(player.get_locked_target() == null, "Lock stays clear after frames")
	check(not lock_on._marker.visible, "Marker hidden after target death")
	var ghost := scene.get_node_or_null("Enemies/GroundDummy")
	lock_on.target = ghost
	ghost.queue_free()
	await process_frame
	check(player.get_locked_target() == null, "Freed reference never escapes get_locked_target")
	check(lock_on.get_target() == null, "get_target clears freed reference")
	await process_frame
	check(lock_on._facing_held == false, "Facing state cleared with freed target")
	var alt_key := InputEventKey.new()
	alt_key.keycode = KEY_ALT
	alt_key.alt_pressed = true
	alt_key.pressed = true
	Input.parse_input_event(alt_key)
	Input.flush_buffered_events()
	await process_frame
	var facing: Vector3 = lock_on.get_facing_direction()
	check(facing.y == 0.0, "Alt without target keeps horizontal facing")
	alt_key.pressed = false
	alt_key.alt_pressed = false
	Input.parse_input_event(alt_key)
	Input.flush_buffered_events()
	print("LOCK_LIFECYCLE: ", failures, " failures")
	quit(0 if failures == 0 else 1)
