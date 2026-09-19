extends Node
## Gerenciador global de configurações de vídeo e exibição com persistência em user://settings.cfg.

signal settings_applied
signal interface_settings_applied
signal audio_settings_applied

const CONFIG_PATH := "user://settings.cfg"
const SECTION_VIDEO := "video"
const SECTION_INTERFACE := "interface"
const AUDIO_DEFAULTS := {"master_volume": 1.0, "effects_volume": 1.0, "sword_volume": 1.0, "steps_volume": 1.0, "audio_muted": false}
const CURSORS = preload("res://cursor_catalog.gd")

const DISPLAY_MODES: Array[String] = ["Janela", "Janela sem bordas", "Tela cheia"]
const RESOLUTIONS: Array[Vector2i] = [
		Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]
const FPS_LIMITS: Array[int] = [30, 60, 120, 144, 0] # 0 = Sem limite
const RENDER_SCALES: Array[float] = [0.5, 0.75, 1.0]
const QUALITY_NAMES: Array[String] = ["Baixa", "Média", "Alta"]
const ZOOM_NAMES: Array[String] = ["Inspeção (6)", "Detalhe (8)", "Bem próximo (10)", "Muito próximo (12)", "Próximo (15)", "Normal (19)", "Distante (23)", "Muito distante (27)"]

# Valores padrão de fábrica
const DEFAULT_DISPLAY_MODE := 2 # Full
const DEFAULT_RESOLUTION := Vector2i(1920, 1080)
const DEFAULT_VSYNC := true
const DEFAULT_FPS_LIMIT := 0 # Sem limite
const DEFAULT_RENDER_SCALE := 1.0 # 100%
const DEFAULT_QUALITY := 2 # Alta
const DEFAULT_ZOOM_INDEX := 5 # Normal (19.0)

# Estado ativo
var display_mode: int = DEFAULT_DISPLAY_MODE
var resolution: Vector2i = DEFAULT_RESOLUTION
var vsync: bool = DEFAULT_VSYNC
var fps_limit: int = DEFAULT_FPS_LIMIT
var render_scale: float = DEFAULT_RENDER_SCALE
var quality: int = DEFAULT_QUALITY
var default_zoom_index: int = DEFAULT_ZOOM_INDEX
var zoom_with_scroll := true
var cursor_style := "default"
var show_controls := true
var master_volume := 1.0
var effects_volume := 1.0
var sword_volume := 1.0
var steps_volume := 1.0
var audio_muted := false
var _last_applied_zoom := DEFAULT_ZOOM_INDEX


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_all_settings()


func get_defaults() -> Dictionary:
	return {"display_mode": DEFAULT_DISPLAY_MODE, "resolution": DEFAULT_RESOLUTION,
		"vsync": DEFAULT_VSYNC, "fps_limit": DEFAULT_FPS_LIMIT, "render_scale": DEFAULT_RENDER_SCALE,
		"quality": DEFAULT_QUALITY, "default_zoom_index": DEFAULT_ZOOM_INDEX, "zoom_with_scroll": true,
		"cursor_style": "default", "show_controls": true,
		"master_volume": 1.0, "effects_volume": 1.0, "sword_volume": 1.0, "steps_volume": 1.0, "audio_muted": false}

func get_settings() -> Dictionary:
	var values := {}
	for key in get_defaults():
		values[key] = get(key)
	return values

func sanitize(values: Dictionary) -> Dictionary:
	var valid := get_defaults()
	for key in valid:
		if values.has(key) and typeof(values[key]) == typeof(valid[key]):
			valid[key] = values[key]
	var res: Vector2i = valid.resolution
	if res.x < 320 or res.y < 240 or res.x > 16384 or res.y > 16384:
		valid.resolution = DEFAULT_RESOLUTION
	for pair in [["display_mode", [0,1,2]], ["fps_limit", FPS_LIMITS], ["render_scale", RENDER_SCALES], ["quality", [0,1,2]], ["default_zoom_index", [0,1,2,3,4,5,6,7]]]:
		if not valid[pair[0]] in pair[1]:
			valid[pair[0]] = get_defaults()[pair[0]]
	valid.cursor_style = CURSORS.STYLES[CURSORS.index_for(valid.cursor_style)].id
	for key in AUDIO_DEFAULTS:
		if key != "audio_muted":
			valid[key] = clampf(valid[key], 0.0, 1.0) if is_finite(valid[key]) else 1.0
	return valid

func _section_for(key: String) -> String:
	if AUDIO_DEFAULTS.has(key):
		return "audio"
	return SECTION_INTERFACE if key in ["cursor_style", "show_controls"] else SECTION_VIDEO

func read_settings(path: String = CONFIG_PATH) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return get_defaults()
	var values := get_defaults()
	for key in values:
		var section := _section_for(key)
		values[key] = cfg.get_value(section, key, values[key])
	var width = cfg.get_value(SECTION_VIDEO, "resolution_width", DEFAULT_RESOLUTION.x)
	var height = cfg.get_value(SECTION_VIDEO, "resolution_height", DEFAULT_RESOLUTION.y)
	if width is int and height is int:
		values.resolution = Vector2i(width, height)
	if cfg.has_section_key(SECTION_VIDEO, "default_zoom_index") and cfg.get_value(SECTION_VIDEO, "zoom_levels_version", 1) == 1:
		var old_index = values.default_zoom_index
		if old_index is int and old_index >= 0 and old_index <= 4:
			values.default_zoom_index = old_index + 3
	return sanitize(values)

func load_settings() -> void:
	_set_values(read_settings())

func _set_values(values: Dictionary) -> void:
	var valid := sanitize(values)
	for key in valid:
		set(key, valid[key])

