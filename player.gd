extends CharacterBody3D

const COMBAT_TEXT = preload("res://floating_combat_text.gd")
const HIT_EFFECT = preload("res://hit_impact.gd")

signal health_changed(current: int, maximum: int)
signal xp_changed(current: int, maximum: int)
signal level_up(new_level: int)
signal died
signal stats_changed
signal attack_executed(target: Node3D, interval: float)
signal manual_attack_requested(world_point: Vector3)
signal took_hit
signal stamina_changed(current: float, maximum: float)

@export_category("PLAYER")

@export_group("MOVIMENTO")
## Velocidade base compartilhada por clique e WASD, antes dos multiplicadores.
@export_range(0.0, 20.0, 0.1, "or_greater", "suffix:m/s") var velocidade_de_movimento: float = 4.0
## Multiplica a velocidade enquanto corre e possui stamina.
@export_range(0.0, 5.0, 0.05, "or_greater") var multiplicador_de_corrida: float = 1.5
## Multiplicador aplicado com a arma em mãos.
@export_range(0.0, 5.0, 0.05, "or_greater") var multiplicador_com_arma: float = 0.80
## Escala global do deslocamento. Mantém a calibração atual das animações; velocidade final = base × escala × arma × corrida.
@export_range(0.01, 3.0, 0.01, "or_greater") var escala_de_movimento: float = 0.68
## Aceleração vertical aplicada quando o personagem está fora do chão.
@export_range(0.0, 100.0, 0.1, "or_greater", "suffix:m/s²") var gravidade: float = 20.0

@export_group("STAMINA")
## Capacidade máxima. Aumentar não repõe stamina; diminuir limita o valor atual ao novo máximo.
@export_range(1.0, 500.0, 1.0, "or_greater") var stamina_maxima: float = 100.0:
	set(value):
		stamina_maxima = maxf(1.0, value)
		if is_node_ready():
			stamina = minf(stamina, stamina_maxima)
			if stamina >= stamina_maxima * percentual_para_retomar_corrida:
				_stamina_exhausted = false
			stamina_changed.emit(stamina, stamina_maxima)
## Stamina consumida por segundo de corrida com deslocamento.
@export_range(0.0, 100.0, 0.1, "or_greater") var consumo_por_segundo: float = 22.0
## Stamina recuperada por segundo após o atraso.
@export_range(0.0, 100.0, 0.1, "or_greater") var regeneracao_por_segundo: float = 28.0
## Atraso após consumir stamina. Alterações valem para o próximo consumo.
@export_range(0.0, 10.0, 0.05, "or_greater", "suffix:s") var atraso_para_regenerar: float = 1.0
## Fração da stamina máxima necessária após exaustão: 0,2 corresponde a 20%.
@export_range(0.0, 1.0, 0.01) var percentual_para_retomar_corrida: float = 0.2

@export_group("COMBATE")
## Ativado: cada golpe atinge todos os inimigos no cone frontal de 120 graus, com dano integral por alvo. Respeita alcance, altura e obstáculos. Desativado: mantém um alvo por golpe. Vale para socos, arma e ataques automáticos/manuais; pode mudar pelo Remote.
@export var atacar_em_area: bool = false
## Dano armado base, somado aos bônus de equipamento. Atualiza os atributos imediatamente.
@export_range(0, 1000, 1, "or_greater") var dano_base: int = 20:
	set(value):
		dano_base = maxi(0, value)
		if is_node_ready() and is_instance_valid(equipment):
			recalculate_stats()
