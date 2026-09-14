extends SceneTree

func _init() -> void:
	# Add impact event to Punch at ~40% of 1.267s = 0.5s
	var punch = ResourceLoader.load("res://assets/player/player_punch.tres") as Animation
	if punch:
		# Remove old method tracks
		for i in range(punch.get_track_count() - 1, -1, -1):
			if punch.track_get_type(i) == Animation.TYPE_METHOD:
				punch.remove_track(i)
		# Add impact callback
		var t = punch.add_track(Animation.TYPE_METHOD)
		punch.track_set_path(t, "../../..")
		punch.track_insert_key(t, 0.5, {"method": "_on_attack_impact", "args": []})
		var t2 = punch.add_track(Animation.TYPE_METHOD)
		punch.track_set_path(t2, "..")
		punch.track_insert_key(t2, 0.5, {"method": "_on_attack_impact", "args": []})
		ResourceSaver.save(punch, "res://assets/player/player_punch.tres")
		print("Added impact event to player_punch.tres at 0.5s")
	
	# Also ensure Run loops
	var run = ResourceLoader.load("res://assets/player/player_run.tres") as Animation
	if run:
		run.loop_mode = Animation.LOOP_LINEAR
		ResourceSaver.save(run, "res://assets/player/player_run.tres")
		print("Set Run to loop")
	
	quit()
