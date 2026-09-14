extends SceneTree

func _init() -> void:
	var scene = ResourceLoader.load("res://player_visual.tscn") as PackedScene
	if not scene:
		quit()
		return
	
	var inst = scene.instantiate()
	var aps = inst.find_children("*", "AnimationPlayer", true, false)
	if aps.size() > 0:
		var ap = aps[0]
		print("Before adding library:")
		for lib_name in ap.get_animation_library_list():
			var lib = ap.get_animation_library(lib_name)
			var anims = lib.get_animation_list()
			print("  Library '", lib_name, "' has ", anims.size(), " anims:")
			for a in anims:
				var anim = lib.get_animation(a)
				print("    ", a, " (tracks: ", anim.get_track_count(), ", length: ", anim.length, ")")
				if anim.get_track_count() > 0:
					print("      track[0]: ", anim.track_get_path(0))
		
		# Now simulate what _ready does
		var library = AnimationLibrary.new()
		var dir = DirAccess.open("res://assets/player/approved")
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if file_name.ends_with(".tres"):
					var anim = ResourceLoader.load("res://assets/player/approved/" + file_name) as Animation
					if anim:
						var anim_name = file_name.replace(".tres", "")
						library.add_animation(anim_name, anim)
				file_name = dir.get_next()
		
		# Check if adding with name "" would replace
		if ap.has_animation_library(&""):
			print("\nAP already has library ''! Will remove first.")
			ap.remove_animation_library(&"")
		
		ap.add_animation_library(&"", library)
		
		print("\nAfter adding library:")
		for lib_name in ap.get_animation_library_list():
			var lib = ap.get_animation_library(lib_name)
			var anims = lib.get_animation_list()
			print("  Library '", lib_name, "' has ", anims.size(), " anims")
			
		# Now check if the animation "player_unarmed_idle" exists  
		print("\nHas 'player_unarmed_idle': ", ap.has_animation(&"player_unarmed_idle"))
		
		# Check track paths in our idle anim
		var idle = ap.get_animation(&"player_unarmed_idle")
		if idle:
			print("Idle animation tracks: ", idle.get_track_count())
			for i in range(mini(idle.get_track_count(), 5)):
				print("  track[", i, "]: ", idle.track_get_path(i), " type=", idle.track_get_type(i))
	
	inst.queue_free()
	quit()
