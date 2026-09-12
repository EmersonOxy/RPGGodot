extends StaticBody3D

const RARITY_COLORS := {
	0: Color(0.92, 0.92, 0.90),   # COMMON - cinza claro / branco
	1: Color(0.35, 0.95, 0.45),   # UNCOMMON - verde
	2: Color(0.35, 0.65, 1.00),   # RARE - azul
	3: Color(0.80, 0.40, 1.00),   # EPIC - roxo
	4: Color(1.00, 0.75, 0.15),   # LEGENDARY - dourado / laranja
}

var item: ItemData = null:
	set(value):
		item = value
		if is_inside_tree():
			_setup_visuals()

@export var quantity: int = 1
@export var label_distance := 14.0
@export var hover_scale := 1.06
@export var hover_duration := 0.12
@export var base_emission_intensity := 0.35
@export var hover_emission_intensity := 0.85

var _collected := false
var _is_hovered := false
var _is_targeted := false
var _bob_tween: Tween
var _hover_tween: Tween
var _mat: StandardMaterial3D
var _backing_mesh: MeshInstance3D

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

	if target_ring and target_ring.mesh and target_ring.mesh.material:
		(target_ring.mesh.material as StandardMaterial3D).albedo_color = rarity_color.lightened(0.2)

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
	_update_visual_state(true)


func _on_mouse_exited() -> void:
	_is_hovered = false
	_update_visual_state(true)


func set_targeted(value: bool) -> void:
	_is_targeted = value
	if is_instance_valid(target_ring):
		target_ring.visible = value
	_update_visual_state(true)


func _update_visual_state(animate: bool) -> void:
	if item == null or _mat == null:
		return

	var rarity_color: Color = RARITY_COLORS.get(item.rarity, RARITY_COLORS[0])
	var active := _is_hovered or _is_targeted

	var target_emission: Color = item.icon_color * (hover_emission_intensity if active else base_emission_intensity)
	var target_scale: Vector3 = Vector3.ONE * (hover_scale if active else 1.0)
	var target_label_color: Color = rarity_color.lightened(0.25) if active else rarity_color
	var target_outline: int = 16 if active else 12

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


func try_pickup(inventory) -> bool:
	if _collected or inventory == null or item == null:
		return false
	if inventory.add_item(item, quantity):
		_collected = true
		queue_free()
		return true
	return false
