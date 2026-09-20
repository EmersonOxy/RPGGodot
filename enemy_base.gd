class_name EnemyBase
extends CharacterBody3D

const COMBAT_TEXT = preload("res://floating_combat_text.gd")

signal died(enemy: Node3D)

enum State { IDLE, CHASE, ATTACK, RETURN }

@export_category("INIMIGO")
@export_group("PERFIL")
## Recurso compartilhado do tipo. Use Tornar único antes de editar somente esta instância.
@export var perfil: EnemyArchetype:
	set(value):
		if is_instance_valid(perfil) and perfil.changed.is_connected(_on_profile_changed):
			perfil.changed.disconnect(_on_profile_changed)
		perfil = value
		if is_instance_valid(perfil):
			perfil.changed.connect(_on_profile_changed)
		if is_node_ready():
			if perfil == null:
				perfil = EnemyArchetype.new()
			else:
				_on_profile_changed()

# Estatísticas efetivas derivadas do perfil e da dificuldade; não são configurações.
var max_health: int = 100
# Stay inside the player's 1.5-unit reach, with a small movement margin.
var attack_range: float = 1.4
var attack_damage: int = 10
var attack_interval: float = 1.5
var enemy_attack_recovery: float = 0.55
var attack_windup: float = 0.4
var aggro_range: float = 8.0
var leash_range: float = 15.0
var move_speed: float = 2.5
@export_group("MOVIMENTO")
## Aceleração vertical desta instância.
@export_range(0.0, 100.0, 0.1, "or_greater", "suffix:m/s²") var gravidade: float = 20.0
@export_group("LOOT")
## Tabela desta instância. Vazia ao iniciar cria a tabela padrão existente; recursos compartilhados afetam todos os consumidores.
@export var tabela_de_loot: Resource
var enemy_name: String = "Dummy"
@export_group("ÁUDIO")
## Som usado no próximo dano, inclusive no golpe fatal.
@export var som_de_dano: AudioStream = preload("res://assets/sound/basics/hit/inimigo_padrao_tomando_dano.mp3")
## Volume em decibéis usado no próximo som de dano.
@export_range(-40.0, 6.0, 0.1, "suffix:dB") var volume_do_dano_db := -8.0
var _damage_voice: AudioStreamPlayer3D
var _visual_scale := Vector3.ONE
var health: int = 100
var is_selected := false
var attack_cooldown: float = 0.0
var attack_recovery_timer: float = 0.0
var hit_recovery_timer: float = 0.0
var target: Node3D = null
var state: State = State.IDLE
var home_position: Vector3
var _windup_remaining := 0.0
var _attack_pending := false
var _hit_flash_remaining := 0.0
var _visual_material: StandardMaterial3D
var _base_color: Color
var _strike_tween: Tween

@onready var selection_indicator: MeshInstance3D = $SelectionIndicator
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var _health_bar_3d: Node3D = $EnemyHealthBar


func _ready() -> void:
	if perfil == null:
		perfil = EnemyArchetype.new()
	_apply_difficulty(false)
	var difficulty := get_node_or_null("/root/Difficulty")
	if difficulty != null:
		difficulty.difficulty_changed.connect(_on_difficulty_changed)
	health = max_health
	attack_cooldown = 0.0
	home_position = global_position
	target = get_tree().get_first_node_in_group("player") as Node3D
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	set_collision_mask_value(3, true)
	set_collision_mask_value(4, true)
	set_selected(false)
	if _health_bar_3d:
		_health_bar_3d.setup(max_health, enemy_name)
	if tabela_de_loot == null:
		tabela_de_loot = _create_default_drop_table()


func _apply_difficulty(preserve_health_ratio: bool) -> void:
	var previous_max := max_health
	var previous_health := health
	var difficulty := get_node_or_null("/root/Difficulty")
	var health_multiplier: float = difficulty.get_multiplier("enemy_health") if difficulty != null else 1.0
	var damage_multiplier: float = difficulty.get_multiplier("enemy_damage") if difficulty != null else 1.0
	var speed_multiplier: float = difficulty.get_multiplier("enemy_speed") if difficulty != null else 1.0
	var perception_multiplier: float = difficulty.get_multiplier("enemy_perception") if difficulty != null else 1.0
	max_health = maxi(1, roundi(perfil.vida_maxima * health_multiplier))
	attack_damage = maxi(1, roundi(perfil.dano * damage_multiplier))
	attack_range = perfil.alcance_de_ataque
	attack_interval = perfil.intervalo_de_ataque
	attack_windup = perfil.antecipacao_do_ataque
	enemy_attack_recovery = perfil.recuperacao_do_ataque
	aggro_range = perfil.distancia_de_deteccao * perception_multiplier
	leash_range = perfil.limite_de_perseguicao
	move_speed = perfil.velocidade_de_movimento * speed_multiplier
	enemy_name = perfil.nome
	_visual_scale = Vector3.ONE * perfil.escala_visual
	if _strike_tween:
		_strike_tween.kill()
	$MeshInstance3D.scale = _visual_scale
	if _visual_material == null:
		_visual_material = $MeshInstance3D.get_active_material(0).duplicate() as StandardMaterial3D
		$MeshInstance3D.material_override = _visual_material
	_base_color = perfil.cor_do_corpo
	_visual_material.albedo_color = _base_color
	if preserve_health_ratio:
		health = clampi(roundi(float(previous_health) / maxf(previous_max, 1) * max_health), 1, max_health)
		if _health_bar_3d:
			_health_bar_3d.setup(max_health, enemy_name)
			_health_bar_3d.update_hp(health, max_health)


