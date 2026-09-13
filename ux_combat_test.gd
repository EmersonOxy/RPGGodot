extends SceneTree

const FCT = preload("res://floating_combat_text.gd")
var failures := 0
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: Node = load("res://equipment_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var player: Node = scene.get_node("Player")
	player.set_physics_process(false)
	var inv: Node = player.inventory
	var bar: Node = player.action_bar
	var potion := TestItems.POCAO_VIDA
	var copy: ItemData = potion.duplicate()
	copy.display_name = "Nome diferente, mesmo ID"
	inv.add_item(copy, 7)
	check(inv.count_item(potion) == 14, "Counts distinct resources by ID")
	bar.assign_item(0, potion)
	bar.assign_item(1, copy)
	check(bar.get_item(0) == null and bar.get_item(1) == copy, "Unique shortcut by ID")
	check(bar.use_slot(1) and inv.count_item(copy) == 13, "Consumes across stacks by ID")
	for i in 13:
		player.health = 1
		bar.use_slot(1)
	check(bar.get_item(1) == null and inv.count_item(potion) == 0, "Exhaustion clears shortcut")
	var menu: Control = scene.get_node("Interface/UIManager/InventoryMenu")
	var panel: Control = menu.get_node("Panel")
	panel.position.x -= 25
	var initial := panel.get_rect()
	menu.fade_duration = 0.02
	for i in 3:
		menu.open()
		await create_timer(0.04).timeout
		menu.close()
		await create_timer(0.04).timeout
	check(panel.get_rect() == initial and not menu.visible, "Fade preserves configured position")
	menu.open()
	menu.close()
	menu.open()
	await create_timer(0.05).timeout
	check(menu.visible and panel.get_rect() == initial, "Interrupted fade preserves position")
	var slot: Control = menu.get_node("Panel/Margin/VBox/BagSlots/Slot01")
	var initial_size := slot.size
	var long_item: ItemData = potion.duplicate()
	long_item.display_name = "Um nome extremamente longo ".repeat(20)
	slot._display_item(long_item, 123456789)
	await process_frame
	await process_frame
	check(slot.size == initial_size, "Content never enlarges slot")
	check(slot.clip_contents and slot.get_node("VBox").clip_contents, "Slot and content clipped")
	check(slot.get_global_rect().encloses(slot.get_node("VBox/Label").get_global_rect()), "Name remains inside slot")
	check(slot.get_global_rect().encloses(slot.get_node("VBox/QtyLabel").get_global_rect()), "Quantity remains inside slot")
	# Actual viewport drag notifications must reach the inherited equipment slot.
	var sword := TestItems.ESPADA_GASTA
	var data := {"kind": "inventory_item", "inventory": inv, "index": 0, "item": sword, "quantity": 1}
	slot.force_drag(data, Label.new())
	await process_frame
	var weapon: Control = menu.get_node("Panel/Margin/VBox/EquipmentArea/WeaponSlot")
	var chest: Control = menu.get_node("Panel/Margin/VBox/EquipmentArea/ChestSlot")
	var action: Control = scene.get_node("Interface/PlayerHUD/ActionBar/Slot1")
	check(weapon._drag_feedback.state == 1, "Compatible weapon highlighted")
	check(chest._drag_feedback.state == 0 and action._drag_feedback.state == 0, "Incompatible slots not highlighted")
	var motion := InputEventMouseMotion.new()
	motion.position = weapon.get_global_rect().get_center()
	root.push_input(motion, true)
	await process_frame
	check(weapon._drag_feedback.state == 2, "Compatible hover stronger")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = motion.position
	root.push_input(release, true)
	await process_frame
	check(player.equipment.get_item(2) == sword and weapon._drag_feedback.state == 0, "Drop preserved and feedback reset")
	inv.add_item(potion, 1)
	var index := -1
	for i in 20:
		if inv.get_slot(i).item == potion:
			index = i
	data = {"kind": "inventory_item", "inventory": inv, "index": index, "item": potion, "quantity": 1}
	slot.force_drag(data, Label.new())
	await process_frame
	check(action._drag_feedback.state == 1 and weapon._drag_feedback.state == 0, "Potion highlights Action Bar only")
	release.position = Vector2(10, 10)
	root.push_input(release, true)
	await process_frame
	var pos: Vector3 = player.global_position + Vector3.UP * 1.6
	var number := FCT.show_damage_number(player, pos, 23)
	var critical := FCT.show_damage_number(player, pos, 47, FCT.DamageType.NORMAL, true)
	var poison := FCT.show_damage_number(player, pos, 8, FCT.DamageType.POISON, true)
	check(number.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "Camera-facing numbers")
	check(critical.font_size == 40 and number.font_size == 32, "Critical 25 percent larger")
	check(critical.modulate == FCT.COLORS[FCT.DamageType.CRITICAL], "Critical gold")
	check(poison.modulate == FCT.COLORS[FCT.DamageType.POISON], "Element and critical can combine")
	player.health = 100
	player.take_damage(10)
	var received: Label3D = scene.get_child(-1)
	check(player.health == 90 and received.modulate == FCT.COLORS[FCT.DamageType.PLAYER_DAMAGE], "Player damage red, original damage unchanged")
	var enemy: Node = load("res://enemy_dummy.tscn").instantiate()
	scene.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.take_damage(23)
	var dealt: Label3D = scene.get_child(-1)
	check(enemy.health == 77 and dealt.text == "23", "Enemy damage connected")
	enemy.queue_free()
	await process_frame
	check(is_instance_valid(dealt), "Number survives target removal")
	for i in 12:
		FCT.show_damage_number(player, pos, i + 1, i % 8, i % 2 == 0)
	await create_timer(1.05).timeout
	check(get_nodes_in_group("floating_combat_text").is_empty(), "All numbers freed after animation")
	print("UX_COMBAT_TEST: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


