extends SceneTree

func _init() -> void:
	# Load the player visual scene to find the actual skeleton path
	var scene = ResourceLoader.load("res://player_visual.tscn") as PackedScene
	if not scene:
		print("Cannot load player_visual.tscn")
		quit()
		return
	
	var inst = scene.instantiate()
	
	# Find the AnimationPlayer and its root
	var ap: AnimationPlayer = null
	var at: AnimationTree = null
	for child in inst.get_children():
		if child is AnimationTree:
			at = child
	
	# Find AnimationPlayer recursively
	var aps = inst.find_children("*", "AnimationPlayer", true, false)
	if aps.size() > 0:
		ap = aps[0]
		print("AnimationPlayer found at: ", ap.get_path())
		print("AnimationPlayer path from root: ", inst.get_path_to(ap))
	
	# Find Skeleton3D
	var skels = inst.find_children("*", "Skeleton3D", true, false)
	if skels.size() > 0:
		var skel = skels[0]
		print("Skeleton3D found at: ", inst.get_path_to(skel))
		print("Skeleton3D name: ", skel.name)
		
		# Path from the AnimationTree root_node (which is ../Model, i.e. the Model node)
		var model = inst.find_child("Model", false, false)
		if model:
			var skel_path_from_model = model.get_path_to(skel)
			print("Skeleton path from Model: ", skel_path_from_model)
			
			# Also check what the existing imported animations use
			if ap:
				var ap_path_from_model = model.get_path_to(ap)
				print("AP path from Model: ", ap_path_from_model)
				for lib_name in ap.get_animation_library_list():
					var lib = ap.get_animation_library(lib_name)
					for anim_name in lib.get_animation_list():
						var anim = lib.get_animation(anim_name)
						if anim.get_track_count() > 0:
							print("  Anim '", lib_name, "/", anim_name, "' track[0] path: ", anim.track_get_path(0))
						break # just first anim
					break # just first lib
		
		# Print bone names
		print("\nSkeleton bones:")
		for i in range(mini(skel.get_bone_count(), 10)):
			print("  ", skel.get_bone_name(i))
	
	# Check one of our approved animations
	var test_anim = ResourceLoader.load("res://assets/player/approved/player_unarmed_idle.tres") as Animation
	if test_anim:
		print("\nApproved anim track paths (first 5):")
		for i in range(mini(test_anim.get_track_count(), 5)):
			print("  ", test_anim.track_get_path(i))
	
	inst.queue_free()
	quit()
