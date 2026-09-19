extends StaticBody3D

const RARITY_COLORS := {
	0: Color(0.88, 0.88, 0.85),   # COMMON - cinza claro / branco
	1: Color(0.25, 0.90, 0.30),   # UNCOMMON - verde vivo
	2: Color(0.30, 0.55, 1.00),   # RARE - azul evidente
	3: Color(0.72, 0.30, 1.00),   # EPIC - roxo evidente
	4: Color(1.00, 0.65, 0.08),   # LEGENDARY - dourado / laranja
}

# Compensação visual de zoom: multiplicador aplicado apenas ao modelo 3D.
const ZOOM_REFERENCE_SIZE := 19.0
const ZOOM_SCALE_STRENGTH := 0.7
const ZOOM_MIN_MULTIPLIER := 0.75
const ZOOM_MAX_MULTIPLIER := 1.6
const CAMERA_FOLLOW = preload("res://camera_follow.gd")

var item: ItemData = null:
	set(value):
		item = value
		if is_inside_tree():
			_setup_visuals()

@export var pickup_sound: AudioStream = preload("res://assets/sound/ui/pegar_item.mp3")
@export_range(-40.0, 6.0) var pickup_volume_db := 0.0
@export var quantity: int = 1
@export var label_distance := 14.0
@export var hover_scale := 1.04
@export var hover_duration := 0.12
@export var base_emission_intensity := 0.35
@export var hover_emission_intensity := 1.2
@export var target_emission_intensity := 1.6

var _collected := false
var _is_hovered := false
var _is_targeted := false
var _spawning := false
var _label_anchor := Vector3.ZERO
var _bob_tween: Tween
var _rot_tween: Tween
var _hover_tween: Tween
var _pulse_tween: Tween
var _spawn_tween: Tween
var _label_fade: Tween
var _mat: StandardMaterial3D
var _backing_mesh: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _custom_model: Node3D = null
var _custom_materials: Array[StandardMaterial3D] = []
var _zoom_root: Node3D
var _stacking_root: Node3D
var _nameplate_scale_root: Node3D
var _camera: Camera3D
var _body_shape: CylinderShape3D
var _label_width := 2.0
var _label_manager: Node
var _body_hovered := false
var _label_hovered := false
var _label_blocks_body := false

@onready var visual_root: Node3D = $VisualRoot
@onready var mesh: MeshInstance3D = $VisualRoot/MeshInstance3D
@onready var label: Label3D = $Label3D
@onready var area: Area3D = $ClickArea
@onready var target_ring: MeshInstance3D = get_node_or_null("TargetRing")
@onready var _label_collision: CollisionShape3D = get_node_or_null("ClickArea/LabelCollision")
var _label_shape: BoxShape3D


func _ready() -> void:
	process_priority = 1 # Camera first, then visual dimensions, then manager (100).
	add_to_group("loot")
	if area:
		area.add_to_group("loot")
		area.mouse_entered.connect(_on_mouse_entered)
		area.mouse_exited.connect(_on_mouse_exited)

	# ZoomScaleRoot fica entre o loot e o VisualRoot: a compensação de zoom
	# multiplica sem brigar com as animações de spawn/hover (que escrevem
	# apenas no VisualRoot).
	_zoom_root = Node3D.new()
	_zoom_root.name = "ZoomScaleRoot"
	add_child(_zoom_root)
	remove_child(visual_root)
	_zoom_root.add_child(visual_root)

	# StackingRoot carrega apenas o label: o layout de pilha dos nameplates
	# escreve nele, sem conflitar com a animação de nascimento do label.
	_stacking_root = Node3D.new()
	_stacking_root.name = "StackingRoot"
	add_child(_stacking_root)
	remove_child(label)
	_nameplate_scale_root = Node3D.new()
	_nameplate_scale_root.name = "NameplateScaleRoot"
	_stacking_root.add_child(_nameplate_scale_root)
	_nameplate_scale_root.position = label.position
	label.position = Vector3.ZERO
	_nameplate_scale_root.add_child(label)
	_update_nameplate_zoom_scale()

	# Registra no gerenciador central de layout dos nameplates.
	_register_label_manager.call_deferred()

	# O cilindro do corpo é compartilhado entre o StaticBody e a ClickArea;
	# duplicado por instância para acompanhar parcialmente o zoom.
	var body_collider := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if body_collider and body_collider.shape is CylinderShape3D:
		_body_shape = (body_collider.shape as CylinderShape3D).duplicate() as CylinderShape3D
		body_collider.shape = _body_shape
		var area_collider := get_node_or_null("ClickArea/CollisionShape3D") as CollisionShape3D
		if area_collider:
			area_collider.shape = _body_shape

	collision_layer = 16
	collision_mask = 0
	set_collision_layer_value(5, true)

	# Guardar referência ao material do anel com material único por instância
	if target_ring and target_ring.mesh and target_ring.mesh.material:
		_ring_mat = (target_ring.mesh.material as StandardMaterial3D).duplicate()
		target_ring.material_override = _ring_mat

	if item != null:
		_setup_visuals()

	_start_bob_animation()


