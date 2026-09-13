extends Node3D
## The existing Player owns movement and combat; this node only presents them.

const IDLE: Animation = preload("res://assets/player/player_idle.tres")
const WALK: Animation = preload("res://assets/player/player_walk.tres")
const ATTACK: Animation = preload("res://assets/player/player_attack.tres")

const SWORD_OFFSETS: Dictionary = {
	&"Armed": {
		"position": Vector3(0.0, -0.12, 0.04),
		"rotation": Vector3(0.0, 0.0, -1.5707963),
	}
}

@export var turn_speed: float = 12.0
@export var walk_reference_speed: float = 1.75
@export var movement_start_threshold: float = 0.10
@export var movement_stop_threshold: float = 0.05
@export var sword_blend_speed: float = 14.0

@onready var body: CharacterBody3D = get_parent() as CharacterBody3D
@onready var animation_player: AnimationPlayer = $Model/AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
var playback: AnimationNodeStateMachinePlayback
var moving := false
var attack_target: WeakRef
var sword_socket: Node3D
var sheathe_socket: Node3D

func _ready() -> void:
	process_physics_priority = 10
	var library := AnimationLibrary.new()
	library.add_animation(&"Idle", IDLE)
	library.add_animation(&"Walk", WALK)
	
	var armed_idle = ResourceLoader.load("res://assets/player/player_armed_idle.tres") as Animation
	var armed_walk = ResourceLoader.load("res://assets/player/player_armed_walk.tres") as Animation
	var armed_attack = ResourceLoader.load("res://assets/player/player_armed_attack.tres") as Animation
	
	if armed_idle: library.add_animation(&"ArmedIdle", armed_idle)
	else: library.add_animation(&"ArmedIdle", IDLE)
	
	if armed_walk: library.add_animation(&"ArmedWalk", armed_walk)
	else: library.add_animation(&"ArmedWalk", WALK)
	
	if armed_attack: library.add_animation(&"ArmedAttack", armed_attack)
	else: library.add_animation(&"ArmedAttack", ATTACK)
	
	library.add_animation(&"UnarmedAttack", ATTACK)
	
	animation_player.add_animation_library(&"character", library)
	animation_player.stop()
	animation_tree.active = true
	playback = animation_tree.get("parameters/playback")
	animation_tree.set("parameters/conditions/stopped", true)
	animation_tree.set("parameters/conditions/moving", false)
	animation_tree.set("parameters/conditions/drawn", false)
	playback.start(&"Idle")
	body.connect("attack_executed", _on_attack_executed)
	sword_socket = find_child("SwordSocket", true, false)
	if sword_socket:
		var init_offset: Dictionary = SWORD_OFFSETS[&"Armed"]
		sword_socket.position = init_offset["position"]
		sword_socket.quaternion = Quaternion.from_euler(init_offset["rotation"])
		
	var skeleton: Skeleton3D = find_children("*", "Skeleton3D", true, false)[0] if not find_children("*", "Skeleton3D", true, false).is_empty() else null
	if skeleton:
		var sheathe_att := BoneAttachment3D.new()
		sheathe_att.name = "SheatheAttachment"
		var possible_bones = ["Spine1", "Spine", "mixamorig_Spine1", "mixamorig_Spine", "Spine_01", "Pelvis", "Hips"]
		for b in possible_bones:
			var idx = skeleton.find_bone(b)
			if idx != -1:
				sheathe_att.bone_name = b
				break
		skeleton.add_child(sheathe_att)
		sheathe_socket = Node3D.new()
		sheathe_socket.name = "SheatheSocket"
		sheathe_socket.position = Vector3(0.0, 0.0, -0.15)
		sheathe_socket.rotation = Vector3(PI, 0, PI/4)
		sheathe_att.add_child(sheathe_socket)
		
		var sword_scene = preload("res://player_sword.tscn")
		var inst = sword_scene.instantiate()
		sheathe_socket.add_child(inst)
		sheathe_socket.visible = false

	if body.has_signal("weapon_drawn_changed"):
		body.weapon_drawn_changed.connect(_on_weapon_drawn_changed)

	# Equipment is created in the parent's _ready, after its children.
	_connect_equipment.call_deferred()