## Dano dos socos; não recebe o bônus de dano da arma.
@export_range(0, 1000, 1, "or_greater") var dano_desarmado: int = 5
## Distância máxima conferida na aproximação e novamente no impacto; obstáculos continuam bloqueando.
@export_range(0.1, 10.0, 0.05, "or_greater", "suffix:m") var alcance_de_ataque: float = 1.5
## Intervalo mínimo de novos golpes armados. Também aguarda o fim da animação; não reinicia o cooldown atual.
@export_range(0.01, 10.0, 0.01, "or_greater", "suffix:s") var intervalo_armado: float = 1.0
## Intervalo mínimo entre socos; também respeita a animação em andamento.
@export_range(0.01, 10.0, 0.01, "or_greater", "suffix:s") var intervalo_desarmado: float = 0.65
## Tempo pelo qual um pedido de ataque aguarda disponibilidade. Usado no próximo pedido.
@export_range(0.0, 2.0, 0.01, "or_greater", "suffix:s") var buffer_de_ataque_manual: float = 0.25
## Pausa mínima do movimento ao receber dano; a animação de reação também pode manter a trava.
@export_range(0.0, 5.0, 0.01, "or_greater", "suffix:s") var trava_de_movimento_ao_receber_golpe: float = 0.18
## Tempo mínimo para voltar a atacar após iniciar a reação ao dano.
@export_range(0.0, 5.0, 0.01, "or_greater", "suffix:s") var trava_de_ataque_ao_receber_golpe: float = 0.12

@export_group("ATRIBUTOS BASE")
## Vida máxima antes dos equipamentos. Aumentar não cura; diminuir limita a vida atual.
@export_range(1, 10000, 1, "or_greater") var vida_maxima_base: int = 100:
	set(value):
		vida_maxima_base = maxi(1, value)
		if is_node_ready() and is_instance_valid(equipment):
			recalculate_stats()
## Armadura base somada aos equipamentos; preserva as regras atuais de aplicação de dano.
@export_range(0, 1000, 1, "or_greater") var armadura_base: int = 0:
	set(value):
		armadura_base = maxi(0, value)
		if is_node_ready() and is_instance_valid(equipment):
			recalculate_stats()
## Força base antes dos bônus de equipamento.
@export_range(0, 1000, 1, "or_greater") var forca_base: int = 10:
	set(value):
		forca_base = maxi(0, value)
		if is_node_ready() and is_instance_valid(equipment):
			recalculate_stats()
## Destreza base antes dos bônus de equipamento.
@export_range(0, 1000, 1, "or_greater") var destreza_base: int = 10:
	set(value):
		destreza_base = maxi(0, value)
		if is_node_ready() and is_instance_valid(equipment):
			recalculate_stats()
## Inteligência base antes dos bônus de equipamento.
@export_range(0, 1000, 1, "or_greater") var inteligencia_base: int = 10:
	set(value):
		inteligencia_base = maxi(0, value)
		if is_node_ready() and is_instance_valid(equipment):
			recalculate_stats()

@export_group("COLETA")
## Distância máxima para coletar loot, tanto por clique quanto por aproximação.
@export_range(0.0, 20.0, 0.05, "or_greater", "suffix:m") var alcance_de_coleta: float = 1.75

# Compatibilidade de leitura para consumidores existentes; sem armazenamento duplicado.
var max_stamina: float:
	get:
		return stamina_maxima
var base_attack_damage: int:
	get:
		return dano_base
var attack_range: float:
	get:
		return alcance_de_ataque
var MOVEMENT_SPEED_SCALE: float:
	get:
		return escala_de_movimento
var HIT_ATTACK_LOCK: float:
	get:
		return trava_de_ataque_ao_receber_golpe

var stamina: float = 100.0
var is_running := false
var _stamina_delay := 0.0
var _stamina_exhausted := false

var weapon_drawn: bool:
	get:
		var visual := get_node_or_null("Visual")
		return visual != null and visual.is_weapon_in_hand()
const ATTACK_DAMAGE: int = 20

