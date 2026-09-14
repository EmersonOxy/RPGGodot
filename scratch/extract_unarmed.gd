extends SceneTree

func _init() -> void:
	var bm = ResourceLoader.load("res://assets/player/greatsword_bone_map.tres") as BoneMap
	var reverse_map = {}
	if bm and bm.profile:
		for i in range(bm.profile.get_bone_size()):
			var hum_name = bm.profile.get_bone_name(i)
			var mix_name = bm.get_skeleton_bone_name(hum_name)
			if mix_name != &"":
				reverse_map[mix_name] = hum_name

	# Extract unarmed Run
	_extract("res://assets/player/Running.fbx", "res://assets/player/player_run.tres", reverse_map, false)
	# Extract unarmed Punch/Attack
	_extract("res://assets/player/Punching.fbx", "res://assets/player/player_punch.tres", reverse_map, false)

	quit()

func _extract(source: String, dest: String, reverse_map: Dictionary, fix_root_motion: bool) -> void:
	var pack = ResourceLoader.load(source) as PackedScene
	if not pack:
		print("Failed to load: ", source)
		return

	var inst = pack.instantiate()
	var ap: AnimationPlayer = null
	for child in inst.get_children():
		if child is AnimationPlayer:
			ap = child
			break
	if not ap:
		ap = inst.get_node_or_null("AnimationPlayer")

	if not ap or ap.get_animation_list().size() == 0:
		print("No AnimationPlayer found in ", source)
		inst.queue_free()
		return

	var anim_name = ap.get_animation_list()[0]
	var anim = ap.get_animation(anim_name).duplicate() as Animation

	# Fix bone names from mixamorig_ to Humanoid
	for i in range(anim.get_track_count()):
		var track_path = str(anim.track_get_path(i))
		if track_path.begins_with("Skeleton3D:"):
			var mix_bone = track_path.replace("Skeleton3D:", "")
			if reverse_map.has(mix_bone):
				var hum_bone = reverse_map[mix_bone]
				anim.track_set_path(i, NodePath("%GeneralSkeleton:" + hum_bone))

	# Fix root motion if needed
	if fix_root_motion:
		for i in range(anim.get_track_count()):
			var p = str(anim.track_get_path(i))
			if "Hips" in p and anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
				for k in range(anim.track_get_key_count(i)):
					var val = anim.track_get_key_value(i, k)
					val.x = 0
					val.z = 0
					anim.track_set_key_value(i, k, val)

	anim.resource_name = dest.get_file().get_basename()
	ResourceSaver.save(anim, dest)
	print("Extracted: ", dest, " (length=", anim.length, "s, tracks=", anim.get_track_count(), ")")

	inst.queue_free()