func _on_profile_changed() -> void:
	if not is_node_ready() or health <= 0:
		return
	var current_health := health
	_apply_difficulty(false)
	health = mini(current_health, max_health)
	if _health_bar_3d:
		_health_bar_3d.setup(max_health, enemy_name)
		_health_bar_3d.update_hp(health, max_health)


func _on_difficulty_changed(_id: String) -> void:
	if health > 0:
		_apply_difficulty(true)


func _create_default_drop_table() -> Resource:
	var dt = load("res://drop_table.gd").new()
	var pocao := load("res://items/pocao_vida.tres")
	var espada := load("res://items/espada_gasta.tres")
	var frag := load("res://items/fragmento_antigo.tres")
	dt.add_entry(pocao, 5.0, 1, 2)
	dt.add_entry(espada, 3.0, 1, 1)
	dt.add_entry(frag, 2.0, 1, 3)
	return dt


func set_selected(value: bool) -> void:
	is_selected = value
	selection_indicator.visible = value
	if _health_bar_3d:
		_health_bar_3d.set_selected(value)


func take_damage(amount: int, damage_type: int = COMBAT_TEXT.DamageType.NORMAL, is_critical: bool = false) -> void:
	if health <= 0 or amount <= 0 or hit_recovery_timer > 0.0:
		return
	hit_recovery_timer = 0.25
	_hit_flash_remaining = 0.12
	_play_damage_sound()
	COMBAT_TEXT.show_damage_number(self, global_position + Vector3.UP * 1.6, mini(amount, health), damage_type, is_critical)
	health = maxi(0, health - amount)
	if _health_bar_3d:
		_health_bar_3d.update_hp(health, max_health)
		_health_bar_3d.set_in_combat(true)
	if health == 0:
		set_selected(false)
		collision_layer = 0
		_drop_loot()
		hide()
		died.emit(self)
		queue_free()


func _play_damage_sound() -> void:
	if som_de_dano == null:
		return
	if is_instance_valid(_damage_voice):
		_damage_voice.queue_free()
	_damage_voice = AudioStreamPlayer3D.new()
	_damage_voice.stream = som_de_dano.duplicate()
	if _damage_voice.stream is AudioStreamMP3:
		(_damage_voice.stream as AudioStreamMP3).loop = false
	_damage_voice.bus = "Effects"
	_damage_voice.volume_db = volume_do_dano_db
	_damage_voice.unit_size = 15.0
	# The fatal hit remains audible after this enemy is freed.
	get_parent().add_child(_damage_voice)
	_damage_voice.global_position = global_position + Vector3.UP
	_damage_voice.finished.connect(_damage_voice.queue_free)
	_damage_voice.play()

func _drop_loot() -> void:
	if tabela_de_loot == null:
		return
	var rolls = tabela_de_loot.roll()
	var scene_root := get_tree().current_scene
	if scene_root == null:
		scene_root = get_parent()
		while scene_root.get_parent() != null and scene_root.get_parent() != get_tree().root:
			scene_root = scene_root.get_parent()
	var total := 0
	for drop in rolls:
		total += int(drop["count"])
	var index := 0
	for drop in rolls:
		var item_data = drop["item"]
		var count: int = drop["count"]
		for i in count:
			var loot_scene := preload("res://world_loot.tscn")
			var loot: Node3D = loot_scene.instantiate()
			loot.item = item_data
			# Loot burst: destinos distribuídos ao redor do inimigo, sem sobrepor.
			var angle := TAU * float(index) / float(maxi(total, 1)) + randf_range(-0.4, 0.4)
			var radius := randf_range(0.35, 0.7)
			var scatter := Vector3(cos(angle), 0.0, sin(angle)) * radius
			var target := _find_surface_position(global_position + scatter)
			scene_root.add_child(loot)
			loot.play_spawn(global_position + Vector3.UP * 0.45, target, randf_range(0.3, 0.45), randf_range(0.3, 0.4))
			index += 1


func _find_surface_position(pos: Vector3) -> Vector3:
	var origin := pos + Vector3.UP * 50.0
	var end := pos + Vector3.DOWN * 50.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result:
		return result.position + Vector3.UP * 0.15
	return pos + Vector3.UP * 0.15


