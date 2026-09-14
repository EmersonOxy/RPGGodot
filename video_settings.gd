class_name VideoSettings
extends VBoxContainer
## Interface gráfica de controle para as configurações de vídeo, escala e zoom.

signal closed
signal applied

@onready var opt_display_mode: OptionButton = $Scroll/Grid/OptDisplayMode
@onready var opt_resolution: OptionButton = $Scroll/Grid/OptResolution
@onready var opt_vsync: OptionButton = $Scroll/Grid/OptVSync
@onready var opt_fps: OptionButton = $Scroll/Grid/OptFPS
@onready var opt_render_scale: OptionButton = $Scroll/Grid/OptRenderScale
@onready var opt_quality: OptionButton = $Scroll/Grid/OptQuality
@onready var opt_default_zoom: OptionButton = $Scroll/Grid/OptDefaultZoom
@onready var opt_scroll_zoom: OptionButton = $Scroll/Grid/OptScrollZoom
@onready var status: Label = $SettingsStatus

@onready var btn_apply: Button = $ButtonsRow/BtnApply
@onready var btn_cancel: Button = $ButtonsRow/BtnCancel
@onready var btn_defaults: Button = $ButtonsRow/BtnDefaults

var _ds: Node = null
var _resolutions: Array[Vector2i] = []


func _ready() -> void:
	_ds = get_node_or_null("/root/DisplaySettings")
	_populate_options()
	btn_apply.pressed.connect(_on_apply_pressed)
	btn_cancel.pressed.connect(_on_cancel_pressed)
	btn_defaults.pressed.connect(_on_defaults_pressed)
	opt_display_mode.item_selected.connect(func(_index): _update_mode_hint())
	load_from_settings()


func _populate_options() -> void:
	# Modo de exibição
	opt_display_mode.clear()
	for mode_name in ["Janela", "Janela sem bordas", "Tela cheia"]:
		opt_display_mode.add_item(mode_name)

	# Resolução
	opt_resolution.clear()
	_resolutions = _ds.get_resolutions()
	for res in _resolutions:
		opt_resolution.add_item("%dx%d" % [res.x, res.y])

	# VSync
	opt_vsync.clear()
	opt_vsync.add_item("Ligado")
	opt_vsync.add_item("Desligado")

	# Limite de FPS
	opt_fps.clear()
	opt_fps.add_item("30")
	opt_fps.add_item("60")
	opt_fps.add_item("120")
	opt_fps.add_item("144")
	opt_fps.add_item("Sem limite")

	# Escala de renderização
	opt_render_scale.clear()
	opt_render_scale.add_item("50%")
	opt_render_scale.add_item("75%")
	opt_render_scale.add_item("100%")

	# Qualidade
	opt_quality.clear()
	opt_quality.add_item("Baixa")
	opt_quality.add_item("Média")
	opt_quality.add_item("Alta")

	# Zoom padrão
	opt_default_zoom.clear()
	for zoom_name in _ds.ZOOM_NAMES:
		opt_default_zoom.add_item(zoom_name)
	opt_scroll_zoom.add_item("Ligado")
	opt_scroll_zoom.add_item("Desligado")


func load_from_settings() -> void:
	if not _ds:
		_ds = get_node_or_null("/root/DisplaySettings")
	if not _ds:
		return

	# Display Mode
	opt_display_mode.selected = clampi(_ds.display_mode, 0, opt_display_mode.item_count - 1)

	# Resolution
	var res_idx := 3 # default 1920x1080
	for i in range(_resolutions.size()):
		if _resolutions[i] == _ds.resolution:
			res_idx = i
			break
	opt_resolution.selected = res_idx

	# VSync: 0=Ligado, 1=Desligado
	opt_vsync.selected = 0 if _ds.vsync else 1

	# FPS Limit
	var fps_idx := 4 # default Sem limite
	for i in range(_ds.FPS_LIMITS.size()):
		if _ds.FPS_LIMITS[i] == _ds.fps_limit:
			fps_idx = i
			break
	opt_fps.selected = fps_idx

	# Render Scale
	var scale_idx := 2 # default 100%
	for i in range(_ds.RENDER_SCALES.size()):
		if is_equal_approx(_ds.RENDER_SCALES[i], _ds.render_scale):
			scale_idx = i
			break
	opt_render_scale.selected = scale_idx

	# Quality
	opt_quality.selected = clampi(_ds.quality, 0, opt_quality.item_count - 1)

	# Default Zoom
	opt_default_zoom.selected = clampi(_ds.default_zoom_index, 0, opt_default_zoom.item_count - 1)
	opt_scroll_zoom.selected = 0 if _ds.zoom_with_scroll else 1
	_update_mode_hint()

func _update_mode_hint() -> void:
	opt_resolution.disabled = opt_display_mode.selected == 2
	status.text = "Tela cheia usa a resolução atual do monitor." if opt_resolution.disabled else "Alterações entram em vigor ao clicar em Aplicar."


func _on_apply_pressed() -> void:
	if not _ds:
		return
	var draft: Dictionary = _ds.get_settings()
	draft.display_mode = opt_display_mode.selected
	if opt_resolution.selected >= 0 and opt_resolution.selected < _resolutions.size():
		draft.resolution = _resolutions[opt_resolution.selected]
	draft.vsync = opt_vsync.selected == 0
	draft.fps_limit = _ds.FPS_LIMITS[opt_fps.selected]
	draft.render_scale = _ds.RENDER_SCALES[opt_render_scale.selected]
	draft.quality = opt_quality.selected
	draft.default_zoom_index = opt_default_zoom.selected
	draft.zoom_with_scroll = opt_scroll_zoom.selected == 0
	var error: Error = _ds.apply_settings(draft)
	if error != OK:
		status.text = "Não foi possível salvar as configurações (%d)." % error
		return
	applied.emit()
	closed.emit()

func _on_cancel_pressed() -> void:
	load_from_settings()
	closed.emit()


func _on_defaults_pressed() -> void:
	opt_display_mode.selected = 0 # Janela
	opt_resolution.selected = 3 # 1920x1080
	opt_vsync.selected = 0 # Ligado
	opt_fps.selected = 4 # Sem limite
	opt_render_scale.selected = 2 # 100%
	opt_quality.selected = 2 # Alta
	opt_default_zoom.selected = _ds.DEFAULT_ZOOM_INDEX # Normal (19)
	opt_scroll_zoom.selected = 0
	_update_mode_hint()
	status.text = "Padrões selecionados. Clique em Aplicar para salvar."


