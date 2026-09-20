@tool
class_name SpawnRegion3D
extends Node3D
## Spawner independente: cada região possui configuração, ciclo de spawn e população próprios.
## A caixa translúcida é exclusiva do editor; nunca entra no jogo, não tem colisão e não é salva na cena.

@export_category("REGIÃO DE SPAWN")

@export_group("GERAL")
## Liga ou desliga este spawner; pode ser alterado durante a execução.
@export var ativada := true
## Nó que recebe os inimigos gerados; vazio ou inválido usa o pai deste spawner.
@export var pai_dos_inimigos := NodePath("../../Enemies")

@export_group("REGIÃO")
## Extensão total do volume, em metros, centrada no nó. A caixa do editor acompanha este valor.
@export var tamanho_da_regiao := Vector3(12.0, 4.0, 12.0):
	set(value):
		tamanho_da_regiao = value
		_atualizar_visual()

@export_group("POPULAÇÃO")
## Máximo de inimigos vivos gerados por ESTE spawner, antes do multiplicador da dificuldade. Conta somente inimigos que ele próprio gerou.
@export_range(0, 100, 1) var maximo_de_inimigos := 3:
	set(value):
		maximo_de_inimigos = value
		if is_node_ready() and not Engine.is_editor_hint():
			_maximo_base = value
			_aplicar_dificuldade()

@export_group("TEMPO")
## Tempo mínimo entre tentativas de gerar inimigos, em segundos. Antes do multiplicador da dificuldade.
@export_range(0.1, 120.0, 0.1, "suffix:s") var intervalo_de_spawn := 8.0:
	set(value):
		intervalo_de_spawn = value
		if is_node_ready() and not Engine.is_editor_hint():
			_intervalo_base = value
			_aplicar_dificuldade()
## Espera antes da primeira tentativa, em segundos. Vale apenas ao iniciar a cena.
@export_range(0.0, 120.0, 0.1, "suffix:s") var atraso_inicial := 3.0

@export_group("POSICIONAMENTO")
## Distância mínima, em metros, que um ponto de spawn deve manter do jogador.
@export_range(0.0, 100.0, 0.5, "suffix:m") var distancia_minima_do_jogador := 10.0
## Distância máxima, em metros, entre o jogador e o ponto de spawn. Zero desativa o limite.
@export_range(0.0, 200.0, 0.5, "suffix:m") var distancia_maxima_do_jogador := 35.0
## Quantidade de pontos sorteados por tentativa antes de desistir.
@export_range(1, 50, 1) var tentativas_de_posicionamento := 12
## Desvio máximo, em metros, aceito entre o ponto sorteado e a navegação mais próxima.
@export_range(0.1, 5.0, 0.1, "suffix:m") var tolerancia_de_navegacao := 2.0
## Raio livre, em metros, exigido ao redor do ponto para evitar sobreposições.
@export_range(0.1, 5.0, 0.1, "suffix:m") var raio_livre := 0.8

@export_group("COMPOSIÇÃO")
## Lista de tipos que este spawner pode gerar, com pesos relativos. Entradas desativadas ou com peso zero são ignoradas.
@export var inimigos: Array[EntradaDeSpawnDeInimigo] = []

@export_category("EDITOR")

@export_group("VISUALIZAÇÃO NO EDITOR")
## Mostra a caixa translúcida da região apenas no editor; nunca aparece no jogo.
@export var mostrar_regiao := true:
	set(value):
		mostrar_regiao = value
		_atualizar_visual()
## Cor da caixa translúcida exibida apenas no editor. A transparência é controlada internamente.
@export var cor_da_regiao := Color(0.98, 0.64, 0.08, 1.0):
	set(value):
		cor_da_regiao = value
		_atualizar_visual()

const _ALPHA_DAS_FACES := 0.18
const _ALPHA_DO_CONTORNO := 0.9

var _visual: Node3D
var _mesh_das_faces: MeshInstance3D
var _mesh_do_contorno: MeshInstance3D

var _timer := 0.0
var _random := RandomNumberGenerator.new()
var _player: Node3D
var _inimigos_vivos: Dictionary = {}
var _intervalo_base := 8.0
var _maximo_base := 3
var _intervalo_efetivo := 8.0
var _maximo_efetivo := 3
var _estado := "aguardando intervalo"
var _ultima_falha := ""


func _ready() -> void:
	if Engine.is_editor_hint():
		_criar_visual()
		return
	_random.randomize()
	_intervalo_base = intervalo_de_spawn
	_maximo_base = maximo_de_inimigos
	_aplicar_dificuldade()
	var difficulty := get_node_or_null("/root/Difficulty")
	if difficulty != null:
		difficulty.difficulty_changed.connect(_on_difficulty_changed)
	_timer = atraso_inicial
	_estado = "aguardando intervalo"