var max_health: int = 100
var attack_damage: int = ATTACK_DAMAGE
var armor: int = 0
var strength: int = 10
var dexterity: int = 10
var intelligence: int = 10
var equipment_bonuses: Dictionary = {}
var equipment: Node
var action_bar: Node
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var inventory: Node = $Inventory
var health: int = 100
var is_dead: bool = false
var death_sequence_finished := false
var approach_target: Node3D = null
var attack_cooldown: float = 0.0
var attack_hit_resolved: bool = false
var _manual_attack_click: Variant = null
var _manual_attack_held := false
var hit_attack_lock_timer: float = 0.0
var hit_move_lock_timer: float = 0.0
var _buffered_attack_point: Variant = null
var _manual_attack_buffer_timer: float = 0.0
var hit_recovery_timer: float = 0.0
var collect_target: Node3D = null
var level: int = 1
var xp: int = 0
var max_xp: int = 100

enum MoveMode { CLICK_MOVE, MANUAL_MOVE }
var move_mode: MoveMode = MoveMode.CLICK_MOVE
var _movement_input_mode := "hybrid"
var is_moving: bool = false
var move_direction: Vector3 = Vector3.ZERO


func _ready() -> void:
	stamina = stamina_maxima
	add_to_group("player")
	equipment = preload("res://equipment.gd").new()
	equipment.name = "Equipment"
	add_child(equipment)
	equipment.changed.connect(recalculate_stats)
	action_bar = preload("res://action_bar.gd").new()
	action_bar.name = "ActionBar"
	add_child(action_bar)
	_equip_starting_items()
	recalculate_stats()
	health = max_health
	var lock_component := preload("res://target_lock.gd").new()
	lock_component.name = "TargetLock"
	add_child(lock_component)
	var settings := get_node("/root/DisplaySettings")
	settings.interface_settings_applied.connect(_on_movement_settings_changed)
	_on_movement_settings_changed()

func allows_mouse_movement() -> bool:
	return _movement_input_mode != "wasd"

func allows_keyboard_movement() -> bool:
	return _movement_input_mode != "mouse"

func _on_movement_settings_changed() -> void:
	var mode: String = get_node("/root/DisplaySettings").movement_input_mode
	if mode == _movement_input_mode:
		return
	_movement_input_mode = mode
	_enter_manual_mode()
	velocity.x = 0.0
	velocity.z = 0.0
	is_moving = false
	move_direction = Vector3.ZERO

func _equip_starting_items() -> void:
	var starting_sword := load("res://items/espada_gasta.tres") as ItemData
	if starting_sword:
		equipment._items[ItemData.EquipmentSlot.WEAPON] = starting_sword
		equipment.changed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("manual_attack") and not event.is_echo():
		if is_dead or get_tree().paused or get_viewport().gui_is_dragging() or get_viewport().gui_get_hovered_control() != null:
			return
		_manual_attack_click = get_viewport().get_mouse_position()
		_manual_attack_held = true
		# Manual control replaces approach/auto-attack, so release really stops chaining.
		stop_approach()
		get_viewport().set_input_as_handled()
	if not is_dead and event.is_action_pressed("toggle_weapon") and not event.is_echo():
		$Visual.toggle_weapon()

func _input(event: InputEvent) -> void:
	# Releases must be seen even when the pointer has moved over UI.
	if event.is_action_released("manual_attack"):
		_manual_attack_held = false
		_buffered_attack_point = null
		_manual_attack_buffer_timer = 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_manual_attack_held = false
		_manual_attack_click = null
		_buffered_attack_point = null
		_manual_attack_buffer_timer = 0.0

func recalculate_stats() -> void:
	equipment_bonuses = equipment.get_bonuses()
		
	attack_damage = maxi(0, dano_base + equipment_bonuses.attack_damage)
	armor = maxi(0, armadura_base + equipment_bonuses.armor)
	strength = forca_base + equipment_bonuses.strength
	dexterity = destreza_base + equipment_bonuses.dexterity
	intelligence = inteligencia_base + equipment_bonuses.intelligence
	max_health = maxi(1, vida_maxima_base + equipment_bonuses.max_health)
	health = mini(health, max_health)
	stats_changed.emit()
	health_changed.emit(health, max_health)

