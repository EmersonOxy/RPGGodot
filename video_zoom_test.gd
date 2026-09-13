extends SceneTree

var failures: int = 0
var checks: int = 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: %s" % message)
		print("FAIL: %s" % message)
	else:
		print("PASS: %s" % message)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	print("--- STARTING VIDEO AND ZOOM AUTOMATED TEST ---")

	# 1. Test DisplaySettings Autoload and Persistence
	var ds = root.get_node_or_null("DisplaySettings")
	check(ds != null, "DisplaySettings autoload exists in root")
	if ds:
		check(ds.RESOLUTIONS.size() == 5, "Has 5 resolution options")
		check(ds.DISPLAY_MODES.size() == 3, "Has 3 display mode options")
		check(ds.FPS_LIMITS.size() == 5, "Has 5 FPS limit options")
		check(ds.RENDER_SCALES.size() == 3, "Has 3 render scale options")
		check(ds.QUALITY_NAMES.size() == 3, "Has 3 quality options")
		check(ds.ZOOM_NAMES.size() == 5, "Has 5 zoom name options")

		# Test applying and saving settings
		ds.display_mode = 0 # Janela
		ds.resolution = Vector2i(1600, 900)
		ds.vsync = false
		ds.fps_limit = 60
		ds.render_scale = 0.75
		ds.quality = 1 # Média
		ds.default_zoom_index = 1 # Próximo (15.0)

		ds.save_settings()
		ds.apply_all_settings()

		check(Engine.max_fps == 60, "Engine max_fps applied to 60")
		check(is_equal_approx(root.scaling_3d_scale, 0.75), "Viewport scaling_3d_scale applied to 0.75")

		# Test loading saved settings
		var loaded_cfg := ConfigFile.new()
		var err := loaded_cfg.load(ds.CONFIG_PATH)
		check(err == OK, "settings.cfg exists and loaded successfully")
		check(loaded_cfg.get_value(ds.SECTION_VIDEO, "resolution_width") == 1600, "Persisted resolution width 1600")
		check(loaded_cfg.get_value(ds.SECTION_VIDEO, "resolution_height") == 900, "Persisted resolution height 900")
		check(loaded_cfg.get_value(ds.SECTION_VIDEO, "vsync") == false, "Persisted vsync false")
		check(loaded_cfg.get_value(ds.SECTION_VIDEO, "fps_limit") == 60, "Persisted fps_limit 60")
		check(is_equal_approx(loaded_cfg.get_value(ds.SECTION_VIDEO, "render_scale"), 0.75), "Persisted render_scale 0.75")
		check(loaded_cfg.get_value(ds.SECTION_VIDEO, "quality") == 1, "Persisted quality 1")
		check(loaded_cfg.get_value(ds.SECTION_VIDEO, "default_zoom_index") == 1, "Persisted default_zoom_index 1")

		# Test backward compatibility
		check(ds.apply_display_settings(1280, 720, false), "apply_display_settings valid resolution accepted")
		check(not ds.apply_display_settings(0, 720, false), "apply_display_settings invalid resolution rejected")

		# Restore defaults
		ds.restore_defaults()
		check(ds.display_mode == ds.DEFAULT_DISPLAY_MODE, "Defaults restored: display_mode")
		check(ds.resolution == ds.DEFAULT_RESOLUTION, "Defaults restored: resolution")
		check(ds.vsync == ds.DEFAULT_VSYNC, "Defaults restored: vsync")
		check(ds.fps_limit == ds.DEFAULT_FPS_LIMIT, "Defaults restored: fps_limit")
		check(ds.render_scale == ds.DEFAULT_RENDER_SCALE, "Defaults restored: render_scale")
		check(ds.quality == ds.DEFAULT_QUALITY, "Defaults restored: quality")
		check(ds.default_zoom_index == ds.DEFAULT_ZOOM_INDEX, "Defaults restored: default_zoom_index")

	# 2. Test Camera Zoom Functionality
	print("--- TESTING CAMERA ZOOM ---")
	var cam_script: Script = load("res://camera_follow.gd")
	check(cam_script != null, "camera_follow.gd loaded successfully")
	var cam := Camera3D.new()
	cam.set_script(cam_script)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	root.add_child(cam)
	await process_frame

	check(cam.size == 19.0, "Camera initial size is 19.0 (Level index 2)")
	check(cam.get_zoom_index() == 2, "Camera initial zoom index is 2")

	# Zoom in: 19 -> 15
	cam.zoom_in()
	check(cam.get_zoom_index() == 1, "Zoom in changes index to 1")
	check(cam.get_target_size() == 15.0, "Zoom in target size is 15.0")

	# Zoom in again: 15 -> 12
	cam.zoom_in()
	check(cam.get_zoom_index() == 0, "Zoom in changes index to 0")
	check(cam.get_target_size() == 12.0, "Zoom in target size is 12.0")

	# Zoom in beyond limit: clamp at 12
	cam.zoom_in()
	check(cam.get_zoom_index() == 0, "Zoom in clamped at minimum index 0")
	check(cam.get_target_size() == 12.0, "Target size clamped at 12.0")

	# Test interpolation towards target
	for i in range(30):
		cam._process(0.016)
	check(absf(cam.size - 12.0) < 0.1, "Camera size smoothly interpolated to near 12.0")

	# Zoom out: 12 -> 15 -> 19 -> 23 -> 27
	cam.zoom_out()
	check(cam.get_zoom_index() == 1, "Zoom out changes index to 1 (15.0)")
	cam.zoom_out()
	check(cam.get_zoom_index() == 2, "Zoom out changes index to 2 (19.0)")
	cam.zoom_out()
	check(cam.get_zoom_index() == 3, "Zoom out changes index to 3 (23.0)")
	cam.zoom_out()
	check(cam.get_zoom_index() == 4, "Zoom out changes index to 4 (27.0)")
	cam.zoom_out()
	check(cam.get_zoom_index() == 4, "Zoom out clamped at maximum index 4 (27.0)")
	check(cam.get_target_size() == 27.0, "Target size clamped at 27.0")

	# Immediate zoom set
	cam.set_zoom_index(2, true)
	check(cam.get_zoom_index() == 2, "set_zoom_index index set to 2")
	check(cam.size == 19.0, "Immediate set size is exactly 19.0")

	cam.queue_free()

	# 3. Test PauseMenu and VideoSettings UI
	print("--- TESTING VIDEO SETTINGS UI ---")
	var pause_scene: PackedScene = load("res://pause_menu.tscn")
	check(pause_scene != null, "pause_menu.tscn loaded successfully")
	var pause_menu := pause_scene.instantiate()
	root.add_child(pause_menu)
	await process_frame

	var settings_box: VideoSettings = pause_menu.get_node_or_null("Center/Panel/Margin/VBox/SettingsBox")
	check(settings_box != null, "SettingsBox exists inside pause_menu")

	if settings_box:
		check(settings_box.opt_display_mode.item_count == 3, "OptDisplayMode has 3 items")
		check(settings_box.opt_resolution.item_count == 5, "OptResolution has 5 items")
		check(settings_box.opt_vsync.item_count == 2, "OptVSync has 2 items")
		check(settings_box.opt_fps.item_count == 5, "OptFPS has 5 items")
		check(settings_box.opt_render_scale.item_count == 3, "OptRenderScale has 3 items")
		check(settings_box.opt_quality.item_count == 3, "OptQuality has 3 items")
		check(settings_box.opt_default_zoom.item_count == 5, "OptDefaultZoom has 5 items")

		check(settings_box.btn_apply != null, "BtnApply exists")
		check(settings_box.btn_cancel != null, "BtnCancel exists")
		check(settings_box.btn_defaults != null, "BtnDefaults exists")

		# Test opening settings view
		var btn_settings: Button = pause_menu.get_node("Center/Panel/Margin/VBox/BtnSettings")
		btn_settings.emit_signal("pressed")
		await process_frame
		check(settings_box.visible, "SettingsBox is visible after clicking Configurações")
		check(not btn_settings.visible, "BtnSettings hidden while settings view is active")

		# Test cancel returns to main pause menu
		settings_box.btn_cancel.emit_signal("pressed")
		await process_frame
		check(not settings_box.visible, "SettingsBox hidden after clicking Cancelar")
		check(btn_settings.visible, "BtnSettings visible again after cancel")

	pause_menu.queue_free()

	print("========================================")
	print("VIDEO_ZOOM_TEST SUMMARY: %d checks, %d failures" % [checks, failures])
	print("========================================")
	quit(1 if failures > 0 else 0)