func save_settings(path: String = CONFIG_PATH) -> Error:
	return _save_values(get_settings(), path)

func _save_values(values: Dictionary, path: String) -> Error:
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(path):
		cfg.load(path)
	var valid := sanitize(values)
	for key in valid:
		if key != "resolution":
			var section := _section_for(key)
			cfg.set_value(section, key, valid[key])
	cfg.set_value(SECTION_VIDEO, "zoom_levels_version", 2)
	cfg.set_value(SECTION_VIDEO, "resolution_width", valid.resolution.x)
	cfg.set_value(SECTION_VIDEO, "resolution_height", valid.resolution.y)
	return cfg.save(path)

func apply_settings(values: Dictionary, path: String = CONFIG_PATH) -> Error:
	var valid := sanitize(values)
	var error := _save_values(valid, path)
	if error != OK:
		return error
	_set_values(valid)
	apply_all_settings()
	return OK

func get_resolutions() -> Array[Vector2i]:
	var result: Array[Vector2i] = RESOLUTIONS.duplicate()
	if DisplayServer.get_name() != "headless":
		var native := DisplayServer.screen_get_size(get_window().current_screen)
		if native.x > 0 and native.y > 0 and not native in result:
			result.append(native)
	if not resolution in result:
		result.append(resolution)
	return result


func apply_interface_settings(style_id: String, controls_visible: bool, path: String = CONFIG_PATH) -> Error:
	var values := get_settings()
	values.cursor_style = style_id
	values.show_controls = controls_visible
	var error := _save_values(values, path)
	if error != OK:
		return error
	_set_values(values)
	_apply_interface_settings()
	return OK


func _apply_interface_settings() -> void:
	CURSORS.apply(cursor_style)
	interface_settings_applied.emit()

func restore_defaults() -> void:
	display_mode = DEFAULT_DISPLAY_MODE
	resolution = DEFAULT_RESOLUTION
	vsync = DEFAULT_VSYNC
	fps_limit = DEFAULT_FPS_LIMIT
	render_scale = DEFAULT_RENDER_SCALE
	quality = DEFAULT_QUALITY
	default_zoom_index = DEFAULT_ZOOM_INDEX
	zoom_with_scroll = true
	cursor_style = "default"
	show_controls = true
	for key in AUDIO_DEFAULTS:
		set(key, AUDIO_DEFAULTS[key])
	save_settings()
	apply_all_settings()


func apply_all_settings() -> void:
	_apply_audio_settings()
	var window := get_window()
	if window:
		match display_mode:
			0: # Janela
				window.mode = Window.MODE_WINDOWED
				window.borderless = false
				_fit_window(window, resolution)
				if DisplayServer.get_name() != "headless":
					window.move_to_center()
			1: # Janela sem bordas
				window.mode = Window.MODE_WINDOWED
				window.borderless = true
				_fit_window(window, resolution)
				if DisplayServer.get_name() != "headless":
					window.move_to_center()
			2: # Tela cheia
				window.borderless = false
				window.mode = Window.MODE_FULLSCREEN

	# VSync
	if DisplayServer.get_name() != "headless":
		var vsync_mode: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
		DisplayServer.window_set_vsync_mode(vsync_mode)

	# Limite de FPS
	Engine.max_fps = fps_limit

	# Escala de renderização 3D
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = render_scale

	# Qualidade gráfica
	_apply_quality(quality)

	# Zoom padrão da câmera
	var cam = get_tree().get_first_node_in_group("game_camera")
	if cam and cam.has_method("set_zoom_index") and default_zoom_index != _last_applied_zoom:
		cam.set_zoom_index(default_zoom_index, false)

	_last_applied_zoom = default_zoom_index
	settings_applied.emit()
	_apply_interface_settings()


func apply_audio_settings(values: Dictionary) -> Error:
	var draft := get_settings()
	for key in AUDIO_DEFAULTS:
		if values.has(key):
			draft[key] = values[key]
	_set_values(draft)
	_apply_audio_settings()
	return save_settings()

func _apply_audio_settings() -> void:
	for bus_name in ["Effects", "Swords", "Footsteps"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
		AudioServer.set_bus_send(AudioServer.get_bus_index(bus_name), "Master" if bus_name == "Effects" else "Effects")
	for pair in [["Master", master_volume], ["Effects", effects_volume], ["Swords", sword_volume], ["Footsteps", steps_volume]]:
		var index := AudioServer.get_bus_index(pair[0])
		var volume: float = pair[1]
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
		AudioServer.set_bus_mute(index, volume <= 0.0 or (pair[0] == "Master" and audio_muted))
	audio_settings_applied.emit()

func _apply_quality(q_level: int) -> void:
	var vp := get_viewport()
	if not vp:
		return
	match q_level:
		0: # Baixa
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
		1: # Média
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
		2: # Alta
			vp.msaa_3d = Viewport.MSAA_4X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			RenderingServer.directional_shadow_atlas_set_size(4096, true)


## Compatibilidade com o método existente usado em display_drag_test.gd
func apply_display_settings(width: int, height: int, fullscreen: bool) -> bool:
	if width <= 0 or height <= 0:
		return false
	resolution = Vector2i(width, height)
	display_mode = 2 if fullscreen else 0
	apply_all_settings()
	return true


func _fit_window(window: Window, requested_size: Vector2i) -> void:
	var fitted := requested_size
	if DisplayServer.get_name() != "headless":
		var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
		var decorations := window.get_size_with_decorations() - window.size
		if usable.size.x > 0 and usable.size.y > 0:
			fitted = requested_size.min((usable.size - decorations).max(Vector2i.ONE))
	window.size = fitted
