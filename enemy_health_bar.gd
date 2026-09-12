extends Node3D

@export_range(0.0, 1.0) var damage_delay := 0.25
@export_range(0.05, 2.0) var damage_duration := 0.4
@onready var _health_bar: ProgressBar = $SubViewport/EnemyHealthBar/HealthBar
@onready var _ghost_bar: ProgressBar = $SubViewport/EnemyHealthBar/DamageGhostBar
@onready var _name_label: Label = $SubViewport/EnemyHealthBar/NameLabel
@onready var _sprite: Sprite3D = $Sprite3D
var _delayed_tween: Tween

func _ready() -> void:
	_sprite.texture = $SubViewport.get_texture()
	show()

func setup(max_hp: int, enemy_name: String) -> void:
	if _delayed_tween:
		_delayed_tween.kill()
	_name_label.text = enemy_name
	_health_bar.max_value = maxi(1, max_hp)
	_ghost_bar.max_value = maxi(1, max_hp)
	_health_bar.value = max_hp
	_ghost_bar.value = max_hp
	show()

func update_hp(current: int, maximum: int) -> void:
	var previous := _health_bar.value
	if _delayed_tween:
		_delayed_tween.kill()
	_health_bar.max_value = maxi(1, maximum)
	_ghost_bar.max_value = maxi(1, maximum)
	_health_bar.value = clampi(current, 0, maxi(1, maximum))
	if _health_bar.value < previous:
		_ghost_bar.value = maxf(_ghost_bar.value, previous)
		_delayed_tween = create_tween()
		_delayed_tween.tween_interval(damage_delay)
		_delayed_tween.tween_property(_ghost_bar, "value", _health_bar.value, damage_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_ghost_bar.value = _health_bar.value

# Mantém a interface usada pelo inimigo. Visibilidade é permanente nesta etapa.
func set_selected(_value: bool) -> void:
	pass

func set_in_combat(_value: bool) -> void:
	pass
