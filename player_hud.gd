extends Control

@onready var _hp_bar: ProgressBar = $HPContainer/HPRow/HPFrame/BarContainer/HPBar
@onready var _hp_label: Label = $HPContainer/HPRow/HPFrame/BarContainer/HPLabel
@onready var _hp_ghost: ProgressBar = $HPContainer/HPRow/HPFrame/BarContainer/HPGhost
@onready var _level_label: Label = $HPContainer/HPRow/LevelBadge/LvLabel
@onready var _xp_bar: ProgressBar = $HPContainer/XPBar
@onready var _xp_label: Label = $HPContainer/XPBar/XPLabel

var _hp_tween: Tween
var _xp_tween: Tween
var _hp_ghost_tween: Tween

var _current_hp: int = 100
var _max_hp: int = 100


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_hp_changed)
		if player.has_signal("xp_changed"):
			player.xp_changed.connect(_on_xp_changed)
		if player.has_signal("level_up"):
			player.level_up.connect(_on_level_up)
		# Init values
		_max_hp = player.max_health
		_current_hp = player.health
		_hp_bar.max_value = _max_hp
		_hp_bar.value = _current_hp
		_hp_ghost.max_value = _max_hp
		_hp_ghost.value = _current_hp
		_hp_label.text = "%d / %d" % [_current_hp, _max_hp]
		_level_label.text = str(player.level)


func _on_hp_changed(current: int, maximum: int) -> void:
	var old_hp := _current_hp
	_current_hp = current
	_max_hp = maximum
	_hp_bar.max_value = maximum
	_hp_label.text = "%d / %d" % [current, maximum]

	if _hp_tween:
		_hp_tween.kill()
	if _hp_ghost_tween:
		_hp_ghost_tween.kill()

	if current < old_hp:
		# DANO: barra verde cai rápido, ghost fica no valor antigo e depois anima
		_hp_ghost.value = old_hp
		_hp_ghost.max_value = maximum
		# Barra verde cai rapidamente
		_hp_tween = create_tween()
		_hp_tween.tween_property(_hp_bar, "value", float(current), 0.1).set_ease(Tween.EASE_OUT)
		# Ghost espera 0.25s depois anima para o novo valor
		_hp_ghost_tween = create_tween()
		_hp_ghost_tween.tween_interval(0.25)
		_hp_ghost_tween.tween_property(_hp_ghost, "value", float(current), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	elif current > old_hp:
		# CURA: barra verde sobe suavemente, sem ghost
		_hp_ghost.value = current
		_hp_ghost.max_value = maximum
		_hp_tween = create_tween()
		_hp_tween.tween_property(_hp_bar, "value", float(current), 0.3).set_ease(Tween.EASE_OUT)
	else:
		_hp_bar.value = current
		_hp_ghost.value = current


func _on_xp_changed(current: int, maximum: int) -> void:
	_xp_bar.max_value = maximum
	_xp_label.text = "%d / %d" % [current, maximum]
	if _xp_tween:
		_xp_tween.kill()
	_xp_tween = create_tween()
	_xp_tween.tween_property(_xp_bar, "value", float(current), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_level_up(new_level: int) -> void:
	_level_label.text = str(new_level)
	# Flash no badge
	var badge := _level_label.get_parent()
	if badge is PanelContainer:
		var flash := create_tween()
		flash.tween_property(badge, "modulate", Color(1.5, 1.3, 0.5), 0.15)
		flash.tween_property(badge, "modulate", Color.WHITE, 0.3)


func set_level(value: int) -> void:
	_level_label.text = str(value)