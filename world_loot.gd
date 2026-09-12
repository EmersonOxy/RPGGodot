extends StaticBody3D

var item = null
@export var quantity: int = 1
@export var label_distance := 12.0
var _collected := false

var _bob_tween: Tween
var _highlight_active: bool = false

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var label: Label3D = $Label3D
@onready var area: Area3D = $ClickArea
@onready var click_shape: CollisionShape3D = $ClickArea/CollisionShape3D

const RARITY_COLORS := {
	0: Color(0.92, 0.92, 0.88),   # COMMON - cinza claro
	1: Color(0.60, 0.94, 0.56),     # UNCOMMON - verde
	2: Color(0.3, 0.5, 1.0),      # RARE - azul
	3: Color(0.7, 0.3, 0.95),     # EPIC - roxo
	4: Color(1.0, 0.7, 0.1),      # LEGENDARY - dourado
}


func _ready() -> void:
	add_to_group("loot")
	collision_layer = 16
	collision_mask = 0
	set_collision_layer_value(5, true)
	if item:
		_setup_visuals()
	_start_bob_animation()
	# Conectar sinais do Area3D
	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)


func _setup_visuals() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = item.icon_color
	mat.emission_enabled = true
	mat.emission = item.icon_color * 0.3
	mesh.material_override = mat
	label.text = item.display_name + ("  ×%d" % quantity if quantity > 1 else "")
	# Cor por raridade
	var rarity_color: Color = RARITY_COLORS.get(item.rarity, RARITY_COLORS[0])
	label.modulate = rarity_color
	# Etiqueta com fundo escuro; usa o mesmo billboard do texto.
	var backing := MeshInstance3D.new()
	var quad := QuadMesh.new()
	var font := label.font if label.font != null else ThemeDB.fallback_font
	var text_width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x
	quad.size = Vector2(text_width * label.pixel_size + 0.24, 0.52)
	var backing_material := StandardMaterial3D.new()
	backing_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	backing_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	backing_material.albedo_color = Color(0.025, 0.03, 0.025, 0.88)
	backing_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	backing_material.no_depth_test = true
	quad.material = backing_material
	backing.mesh = quad
	backing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.add_child(backing)
	backing.position = Vector3.ZERO


func _start_bob_animation() -> void:
	if _bob_tween:
		_bob_tween.kill()
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(mesh, "position:y", 0.4, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(mesh, "position:y", 0.25, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var rot_tween := create_tween().set_loops()
	rot_tween.tween_property(mesh, "rotation:y", TAU, 4.0).set_trans(Tween.TRANS_LINEAR)


func _on_mouse_entered() -> void:
	_highlight_active = true
	label.modulate = Color.WHITE

func _on_mouse_exited() -> void:
	_highlight_active = false
	if item:
		label.modulate = RARITY_COLORS.get(item.rarity, Color.WHITE)

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



