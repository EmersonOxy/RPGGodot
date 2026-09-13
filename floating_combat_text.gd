extends RefCounted

enum DamageType { NORMAL, PLAYER_DAMAGE, CRITICAL, POISON, ICE, FIRE, BLEED, LIGHTNING }

const COLORS := [Color(0.95, 0.94, 0.88), Color(1.0, 0.24, 0.2), Color(1.0, 0.8, 0.25), Color(0.4, 0.9, 0.3), Color(0.4, 0.85, 1.0), Color(1.0, 0.5, 0.16), Color(0.7, 0.16, 0.22), Color(0.7, 0.65, 1.0)]

# Apenas apresentação: não sorteia críticos nem modifica o dano aplicado.
# Contexto pode ser qualquer nó na cena; o número vive separado do alvo.
static func show_damage_number(context: Node, world_position: Vector3, amount: int, damage_type: DamageType = DamageType.NORMAL, is_critical: bool = false) -> Label3D:
	if amount <= 0 or not is_instance_valid(context) or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	var label := Label3D.new()
	label.name = "DamageNumber"
	label.add_to_group("floating_combat_text")
	label.text = str(amount)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.007
	var critical := is_critical or damage_type == DamageType.CRITICAL
	label.font_size = 40 if critical else 32
	label.outline_size = 7
	label.outline_modulate = Color(0.025, 0.02, 0.015, 0.95)
	var category := clampi(damage_type, 0, COLORS.size() - 1)
	# Crítico elemental mantém a cor do efeito, com tamanho e pop de crítico.
	if critical and damage_type == DamageType.NORMAL:
		category = DamageType.CRITICAL
	label.modulate = COLORS[category]
	if parent.is_node_ready():
		_animate_number(parent, label, world_position, critical)
	else:
		# Dano também pode acontecer no _ready de um filho (cena de teste, por exemplo).
		_animate_number.call_deferred(parent, label, world_position, critical)
	return label

static func _animate_number(parent: Node, label: Label3D, world_position: Vector3, critical: bool) -> void:
	if not is_instance_valid(parent):
		label.free()
		return
	parent.add_child(label)
	label.global_position = world_position + Vector3(randf_range(-0.16, 0.16), randf_range(0.0, 0.12), randf_range(-0.12, 0.12))
	label.scale = Vector3.ONE * (0.8 if critical else 1.0)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector3(randf_range(-0.15, 0.15), 0.85 if critical else 0.65, 0), 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.3)
	tween.tween_property(label, "outline_modulate:a", 0.0, 0.55).set_delay(0.3)
	if critical:
		tween.tween_property(label, "scale", Vector3.ONE * 1.12, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "scale", Vector3.ONE, 0.15).set_delay(0.1)
	tween.chain().tween_callback(label.queue_free)
