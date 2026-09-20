extends SceneTree

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var difficulty: DifficultyManager = root.get_node("Difficulty")
	difficulty.set_difficulty("normal", "user://spawn_region_test.cfg")
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	var west: SpawnRegion3D = scene.get_node("SpawnRegions/WestGround")
	var north: SpawnRegion3D = scene.get_node("SpawnRegions/NorthGround")
	var player: Node3D = scene.get_node("Player")
	for _frame in 5:
		await physics_frame
	west._timer = 100000.0
	north._timer = 100000.0
	west.ativada = true
	north.ativada = true
	west.distancia_minima_do_jogador = 0.0
	west.distancia_maxima_do_jogador = 1000.0
	north.distancia_minima_do_jogador = 0.0
	north.distancia_maxima_do_jogador = 1000.0
	# Limites independentes
	west.maximo_de_inimigos = 2
	north.maximo_de_inimigos = 3
	check(west._maximo_efetivo == 2 and north._maximo_efetivo == 3, "Each spawner keeps its own limit")
	var primeiro_west := west.try_spawn() as EnemyBase
	var segundo_west := west.try_spawn() as EnemyBase
	check(primeiro_west != null and segundo_west != null, "West spawns up to its own limit")
	check(west._inimigos_vivos.size() == 2, "West respects its own limit")
	check(west.try_spawn() == null, "Full West blocks only West")
	check(north.try_spawn() != null, "Filling West does not block North")
	check(north._inimigos_vivos.size() == 1, "North tracks only its own enemies")
	# Inimigos manuais não consomem limite
	check(
		is_instance_valid(scene.get_node_or_null("Enemies/GroundDummy"))
		and is_instance_valid(scene.get_node_or_null("Enemies/HeavyDummy"))
		and is_instance_valid(scene.get_node_or_null("Enemies/AgileDummy"))
		and is_instance_valid(scene.get_node_or_null("Enemies/DeckDummy")),
		"Manual enemies remain in the scene"
	)
	check(west._inimigos_vivos.size() == 2, "Manual enemies do not consume West limit")
	# Matar inimigo libera vaga apenas no spawner correto
	var norte_antes := north._inimigos_vivos.size()
	primeiro_west.take_damage(999999)
	for _frame in 3:
		await physics_frame
	check(west._inimigos_vivos.size() == 1, "Killing an enemy frees a West slot")
	check(north._inimigos_vivos.size() == norte_antes, "West kill does not change North population")
	check(west.try_spawn() != null, "Freed slot allows a new West spawn")
	# Desativar um spawner não afeta o outro
	west.ativada = false
	check(west.try_spawn() == null, "Disabled spawner does not spawn")
	check(north.try_spawn() != null, "Disabling West does not affect North")
	west.ativada = true
	# Composição ponderada ignora entradas desativadas e peso zero
	var entrada_desativada := EntradaDeSpawnDeInimigo.new()
	entrada_desativada.cena_do_inimigo = load("res://enemies/enemy_heavy.tscn")
	entrada_desativada.ativado = false
	var entrada_peso_zero := EntradaDeSpawnDeInimigo.new()
	entrada_peso_zero.cena_do_inimigo = load("res://enemies/enemy_agile.tscn")
	entrada_peso_zero.peso = 0.0
	var entrada_valida := EntradaDeSpawnDeInimigo.new()
	entrada_valida.cena_do_inimigo = load("res://enemy_dummy.tscn")
	entrada_valida.peso = 1.0
	west.maximo_de_inimigos = 20
	west.inimigos = [entrada_desativada, entrada_peso_zero, entrada_valida]
	var gerados_validos := 0
	var algum_errado := false
	for _i in 6:
		var gerado := west.try_spawn()
		if gerado != null:
			gerados_validos += 1
			if gerado.scene_file_path != "res://enemy_dummy.tscn":
				algum_errado = true
	check(gerados_validos > 0 and not algum_errado, "Weighted pick ignores disabled and zero-weight entries")
	# Composição vazia não gera erro
	west.inimigos = []
	check(west.try_spawn() == null, "Empty composition spawns nothing")
	west.inimigos = [entrada_valida]
	# Inimigo spawnado recebe posição/home corretos e entra em CHASE
	for id in west._inimigos_vivos.keys():
		var vivo := instance_from_id(id) as EnemyBase
		if is_instance_valid(vivo):
			vivo.take_damage(999999)
	for _frame in 3:
		await physics_frame
	check(west._inimigos_vivos.is_empty(), "All West enemies were freed")
	var para_chase := west.try_spawn() as EnemyBase
	check(para_chase != null, "Chase test enemy spawns")
	if para_chase != null:
		check(para_chase.home_position.is_equal_approx(para_chase.global_position), "Spawned enemy home equals spawn position")
		player.global_position = para_chase.global_position + Vector3(2.0, 0.0, 0.0)
		var alcancou_chase := false
		for _frame in 30:
			await physics_frame
			if para_chase.state == EnemyBase.State.CHASE:
				alcancou_chase = true
				break
		check(alcancou_chase, "Spawned enemy enters CHASE when the player approaches")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://spawn_region_test.cfg"))
	print("SPAWN_REGION: ", failures, " failures")
	quit(0 if failures == 0 else 1)
