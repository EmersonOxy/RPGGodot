extends Node
## First lock-on stage: independent from click-to-approach and camera control.
@export var acquire_distance := 12.0
@export var release_distance := 18.0
var target: Node3D
var _facing_held := false
class LockDot extends Node2D:
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 7.0, Color(0.0, 0.0, 0.0, 0.85), true, -1.0, true)
		draw_circle(Vector2.ZERO, 5.0, Color.WHITE, true, -1.0, true)

var _marker: Node2D
@onready var player: Node3D = get_parent()

func _ready() -> void:
	process_priority = 10 # Project after the camera has updated its follow/zoom.
	var overlay := CanvasLayer.new()
	overlay.name = "TargetLockOverlay"
	overlay.layer = 0 # Above the 3D world, below the game menus.
	add_child(overlay)
	_marker = LockDot.new()
	_marker.name = "TargetLockMarker"
	_marker.visible = false
	overlay.add_child(_marker)

func get_target() -> Node3D:
	if target != null and (not _alive(target) or player.get("is_dead") == true or player.global_position.distance_to(target.global_position) > release_distance):
		clear()
	return target

func clear() -> void:
	target = null
	_facing_held = false
	if is_instance_valid(_marker):
		_marker.visible = false

func _alive(enemy: Variant) -> bool:
	return is_instance_valid(enemy) and enemy is Node3D and not enemy.is_queued_for_deletion() and enemy.is_inside_tree() and enemy.is_in_group("enemies") and enemy.get("health") != null and enemy.get("health") > 0

func _target_center(enemy: Node3D) -> Vector3:
	var body_shape := enemy.get_node_or_null("CollisionShape3D") as CollisionShape3D
	return body_shape.global_position if body_shape != null else enemy.global_position + Vector3.UP * 0.9

func _can_acquire(enemy: Variant, camera: Camera3D) -> bool:
	if not _alive(enemy) or not enemy.is_visible_in_tree() or player.global_position.distance_to(enemy.global_position) > acquire_distance:
		return false
	var point: Vector3 = _target_center(enemy)
	if camera.is_position_behind(point) or not get_viewport().get_visible_rect().has_point(camera.unproject_position(point)):
		return false
	var ray := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.9, point, 3)
	return player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func toggle() -> void:
	if get_tree().paused or player.get("is_dead") == true:
		return
	if get_target() != null:
		clear()
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var preferred: Node3D = player.get_parent().get("selected_enemy")
	if _can_acquire(preferred, camera):
		target = preferred
		return
	var best := INF
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if candidate is Node3D and _can_acquire(candidate, camera):
			var score := camera.unproject_position(_target_center(candidate)).distance_squared_to(get_viewport().get_mouse_position())
			if score < best:
				best = score
				target = candidate

func switch_target(side: int) -> bool:
	if get_tree().paused or get_target() == null or side == 0:
		return false
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var origin := camera.unproject_position(_target_center(target))
	var best := INF
	var next_target: Node3D = null
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if candidate == target or not candidate is Node3D or not _can_acquire(candidate, camera):
			continue
		var offset := camera.unproject_position(_target_center(candidate)) - origin
		if offset.x * signi(side) <= 0.5:
			continue
		var score := offset.length_squared()
		if score < best or (is_equal_approx(score, best) and next_target != null and candidate.get_instance_id() < next_target.get_instance_id()):
			best = score
			next_target = candidate
	if next_target == null:
		return false
	target = next_target
	_process(0.0)
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("hold_target_facing") and not event.is_echo():
		if not _facing_input_blocked():
			_facing_held = true
			get_viewport().set_input_as_handled()
		return
	var toggling := event.is_action_pressed("toggle_target_lock")
	var left := event.is_action_pressed("target_lock_left")
	var right := event.is_action_pressed("target_lock_right")
	if (toggling or left or right) and not event.is_echo():
		# Keyboard commands must not depend on where the mouse happens to be.
		var focus := get_viewport().gui_get_focus_owner()
		var inventory := player.get_parent().get_node_or_null("Interface/UIManager/InventoryMenu")
		if get_tree().paused or player.get("is_dead") == true or get_viewport().gui_is_dragging() or focus is LineEdit or focus is TextEdit:
			return
		if inventory != null and inventory.get("_is_open") == true:
			return
		if not toggling:
			if get_target() != null:
				switch_target(-1 if left else 1)
				get_viewport().set_input_as_handled()
			return
		var was_locked := get_target() != null
		toggle()
		_process(0.0)
		var scene := player.get_parent()
		if scene.has_method("show_notification"):
			if get_target() != null:
				scene.show_notification("Alvo travado — T para destravar")
			elif was_locked:
				scene.show_notification("Alvo destravado")
			else:
				scene.show_notification("Nenhum alvo válido: aproxime-se de um inimigo visível")
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if event.is_action_released("hold_target_facing"):
		_facing_held = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_facing_held = false

func _facing_input_blocked() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	var inventory := player.get_parent().get_node_or_null("Interface/UIManager/InventoryMenu")
	return get_tree().paused or player.get("is_dead") == true or get_viewport().gui_is_dragging() or focus is LineEdit or focus is TextEdit or (inventory != null and inventory.get("_is_open") == true)

func get_facing_direction() -> Vector3:
	if not _facing_held:
		return Vector3.ZERO
	if not Input.is_action_pressed("hold_target_facing") or _facing_input_blocked():
		_facing_held = false
		return Vector3.ZERO
	var current := target
	if current != null and not _alive(current):
		clear()
		current = null
	if current == null:
		return _direction_to_mouse(get_viewport().get_mouse_position())
	var direction := current.global_position - player.global_position
	direction.y = 0.0
	return direction

func _direction_to_mouse(cursor: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.ZERO
	var origin := camera.project_ray_origin(cursor)
	var normal := camera.project_ray_normal(cursor)
	if absf(normal.y) < 0.0001:
		return Vector3.ZERO
	var t := (player.global_position.y - origin.y) / normal.y
	var point := origin + normal * t
	var direction := point - player.global_position
	direction.y = 0.0
	return direction

func _process(_delta: float) -> void:
	var current := get_target()
	if current == null:
		return
	var camera := get_viewport().get_camera_3d()
	var center := _target_center(current)
	_marker.visible = camera != null and current.is_visible_in_tree() and not camera.is_position_behind(center)
	if camera != null:
		_marker.position = camera.unproject_position(center)
