extends Node3D

const CLICK_INDICATOR_SCENE := preload("res://click_indicator.tscn")

@onready var camera: Camera3D = $Player/Camera3D
@onready var player: CharacterBody3D = $Player
@onready var click_indicator: Node3D = get_node_or_null("ClickIndicator")
@onready var death_label: Label = $Interface/DeathLabel
@onready var notification_label: Label = $Interface/NotificationLabel
@onready var inventory_menu: Control = $Interface/UIManager/InventoryMenu

var click_position := Vector2.ZERO
var click_pending := false
var selected_enemy: Node3D = null
var _notification_tween: Tween


func _ready() -> void:
	if click_indicator == null:
		click_indicator = CLICK_INDICATOR_SCENE.instantiate()
		click_indicator.name = "ClickIndicator"
		add_child(click_indicator)
	death_label.visible = false
	player.died.connect(_on_player_died)
	player.get_node("Visual").death_animation_finished.connect(_on_death_animation_finished)


func select_enemy(enemy: Node3D) -> void:
	if is_instance_valid(selected_enemy):
		if selected_enemy.died.is_connected(_on_selected_enemy_died):
			selected_enemy.died.disconnect(_on_selected_enemy_died)
		if selected_enemy.has_method("set_selected"):
			selected_enemy.set_selected(false)
	selected_enemy = enemy
	if is_instance_valid(selected_enemy):
		if selected_enemy.has_method("set_selected"):
			selected_enemy.set_selected(true)
		selected_enemy.died.connect(_on_selected_enemy_died)


func _on_selected_enemy_died(_enemy: Node3D) -> void:
	select_enemy(null)
	player.stop_approach()



func _on_player_died() -> void:
	click_pending = false
	select_enemy(null)
	click_indicator.hide()
	inventory_menu.close()
	$Interface/PlayerHUD.hide()
	notification_label.hide()

func _on_death_animation_finished() -> void:
	player.death_sequence_finished = true
	death_label.visible = true

func _input(_event: InputEvent) -> void:
	if player.is_dead and not player.death_sequence_finished:
		get_viewport().set_input_as_handled()


func show_notification(text: String, duration: float = 1.5) -> void:
	notification_label.text = text
	notification_label.visible = true
	if _notification_tween:
		_notification_tween.kill()
	_notification_tween = create_tween()
	_notification_tween.tween_interval(duration)
	_notification_tween.tween_callback(func(): notification_label.visible = false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		click_pending = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Ignorar cliques dentro do inventário
			if inventory_menu and inventory_menu._is_open:
				var inv_rect: Rect2 = inventory_menu.get_node("Panel").get_global_rect()
				if inv_rect.has_point(event.position):
					return
			click_position = event.position
			click_pending = true
	elif event is InputEventKey:
		if event.pressed and not event.echo and player.is_dead and player.death_sequence_finished:
			if event.keycode == KEY_R or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
				get_tree().reload_current_scene()


func _resolve_loot(collider: Object) -> Node3D:
	if collider == null:
		return null
	if collider.is_in_group("loot"):
		if collider is StaticBody3D:
			return collider as Node3D
		elif collider.get_parent() and collider.get_parent().is_in_group("loot"):
			return collider.get_parent() as Node3D
	return null


func _physics_process(_delta: float) -> void:
	if not click_pending:
		return
	click_pending = false
	if player.is_dead:
		return
	# Nameplates render above the world; pick their visible rectangles before a body
	# or terrain ray can intercept the click (including while stacking is moving).
	var label_manager := get_node_or_null("LootLabelManager")
	if label_manager:
		var label_loot: Node3D = label_manager.get_loot_at_screen_position(click_position)
		if label_loot != null:
			select_enemy(null)
			player.approach_loot(label_loot)
			return

	var origin := camera.project_ray_origin(click_position)
	var end := origin + camera.project_ray_normal(click_position) * 100.0

	# 1. Prioridade máxima: Loot (camada 16).
	# collide_with_areas = true garante detecção instantânea do loot e de sua ClickArea sobre qualquer chão.
	var loot_query := PhysicsRayQueryParameters3D.create(origin, end, 16)
	loot_query.collide_with_areas = true
	var loot_hit := get_world_3d().direct_space_state.intersect_ray(loot_query)
	if not loot_hit.is_empty():
		var loot_node := _resolve_loot(loot_hit.collider)
		if loot_node != null:
			select_enemy(null)
			player.approach_loot(loot_node)
			return

	# 2. Inimigos e chão transitável
	var query := PhysicsRayQueryParameters3D.create(origin, end, 29)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return

	if hit.collider.is_in_group("loot"):
		var loot_node := _resolve_loot(hit.collider)
		if loot_node != null:
			select_enemy(null)
			player.approach_loot(loot_node)
			return

	if hit.collider.is_in_group("enemies"):
		select_enemy(hit.collider)
		player.approach_enemy(hit.collider)
		return

	if hit.collider.is_in_group("walkable") and hit.normal.y > 0.7:
		select_enemy(null)
		player.set_destination(hit.position)
		click_indicator.show_at(hit.position, hit.normal)
