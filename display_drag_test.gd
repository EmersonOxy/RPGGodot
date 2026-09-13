extends SceneTree

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
	var settings := root.get_node("DisplaySettings")
	var menu: Control = scene.get_node("Interface/UIManager/InventoryMenu")
	menu.open()
	await create_timer(0.3).timeout
	var panel: Control = menu.get_node("Panel")
	var hud: Control = scene.get_node("Interface/PlayerHUD/HPContainer")
	var bar: Control = scene.get_node("Interface/PlayerHUD/ActionBar")
	var design_rect := panel.get_rect()
	var camera: Camera3D = scene.get_node("Player/Camera3D")
	var camera_size := camera.size
	check(root.content_scale_size == Vector2i(1920, 1080), "Design base unchanged")
	check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "Native proportional scaling")
	for resolution in [Vector2i(1920,1080),Vector2i(1600,900),Vector2i(1366,768),Vector2i(1280,720),Vector2i(2560,1440),Vector2i(1024,768),Vector2i(2560,1080)]:
		check(settings.apply_display_settings(resolution.x, resolution.y, false), "Apply resolution")
		await process_frame
		await process_frame
		check(root.get_visible_rect().size.is_equal_approx(Vector2(1920,1080)) and panel.get_rect().is_equal_approx(design_rect), "Layout stable at " + str(resolution))
		check(is_equal_approx(hud.get_global_rect().get_center().x, 960) and is_equal_approx(bar.get_global_rect().get_center().x, 960), "HUD and bar centered")
		check(root.get_visible_rect().encloses(panel.get_global_rect()) and root.get_visible_rect().encloses(bar.get_global_rect()), "Panel and bar inside screen")
	check(camera.projection == Camera3D.PROJECTION_ORTHOGONAL and camera.keep_aspect == Camera3D.KEEP_HEIGHT and camera.size == camera_size, "Camera unchanged")
	check(not settings.apply_display_settings(0,720,false), "Invalid resolution rejected")
	var bag: Control = menu.get_node("Panel/Margin/VBox/BagSlots")
	check(bag.get_child_count() == 20, "20 bag slots preserved")
	for slot in bag.get_children():
		check(slot.get_child_count() == 1, "Bag has no drag feedback component")
	var player: Node = scene.get_node("Player")
	var inventory: Node = player.inventory
	var source: Control = bag.get_child(0)
	source.force_drag({"kind":"inventory_item", "inventory":inventory, "index":0, "item":TestItems.ESPADA_GASTA, "quantity":1}, Label.new())
	await process_frame
	var weapon: Control = menu.get_node("Panel/Margin/VBox/EquipmentArea/WeaponSlot")
	var chest: Control = menu.get_node("Panel/Margin/VBox/EquipmentArea/ChestSlot")
	check(weapon._drag_feedback.state == 1 and chest._drag_feedback.state == 0, "Sword highlights weapon only")
	check(bar.get_child(0)._drag_feedback.state == 0, "Sword does not highlight bar")
	var motion := InputEventMouseMotion.new()
	motion.position = bag.get_child(8).get_global_rect().get_center()
	root.push_input(motion, true)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = motion.position
	root.push_input(release, true)
	await process_frame
	check(inventory.get_slot(8).item == TestItems.ESPADA_GASTA and inventory.get_slot(0).item == null, "Bag drag remains functional")
	print("DISPLAY_DRAG_TEST: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
