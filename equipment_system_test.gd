extends SceneTree

var checks := 0
var failures := 0
var inv: Node
var eq: Node
var player: Node

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func bag_data(item: ItemData) -> Dictionary:
	for i in inv.get_slot_count():
		if inv.get_slot(i).item == item:
			return {"kind": "inventory_item", "inventory": inv, "index": i, "item": item, "quantity": inv.get_slot(i).quantity}
	return {}

func equipped_data(slot: int) -> Dictionary:
	return {"kind": "equipment_item", "equipment": eq, "slot": slot, "item": eq.get_item(slot)}

func empty_slot() -> int:
	for i in inv.get_slot_count():
		if inv.get_slot(i).item == null:
			return i
	return -1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := load("res://equipment_test.tscn").instantiate() as Node
	root.add_child(scene)
	current_scene = scene
	await process_frame
	player = scene.get_node("Player")
	player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	inv = player.inventory
	eq = player.equipment
	var actions: Node = player.action_bar
	var sword := TestItems.ESPADA_GASTA
	var iron := TestItems.ESPADA_FERRO
	var chest := TestItems.PEITORAL_COURO
	var potion := TestItems.POCAO_VIDA
	check(inv.get_slot_count() == 20, "20 slots")
	check(eq.equip_from_bag(bag_data(sword), 2), "equip sword")
	check(player.attack_damage == 25 and inv.count_item(sword) == 0, "damage +5")
	check(eq.equip_from_bag(bag_data(iron), 2), "replace sword")
	check(player.attack_damage == 32 and player.strength == 12 and inv.count_item(sword) == 1, "replacement bonuses and item returned")
	check(eq.unequip_to_bag(equipped_data(2), empty_slot()), "unequip")
	check(player.attack_damage == 20 and player.strength == 10, "base restored")
	for i in 6:
		check(eq.equip_from_bag(bag_data(iron), 2), "repeat equip")
		check(eq.unequip_to_bag(equipped_data(2), empty_slot()), "repeat unequip")
	check(player.attack_damage == 20 and player.base_attack_damage == 20, "no accumulation")
	check(not eq.equip_from_bag(bag_data(chest), 2) and inv.count_item(chest) == 1, "incompatible rejected")
	player.health = 100
	check(eq.equip_from_bag(bag_data(chest), 4), "chest accepted")
	check(player.max_health == 115 and player.health == 100 and player.armor == 8, "max HP no healing")
	player.health = 110
	check(eq.unequip_to_bag(equipped_data(4), empty_slot()), "remove chest")
	check(player.health == 100 and player.max_health == 100 and player.armor == 0, "HP clamped")
	check(actions.accept_drop(0, bag_data(potion)) and inv.count_item(potion) == 7, "shortcut leaves stack")
	check(not actions.accept_drop(1, bag_data(sword)), "weapon rejected by bar")
	check(not actions.accept_drop(1, bag_data(TestItems.FRAGMENTO_ANTIGO)), "material rejected by bar")
	check(not actions.use_slot(0) and inv.count_item(potion) == 7, "full life no consume")
	player.health = 30
	check(actions.use_slot(0) and player.health == 65 and inv.count_item(potion) == 6, "heals 35 consumes one")
	check(actions.accept_drop(2, {"kind": "action_item", "action_bar": actions, "index": 0, "item": potion}), "move shortcut")
	check(actions.get_item(0) == null and actions.get_item(2) == potion, "shortcut moved")
	actions.clear_slot(2)
	check(inv.count_item(potion) == 6, "clear keeps items")
	actions.assign_item(2, potion)
	actions.assign_item(0, potion)
	check(actions.get_item(2) == null, "one shortcut per item ID")
	player.is_dead = true
	check(not actions.use_slot(0) and inv.count_item(potion) == 6, "dead no use")
	player.is_dead = false
	for i in 6:
		player.health = 1
		check(actions.use_slot(0), "consume remainder")
	check(actions.get_item(0) == null and actions.get_item(2) == null and inv.count_item(potion) == 0, "all references cleared on exhaustion")
	check(eq.equip_from_bag(bag_data(sword), 2), "equip before full bag")
	while empty_slot() >= 0:
		inv.add_item(sword)
	var full_data := bag_data(iron)
	check(not eq.equip_from_bag(full_data, 2), "full bag swap cancelled")
	check(eq.get_item(2) == sword and inv.matches_slot(full_data.index, iron, 1), "full bag conserves both")
	check(not eq.unequip_to_bag(equipped_data(2), 0), "occupied bag rejects unequip")
	# GUI layout and the actual viewport drop routing with inventory open.
	var menu := scene.get_node("Interface/UIManager/InventoryMenu")
	menu.open()
	await create_timer(0.35).timeout
	var area := menu.get_node("Panel/Margin/VBox/EquipmentArea")
	check(area is Control and not area is Container and area.get_child_count() == 10, "manual equipment layout")
	check(menu.get_node("Panel/Margin/VBox/BagSlots").get_child_count() == 20, "bag layout intact")
	check(menu.get_node("Panel").get_global_rect().encloses(area.get_global_rect()), "equipment fits panel")
	var close_hint: Control = menu.get_node("Panel/Margin/VBox/CloseHint")
	check(root.get_visible_rect().encloses(close_hint.get_global_rect()), "inventory fits screen")
	# Free one bag slot, add a potion and force a real drag into the HUD.
	var remove := bag_data(sword)
	inv.remove_slot(remove.index, remove.item, remove.quantity)
	inv.add_item(potion, 2)
	var data := bag_data(potion)
	var bag_slot: Control = menu.get_node("Panel/Margin/VBox/BagSlots").get_child(data.index)
	bag_slot.force_drag(data, Label.new())
	await process_frame
	var hud_slot: Control = scene.get_node("Interface/PlayerHUD/ActionBar/Slot1")
	var motion := InputEventMouseMotion.new()
	motion.position = hud_slot.get_global_rect().get_center()
	root.push_input(motion, true)
	await process_frame
	print("HOVER: ", root.gui_get_hovered_control(), " TARGET: ", hud_slot, " DRAG: ", root.gui_is_dragging())
	check(root.gui_get_hovered_control() == hud_slot, "HUD receives drag through menu overlay")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = motion.position
	release.pressed = false
	root.push_input(release, true)
	await process_frame
	check(actions.get_item(0) == potion and inv.count_item(potion) == 2, "real HUD drop creates shortcut")
	player.health = 1
	var key := InputEventKey.new()
	key.physical_keycode = KEY_1
	key.pressed = true
	root.push_input(key, true)
	await process_frame
	check(player.health == 36 and inv.count_item(potion) == 1, "Input Action 1 consumes potion")
	check(sword.get_bonus_text() == "Dano +5", "tooltip omits zero bonuses")
	print("EQUIPMENT_TEST: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

