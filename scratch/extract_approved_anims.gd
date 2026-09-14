extends SceneTree

var reverse_map = {}

func _init() -> void:
	var bm = ResourceLoader.load("res://assets/player/greatsword_bone_map.tres") as BoneMap
	if bm and bm.profile:
		for i in range(bm.profile.get_bone_size()):
			var hum_name = bm.profile.get_bone_name(i)
			var mix_name = bm.get_skeleton_bone_name(hum_name)
			if mix_name != &"":
				reverse_map[mix_name] = hum_name
				
	var dir = DirAccess.open("res://assets/player")
	if not dir.dir_exists("approved"):
		dir.make_dir("approved")
		
	# --- UNARMED ---
	var un = "res://assets/player/Sem espada/"
	_ex(un+"idle_sem_espada.fbx", "player_unarmed_idle", false, [], [])
	_ex(un+"andar_sem_espada.fbx", "player_unarmed_walk", true, [], [])
	_ex(un+"correr_sem_espada.fbx", "player_unarmed_run", true, [], [])
	_ex(un+"morrer_sem_espada.fbx", "player_unarmed_death", false, [], [])
	
	_ex(un+"atacar_sem_espada.fbx", "player_unarmed_attack_1", false, [0.35], ["_on_attack_impact"])
	_ex(un+"atacar_sem_espada_2.fbx", "player_unarmed_attack_2", false, [0.4], ["_on_attack_impact"])
	_ex(un+"atacar_sem_espada_3.fbx", "player_unarmed_attack_3", false, [0.35], ["_on_attack_impact"])
	
	_ex(un+"tomar_dano_sem_espada.fbx", "player_unarmed_hit_1", false, [], [])
	_ex(un+"tomar_dano_sem_espada_2.fbx", "player_unarmed_hit_2", false, [], [])
	_ex(un+"tomar_dano_sem_espada_3.fbx", "player_unarmed_hit_3", false, [], [])
	_ex(un+"tomar_dano_sem_espada_4.fbx", "player_unarmed_hit_4", false, [], [])
	
	# --- ARMED ---
	var ar = "res://assets/player/Com espada/"
	_ex(ar+"idle_com_espada_duas_maos.fbx", "player_armed_idle", false, [], [])
	_ex(ar+"Idle_com_espada_duas_maos_demorado.fbx", "player_armed_idle_long_1", false, [], [])
	_ex(ar+"Idle_com_espada_duas_maos_demorado_2.fbx", "player_armed_idle_long_2", false, [], [])
	_ex(ar+"andar_com_espada_duas_maos.fbx", "player_armed_walk", true, [], [])
	_ex(ar+"correr_com_espada_duas_maos.fbx", "player_armed_run", true, [], [])
	
	_ex(ar+"atacar_com_espada_duas_maos.fbx", "player_armed_attack", false, [0.4], ["_on_attack_impact"])
	
	_ex(ar+"tomar_dano_com_espada_duas_maos.fbx", "player_armed_hit_1", false, [], [])
	_ex(ar+"tomar_dano_com_espada_duas_maos_2.fbx", "player_armed_hit_2", false, [], [])
	
	_ex(ar+"morrer_com_espada_duas_maos.fbx", "player_armed_death_1", false, [], [])
	_ex(ar+"morrer_com_espada_duas_maos_2.fbx", "player_armed_death_2", false, [], [])
	
	# --- TRANSITIONS ---
	var tr = "res://assets/player/Transições/"
	_ex(tr+"sacar_espada_duas_maos.fbx", "player_draw_1", false, [0.3, 0.4], ["_on_draw_sheathe_event", "_on_draw_sheathe_event"])
	_ex(tr+"sacar_espada_duas_maos_2.fbx", "player_draw_2", false, [0.3, 0.4], ["_on_draw_sheathe_event", "_on_draw_sheathe_event"])
	
	_ex(tr+"guardar_espada_duas_maos.fbx", "player_sheathe_1", false, [0.6, 0.7], ["_on_draw_sheathe_event", "_on_draw_sheathe_event"])
	_ex(tr+"guardar_espada_duas_maos_2.fbx", "player_sheathe_2", false, [0.6, 0.7], ["_on_draw_sheathe_event", "_on_draw_sheathe_event"])

	quit()

func _ex(source: String, dest_name: String, fix_root_motion: bool, method_times: Array, method_names: Array) -> void:
	if not FileAccess.file_exists(source):
		print("File missing: ", source)
		return
		
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
		inst.queue_free()
		return

	var anim_name = ap.get_animation_list()[0]
	var anim = ap.get_animation(anim_name).duplicate() as Animation

	# Fix bone names (Godot retarget already applied Humanoid names via import settings)
	for i in range(anim.get_track_count()):
		var track_path = str(anim.track_get_path(i))
		if track_path.begins_with("Skeleton3D:"):
			var hum_bone = track_path.replace("Skeleton3D:", "")
			anim.track_set_path(i, NodePath("%GeneralSkeleton:" + hum_bone))

	# Fix root motion
	if fix_root_motion:
		for i in range(anim.get_track_count()):
			var p = str(anim.track_get_path(i))
			if "Hips" in p and anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
				for k in range(anim.track_get_key_count(i)):
					var val = anim.track_get_key_value(i, k)
					val.x = 0
					val.z = 0
					anim.track_set_key_value(i, k, val)

	# Inject methods
	if method_times.size() > 0:
		var t = anim.add_track(Animation.TYPE_METHOD)
		# Path pointing to player_visual (which is at model level, parent of AnimationPlayer)
		# Handled based on node tree. For safety, point to "" which is AnimationPlayer and we can proxy,
		# or "..", ".." is usually PlayerVisual.
		anim.track_set_path(t, "..")
		for j in range(method_times.size()):
			# Let's pass boolean argument to draw/sheathe: true for draw, false for sheathe.
			# But how do we know? We can deduce from the name.
			var is_draw = "draw" in dest_name
			if "sheathe" in dest_name or "draw" in dest_name:
				anim.track_insert_key(t, method_times[j], {"method": method_names[j], "args": []})
			else:
				anim.track_insert_key(t, method_times[j], {"method": method_names[j], "args": []})
				
		var t2 = anim.add_track(Animation.TYPE_METHOD)
		# Alternate path in case PlayerVisual is root of tree vs child of body
		anim.track_set_path(t2, "../../..")
		for j in range(method_times.size()):
			anim.track_insert_key(t2, method_times[j], {"method": method_names[j], "args": []})

	# Ensure looping for certain clips
	if "walk" in dest_name or "run" in dest_name or "idle" in dest_name:
		anim.loop_mode = Animation.LOOP_LINEAR

	var dest = "res://assets/player/approved/" + dest_name + ".tres"
	anim.resource_name = dest_name
	ResourceSaver.save(anim, dest)
	print("Extracted: ", dest_name)
	inst.queue_free()