func use_consumable(item: ItemData) -> bool:
	if is_dead or health <= 0 or health >= max_health or item == null or item.item_type != ItemData.ItemType.CONSUMABLE or item.equipment_slot != ItemData.EquipmentSlot.NONE or item.heal_amount <= 0:
		return false
	if not inventory.consume_one(item):
		return false
	health = mini(max_health, health + item.heal_amount)
	health_changed.emit(health, max_health)
	return true


func gain_xp(amount: int) -> void:
	xp += amount
	while xp >= max_xp:
		xp -= max_xp
		level += 1
		max_xp = _xp_for_level(level)
		level_up.emit(level)
	xp_changed.emit(xp, max_xp)


func _xp_for_level(lvl: int) -> int:
	return 80 + (lvl - 1) * 20


func set_destination(point: Vector3) -> void:
	if is_dead or not allows_mouse_movement():
		return
	move_mode = MoveMode.CLICK_MOVE
	approach_target = null
	_set_collect_target(null)
	if NavigationServer3D.map_get_iteration_id(navigation_agent.get_navigation_map()) > 0:
		navigation_agent.target_position = point


func approach_enemy(enemy: Node3D) -> void:
	if is_dead or not allows_mouse_movement():
		return
	set_destination(enemy.global_position)
	approach_target = enemy
	_set_collect_target(null)


func approach_loot(loot: Node3D) -> void:
	if is_dead or not is_instance_valid(loot):
		return
	var dist := global_position.distance_to(loot.global_position)
	if dist <= alcance_de_coleta:
		if loot.has_method("try_pickup"):
			if loot.try_pickup(inventory):
				_set_collect_target(null)
				return
	if not allows_mouse_movement():
		return
	set_destination(loot.global_position)
	_set_collect_target(loot)
	approach_target = null


func _set_collect_target(new_target: Node3D) -> void:
	if is_instance_valid(collect_target) and collect_target != new_target:
		if collect_target.has_method("set_targeted"):
			collect_target.set_targeted(false)
	collect_target = new_target
	if is_instance_valid(collect_target):
		if collect_target.has_method("set_targeted"):
			collect_target.set_targeted(true)


func stop_approach() -> void:
	approach_target = null
	_set_collect_target(null)
	if is_dead:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	set_destination(global_position)
	velocity.x = 0.0
	velocity.z = 0.0


func _enter_manual_mode() -> void:
	move_mode = MoveMode.MANUAL_MOVE
	approach_target = null
	_set_collect_target(null)
	if NavigationServer3D.map_get_iteration_id(navigation_agent.get_navigation_map()) > 0:
		navigation_agent.target_position = global_position


func get_movement_speed_multiplier() -> float:
	return escala_de_movimento * (multiplicador_com_arma if weapon_drawn else 1.0)


func _manual_move(manual_input: Vector2) -> void:
	var fwd := Vector3(0.0, 0.0, -1.0)
	var right := Vector3(1.0, 0.0, 0.0)
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		fwd = -cam.global_transform.basis.z
		fwd.y = 0.0
		right = cam.global_transform.basis.x
		right.y = 0.0
		fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3(0.0, 0.0, -1.0)
		right = right.normalized() if right.length() > 0.01 else Vector3(1.0, 0.0, 0.0)
	var direction := right * manual_input.x - fwd * manual_input.y
	if direction.length() > 1.0:
		direction = direction.normalized()
		
	var running := _can_run()
	var current_speed = velocidade_de_movimento * get_movement_speed_multiplier() * (multiplicador_de_corrida if running else 1.0)
	
	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed

	is_moving = true
	move_direction = direction.normalized()


func _update_anim_state() -> void:
	var planar := Vector2(velocity.x, velocity.z).length()
	is_moving = planar > 0.1
	if is_moving:
		move_direction = Vector3(velocity.x, 0.0, velocity.z).normalized()
	else:
		move_direction = Vector3.ZERO


func _can_run() -> bool:
	return Input.is_action_pressed("run") and stamina > 0.0 and not _stamina_exhausted


