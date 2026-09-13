extends Node3D
## The existing Player owns movement and combat; this node only presents them.

const IDLE: Animation = preload("res://assets/player/player_idle.tres")
const WALK: Animation = preload("res://assets/player/player_walk.tres")
const ATTACK: Animation = preload("res://assets/player/player_attack.tres")

@export var turn_speed: float = 12.0
@export var walk_reference_speed: float = 1.75
@export var movement_start_threshold: float = 0.10
@export var movement_stop_threshold: float = 0.05

@onready var body: CharacterBody3D = get_parent() as CharacterBody3D
@onready var animation_player: AnimationPlayer = $Model/AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
var playback: AnimationNodeStateMachinePlayback
var moving := false
var attack_target: WeakRef
var sword_socket: Node3D

func _ready() -> void:
	process_physics_priority = 10
	var library := AnimationLibrary.new()
	library.add_animation(&"Idle", IDLE)
	library.add_animation(&"Walk", WALK)
	library.add_animation(&"Attack", ATTACK)
	animation_player.add_animation_library(&"character", library)
	animation_player.stop()
	animation_tree.active = true
	playback = animation_tree.get("parameters/playback")
	animation_tree.set("parameters/conditions/stopped", true)
	playback.start(&"Idle")
	body.connect("attack_executed", _on_attack_executed)
	sword_socket = find_child("SwordSocket", true, false)
	# Equipment is created in the parent's _ready, after its children.
	_connect_equipment.call_deferred()

func _connect_equipment() -> void:
	var equipment := body.get_node_or_null("Equipment")
	if equipment:
		equipment.changed.connect(_refresh_weapon)
		_refresh_weapon()

func _refresh_weapon() -> void:
	var equipment := body.get_node_or_null("Equipment")
	if sword_socket and equipment:
		sword_socket.visible = equipment.get_item(ItemData.EquipmentSlot.WEAPON) != null

func _physics_process(delta: float) -> void:
	if body:
		update_movement(body.get_real_velocity() if body.is_physics_processing() else Vector3.ZERO, delta)

func update_movement(actual_velocity: Vector3, delta: float) -> void:
	var planar := Vector3(actual_velocity.x, 0, actual_velocity.z)
	var speed := planar.length()
	moving = speed > (movement_stop_threshold if moving else movement_start_threshold)
	animation_tree.set("parameters/conditions/moving", moving)
	animation_tree.set("parameters/conditions/stopped", not moving)
	animation_tree.set("parameters/Walk/Speed/scale", clampf(speed / maxf(walk_reference_speed, 0.01), 0.25, 3.0))
	var attacking := playback.get_current_node() == &"Attack" or &"Attack" in playback.get_travel_path()
	if not attacking:
		var next: StringName = &"Walk" if moving else &"Idle"
		if playback.get_current_node() != next:
			playback.travel(next)
	var direction := planar
	if attacking and attack_target:
		var target := attack_target.get_ref() as Node3D
		if is_instance_valid(target):
			direction = target.global_position - body.global_position
			direction.y = 0
	if direction.length_squared() > 0.0025:
		var local_direction := body.global_basis.inverse() * direction
		rotation.y = lerp_angle(rotation.y, atan2(local_direction.x, local_direction.z), 1.0 - exp(-turn_speed * delta))

func _on_attack_executed(target: Node3D, interval: float) -> void:
	attack_target = weakref(target)
	# Fit the visual within the existing cooldown; never change combat timing.
	animation_tree.set("parameters/Attack/Speed/scale", ATTACK.length / maxf(interval * 0.85, 0.15))
	playback.travel(&"Attack")
