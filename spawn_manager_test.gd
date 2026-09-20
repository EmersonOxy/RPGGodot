extends SceneTree

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	var manager: EnemySpawnManager = scene.get_node("EnemySpawnManager")
	manager.enabled = false
	manager.minimum_player_distance = 0.0
	manager.maximum_player_distance = 100.0
	manager.global_max_alive = 5
	for _frame in 5:
		await physics_frame
	var regions := manager._eligible_regions()
	check(regions.size() == 2, "Both configured spawn regions are eligible")
	var enemy := manager.try_spawn()
	check(enemy == null, "Disabled manager does not spawn")
	manager.enabled = true
	enemy = manager.try_spawn()
	check(enemy != null, "Manager finds a navigable spawn point")
	if enemy != null:
		check(enemy.is_in_group("spawned_enemy"), "Spawned enemy is tracked")
		check(enemy.get_parent() == scene.get_node("Enemies"), "Spawned enemy uses configured parent")
	check(manager._living_enemy_count() == 5, "Global enemy limit counts existing and spawned enemies")
	check(manager.try_spawn() == null, "Global enemy limit prevents extra spawn")
	print("SPAWN_MANAGER: ", failures, " failures")
	quit(0 if failures == 0 else 1)