func _update_stamina(delta: float, moving_on_ground: bool) -> void:
	var previous := stamina
	is_running = moving_on_ground and _can_run()
	if is_running:
		stamina = maxf(0.0, stamina - consumo_por_segundo * delta)
		_stamina_delay = atraso_para_regenerar
		if stamina <= 0.0:
			_stamina_exhausted = true
			is_running = false
	else:
		var waiting := minf(_stamina_delay, delta)
		_stamina_delay = maxf(0.0, _stamina_delay - delta)
		stamina = minf(stamina_maxima, stamina + regeneracao_por_segundo * (delta - waiting))
		if stamina >= stamina_maxima * percentual_para_retomar_corrida:
			_stamina_exhausted = false
	if not is_equal_approx(previous, stamina):
		stamina_changed.emit(stamina, stamina_maxima)


func is_in_attack_range() -> bool:
	if is_dead:
		return false
	if not is_instance_valid(approach_target):
		return false
	var difference := approach_target.global_position - global_position
	if difference.length() > alcance_de_ataque or absf(difference.y) > 0.35:
		return false
	var origin := global_position + Vector3.UP * 0.9
	var end := approach_target.global_position + Vector3.UP * 0.9
	var query := PhysicsRayQueryParameters3D.create(origin, end, 3)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _try_collect() -> void:
	if not is_instance_valid(collect_target):
		_set_collect_target(null)
		return
	var dist := global_position.distance_to(collect_target.global_position)
	if dist <= alcance_de_coleta:
		var loot := collect_target as StaticBody3D
		if loot and loot.has_method("try_pickup"):
			if loot.try_pickup(inventory):
				_set_collect_target(null)
			else:
				_set_collect_target(null)


