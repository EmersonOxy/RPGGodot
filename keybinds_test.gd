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
	var kb: Node = root.get_node("Keybinds")
	check(kb != null, "Keybinds autoload present")
	check(InputMap.has_action("toggle_inventory"), "Inventory action registered")
	var path := "user://keybinds_test_%d.cfg" % Time.get_ticks_usec()
	kb.reset_all(path)
	check(kb.get_binding_text("toggle_target_lock") == "T", "Default lock key reads T")
	check(kb.get_binding_text("run") == "Shift", "Default run reads Shift")
	check(kb.get_binding_text("manual_attack") == "Mouse Dir.", "Default attack reads right button")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_J
	var result: Dictionary = kb.bind("toggle_target_lock", key, path)
	check(result.get("ok", false) == true, "Bind J to lock succeeds")
	check(InputMap.action_get_events("toggle_target_lock").size() == 1, "Single event after rebind")
	check(kb.get_binding_text("toggle_target_lock") == "J", "Lock key now J")
	var conflict: Dictionary = kb.bind("target_lock_left", key, path)
	check(conflict.get("ok", false) == false and conflict.get("conflict", "") == "toggle_target_lock", "Conflict detected and reported")
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	left.pressed = true
	var reserved: Dictionary = kb.bind("run", left, path)
	check(reserved.get("ok", false) == false and reserved.get("conflict", "") == "reserved", "Left button rejected as reserved")
	kb.reset_action("toggle_target_lock", path)
	check(kb.get_binding_text("toggle_target_lock") == "T", "Reset action restores default")
	kb.unbind("toggle_pause", path)
	check(kb.get_binding_text("toggle_pause") == "—", "Unbind leaves action empty")
	kb.reset_all(path)
	check(kb.get_binding_text("toggle_target_lock") == "T", "Reset all restores lock default")
	check(kb.get_binding_text("toggle_pause") == "Esc", "Reset all restores pause default")
	var shift := InputEventKey.new()
	shift.keycode = KEY_L
	kb.bind("run", shift, path)
	kb.bind("toggle_target_lock", key, path)
	var cfg := ConfigFile.new()
	check(cfg.load(path) == OK, "Binds file saved")
	check(int(cfg.get_value("binds", "run", {}).get("keycode", 0)) == KEY_L, "Run bind persisted as L")
	check(int(cfg.get_value("binds", "toggle_target_lock", {}).get("physical", 0)) == KEY_J, "Lock bind persisted as J")
	var kb2: Node = load("res://keybinds.gd").new()
	root.add_child(kb2)
	kb2.load_binds(path)
	check(kb2.get_binding_text("run") == "L", "Persisted run bind reloads")
	check(kb2.get_binding_text("toggle_target_lock") == "J", "Persisted lock bind reloads")
	kb2.free()
	kb.reset_all(path)
	check(kb.get_binding_text("run") == "Shift" and kb.get_binding_text("toggle_target_lock") == "T", "Reset all restores original defaults")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("KEYBINDS: ", failures, " failures")
	quit(0 if failures == 0 else 1)
