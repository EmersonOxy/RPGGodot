extends SceneTree

func _init():
	_extract_and_fix("res://assets/player/Great Sword Pack/great sword run.fbx", "res://assets/player/player_armed_run.tres", true)
	_extract_and_fix("res://assets/player/Great Sword Pack/great sword impact.fbx", "res://assets/player/player_armed_hit.tres", false)
	quit()

func _extract_and_fix(source: String, dest: String, fix_root_motion: bool):
	var pack = ResourceLoader.load(source) as PackedScene
	if not pack:
		print("Failed to load: ", source)
		return
		
	var inst = pack.instantiate()
	var ap: AnimationPlayer = inst.get_node_or_null("AnimationPlayer")
	
	if not ap:
		for child in inst.get_children():
			if child is AnimationPlayer:
				ap = child
				break
				
	if ap and ap.get_animation_list().size() > 0:
		var anim_name = ap.get_animation_list()[0]
		var anim = ap.get_animation(anim_name).duplicate() as Animation
		
		# Fix root motion for run
		if fix_root_motion:
			for i in range(anim.get_track_count()):
				if anim.track_get_path(i) == NodePath("GeneralSkeleton:Hips") or anim.track_get_path(i) == NodePath("%GeneralSkeleton:Hips"):
					if anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
						var kc = anim.track_get_key_count(i)
						for k in range(kc):
							var val = anim.track_get_key_value(i, k)
							val.x = 0
							val.z = 0
							anim.track_set_key_value(i, k, val)
							
		# Save
		anim.resource_name = dest.get_file().get_basename()
		ResourceSaver.save(anim, dest)
		print("Saved to ", dest)
	else:
		print("No AnimationPlayer found in ", source)
		
	inst.queue_free()
