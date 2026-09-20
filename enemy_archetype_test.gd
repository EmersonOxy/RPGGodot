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
	var standard: EnemyArchetype = load("res://enemies/archetype_standard.tres")
	var heavy: EnemyArchetype = load("res://enemies/archetype_heavy.tres")
	var agile: EnemyArchetype = load("res://enemies/archetype_agile.tres")
	check(standard != null and heavy != null and agile != null, "Archetype resources load")
	check(heavy.vida_maxima == 240 and heavy.velocidade_de_movimento == 1.5 and heavy.antecipacao_do_ataque > standard.antecipacao_do_ataque, "Heavy profile: tanky, slow, telegraphed")
	check(agile.vida_maxima == 55 and agile.velocidade_de_movimento == 4.3 and agile.intervalo_de_ataque < standard.intervalo_de_ataque, "Agile profile: fragile and fast")
	var heavy_enemy: Node3D = load("res://enemies/enemy_heavy.tscn").instantiate()
	root.add_child(heavy_enemy)
	await process_frame
	check(heavy_enemy.max_health == 240 and heavy_enemy.health == 240, "Heavy enemy applies archetype health")
	check(heavy_enemy.move_speed == 1.5 and heavy_enemy.enemy_name == "Pesado", "Heavy enemy applies speed and name")
	check(heavy_enemy._visual_scale == Vector3(1.2, 1.2, 1.2), "Heavy enemy applies visual scale")
	check(heavy_enemy._base_color == Color(0.28, 0.22, 0.42, 1), "Heavy enemy applies body color")
	heavy_enemy.take_damage(40)
	check(heavy_enemy.health == 200, "Damage subtracts from archetype health")
	# Recurso particular para verificar edição ao vivo sem alterar o perfil compartilhado.
	heavy_enemy.perfil = heavy.duplicate()
	heavy_enemy.perfil.vida_maxima = 300
	check(heavy_enemy.max_health == 300 and heavy_enemy.health == 200, "Live maximum does not heal")
	heavy_enemy.perfil.velocidade_de_movimento = 2.0
	check(heavy_enemy.move_speed == 2.0 and heavy.velocidade_de_movimento == 1.5, "Unique profile updates only its consumer")
	heavy_enemy.perfil.vida_maxima = 150
	check(heavy_enemy.health == 150, "Reduced maximum clamps current health")
	var agile_enemy: Node3D = load("res://enemies/enemy_agile.tscn").instantiate()
	root.add_child(agile_enemy)
	await process_frame
	check(agile_enemy.max_health == 55 and agile_enemy.move_speed == 4.3 and agile_enemy.enemy_name == "Ágil", "Agile enemy applies archetype")
	var dummy: Node3D = load("res://enemy_dummy.tscn").instantiate()
	root.add_child(dummy)
	await process_frame
	check(dummy.max_health == 100 and dummy.move_speed == 2.5 and dummy.enemy_name == "Dummy", "Legacy dummy keeps standard profile")
	heavy_enemy.free()
	agile_enemy.free()
	dummy.free()
	await process_frame
	print("ARCHETYPES: ", failures, " failures")
	quit(0 if failures == 0 else 1)
