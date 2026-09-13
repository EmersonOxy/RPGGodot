extends Node

# Prévia opcional para conferir críticos sem acrescentar chances ao combate.
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var text_system = preload("res://floating_combat_text.gd")
	for category in [text_system.DamageType.NORMAL, text_system.DamageType.CRITICAL, text_system.DamageType.POISON]:
		text_system.show_damage_number(self, player.global_position + Vector3.UP * 1.6, 47 if category == text_system.DamageType.CRITICAL else 23, category)
		await get_tree().create_timer(1.0).timeout
