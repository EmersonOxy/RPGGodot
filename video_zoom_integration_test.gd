extends SceneTree

const TEST_PATH := "user://video_zoom_validation.cfg"
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var service := root.get_node("DisplaySettings")
	var camera: Camera3D = scene.get_node("Player/Camera3D")
	var player: Node3D = scene.get_node("Player")
	player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var defaults: Dictionary = service.get_defaults()
	check(service.apply_settings(defaults, TEST_PATH) == OK, "Settings save/apply")
	check(service.read_settings(TEST_PATH) == defaults, "ConfigFile roundtrip")
	var values := defaults.duplicate()
	values.default_zoom_index = 4
	values.zoom_with_scroll = false
	values.render_scale = 0.75
	values.fps_limit = 144
	values.vsync = false
	values.quality = 1
	values.resolution = Vector2i(1600,900)
	check(service.apply_settings(values, TEST_PATH) == OK and service.read_settings(TEST_PATH) == values, "All fields persist")
	check(camera._target_size == 27 and not camera._scroll_enabled, "Camera receives default and scroll settings")
	check(root.scaling_3d_scale == 0.75 and root.content_scale_size == Vector2i(1920,1080), "3D render scale independent of UI")
	check(Engine.max_fps == 144 and root.msaa_3d == Viewport.MSAA_2X, "FPS and quality applied")
	var invalid := values.duplicate()
	invalid.resolution = Vector2i(-1,0)
	invalid.default_zoom_index = 99
	invalid.render_scale = "invalid"
	check(service.sanitize(invalid).resolution == defaults.resolution and service.sanitize(invalid).default_zoom_index == 2 and service.sanitize(invalid).render_scale == 1.0, "Invalid config safely sanitized")
	service.apply_settings(defaults, TEST_PATH)
	camera.set_zoom_index(2)
	camera._process(1.0)
	# Elimina somente no teste o assentamento vertical do follow preexistente.
	camera.global_position = player.global_position + camera._offset
	var fixed_transform := camera.global_transform
	var size_before := camera.size
	camera.set_zoom_index(0)
	check(camera.size == size_before and camera._target_size == 12, "Zoom target changes without jump")
	camera._process(0.1)
	check(camera.size > 12 and camera.size < 19, "Smooth intermediate zoom")
	camera.set_zoom_index(1)
	camera.set_zoom_index(4)
	camera.set_zoom_index(9)
	camera._process(1.0)
	check(camera.size == 27 and camera._target_size == 27, "Rapid changes settle at upper limit")
	camera.set_zoom_index(-3)
	camera._process(1.0)
	check(camera.size == 12, "Lower zoom limit")
	check(camera.global_transform.is_equal_approx(fixed_transform), "Zoom does not change camera transform")
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(2560,1080)]:
		service.apply_display_settings(resolution.x, resolution.y, false)
		await process_frame
		check(camera.size == 12 and camera._target_size == 12, "Resolution leaves zoom untouched")
		check(root.get_visible_rect().size.is_equal_approx(Vector2(1920,1080)), "Keep aspect preserves composition")
	# Native projection remains aligned for world interaction and orthographic occlusion.
	var enemy: Node3D = load("res://enemy_dummy.tscn").instantiate()
	scene.add_child(enemy)
	enemy.global_position = player.global_position + Vector3(3,0,3)
	enemy.set_physics_process(false)
	var loot: Node3D = load("res://world_loot.tscn").instantiate()
	loot.item = TestItems.POCAO_VIDA
	scene.add_child(loot)
	loot.global_position = player.global_position + Vector3(-3,0,3)
	await physics_frame
	await process_frame
	for index in [0,2,4]:
		camera.set_zoom_index(index)
		camera._process(1.0)
		for target in [enemy.global_position + Vector3.UP * 0.7, loot.global_position, player.global_position + Vector3.UP * 0.9]:
			var screen := camera.unproject_position(target)
			var origin := camera.project_ray_origin(screen)
			var direction := camera.project_ray_normal(screen)
			check((target-origin).cross(direction).length() < 0.001, "Projection/ray alignment at zoom %d" % index)
		for pair in [[enemy, enemy.global_position + Vector3.UP * 0.7, 8], [loot, loot.global_position, 16]]:
			var screen := camera.unproject_position(pair[1])
			var origin := camera.project_ray_origin(screen)
			var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen)*100, pair[2])
			query.collide_with_areas = true
			var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and (hit.collider == pair[0] or pair[0].is_ancestor_of(hit.collider)), "Enemy/loot ray hits at zoom %d" % index)
	var pause_menu := scene.get_node("Interface/UIManager/PauseMenu")
	var form := pause_menu.get_node("Center/Panel/Margin/VBox/SettingsBox")
	service.apply_settings(defaults, TEST_PATH)
	paused = true
	pause_menu.show()
	pause_menu._open_settings()
	form.opt_fps.selected = 0
	form._on_cancel_pressed()
	check(service.get_settings().fps_limit == defaults.fps_limit, "Cancel does not apply draft")
	pause_menu._open_settings()
	form._on_defaults_pressed()
	check(form.opt_default_zoom.selected == 2 and service.get_settings() == defaults, "Restore defaults remains a draft")
	await process_frame
	check(root.get_visible_rect().encloses(pause_menu.get_node("Center/Panel").get_global_rect()), "Video menu fits design viewport")
	pause_menu.hide()
	paused = false
	camera.set_zoom_index(2)
	camera._process(1.0)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(500,400)
	root.push_input(motion,true)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = motion.position
	root.push_input(wheel,true)
	check(camera._target_size == 15, "Wheel up zooms in")
	var menu: Control = scene.get_node("Interface/UIManager/InventoryMenu")
	menu.open()
	await create_timer(0.3).timeout
	motion.position = menu.get_node("Panel").get_global_rect().get_center()
	root.push_input(motion,true)
	wheel.position = motion.position
	root.push_input(wheel,true)
	check(camera._target_size == 15, "Inventory blocks camera scroll")
	values = defaults.duplicate()
	values.render_scale = 0.5
	service.apply_settings(values, TEST_PATH)
	check(camera._target_size == 15, "Quality/render settings preserve transient zoom")
	DirAccess.remove_absolute(TEST_PATH)
	print("VIDEO_ZOOM_TEST: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

