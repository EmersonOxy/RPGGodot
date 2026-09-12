extends StaticBody3D

const RARITY_COLORS := {
	0: Color(0.88, 0.88, 0.85),   # COMMON - cinza claro / branco
	1: Color(0.25, 0.90, 0.30),   # UNCOMMON - verde vivo
	2: Color(0.30, 0.55, 1.00),   # RARE - azul evidente
	3: Color(0.72, 0.30, 1.00),   # EPIC - roxo evidente
	4: Color(1.00, 0.65, 0.08),   # LEGENDARY - dourado / laranja
}

var item: ItemData = null:
	set(value):
		item = value
		if is_inside_tree():
			_setup_visuals()

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
var _bob_tween: Tween
var _hover_tween: Tween
var _pulse_tween: Tween
var _mat: StandardMaterial3D
var _backing_mesh: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _base_label_y: float

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var label: Label3D = $Label3D
@onready var area: Area3D = $ClickArea
@onready var target_ring: MeshInstance3D = get_node_or_null("TargetRing")


func _ready() -> void:
	add_to_group("loot")
	if area:
		area.add_to_group("loot")
		area.mouse_entered.connect(_on_mouse_entered)
		area.mouse_exited.connect(_on_mouse_exited)

	collision_layer = 16
	collision_mask = 0
	set_collision_layer_value(5, true)

	_base_label_y = label.position.y

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
	label.pixel_size = 0.009
	label.font_size = 48
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10

	if _ring_mat:
		_ring_mat.albedo_color = rarity_color.lightened(0.2)
		_ring_mat.albedo_color.a = 0.0

	_create_or_update_backing()


func _create_or_update_backing() -> void:
	if _backing_mesh == null:
		_backing_mesh = MeshInstance3D.new()
		_backing_mesh.name = "LabelBacking"
		var quad := QuadMesh.new()
		var font := label.font if label.font != null else ThemeDB.fallback_font
		var text_width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x
		quad.size = Vector2(text_width * label.pixel_size + 0.32, 0.58)

		var backing_material := StandardMaterial3D.new()
		backing_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		backing_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		backing_material.albedo_color = Color(0.02, 0.025, 0.02, 0.85)
		backing_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		backing_material.no_depth_test = true
		backing_material.render_priority = 9
		quad.material = backing_material

		_backing_mesh.mesh = quad
		_backing_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		label.add_child(_backing_mesh)
		_backing_mesh.position = Vector3(0, 0, -0.01)


func _start_bob_animation() -> void:
	if _bob_tween:
		_bob_tween.kill()
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(mesh, "position:y", 0.4, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(mesh, "position:y", 0.25, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var rot_tween := create_tween().set_loops()
	rot_tween.tween_property(mesh, "rotation:y", TAU, 4.0).set_trans(Tween.TRANS_LINEAR)


func _on_mouse_entered() -> void:
	_is_hovered = true
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	_update_visual_state(true)


func _on_mouse_exited() -> void:
	_is_hovered = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
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
	if item == null or _mat == null:
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
		_hover_tween.tween_property(_mat, "emission", target_emission, hover_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hover_tween.tween_property(mesh, "scale", target_scale, hover_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hover_tween.tween_property(label, "modulate", target_label_color, hover_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hover_tween.tween_property(label, "outline_size", target_outline, hover_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_mat.emission = target_emission
		mesh.scale = target_scale
		label.modulate = target_label_color
		label.outline_size = target_outline


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	label.visible = player == null or global_position.distance_to(player.global_position) <= label_distance

	# Offset vertical para evitar sobreposição de nomes de loots próximos
	_update_label_offset()


func _update_label_offset() -> void:
	var my_pos := global_position
	var offset_index := 0
	for node in get_tree().get_nodes_in_group("loot"):
		if node == self or node is Area3D:
			continue
		if not node is StaticBody3D:
			continue
		var other_pos: Vector3 = node.global_position
		var dist_xz := Vector2(my_pos.x - other_pos.x, my_pos.z - other_pos.z).length()
		if dist_xz < 1.2:
			# Desempatar por instance_id para ordenação estável
			if node.get_instance_id() < get_instance_id():
				offset_index += 1
	label.position.y = _base_label_y + offset_index * 0.45
	var label_col := get_node_or_null("ClickArea/LabelCollision") as Node3D
	if label_col:
		label_col.position.y = label.position.y


func _exit_tree() -> void:
	if _is_hovered:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_stop_pulse()


func try_pickup(inventory) -> bool:
	if _collected or inventory == null or item == null:
		return false
	if inventory.add_item(item, quantity):
		_collected = true
		if _is_hovered:
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		_stop_pulse()
		queue_free()
		return true
	return false
