extends SceneTree

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("run")


func criar_inimigo(scene: Node, posicao: Vector3, modo: int, raio: float = 6.0, pausa_min: float = 1.5, pausa_max: float = 4.0) -> EnemyBase:
	var inimigo := (load("res://enemy_dummy.tscn") as PackedScene).instantiate() as EnemyBase
	var perfil_proprio := EnemyArchetype.new()
	perfil_proprio.vida_maxima = 100
	perfil_proprio.dano = 10
	perfil_proprio.alcance_de_ataque = 1.4
	perfil_proprio.velocidade_de_movimento = 2.5
	perfil_proprio.distancia_de_deteccao = 8.0
	perfil_proprio.limite_de_perseguicao = 15.0
	perfil_proprio.comportamento_fora_de_combate = modo
	perfil_proprio.raio_de_movimento_ambiente = raio
	perfil_proprio.multiplicador_de_velocidade_ambiente = 0.7
	perfil_proprio.pausa_minima_ambiente = pausa_min
	perfil_proprio.pausa_maxima_ambiente = pausa_max
	perfil_proprio.tentativas_de_destino = 8
	scene.get_node("Enemies").add_child(inimigo)
	inimigo.perfil = perfil_proprio
	inimigo.setup_spawn(posicao)
	return inimigo


func run() -> void:
	var difficulty: DifficultyManager = root.get_node("Difficulty")
	difficulty.set_difficulty("normal", "user://enemy_wander_test.cfg")
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("SpawnRegions/WestGround").ativada = false
	scene.get_node("SpawnRegions/NorthGround").ativada = false
	var player: Node3D = scene.get_node("Player")
	for _frame in 5:
		await physics_frame
	var map := scene.get_world_3d().navigation_map
	var base_ab := NavigationServer3D.map_get_closest_point(map, Vector3(8.0, 0.0, 8.0))
	var base_c := NavigationServer3D.map_get_closest_point(map, Vector3(10.0, 0.0, 10.0))
	# Modo PARADO não se move sem estímulo
	var parado := criar_inimigo(scene, base_ab, 0)
	for _frame in 30:
		await physics_frame
	check(parado.state == EnemyBase.State.IDLE, "Parado remains IDLE without stimulus")
	var posicao_estavel := parado.global_position
	for _frame in 20:
		await physics_frame
	check(parado.global_position.distance_to(posicao_estavel) < 0.01, "Parado does not move")
	check(not parado._tem_destino_ambiente, "Parado picks no ambient destination")
	parado.queue_free()
	# Modo VAGAR escolhe destino dentro do raio e navegável
	var vagar := criar_inimigo(scene, base_ab, 1, 5.0, 0.1, 0.2)
	for _frame in 60:
		await physics_frame
		if vagar._tem_destino_ambiente:
			break
	check(vagar.state == EnemyBase.State.WANDER, "Vagar enters WANDER")
	check(vagar._tem_destino_ambiente, "Vagar picks a destination")
	if vagar._tem_destino_ambiente:
		var flat := Vector2(vagar._destino_ambiente.x, vagar._destino_ambiente.z).distance_to(Vector2(vagar.home_position.x, vagar.home_position.z))
		check(flat <= 7.0, "Destination stays within ambient radius")
		var mais_perto := NavigationServer3D.map_get_closest_point(map, vagar._destino_ambiente)
		check(mais_perto.distance_to(vagar._destino_ambiente) < 0.5, "Destination is navigable")
	# Eventualmente para e escolhe outro destino
	var destinos_escolhidos := 0
	var tinha_destino := false
	for _frame in 500:
		await physics_frame
		if vagar._tem_destino_ambiente and not tinha_destino:
			destinos_escolhidos += 1
		tinha_destino = vagar._tem_destino_ambiente
	check(destinos_escolhidos >= 3, "Vagar picks new destinations repeatedly")
	check(vagar.global_position.distance_to(base_ab) > 0.5, "Vagar actually walks")
	# Dois inimigos não dependem do mesmo timer
	var outro := criar_inimigo(scene, NavigationServer3D.map_get_closest_point(map, Vector3(13.0, 0.0, 9.0)), 1, 3.0, 0.1, 0.3)
	var timers_diferentes := false
	for _frame in 60:
		await physics_frame
		if absf(vagar._wander_timer - outro._wander_timer) > 0.01:
			timers_diferentes = true
			break
	check(timers_diferentes, "Two wanderers use independent timers")
	vagar.queue_free()
	outro.queue_free()
	# Percepção do Player interrompe o vagar com CHASE e depois ATTACK
	var cacador := criar_inimigo(scene, base_c, 1, 4.0, 0.1, 0.2)
	player.global_position = cacador.global_position + Vector3(3.0, 0.0, 0.0)
	var entrou_chase := false
	for _frame in 15:
		await physics_frame
		if cacador.state == EnemyBase.State.CHASE:
			entrou_chase = true
			break
	check(entrou_chase, "Player perception interrupts wander with CHASE")
	player.global_position = cacador.global_position + Vector3(1.0, 0.0, 0.0)
	var entrou_attack := false
	for _frame in 30:
		await physics_frame
		if cacador.state == EnemyBase.State.ATTACK:
			entrou_attack = true
			break
	check(entrou_attack, "In range transitions to ATTACK")
	# Perder o Player entra em RETURN e depois retoma o comportamento ambiente
	player.global_position = cacador.home_position + Vector3(30.0, 0.0, 0.0)
	var entrou_return := false
	for _frame in 120:
		await physics_frame
		if cacador.state == EnemyBase.State.RETURN:
			entrou_return = true
			break
	check(entrou_return, "Losing the player enters RETURN")
	var retomou_wander := false
	var pausa_respeitada := true
	for _frame in 400:
		await physics_frame
		if cacador.state == EnemyBase.State.WANDER:
			retomou_wander = true
			if cacador._tem_destino_ambiente:
				pausa_respeitada = false
			break
	check(retomou_wander, "After RETURN the enemy resumes ambient behavior")
	check(pausa_respeitada, "Ambient behavior restarts with a pause, not an immediate walk")
	cacador.queue_free()
	# O vagar nunca deriva progressivamente para longe de home
	var derivador := criar_inimigo(scene, base_c, 1, 6.0, 0.1, 0.2)
	var maior_distancia := 0.0
	var dentro_do_raio := true
	for _frame in 900:
		await physics_frame
		var flat := Vector2(derivador.global_position.x, derivador.global_position.z).distance_to(Vector2(derivador.home_position.x, derivador.home_position.z))
		maior_distancia = maxf(maior_distancia, flat)
		if flat > 12.0 and dentro_do_raio:
			dentro_do_raio = false
			print("DRIFT home=", derivador.home_position, " pos=", derivador.global_position, " estado=", derivador.state, " destino=", derivador._destino_ambiente, " tem=", derivador._tem_destino_ambiente)
	check(dentro_do_raio, "Wanderer never drifts far from home")
	check(maior_distancia > 0.5, "Wanderer actually roams around home")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://enemy_wander_test.cfg"))
	print("ENEMY_WANDER: ", failures, " failures")
	quit(0 if failures == 0 else 1)