func _connect_equipment() -> void:
	var equipment := body.get_node_or_null("Equipment")
	if equipment:
		equipment.changed.connect(_refresh_weapon)
		_refresh_weapon()

func _on_weapon_drawn_changed(drawn: bool) -> void:
	_refresh_weapon()

func _refresh_weapon() -> void:
	var equipment := body.get_node_or_null("Equipment")
	var has_weapon = equipment and equipment.get_item(ItemData.EquipmentSlot.WEAPON) != null
	var drawn = false
	if "weapon_drawn" in body:
		drawn = body.weapon_drawn
	
	if sword_socket:
		sword_socket.visible = has_weapon and drawn
	if sheathe_socket:
		sheathe_socket.visible = has_weapon and not drawn

func _physics_process(delta: float) -> void:
	if body:
		update_movement(body.get_real_velocity() if body.is_physics_processing() else Vector3.ZERO, delta)
	_update_sword_socket(delta)

func _update_sword_socket(delta: float) -> void:
	if not sword_socket or not playback:
		return
	var target_offset: Dictionary = SWORD_OFFSETS[&"Armed"]
	var target_pos: Vector3 = target_offset["position"]
	var target_rot: Quaternion = Quaternion.from_euler(target_offset["rotation"])

	var blend_rate: float = 1.0 - exp(-sword_blend_speed * delta)
	sword_socket.position = sword_socket.position.lerp(target_pos, blend_rate)
	sword_socket.quaternion = sword_socket.quaternion.slerp(target_rot, blend_rate)

func update_movement(actual_velocity: Vector3, delta: float) -> void:
	var planar := Vector3(actual_velocity.x, 0, actual_velocity.z)
	var speed := planar.length()
	moving = speed > (movement_stop_threshold if moving else movement_start_threshold)
	animation_tree.set("parameters/conditions/moving", moving)
	animation_tree.set("parameters/conditions/stopped", not moving)
	animation_tree.set("parameters/Walk/Speed/scale", clampf(speed / maxf(walk_reference_speed, 0.01), 0.25, 3.0))
	animation_tree.set("parameters/ArmedWalk/Speed/scale", clampf(speed / maxf(walk_reference_speed, 0.01), 0.25, 3.0))
	var current_node := playback.get_current_node()
	var attacking := current_node == &"ArmedAttack" or &"ArmedAttack" in playback.get_travel_path() or current_node == &"UnarmedAttack" or &"UnarmedAttack" in playback.get_travel_path()
	
	if not attacking:
		var drawn = false
		if "weapon_drawn" in body:
			drawn = body.weapon_drawn
			
		var next: StringName
		if drawn:
			next = &"ArmedWalk" if moving else &"ArmedIdle"
		else:
			next = &"Walk" if moving else &"Idle"
			
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
	var drawn = false
	if "weapon_drawn" in body:
		drawn = body.weapon_drawn
		
	if drawn:
		var anim: Animation = animation_player.get_animation(&"character/ArmedAttack")
		var anim_len: float = anim.length if anim else ATTACK.length
		animation_tree.set("parameters/ArmedAttack/Speed/scale", anim_len / maxf(interval * 0.85, 0.15))
		playback.travel(&"ArmedAttack")
	else:
		var anim: Animation = animation_player.get_animation(&"character/UnarmedAttack")
		var anim_len: float = anim.length if anim else ATTACK.length
		animation_tree.set("parameters/UnarmedAttack/Speed/scale", anim_len / maxf(interval * 0.85, 0.15))
		playback.travel(&"UnarmedAttack")

func _on_attack_impact() -> void:
	if body and body.has_method("_on_attack_impact"):
		body._on_attack_impact()