func _physics_process(delta: float) -> void:
	hit_recovery_timer = maxf(0.0, hit_recovery_timer - delta)
	_hit_flash_remaining = maxf(0.0, _hit_flash_remaining - delta)
	_visual_material.albedo_color = Color.WHITE if _hit_flash_remaining > 0.0 else (Color(1.0, 0.65, 0.12) if _attack_pending else _base_color)
	# Recovery is additional to the existing cooldown, including fractional frames.
	var recovery_elapsed := minf(attack_recovery_timer, delta)
	attack_recovery_timer = maxf(0.0, attack_recovery_timer - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - (delta - recovery_elapsed))
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= gravidade * delta
	else:
		velocity.y = 0.0
	if health <= 0:
		return
	# A committed attack owns movement through preparation and recovery.
	if _attack_pending:
		_windup_remaining = maxf(0.0, _windup_remaining - delta)
		if _windup_remaining <= 0.0:
			_attack_pending = false
			attack_recovery_timer = enemy_attack_recovery
			attack_cooldown = attack_interval
			if is_instance_valid(target) and not target.is_dead and _is_target_in_range():
				target.take_damage(attack_damage)
			_play_attack_visual(false)
		move_and_slide()
		return
	if attack_recovery_timer > 0.0:
		move_and_slide()
		return
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node3D
		if not is_instance_valid(target):
			move_and_slide()
			return
	_update_state()
	match state:
		State.IDLE:
			_stop()
		State.CHASE:
			_chase(delta)
		State.ATTACK:
			_attack()
		State.RETURN:
			_return_home(delta)
	move_and_slide()


func _update_state() -> void:
	var player_alive: bool = not ("is_dead" in target and target.is_dead)
	var distance_to_player := global_position.distance_to(target.global_position)
	var leashed := home_position.distance_to(target.global_position) > leash_range
	match state:
		State.IDLE:
			if not player_alive or leashed:
				return
			if _is_target_in_range():
				state = State.ATTACK
			elif distance_to_player <= aggro_range:
				state = State.CHASE
		State.CHASE:
			if not player_alive or leashed:
				state = State.RETURN
			elif _is_target_in_range():
				state = State.ATTACK
		State.ATTACK:
			if not player_alive or leashed:
				state = State.RETURN
			elif not _is_target_in_range():
				state = State.CHASE
		State.RETURN:
			if player_alive and not leashed and distance_to_player <= aggro_range:
				if _is_target_in_range():
					state = State.ATTACK
				else:
					state = State.CHASE
			elif _is_home_reached():
				state = State.IDLE


func _stop() -> void:
	if not navigation_agent.is_navigation_finished():
		navigation_agent.target_position = global_position


func _chase(delta: float) -> void:
	if navigation_agent.target_position.distance_to(target.global_position) > 0.25:
		navigation_agent.target_position = target.global_position
	_follow_path(delta)


func _attack() -> void:
	_stop()
	if attack_cooldown > 0.0 or attack_recovery_timer > 0.0:
		return
	if not target.has_method("take_damage"):
		return
	_attack_pending = true
	_windup_remaining = attack_windup
	_play_attack_visual(true)


func _play_attack_visual(preparing: bool) -> void:
	if _strike_tween:
		_strike_tween.kill()
	_strike_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	if preparing:
		_strike_tween.tween_property($MeshInstance3D, "scale", _visual_scale * Vector3(1.1, 0.9, 1.1), attack_windup)
	else:
		_strike_tween.tween_property($MeshInstance3D, "scale", _visual_scale * Vector3(0.94, 1.06, 0.94), 0.08)
		_strike_tween.tween_property($MeshInstance3D, "scale", _visual_scale, maxf(0.05, enemy_attack_recovery - 0.08))


func _return_home(delta: float) -> void:
	if navigation_agent.target_position != home_position:
		navigation_agent.target_position = home_position
	_follow_path(delta)


func _follow_path(delta: float) -> void:
	if NavigationServer3D.map_get_iteration_id(navigation_agent.get_navigation_map()) <= 0:
		return
	if navigation_agent.is_navigation_finished():
		return
	var next_point := navigation_agent.get_next_path_position()
	var direction := next_point - global_position
	direction.y = 0.0
	if direction.length() > 0.01:
		var movement := direction.normalized() * minf(move_speed, direction.length() / delta)
		velocity.x = movement.x
		velocity.z = movement.z

	elif not navigation_agent.is_navigation_finished() and (next_point - global_position).length() > 0.15:
		var to_target := navigation_agent.target_position - global_position
		to_target.y = 0.0
		if to_target.length() > 0.2:
			var advance := to_target.normalized() * minf(move_speed, to_target.length() / delta)
			velocity.x = advance.x
			velocity.z = advance.z


func _is_home_reached() -> bool:
	var flat := Vector2(global_position.x, global_position.z).distance_to(Vector2(home_position.x, home_position.z))
	return flat < 0.4 and absf(global_position.y - home_position.y) < 0.6


func _is_target_in_range() -> bool:
	if not is_instance_valid(target):
		return false
	var difference := target.global_position - global_position
	if difference.length() > attack_range or absf(difference.y) > 0.35:
		return false
	var origin := global_position + Vector3.UP * 0.9
	var end := target.global_position + Vector3.UP * 0.9
	var query := PhysicsRayQueryParameters3D.create(origin, end, 3)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