func _physics_process(delta: float) -> void:
	hit_recovery_timer = maxf(0.0, hit_recovery_timer - delta)
	hit_attack_lock_timer = maxf(0.0, hit_attack_lock_timer - delta)
	hit_move_lock_timer = maxf(0.0, hit_move_lock_timer - delta)
	_manual_attack_buffer_timer = maxf(0.0, _manual_attack_buffer_timer - delta)
	if _manual_attack_buffer_timer <= 0.0:
		_buffered_attack_point = null
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= gravidade * delta
	else:
		velocity.y = 0.0

	if is_dead:
		move_and_slide()
		_update_anim_state()
		is_running = false
		_manual_attack_held = false
		_manual_attack_click = null
		_buffered_attack_point = null
		return

	# Damage flinch: a brief pause before movement inputs are accepted again.
	if hit_move_lock_timer > 0.0:
		move_and_slide()
		_update_anim_state()
		_update_stamina(delta, false)
		return

	if _manual_attack_click != null:
		var point: Variant = _mouse_attack_point(_manual_attack_click)
		_manual_attack_click = null
		if point is Vector3:
			request_manual_attack(point)
	if _buffered_attack_point != null:
		_try_start_manual_attack(_buffered_attack_point)
	if _manual_attack_held:
		if not Input.is_action_pressed("manual_attack") or get_viewport().gui_is_dragging() or get_viewport().gui_get_hovered_control() != null:
			_manual_attack_held = false
			_buffered_attack_point = null
		elif attack_cooldown <= 0.0 and $Visual.can_start_manual_attack():
			# Aim again at each new strike without redirecting the committed animation.
			var held_point: Variant = _mouse_attack_point(get_viewport().get_mouse_position())
			if held_point is Vector3:
				_try_start_manual_attack(held_point)

	# Keep gravidade, but defer movement commands until the attack or hit clip finishes.
	if $Visual.is_attack_movement_locked() or $Visual.is_hit_movement_locked():
		move_and_slide()
		_update_anim_state()
		_update_stamina(delta, false)
		return

	var map_ready := NavigationServer3D.map_get_iteration_id(navigation_agent.get_navigation_map()) > 0
	if approach_target != null:
		if not is_instance_valid(approach_target):
			stop_approach()
		elif map_ready and navigation_agent.target_position.distance_to(approach_target.global_position) > 0.25:
			navigation_agent.target_position = approach_target.global_position
	if collect_target != null:
		if not is_instance_valid(collect_target):
			_set_collect_target(null)
		elif map_ready and navigation_agent.target_position.distance_to(collect_target.global_position) > 0.25:
			navigation_agent.target_position = collect_target.global_position
	var manual_input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward") if allows_keyboard_movement() else Vector2.ZERO
	if manual_input.length() > 0.01:
		if move_mode != MoveMode.MANUAL_MOVE:
			_enter_manual_mode()
		_manual_move(manual_input)
	else:
		if move_mode == MoveMode.MANUAL_MOVE and map_ready:
			navigation_agent.target_position = global_position
		move_mode = MoveMode.CLICK_MOVE
		if allows_mouse_movement() and map_ready and not is_in_attack_range() and not navigation_agent.is_navigation_finished():
			var running := _can_run()
			var current_speed = velocidade_de_movimento * get_movement_speed_multiplier() * (multiplicador_de_corrida if running else 1.0)
			
			var next_point := navigation_agent.get_next_path_position()
			var direction := next_point - global_position
			direction.y = 0.0
			if direction.length() > 0.01:
				var movement := direction.normalized() * minf(current_speed, direction.length() / delta)
				velocity.x = movement.x
				velocity.z = movement.z

			elif (next_point - global_position).length() > 0.15:
				var to_target := navigation_agent.target_position - global_position
				to_target.y = 0.0
				if to_target.length() > 0.2:
					var advance := to_target.normalized() * minf(current_speed, to_target.length() / delta)
					velocity.x = advance.x
					velocity.z = advance.z
			_update_anim_state()

	move_and_slide()
	_update_anim_state()
	var actual_velocity := get_real_velocity()
	_update_stamina(delta, is_on_floor() and Vector2(actual_velocity.x, actual_velocity.z).length() > 0.1)

	if _buffered_attack_point == null and is_in_attack_range() and approach_target.is_selected and attack_cooldown <= 0.0 and $Visual.can_start_manual_attack():
		attack_cooldown = intervalo_armado if weapon_drawn else intervalo_desarmado
		attack_hit_resolved = false
		attack_executed.emit(approach_target, attack_cooldown)

	if collect_target != null:
		_try_collect()


func take_damage(amount: int, damage_type: int = COMBAT_TEXT.DamageType.PLAYER_DAMAGE, is_critical: bool = false) -> void:
	if is_dead or health <= 0 or amount <= 0 or hit_recovery_timer > 0.0:
		return
	hit_recovery_timer = 0.25
	hit_move_lock_timer = trava_de_movimento_ao_receber_golpe
	COMBAT_TEXT.show_damage_number(self, global_position + Vector3.UP * 1.6, mini(amount, health), damage_type, is_critical)
	health = maxi(0, health - amount)
	if health > 0:
		took_hit.emit()
	health_changed.emit(health, max_health)
	if health == 0:
		is_dead = true
		approach_target = null
		_set_collect_target(null)
		velocity.x = 0.0
		velocity.z = 0.0
		is_moving = false
		move_direction = Vector3.ZERO
		died.emit()

func _on_attack_impact(target: Node3D = null, manual_direction: Vector3 = Vector3.ZERO) -> void:
	if is_dead or attack_hit_resolved:
		return
	attack_hit_resolved = true
	if atacar_em_area:
		var direction := manual_direction
		if direction.is_zero_approx():
			direction = $Visual.global_basis.z
		direction.y = 0.0
		direction = direction.normalized()
		var targets: Array[Node3D] = []
		for candidate in get_tree().get_nodes_in_group("enemies"):
			if candidate is Node3D and _can_hit_manually(candidate, direction):
				targets.append(candidate)
		# A lista é capturada antes de dano/morte alterarem a seleção ou a árvore.
		for candidate in targets:
			if is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
				_apply_attack_damage(candidate)
		return
	
	if not manual_direction.is_zero_approx():
		target = _find_manual_attack_target(manual_direction)
	elif target == null:
		target = approach_target
	if not is_instance_valid(target):
		return
	_apply_attack_damage(target)


