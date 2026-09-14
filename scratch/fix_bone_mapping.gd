extends SceneTree

func _init() -> void:
	var bm = ResourceLoader.load("res://assets/player/greatsword_bone_map.tres") as BoneMap
	if not bm:
		print("BoneMap not found!")
		quit()
		return
		
	# Create reverse mapping: mixamorig_X -> Humanoid_X
	var reverse_map = {}
	var profile = bm.profile
	if profile:
		for i in range(profile.get_bone_size()):
			var hum_name = profile.get_bone_name(i)
			var mix_name = bm.get_skeleton_bone_name(hum_name)
			if mix_name != &"":
				reverse_map[mix_name] = hum_name
				
	_fix_anim("res://assets/player/player_armed_run.tres", reverse_map)
	_fix_anim("res://assets/player/player_armed_hit.tres", reverse_map)
	
	quit()

func _fix_anim(path: String, reverse_map: Dictionary) -> void:
	var anim = ResourceLoader.load(path) as Animation
	if not anim:
		return
		
	var modified = false
	for i in range(anim.get_track_count()):
		var track_path = str(anim.track_get_path(i))
		if track_path.begins_with("Skeleton3D:"):
			var mix_bone = track_path.replace("Skeleton3D:", "")
			if reverse_map.has(mix_bone):
				var hum_bone = reverse_map[mix_bone]
				var new_path = "%GeneralSkeleton:" + hum_bone
				anim.track_set_path(i, NodePath(new_path))
				modified = true
				
	if modified:
		ResourceSaver.save(anim, path)
		print("Fixed bones for: ", path)
