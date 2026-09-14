extends SceneTree
const CATALOG = preload("res://player_animation_catalog.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for name in CATALOG.CLIPS:
		var entry: Array = CATALOG.CLIPS[name]
		assert(ResourceLoader.exists("res://assets/player/" + entry[1]))
		var path: String = "res://assets/player/approved/" + entry[0] + ".tres"
		var clip: Animation = load(path)
		var changed := false
		var event_time := -1.0
		for track in range(clip.get_track_count()-1, -1, -1):
			if clip.track_get_type(track) == Animation.TYPE_METHOD:
				for key in clip.track_get_key_count(track):
					var time := clip.track_get_key_time(track, key)
					event_time = time if event_time < 0.0 else minf(time, event_time)
				clip.remove_track(track)
				changed = true
		if event_time >= 0:
			var track := clip.add_track(Animation.TYPE_METHOD)
			clip.track_set_path(track, NodePath(".."))
			var method := &"_on_attack_impact" if "Attack" in name else &"_on_draw_sheathe_event"
			clip.track_insert_key(track, event_time, {"method": method, "args": []})
			print(name, " single event=", event_time, " receiver=Visual")
		if name.begins_with("Long"):
			clip.loop_mode = Animation.LOOP_NONE
			changed = true
		if name in ["Walk", "Run", "ArmedWalk", "ArmedRun"]:
			for track in clip.get_track_count():
				if clip.track_get_type(track) == Animation.TYPE_POSITION_3D:
					for key in clip.track_get_key_count(track):
						var position: Vector3 = clip.track_get_key_value(track, key)
						assert(absf(position.x) < 0.001 and absf(position.z) < 0.001, "Locomotion drift")
		if changed:
			assert(ResourceSaver.save(clip, path) == OK)
	var model: Node = load("res://assets/player/medieval_knight__sculpture__game_ready.glb").instantiate()
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var graph := AnimationNodeBlendTree.new()
	for armed in [false, true]:
		var space := AnimationNodeBlendSpace1D.new()
		space.min_space = 0
		space.max_space = 6
		space.value_label = "Speed (m/s)"
		var prefix := "Armed" if armed else ""
		for i in 3:
			var leaf := AnimationNodeBlendTree.new()
			var clip := AnimationNodeAnimation.new()
			clip.animation = prefix + ["Idle", "Walk", "Run"][i]
			leaf.add_node("Clip", clip)
			leaf.add_node("Speed", AnimationNodeTimeScale.new())
			leaf.connect_node("Speed", 0, "Clip")
			leaf.connect_node("output", 0, "Speed")
			space.add_blend_point(leaf, [0.0, 4.0, 6.0][i], -1, str(i))
		graph.add_node("Armed" if armed else "Unarmed", space, Vector2(0, 200 if armed else 0))
	graph.add_node("WeaponBlend", AnimationNodeBlend2.new(), Vector2(240, 100))
	graph.connect_node("WeaponBlend", 0, "Unarmed")
	graph.connect_node("WeaponBlend", 1, "Armed")
	var previous := "WeaponBlend"
	for action in ["LongIdle", "Weapon", "Attack", "Hit"]:
		var clip := AnimationNodeAnimation.new()
		clip.animation = {"LongIdle":"Long1", "Weapon":"Draw1", "Attack":"Attack1", "Hit":"Hit1"}[action]
		graph.add_node(action + "Clip", clip)
		var shot := AnimationNodeOneShot.new()
		shot.fadein_time = 0.12 if action in ["Attack", "Hit"] else 0.15
		shot.fadeout_time = shot.fadein_time
		# All locomotion continues underneath, including zero-weight sections.
		shot.sync = true
		if action == "Weapon":
			shot.filter_enabled = true
			var spine := skeleton.find_bone("Spine")
			assert(spine >= 0)
			for bone in skeleton.get_bone_count():
				var ancestor := bone
				while ancestor >= 0 and ancestor != spine:
					ancestor = skeleton.get_bone_parent(ancestor)
				if ancestor == spine:
					shot.set_filter_path(NodePath("%GeneralSkeleton:" + skeleton.get_bone_name(bone)), true)
			shot.set_filter_path(NodePath(".."), true)
		graph.add_node(action, shot)
		graph.connect_node(action, 0, previous)
		if action == "Attack":
			graph.add_node("AttackSpeed", AnimationNodeTimeScale.new())
			graph.connect_node("AttackSpeed", 0, action + "Clip")
			graph.connect_node(action, 1, "AttackSpeed")
		else:
			graph.connect_node(action, 1, action + "Clip")
		previous = action
	var death := AnimationNodeAnimation.new()
	death.animation = &"Death"
	graph.add_node("DeathClip", death)
	var life := AnimationNodeTransition.new()
	life.input_count = 2
	life.set_input_name(0, "Alive")
	life.set_input_name(1, "Death")
	life.xfade_time = 0.12
	graph.add_node("Life", life)
	graph.connect_node("Life", 0, previous)
	graph.connect_node("Life", 1, "DeathClip")
	graph.connect_node("output", 0, "Life")
	assert(ResourceSaver.save(graph, "res://player_animation_graph.tres") == OK)
	assert(ResourceSaver.save(CATALOG.library(), "res://player_animation_library.tres") == OK)
	model.free()
	quit()