func _setup_visuals() -> void:
	if item == null:
		return

	if _custom_model and is_instance_valid(_custom_model):
		_custom_model.queue_free()
		_custom_model = null
	_custom_materials.clear()

	if item.world_scene != null:
		mesh.visible = false
		_mat = null
		_custom_model = item.world_scene.instantiate() as Node3D
		visual_root.add_child(_custom_model)
		_custom_model.scale = item.world_scale if item.world_scale != Vector3.ZERO else Vector3.ONE
		_custom_model.rotation = item.world_rotation
		_custom_model.position = item.world_position

		for child in _custom_model.find_children("*", "MeshInstance3D", true, false):
			var mi := child as MeshInstance3D
			for slot in range(mi.get_surface_override_material_count()):
				var sm := mi.get_active_material(slot)
				if sm is StandardMaterial3D and not sm in _custom_materials:
					var dup := sm.duplicate() as StandardMaterial3D
					mi.set_surface_override_material(slot, dup)
					dup.emission_enabled = true
					dup.emission = item.icon_color * base_emission_intensity
					_custom_materials.append(dup)
			if _custom_materials.is_empty():
				var sm := mi.get_active_material(0)
				if sm is StandardMaterial3D and not sm in _custom_materials:
					var dup := sm.duplicate() as StandardMaterial3D
					mi.material_override = dup
					dup.emission_enabled = true
					dup.emission = item.icon_color * base_emission_intensity
					_custom_materials.append(dup)
	else:
		mesh.visible = true
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = item.icon_color
		_mat.emission_enabled = true
		_mat.emission = item.icon_color * base_emission_intensity
		mesh.material_override = _mat

	var rarity_color: Color = RARITY_COLORS.get(item.rarity, RARITY_COLORS[0])
	label.text = item.display_name + ("  ×%d" % quantity if quantity > 1 else "")
	label.modulate = rarity_color
	label.outline_modulate = Color.BLACK
	label.outline_size = 12
	label.pixel_size = 0.0063
	label.font_size = 48
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10

	if _ring_mat:
		_ring_mat.albedo_color = rarity_color.lightened(0.2)
		_ring_mat.albedo_color.a = 0.0

	_create_or_update_backing()


func _create_or_update_backing() -> void:
	var font := label.font if label.font != null else ThemeDB.fallback_font
	var text_width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x
	var backing_width: float = text_width * label.pixel_size + 0.32
	_label_width = backing_width
	if _backing_mesh == null:
		_backing_mesh = MeshInstance3D.new()
		_backing_mesh.name = "LabelBacking"
		var quad := QuadMesh.new()
		quad.size = Vector2(backing_width, 0.58)

		var backing_material := StandardMaterial3D.new()
		backing_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		backing_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		backing_material.albedo_color = Color(0.02, 0.025, 0.02, 0.85)
		backing_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		# Preserve inherited zoom/spawn scale when the shader faces the camera.
		backing_material.billboard_keep_scale = true
		backing_material.no_depth_test = true
		backing_material.render_priority = 9
		quad.material = backing_material

		_backing_mesh.mesh = quad
		_backing_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		label.add_child(_backing_mesh)
		_backing_mesh.position = Vector3(0, 0, -0.01)
	(_backing_mesh.mesh as QuadMesh).size = Vector2(backing_width, 0.58)
	_update_label_collision(backing_width)

	_start_bob_animation()