func _aplicar_dificuldade() -> void:
	var difficulty := get_node_or_null("/root/Difficulty")
	if difficulty == null:
		_intervalo_efetivo = _intervalo_base
		_maximo_efetivo = _maximo_base
		return
	_intervalo_efetivo = _intervalo_base * difficulty.get_multiplier("spawn_interval")
	_maximo_efetivo = maxi(1, roundi(_maximo_base * difficulty.get_multiplier("max_enemies")))
	_timer = minf(_timer, _intervalo_efetivo)


func _on_difficulty_changed(_id: String) -> void:
	_aplicar_dificuldade()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not ativada:
		_estado = "desativado"
		return
	if _maximo_efetivo <= 0:
		_estado = "população desligada"
		return
	_timer -= delta
	if _timer > 0.0:
		_estado = "aguardando intervalo"
		return
	_timer = _intervalo_efetivo
	_estado = "aguardando intervalo"
	try_spawn()


func try_spawn() -> Node3D:
	if not ativada:
		_ultima_falha = "spawner desativado"
		_estado = "desativado"
		return null
	if _inimigos_vivos.size() >= _maximo_efetivo:
		_ultima_falha = "limite de inimigos atingido"
		_estado = "limite de inimigos atingido"
		return null
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if not is_instance_valid(_player):
		_ultima_falha = "jogador não encontrado"
		_estado = "aguardando jogador"
		return null
	var scene := _sortear_cena()
	if scene == null:
		_ultima_falha = "composição sem entradas ativadas"
		_estado = "sem composição"
		return null
	var position: Variant = _encontrar_posicao()
	if position == null:
		_ultima_falha = "sem posição válida"
		_estado = "sem posição válida"
		return null
	_ultima_falha = ""
	_estado = "spawn realizado"
	return _spawn_enemy(scene, position)


func _sortear_cena() -> PackedScene:
	var candidatas: Array[EntradaDeSpawnDeInimigo] = []
	var peso_total := 0.0
	for entrada in inimigos:
		if entrada == null or not entrada.ativado or entrada.cena_do_inimigo == null or entrada.peso <= 0.0:
			continue
		candidatas.append(entrada)
		peso_total += entrada.peso
	if candidatas.is_empty():
		return null
	var sorteio := _random.randf_range(0.0, peso_total)
	for entrada in candidatas:
		sorteio -= entrada.peso
		if sorteio <= 0.0:
			return entrada.cena_do_inimigo
	return candidatas.back().cena_do_inimigo


func _encontrar_posicao() -> Variant:
	var navigation_map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(navigation_map) <= 0:
		return null
	for _attempt in tentativas_de_posicionamento:
		var sampled := random_world_point(_random)
		var point := NavigationServer3D.map_get_closest_point(navigation_map, sampled)
		if point.distance_to(sampled) > tolerancia_de_navegacao:
			continue
		if not contains_world_point(point, tolerancia_de_navegacao):
			continue
		var player_distance := point.distance_to(_player.global_position)
		if player_distance < distancia_minima_do_jogador:
			continue
		if distancia_maxima_do_jogador > 0.0 and player_distance > distancia_maxima_do_jogador:
			continue
		if _position_is_clear(point):
			return point
	return null


func _position_is_clear(point: Vector3) -> bool:
	var shape := SphereShape3D.new()
	shape.radius = raio_livre
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * raio_livre)
	query.collision_mask = 9
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _spawn_enemy(scene: PackedScene, position: Vector3) -> Node3D:
	var enemy := scene.instantiate() as Node3D
	if enemy == null:
		_ultima_falha = "cena de inimigo inválida"
		_estado = "cena inválida"
		return null
	var pai := get_node_or_null(pai_dos_inimigos)
	if pai == null:
		pai = get_parent()
	pai.add_child(enemy)
	if enemy is EnemyBase:
		enemy.setup_spawn(position)
	else:
		enemy.global_position = position
	var id := enemy.get_instance_id()
	_inimigos_vivos[id] = 1
	enemy.tree_exited.connect(_on_inimigo_saiu.bind(id))
	if enemy.has_signal("died"):
		enemy.died.connect(_on_inimigo_morreu.bind(id))
	return enemy


func _on_inimigo_saiu(id: int) -> void:
	_inimigos_vivos.erase(id)


func _on_inimigo_morreu(_enemy: Node3D, id: int) -> void:
	_inimigos_vivos.erase(id)


