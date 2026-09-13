extends Node
## Gerenciador global de configurações de vídeo e exibição com persistência em user://settings.cfg.

signal settings_applied

const CONFIG_PATH := "user://settings.cfg"
const SECTION_VIDEO := "video"

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
const ZOOM_NAMES: Array[String] = ["Muito próximo", "Próximo", "Normal", "Distante", "Muito distante"]

# Valores padrão de fábrica
const DEFAULT_DISPLAY_MODE := 0 # Janela
const DEFAULT_RESOLUTION := Vector2i(1920, 1080)
const DEFAULT_VSYNC := true
const DEFAULT_FPS_LIMIT := 0 # Sem limite
const DEFAULT_RENDER_SCALE := 1.0 # 100%
const DEFAULT_QUALITY := 2 # Alta
const DEFAULT_ZOOM_INDEX := 2 # Normal (19.0)

# Estado ativo
var display_mode: int = DEFAULT_DISPLAY_MODE
var resolution: Vector2i = DEFAULT_RESOLUTION
var vsync: bool = DEFAULT_VSYNC
var fps_limit: int = DEFAULT_FPS_LIMIT
var render_scale: float = DEFAULT_RENDER_SCALE
var quality: int = DEFAULT_QUALITY
var default_zoom_index: int = DEFAULT_ZOOM_INDEX
var zoom_with_scroll := true
var _last_applied_zoom := DEFAULT_ZOOM_INDEX


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_all_settings()


func get_defaults() -> Dictionary:
	return {"display_mode": DEFAULT_DISPLAY_MODE, "resolution": DEFAULT_RESOLUTION,
		"vsync": DEFAULT_VSYNC, "fps_limit": DEFAULT_FPS_LIMIT, "render_scale": DEFAULT_RENDER_SCALE,
		"quality": DEFAULT_QUALITY, "default_zoom_index": DEFAULT_ZOOM_INDEX, "zoom_with_scroll": true}

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
	for pair in [["display_mode", [0,1,2]], ["fps_limit", FPS_LIMITS], ["render_scale", RENDER_SCALES], ["quality", [0,1,2]], ["default_zoom_index", [0,1,2,3,4]]]:
		if not valid[pair[0]] in pair[1]:
			valid[pair[0]] = get_defaults()[pair[0]]
	return valid

func read_settings(path: String = CONFIG_PATH) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return get_defaults()
	var values := get_defaults()
	for key in values:
		values[key] = cfg.get_value(SECTION_VIDEO, key, values[key])
	var width = cfg.get_value(SECTION_VIDEO, "resolution_width", DEFAULT_RESOLUTION.x)
	var height = cfg.get_value(SECTION_VIDEO, "resolution_height", DEFAULT_RESOLUTION.y)
	if width is int and height is int:
		values.resolution = Vector2i(width, height)
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
			cfg.set_value(SECTION_VIDEO, key, valid[key])
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

func restore_defaults() -> void:
	display_mode = DEFAULT_DISPLAY_MODE
	resolution = DEFAULT_RESOLUTION
	vsync = DEFAULT_VSYNC
	fps_limit = DEFAULT_FPS_LIMIT
	render_scale = DEFAULT_RENDER_SCALE
	quality = DEFAULT_QUALITY
	default_zoom_index = DEFAULT_ZOOM_INDEX
	zoom_with_scroll = true
	save_settings()
	apply_all_settings()


func apply_all_settings() -> void:
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

