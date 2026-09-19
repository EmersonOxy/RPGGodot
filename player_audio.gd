extends Node
## Temporary movement loops and sword variations. Settings are live in the Inspector.

@export_group("Sword")
@export var sword_standard: AudioStream = preload("res://assets/sound/sword/attack/som_ataque_espada_padrao.mp3")
@export var sword_alternative: AudioStream = preload("res://assets/sound/sword/attack/som_ataque_espada_alternativo.mp3")
@export_range(0.0, 1.0) var alternative_chance := 0.35
@export_range(0.0, 30.0) var alternative_interval := 4.0
@export_range(1.0, 30.0) var encounter_reset_delay := 6.0
@export_range(-40.0, 6.0) var sword_volume_db := -8.0
@export_group("Footsteps")
@export var grass_steps: AudioStream = preload("res://assets/sound/basics/passos_em_grama_padrao.mp3")
@export var grass_steps_alternative: AudioStream = preload("res://assets/sound/basics/passos_em_grama_alternativo.mp3")
@export var stone_steps: AudioStream = preload("res://assets/sound/basics/passos_em_pedra_padrao.mp3")
@export var stone_steps_alternative: AudioStream = preload("res://assets/sound/basics/passos_em_pedra_alternativo.mp3")
@export var cloth_steps: AudioStream = preload("res://assets/sound/basics/passos_em_tecido_padrao.mp3")
@export var cloth_steps_alternative: AudioStream = preload("res://assets/sound/basics/passos_em_tecido_alternativo.mp3")
@export_range(0.0, 1.0) var footsteps_alternative_chance := 0.35
@export_range(0.1, 30.0) var footsteps_alternative_interval := 4.0
@export_range(-40.0, 6.0) var footsteps_volume_db := -14.0
@export_range(0.5, 2.0) var walk_playback_speed := 1.1
@export_group("Voice")
@export var attack_grunt: AudioStream = preload("res://assets/sound/basics/hit/grunidos_de_ataque.mp3")
@export var damage_standard: AudioStream = preload("res://assets/sound/basics/hit/som_de_dano_padrao.mp3")
@export var damage_alternative: AudioStream = preload("res://assets/sound/basics/hit/som_de_dano_alternativo.mp3")
@export var death_voice: AudioStream = preload("res://assets/sound/basics/hit/player_morto.mp3")
@export_range(0.0, 1.0) var damage_alternative_chance := 0.35
@export_range(-40.0, 6.0) var voice_volume_db := -8.0

@onready var body: CharacterBody3D = get_parent() as CharacterBody3D
var _sword: AudioStreamPlayer
var _alternative: AudioStreamPlayer
var _steps: AudioStreamPlayer
var _voice: AudioStreamPlayer
var _voice_is_attack := false
var _step_kind := ""
var _step_variation_elapsed := 0.0
var _step_phase := 1.0
var _target: WeakRef
var _since_attack := 999.0
var _since_alternative := 999.0
var _step_source: AudioStream

func _ready() -> void:
	# After Player movement and Visual animation updates.
	process_physics_priority = 30
	_sword = AudioStreamPlayer.new()
	_sword.name = "Sword"
	_sword.bus = "Swords"
	add_child(_sword)
	_alternative = AudioStreamPlayer.new()
	_alternative.name = "SwordAlternative"
	_alternative.bus = "Swords"
	add_child(_alternative)
	_steps = AudioStreamPlayer.new()
	_steps.name = "Footsteps"
	_steps.bus = "Footsteps"
	add_child(_steps)
	_voice = AudioStreamPlayer.new()
	_voice.name = "Voice"
	_voice.bus = "Effects"
	add_child(_voice)
	body.get_node("Visual").sword_swing.connect(_on_sword_swing)
	body.get_node("Visual").attack_voice.connect(_on_attack_voice)
	body.get_node("Visual").hit_animation_started.connect(_on_player_hit)
	body.died.connect(_on_player_died)

func _play_voice(source: AudioStream, is_attack: bool = false) -> void:
	if source == null:
		return
	_voice.stop()
	_voice_is_attack = is_attack
	_voice.stream = source.duplicate()
	if _voice.stream is AudioStreamMP3:
		# Attack grunts run for as long as the attack is committed or the button is held.
		(_voice.stream as AudioStreamMP3).loop = is_attack
	_voice.volume_db = voice_volume_db
	_voice.play()

func _on_attack_voice() -> void:
	if body.is_dead:
		return
	# Keep the running grunt track across repeated strikes; never restart per swing.
	if _voice_is_attack and _voice.playing:
		return
	_play_voice(attack_grunt, true)

