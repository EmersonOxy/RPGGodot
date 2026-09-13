extends Node

# Cena de teste opcional: execute equipment_test.tscn com F6.
func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	for item in [TestItems.ESPADA_GASTA, TestItems.ESPADA_FERRO, TestItems.PEITORAL_COURO, TestItems.BOTAS_COURO, TestItems.ANEL_SIMPLES, TestItems.AMULETO_ANTIGO, TestItems.FRAGMENTO_ANTIGO]:
		player.inventory.add_item(item)
	player.inventory.add_item(TestItems.POCAO_VIDA, 7)
	player.take_damage(50)