func _update_label_collision(width: float) -> void:
	# A área interativa do nome acompanha exatamente o fundo visível.
	if _label_collision == null:
		return
	if _label_shape == null:
		if _label_collision.shape is BoxShape3D:
			_label_shape = (_label_collision.shape as BoxShape3D).duplicate() as BoxShape3D
		else:
			_label_shape = BoxShape3D.new()
		_label_collision.shape = _label_shape
	_label_shape.size = Vector3(width, 0.58, 0.04)
	_sync_label_collision()


func _sync_label_collision() -> void:
	if _label_collision == null or _label_shape == null or _backing_mesh == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	# Billboard dimensions include both zoom and spawn scale.
	var size := Vector3(maxf(get_label_width(), 0.001), maxf(get_label_height(), 0.001), 0.04)
	if not _label_shape.size.is_equal_approx(size):
		_label_shape.size = size
	var transform := Transform3D(camera.global_basis.orthonormalized(), _backing_mesh.global_position)
	if _label_collision.global_transform != transform:
		_label_collision.global_transform = transform
	var disabled := not is_label_visible()
	if _label_collision.disabled != disabled:
		_label_collision.set_deferred("disabled", disabled)


func _start_bob_animation() -> void:
	if _bob_tween:
		_bob_tween.kill()
		_bob_tween = null
	if _rot_tween:
		_rot_tween.kill()
		_rot_tween = null

	if item != null and item.world_display_mode == ItemData.WorldDisplayMode.GROUND_STATIC:
		visual_root.position = Vector3(0, 0.02 + item.world_ground_offset, 0)
		visual_root.rotation = Vector3.ZERO
		return

	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(visual_root, "position:y", 0.4, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(visual_root, "position:y", 0.25, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_rot_tween = create_tween().set_loops()
	_rot_tween.tween_property(visual_root, "rotation:y", TAU, 4.0).set_trans(Tween.TRANS_LINEAR)


func _on_mouse_entered() -> void:
	if _spawning:
		return
	_body_hovered = true
	_refresh_mouse_hover()


func _on_mouse_exited() -> void:
	if _spawning:
		return
	_body_hovered = false
	_refresh_mouse_hover()


func set_label_hover(hovered: bool, blocks_body: bool) -> void:
	_label_hovered = hovered
	_label_blocks_body = blocks_body
	_refresh_mouse_hover()


func _refresh_mouse_hover() -> void:
	var hovered := not _spawning and (_label_hovered or (_body_hovered and not _label_blocks_body))
	if _label_hovered:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	if hovered == _is_hovered:
		return
	_is_hovered = hovered
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovered else Input.CURSOR_ARROW)
	_update_visual_state(true)


func set_targeted(value: bool) -> void:
	_is_targeted = value
	_update_visual_state(true)
	if value:
		_start_pulse()
	else:
		_stop_pulse()


func _start_pulse() -> void:
	_stop_pulse()
	if _ring_mat == null:
		return
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_method(_set_ring_alpha, 0.6, 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_method(_set_ring_alpha, 1.0, 0.6, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null


func _set_ring_alpha(a: float) -> void:
	if _ring_mat:
		_ring_mat.albedo_color.a = a


func _update_visual_state(animate: bool) -> void:
	if item == null or _spawning:
		return

	var rarity_color: Color = RARITY_COLORS.get(item.rarity, RARITY_COLORS[0])

	# Determinar intensidades com base no estado
	var emission_mult: float
	var target_scale: Vector3
	var target_label_color: Color
	var target_outline: int
	var ring_alpha: float

	if _is_targeted:
		emission_mult = target_emission_intensity
		target_scale = Vector3.ONE * hover_scale
		target_label_color = rarity_color.lightened(0.35)
		target_outline = 22
		ring_alpha = 0.8
	elif _is_hovered:
		emission_mult = hover_emission_intensity
		target_scale = Vector3.ONE * hover_scale
		target_label_color = rarity_color.lightened(0.25)
		target_outline = 18
		ring_alpha = 0.35
	else:
		emission_mult = base_emission_intensity
		target_scale = Vector3.ONE
		target_label_color = rarity_color
		target_outline = 12
		ring_alpha = 0.0

	var target_emission: Color = item.icon_color * emission_mult

	# Mostrar/esconder anel
	if target_ring and _ring_mat:
		target_ring.visible = ring_alpha > 0.01
		if not _is_targeted:
			_ring_mat.albedo_color.a = ring_alpha

	if _hover_tween:
		_hover_tween.kill()

	if animate:
		_hover_tween = create_tween().set_parallel(true)
		if _mat:
			_hover_tween.tween_property(_mat, "emission", target_emission, hover_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		for cmat in _custom_materials:
			_hover_tween.tween_property(cmat, "emission", target_emission, hover_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hover_tween.tween_property(visual_root, "scale", target_scale, hover_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hover_tween.tween_property(label, "modulate", target_label_color, hover_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hover_tween.tween_property(label, "outline_size", target_outline, hover_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		if _mat:
			_mat.emission = target_emission
		for cmat in _custom_materials:
			cmat.emission = target_emission
		visual_root.scale = target_scale
		label.modulate = target_label_color
		label.outline_size = target_outline


func _update_zoom_scale() -> void:
	if _zoom_root == null:
		return
	_camera = get_viewport().get_camera_3d()
	if _camera == null:
		return
	# Compensação parcial: zoom out aumenta o modelo, zoom in diminui.
	var ratio := _camera.size / ZOOM_REFERENCE_SIZE
	var multiplier := clampf(pow(ratio, ZOOM_SCALE_STRENGTH), ZOOM_MIN_MULTIPLIER, ZOOM_MAX_MULTIPLIER)
	_zoom_root.scale = Vector3.ONE * multiplier
	# Hitbox do modelo usa sua compensação parcial independente do nameplate.
	if _body_shape != null:
		_body_shape.radius = 0.45 * multiplier
		_body_shape.height = 1.1 * multiplier


func _update_nameplate_zoom_scale() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null and _nameplate_scale_root != null:
		_nameplate_scale_root.scale = Vector3.ONE * (camera.size / CAMERA_FOLLOW.REFERENCE_CAMERA_SIZE)


## API usada pelo LootLabelManager para o layout dos nameplates.
func is_label_ready() -> bool:
	return label != null and not _spawning and _backing_mesh != null and (_label_fade == null or not _label_fade.is_running())


func is_label_visible() -> bool:
	return label != null and _backing_mesh != null and label.is_visible_in_tree() and label.modulate.a > 0.01 and not _spawning and not _collected


func get_label_base_position() -> Vector3:
	# Actual visual center, including all parent transforms, but excluding stacking.
	# Rebuild from the base instead of subtracting nearly equal float positions.
	return (global_transform * Transform3D(_stacking_root.basis, Vector3.ZERO) * _nameplate_scale_root.transform * label.transform * _backing_mesh.transform).origin


func get_label_width() -> float:
	return (_backing_mesh.mesh as QuadMesh).size.x * _backing_mesh.global_basis.get_scale().abs().x


func get_label_height() -> float:
	return (_backing_mesh.mesh as QuadMesh).size.y * _backing_mesh.global_basis.get_scale().abs().y


func get_label_screen_rect(camera: Camera3D, stacked: bool = true) -> Rect2:
	var center := _backing_mesh.global_position if stacked else get_label_base_position()
	var right := camera.global_basis.x.normalized() * get_label_width() * 0.5
	var up := camera.global_basis.y.normalized() * get_label_height() * 0.5
	var rect := Rect2(camera.unproject_position(center - right - up), Vector2.ZERO)
	rect = rect.expand(camera.unproject_position(center + right - up))
	rect = rect.expand(camera.unproject_position(center - right + up))
	return rect.expand(camera.unproject_position(center + right + up))


func apply_stack_offset(target: Vector3, weight: float) -> void:
	if _stacking_root == null:
		return
	_stacking_root.position = _stacking_root.position.lerp(global_basis.inverse() * target, weight)
	_sync_label_collision()


func _register_label_manager() -> void:
	if not is_inside_tree():
		return
	_label_manager = get_tree().get_first_node_in_group("loot_label_manager")
	if is_instance_valid(_label_manager):
		_label_manager.register_loot(self)


func _process(_delta: float) -> void:
	_update_zoom_scale()
	_update_nameplate_zoom_scale()
	var player := get_tree().get_first_node_in_group("player") as Node3D
	label.visible = not _spawning and (player == null or global_position.distance_to(player.global_position) <= label_distance)
	_sync_label_collision()


func _exit_tree() -> void:
	if _is_hovered:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_stop_pulse()
	if is_instance_valid(_label_manager):
		_label_manager.unregister_loot(self)


func _play_pickup_sound() -> void:
	if pickup_sound == null:
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		scene_root = get_parent()
	var player := AudioStreamPlayer.new()
	player.stream = pickup_sound.duplicate()
	if player.stream is AudioStreamMP3:
		(player.stream as AudioStreamMP3).loop = false
	player.bus = "Effects"
	player.volume_db = pickup_volume_db
	scene_root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func play_spawn(start_position: Vector3, target_position: Vector3, peak_height: float = 0.25, duration: float = 0.3) -> void:
	# Animação visual de "largar/jogar": arco curto, escala sobe até 1 e squash
	# discreto ao pousar. Não altera world_scale nem a lógica de pickup.
	_spawning = true
	label.visible = false
	label.modulate.a = 0.0
	_kill_spawn_tweens()
	global_position = start_position
	visual_root.scale = Vector3.ONE * 0.7
	var tween := create_tween()
	_spawn_tween = tween
	tween.tween_method(_set_arc_position.bind(start_position, target_position, peak_height), 0.0, 1.0, duration)
	tween.set_parallel(true)
	tween.tween_property(visual_root, "scale", Vector3.ONE, duration * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual_root, "rotation:y", 0.0, duration).from(randf_range(-0.5, 0.5))
	tween.chain()
	tween.tween_property(visual_root, "scale", Vector3.ONE * 1.06, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual_root, "scale", Vector3.ONE, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_finish_spawn)


func _set_arc_position(t: float, start: Vector3, target: Vector3, peak: float) -> void:
	var p := start.lerp(target, t)
	p.y += peak * sin(t * PI)
	global_position = p


func _finish_spawn() -> void:
	if not is_inside_tree():
		return
	_spawning = false
	_update_visual_state(false)
	label.visible = true
	# Âncora: centro visual do texto em coordenadas locais do label, para que
	# o crescimento parta do centro e não do canto.
	_label_anchor = Vector3.ZERO
	var aabb := label.get_aabb()
	if aabb.size.length_squared() > 0.0001:
		_label_anchor = aabb.get_center()
	var final_center := label.position + _label_anchor
	var start_center := final_center + Vector3(0.0, -0.18, 0.0)
	var outline_final: float = label.outline_size
	label.scale = Vector3.ONE * 0.2
	label.modulate.a = 0.0
	# Texto e contorno nascem juntos de dentro do item: escala + subida + outline
	# proporcionais em uma única interpolação; alpha acompanha em paralelo.
	_label_fade = create_tween()
	_label_fade.set_parallel(true)
	_label_fade.tween_method(_set_label_spawn.bind(start_center, final_center, outline_final), 0.0, 1.0, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_label_fade.tween_property(label, "modulate:a", 1.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_start_bob_animation()


func _set_label_spawn(t: float, start_center: Vector3, final_center: Vector3, outline_final: float) -> void:
	var s: float = lerpf(0.2, 1.0, t)
	label.scale = Vector3.ONE * s
	label.position = start_center.lerp(final_center, t) - _label_anchor * s
	label.outline_size = lerpf(outline_final * 0.2, outline_final, t)
	_sync_label_collision()


func _kill_spawn_tweens() -> void:
	if _spawn_tween:
		_spawn_tween.kill()
		_spawn_tween = null
	if _label_fade:
		_label_fade.kill()
		_label_fade = null
	if _bob_tween:
		_bob_tween.kill()
		_bob_tween = null
	if _rot_tween:
		_rot_tween.kill()
		_rot_tween = null


func try_pickup(inventory) -> bool:
	if _collected or inventory == null or item == null or _spawning:
		return false
	if not inventory.can_add(item, quantity):
		return false
	Acquisitions.register_acquisition(item, quantity)
	if inventory.add_item(item, quantity):
		_collected = true
		_play_pickup_sound()
		if _is_hovered:
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		_stop_pulse()
		queue_free()
		return true
	Acquisitions.clear_new(item)
	return false