func _apply_attack_damage(target: Node3D) -> void:
	var difference := target.global_position - global_position
	if difference.length() > alcance_de_ataque or absf(difference.y) > 0.35 or target.health <= 0:
		return
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.9, target.global_position + Vector3.UP * 0.9, 3)
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return
		
	var final_damage = attack_damage if weapon_drawn else dano_desarmado
	var armed := weapon_drawn
	var hit_position := target.global_position + Vector3.UP * 1.0 - difference.normalized() * 0.3
	var hp_before: int = target.health
	target.take_damage(final_damage)
	var damage_dealt: bool = not is_instance_valid(target) or target.health < hp_before
	if damage_dealt:
		HIT_EFFECT.spawn(get_tree().current_scene, hit_position, armed)
		var camera := get_viewport().get_camera_3d()
		if camera and camera.has_method("play_hit_impulse"):
			camera.play_hit_impulse(difference, 1.0 if armed else 0.45)
	
	if is_instance_valid(target) and hp_before > 0 and target.health <= 0:
		gain_xp(25)
	elif not is_instance_valid(target):
		gain_xp(25)


func request_manual_attack(world_point: Vector3) -> bool:
	if is_dead or get_tree().paused:
		return false
	# One slot: a newer click replaces the aim and expiry, never adds a queued attack.
	_buffered_attack_point = world_point
	_manual_attack_buffer_timer = buffer_de_ataque_manual
	return _try_start_manual_attack(world_point)


func _try_start_manual_attack(world_point: Vector3) -> bool:
	if is_dead or get_tree().paused or attack_cooldown > 0.0 or not $Visual.can_start_manual_attack():
		return false
	_buffered_attack_point = null
	_manual_attack_buffer_timer = 0.0
	attack_cooldown = intervalo_armado if weapon_drawn else intervalo_desarmado
	attack_hit_resolved = false
	var locked := get_locked_target()
	if locked != null:
		world_point = locked.global_position
	manual_attack_requested.emit(world_point)
	return true


func _mouse_attack_point(screen_position: Vector2) -> Variant:
	var locked := get_locked_target()
	if locked != null:
		return locked.global_position
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	# Environment only: enemies, loot and the Player cannot intercept the aiming ray.
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * camera.far, 3)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit.position
	# Empty sky/background still provides a horizontal aiming point at Player height.
	return Plane(Vector3.UP, global_position.y).intersects_ray(origin, direction)


func _find_manual_attack_target(direction: Vector3) -> Node3D:
	var locked := get_locked_target()
	if _can_hit_manually(locked, direction):
		return locked
	if _can_hit_manually(approach_target, direction):
		return approach_target
	var closest: Node3D = null
	var best_distance := INF
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if candidate is Node3D and _can_hit_manually(candidate, direction):
			var distance := global_position.distance_squared_to(candidate.global_position)
			if distance < best_distance:
				best_distance = distance
				closest = candidate
	return closest


func get_locked_target() -> Node3D:
	var component := get_node_or_null("TargetLock")
	var locked: Node3D = component.get_target() if component != null else null
	return locked if is_instance_valid(locked) else null


func _can_hit_manually(target: Node3D, direction: Vector3) -> bool:
	if not is_instance_valid(target) or not target.is_in_group("enemies") or not target.has_method("take_damage") or target.get("health") == null or target.health <= 0:
		return false
	var difference := target.global_position - global_position
	if difference.length() > alcance_de_ataque or absf(difference.y) > 0.35:
		return false
	difference.y = 0.0
	# Cone frontal compartilhado pela seleção individual e pelo ataque em área.
	if not difference.is_zero_approx() and difference.normalized().dot(direction) < 0.5:
		return false
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.9, target.global_position + Vector3.UP * 0.9, 3)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
