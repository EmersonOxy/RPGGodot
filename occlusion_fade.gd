extends Node3D
## Só objetos que interceptam a visão recebem fade. Fora dela, são opacos.

@export var camera: Camera3D
@export var player: Node3D
@export_range(0.05, 0.95) var occluded_alpha: float = 0.2
@export var fade_duration: float = 0.25
@export_flags_3d_physics var occluder_mask: int = 3

const MASK_SHADER := preload("res://occluder_mask.gdshader")
const AIM_OFFSETS := [Vector3(0, 0.45, 0), Vector3(0, 0.9, 0), Vector3(0, 1.5, 0)]
const MAX_STACK := 8

# Cada malha tem material/estado próprios: compartilhar cor não compartilha fade.
var _entries: Array[Dictionary] = []


func _ready() -> void:
	if camera == null:
		camera = get_node_or_null("../Player/Camera3D") as Camera3D
	if player == null:
		player = get_node_or_null("../Player") as Node3D
	for node in get_parent().find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var body := mesh.get_parent()
		while body != null and not body is CollisionObject3D:
			body = body.get_parent()
		if body == null:
			continue
		var source := mesh.material_override as ShaderMaterial
		var local_mask := source != null and source.shader == MASK_SHADER
		var full_fade := body.is_in_group("full_occluder")
		if not local_mask and not full_fade:
			continue
		var opaque: Material = mesh.material_override
		var mask: ShaderMaterial = null
		if local_mask:
			# ALPHA=1 num shader ainda usa a fila transparente. Restaura material
			# realmente opaco quando o objeto não precisa do recorte.
			var solid := StandardMaterial3D.new()
			solid.albedo_color = source.get_shader_parameter("albedo_color")
			solid.roughness = source.get_shader_parameter("roughness")
			opaque = solid
			mask = source.duplicate() as ShaderMaterial
			mask.set_shader_parameter("occlusion_strength", 0.0)
			mesh.material_override = opaque
		_entries.append({"mesh": mesh, "body": body, "opaque": opaque,
			"mask": mask, "full": full_fade, "amount": 0.0,
			"transparency": mesh.transparency, "shadow": mesh.cast_shadow})


func _physics_process(delta: float) -> void:
	var seen := {}
	if is_instance_valid(player) and is_instance_valid(camera):
		var space := get_world_3d().direct_space_state
		# O piso que sustenta os pés não deve desaparecer.
		var floor_query := PhysicsRayQueryParameters3D.create(
			player.global_position + Vector3.UP * 0.1,
			player.global_position + Vector3.DOWN * 0.35, 1)
		var floor_hit := space.intersect_ray(floor_query)
		var support: Object = floor_hit.get("collider")
		for offset in AIM_OFFSETS:
			var aim: Vector3 = player.global_position + offset
			var origin := camera.project_ray_origin(camera.unproject_position(aim))
			var excluded: Array[RID] = []
			for layer in range(MAX_STACK):
				var query := PhysicsRayQueryParameters3D.create(origin, aim, occluder_mask, excluded)
				var hit := space.intersect_ray(query)
				if hit.is_empty():
					break
				excluded.append(hit.rid)
				var body = hit.collider
				if body != support and not body.is_in_group("no_occlusion"):
					seen[body] = true
	_update_fades(seen, delta)


func _update_fades(seen: Dictionary, delta: float) -> void:
	for entry in _entries:
		var mesh = entry.mesh
		if not is_instance_valid(mesh):
			continue
		var wanted := 1.0 if is_instance_valid(entry.body) and seen.has(entry.body) else 0.0
		entry.amount = move_toward(entry.amount, wanted, delta / maxf(fade_duration, 0.01))
		if entry.full:
			mesh.transparency = lerpf(entry.transparency, 1.0 - occluded_alpha, entry.amount)
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if entry.amount > 0.01 else entry.shadow
		elif entry.mask != null:
			if entry.amount > 0.0:
				if is_instance_valid(player):
					entry.mask.set_shader_parameter("player_position", player.global_position)
				entry.mask.set_shader_parameter("occlusion_strength", entry.amount)
				mesh.material_override = entry.mask
			else:
				mesh.material_override = entry.opaque


func _exit_tree() -> void:
	for entry in _entries:
		if is_instance_valid(entry.mesh):
			entry.mesh.material_override = entry.opaque
			entry.mesh.transparency = entry.transparency
			entry.mesh.cast_shadow = entry.shadow
