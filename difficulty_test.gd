extends SceneTree

const TEST_PATH := "user://difficulty_test.cfg"
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var difficulty: DifficultyManager = root.get_node("Difficulty")
	check(difficulty.sanitize_id("unknown") == "normal", "Invalid difficulty falls back to normal")
	check(difficulty.set_difficulty("hard", TEST_PATH) == OK, "Hard difficulty persists")
	var config := ConfigFile.new()
	check(config.load(TEST_PATH) == OK and config.get_value("gameplay", "difficulty") == "hard", "Saved difficulty roundtrip")
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	var heavy: Node = scene.get_node("Enemies/HeavyDummy")
	var manager: EnemySpawnManager = scene.get_node("EnemySpawnManager")
	check(heavy.max_health == 324 and heavy.attack_damage == 31, "Hard scales enemy health and damage")
	check(is_equal_approx(heavy.move_speed, 1.65) and is_equal_approx(heavy.aggro_range, 10.8), "Hard scales speed and perception")
	check(manager.global_max_alive == 9 and is_equal_approx(manager.spawn_interval, 6.0), "Hard scales spawn limit and interval")
	var previous_health: int = heavy.health
	check(difficulty.set_difficulty("easy", TEST_PATH) == OK, "Easy difficulty applies live")
	check(heavy.max_health == 180 and heavy.health < previous_health, "Live change preserves enemy health ratio")
	check(manager.global_max_alive == 5 and is_equal_approx(manager.spawn_interval, 10.0), "Easy updates spawn settings live")
	difficulty.set_difficulty("normal", TEST_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	print("DIFFICULTY: ", failures, " failures")
	quit(0 if failures == 0 else 1)