func random_world_point(random: RandomNumberGenerator) -> Vector3:
	var half_size := tamanho_da_regiao * 0.5
	var local_point := Vector3(
		random.randf_range(-half_size.x, half_size.x),
		random.randf_range(-half_size.y, half_size.y),
		random.randf_range(-half_size.z, half_size.z)
	)
	return to_global(local_point)


func contains_world_point(point: Vector3, margin: float = 0.0) -> bool:
	var local_point := to_local(point)
	var half_size := tamanho_da_regiao * 0.5 + Vector3.ONE * margin
	return (
		absf(local_point.x) <= half_size.x
		and absf(local_point.y) <= half_size.y
		and absf(local_point.z) <= half_size.z
	)


func _criar_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "_VisualizacaoNoEditor"
	_visual.owner = null
	add_child(_visual)

	var material_das_faces := StandardMaterial3D.new()
	material_das_faces.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_das_faces.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_das_faces.cull_mode = BaseMaterial3D.CULL_DISABLED

	var caixa := BoxMesh.new()
	caixa.size = tamanho_da_regiao

	_mesh_das_faces = MeshInstance3D.new()
	_mesh_das_faces.name = "_Faces"
	_mesh_das_faces.owner = null
	_mesh_das_faces.mesh = caixa
	_mesh_das_faces.material_override = material_das_faces
	_mesh_das_faces.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(_mesh_das_faces)

	var linhas := ImmediateMesh.new()
	linhas.surface_begin(Mesh.PRIMITIVE_LINES)
	var cantos := [
		Vector3(-0.5, -0.5, -0.5), Vector3(0.5, -0.5, -0.5),
		Vector3(0.5, -0.5, 0.5), Vector3(-0.5, -0.5, 0.5),
		Vector3(-0.5, 0.5, -0.5), Vector3(0.5, 0.5, -0.5),
		Vector3(0.5, 0.5, 0.5), Vector3(-0.5, 0.5, 0.5),
	]
	var arestas := [
		[0, 1], [1, 2], [2, 3], [3, 0],
		[4, 5], [5, 6], [6, 7], [7, 4],
		[0, 4], [1, 5], [2, 6], [3, 7],
	]
	for aresta in arestas:
		linhas.surface_add_vertex(cantos[aresta[0]])
		linhas.surface_add_vertex(cantos[aresta[1]])
	linhas.surface_end()

	var material_do_contorno := StandardMaterial3D.new()
	material_do_contorno.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_do_contorno.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_mesh_do_contorno = MeshInstance3D.new()
	_mesh_do_contorno.name = "_Contorno"
	_mesh_do_contorno.owner = null
	_mesh_do_contorno.mesh = linhas
	_mesh_do_contorno.scale = tamanho_da_regiao
	_mesh_do_contorno.material_override = material_do_contorno
	_mesh_do_contorno.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(_mesh_do_contorno)

	_atualizar_visual()


func _atualizar_visual() -> void:
	if not Engine.is_editor_hint():
		return
	if is_instance_valid(_visual):
		_visual.visible = mostrar_regiao
	if is_instance_valid(_mesh_das_faces):
		var caixa := _mesh_das_faces.mesh as BoxMesh
		if caixa != null:
			caixa.size = tamanho_da_regiao
		var material := _mesh_das_faces.material_override as StandardMaterial3D
		if material != null:
			var cor := cor_da_regiao
			cor.a = _ALPHA_DAS_FACES
			material.albedo_color = cor
	if is_instance_valid(_mesh_do_contorno):
		_mesh_do_contorno.scale = tamanho_da_regiao
		var material := _mesh_do_contorno.material_override as StandardMaterial3D
		if material != null:
			var cor := cor_da_regiao
			cor.a = _ALPHA_DO_CONTORNO
			material.albedo_color = cor


func _get_property_list() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	resultado.append({"name": "DEBUG/Inimigos Vivos", "type": TYPE_STRING, "usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY})
	resultado.append({"name": "DEBUG/Próximo Spawn", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_NONE, "hint_string": "suffix:s", "usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY})
	resultado.append({"name": "DEBUG/Estado", "type": TYPE_STRING, "usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY})
	resultado.append({"name": "DEBUG/Última Falha", "type": TYPE_STRING, "usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY})
	return resultado


func _get(property: StringName) -> Variant:
	match String(property):
		"DEBUG/Inimigos Vivos":
			return "%d / %d" % [_inimigos_vivos.size(), _maximo_efetivo]
		"DEBUG/Próximo Spawn":
			return maxf(0.0, _timer)
		"DEBUG/Estado":
			return _estado
		"DEBUG/Última Falha":
			return _ultima_falha
	return null


func _set(_property: StringName, _value: Variant) -> bool:
	return false
