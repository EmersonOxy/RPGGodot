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
	var west: SpawnRegion3D = scene.get_node("SpawnRegions/WestGround")
	var north: SpawnRegion3D = scene.get_node("SpawnRegions/NorthGround")
	check(heavy.max_health == 324 and heavy.attack_damage == 31, "Hard scales enemy health and damage")
	check(is_equal_approx(heavy.move_speed, 1.65) and is_equal_approx(heavy.aggro_range, 10.8), "Hard scales speed and perception")
	west.intervalo_de_spawn = 8.0
	west.maximo_de_inimigos = 10
	north.intervalo_de_spawn = 15.0
	check(west._maximo_efetivo == 13 and is_equal_approx(west._intervalo_efetivo, 6.0), "Hard scales west spawn limit and interval")
	check(is_equal_approx(north._intervalo_efetivo, 11.25), "North keeps its own base under hard")
	check(is_equal_approx(west._intervalo_efetivo, 6.0), "Changing North does not change West")
	var previous_health: int = heavy.health
	check(difficulty.set_difficulty("easy", TEST_PATH) == OK, "Easy difficulty applies live")
	check(heavy.max_health == 180 and heavy.health < previous_health, "Live change preserves enemy health ratio")
	check(west._maximo_efetivo == 8 and is_equal_approx(west._intervalo_efetivo, 10.0), "Easy updates west spawn settings live")
	check(is_equal_approx(north._intervalo_efetivo, 18.75), "Easy keeps north base independent")
	difficulty.set_difficulty("normal", TEST_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	print("DIFFICULTY: ", failures, " failures")
	quit(0 if failures == 0 else 1)