func _on_player_hit() -> void:
	if body.health > 0 and not body.is_dead:
		_play_voice(damage_alternative if randf() < damage_alternative_chance else damage_standard)

func _on_player_died() -> void:
	_stop_audio()
	_play_voice(death_voice)

func _on_sword_swing(target: Node3D) -> void:
	if body.is_dead:
		return
	var use_alternative := false
	if is_instance_valid(target):
		var first_attack: bool = _target == null or _target.get_ref() != target or _since_attack >= encounter_reset_delay
		use_alternative = first_attack or (_since_alternative >= alternative_interval and randf() < alternative_chance)
		_target = weakref(target)
		_since_attack = 0.0
	_play_sword_layer(_sword, sword_standard)
	if use_alternative and sword_alternative != null:
		_play_sword_layer(_alternative, sword_alternative)
		_since_alternative = 0.0

func _play_sword_layer(player: AudioStreamPlayer, source: AudioStream) -> void:
	if source == null:
		return
	player.stream = source.duplicate()
	if player.stream is AudioStreamMP3:
		(player.stream as AudioStreamMP3).loop = false
	player.volume_db = sword_volume_db
	player.play()

func _physics_process(delta: float) -> void:
	var visual := body.get_node("Visual")
	# The grunt runs while an attack is committed, the attack button is held, or
	# an auto-attack target is still selected and within reach.
	if _voice_is_attack and not visual.is_attack_movement_locked() and not body._manual_attack_held:
		var engaged: bool = is_instance_valid(body.approach_target) and body.approach_target.is_selected and body.is_in_attack_range()
		if not engaged:
			_voice.stop()
			_voice_is_attack = false
	_since_attack += delta
	_since_alternative += delta
	_sword.volume_db = sword_volume_db
	_alternative.volume_db = sword_volume_db
	_voice.volume_db = voice_volume_db
	var velocity := body.get_real_velocity()
	var speed := Vector2(velocity.x, velocity.z).length()
	if body.is_dead or not body.is_on_floor() or speed < 0.1 or visual.is_attack_movement_locked():
		_stop_steps()
		return
	var kind := _surface_kind()
	var source := _standard_steps(kind)
	# Half the amplitude (-6.02 dB) for grass only; stone keeps its base volume.
	_steps.volume_db = footsteps_volume_db + (linear_to_db(0.5) if kind == "grass" else 0.0)
	if source == null:
		_stop_steps()
		return
	if source != _step_source or kind != _step_kind:
		_stop_steps()
		_step_kind = kind
		_step_source = source
	# Two footfalls per locomotion cycle, following the actual AnimationTree rates.
	var interval: float = visual.get_footstep_interval()
	_step_phase += delta / maxf(interval, 0.08)
	_step_variation_elapsed += delta
	_steps.pitch_scale = walk_playback_speed
	if _step_phase >= 1.0:
		_step_phase = fmod(_step_phase, 1.0)
		if _step_variation_elapsed >= footsteps_alternative_interval:
			_step_variation_elapsed = 0.0
			if randf() < footsteps_alternative_chance:
				var alternative := _alternative_steps(kind)
				if alternative != null:
					source = alternative
		# A single player replaces the previous footfall: never layered footsteps.
		_steps.stop()
		if _steps.stream == null or _steps.stream.get_meta("source_id", 0) != source.get_instance_id():
			_steps.stream = source.duplicate()
			_steps.stream.set_meta("source_id", source.get_instance_id())
			if _steps.stream is AudioStreamMP3:
				(_steps.stream as AudioStreamMP3).loop = false
		_steps.play()

func _alternative_steps(kind: String) -> AudioStream:
	var source: AudioStream = stone_steps_alternative
	if kind == "grass":
		source = grass_steps_alternative
	elif kind == "cloth":
		source = cloth_steps_alternative
	return source

func _standard_steps(kind: String) -> AudioStream:
	if kind == "grass":
		return grass_steps
	if kind == "cloth":
		return cloth_steps
	return stone_steps

func _stop_steps() -> void:
	_steps.stop()
	_step_variation_elapsed = 0.0
	_step_phase = 1.0

func _surface_kind() -> String:
	var origin := body.global_position + Vector3.UP * 0.25
	var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN, 3)
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return "stone"
	var surface: Node = hit.collider
	# Custom surfaces can override the temporary map mapping with metadata.
	var kind: String = str(surface.get_meta("footstep_surface", "grass" if surface.name == "Ground" else "stone"))
	match kind.to_lower():
		"grass", "grama":
			return "grass"
		"cloth", "fabric", "tecido":
			return "cloth"
	return "stone"

func _stop_audio() -> void:
	_stop_steps()
	_sword.stop()
	_alternative.stop()
