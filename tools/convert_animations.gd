@tool
extends EditorScript

var source_dir = "res://assets/player/approved/"
var target_dir = "res://assets/player/editable_animations/"

var animations_to_convert = [
	"player_armed_attack.tres",
	"player_armed_death_1.tres",
	"player_armed_death_2.tres",
	"player_armed_hit_1.tres",
	"player_armed_hit_2.tres",
	"player_armed_idle.tres",
	"player_armed_idle_long_1.tres",
	"player_armed_idle_long_2.tres",
	"player_armed_run.tres",
	"player_armed_walk.tres",
	"player_draw_1.tres",
	"player_draw_2.tres",
	"player_sheathe_1.tres",
	"player_sheathe_2.tres",
	"player_unarmed_attack_1.tres",
	"player_unarmed_attack_2.tres",
	"player_unarmed_attack_3.tres",
	"player_unarmed_death.tres",
	"player_unarmed_hit_1.tres",
	"player_unarmed_hit_2.tres",
	"player_unarmed_hit_3.tres",
	"player_unarmed_hit_4.tres",
	"player_unarmed_idle.tres",
	"player_unarmed_run.tres",
	"player_unarmed_walk.tres",
]

func _run() -> void:
	if not DirAccess.dir_exists_absolute(target_dir):
		DirAccess.make_dir_recursive_absolute(target_dir)
	
	var library = load("res://player_animation_library.tres")
	var new_library_data = {}
	var conversion_report = []
	
	for anim_file in animations_to_convert:
		var source_path = source_dir + anim_file
		var target_path = target_dir + anim_file
		
		print("Converting: " + anim_file)
		
		var original_anim = load(source_path)
		if not original_anim:
			push_error("Failed to load: " + source_path)
			continue
		
		var new_anim = Animation.new()
		new_anim.length = original_anim.length
		new_anim.loop_mode = original_anim.loop_mode
		new_anim.step = original_anim.step
		
		var track_count = original_anim.get_track_count()
		var imported_track_count = 0
		
		for i in range(track_count):
			var track_type = original_anim.track_get_type(i)
			var track_path = original_anim.track_get_path(i)
			var interp = original_anim.track_get_interpolation_type(i)
			var loop_wrap = original_anim.track_get_loop_wrap(i)
			var enabled = original_anim.track_is_enabled(i)
			var imported = original_anim.track_is_imported(i)
			
			if imported:
				imported_track_count += 1
			
			new_anim.add_track(track_type)
			new_anim.track_set_path(i, track_path)
			new_anim.track_set_interpolation_type(i, interp)
			new_anim.track_set_loop_wrap(i, loop_wrap)
			new_anim.track_set_enabled(i, enabled)
			
			var key_count = original_anim.track_get_key_count(i)
			for k in range(key_count):
				var time = original_anim.track_get_key_time(i, k)
				var transition = original_anim.track_get_key_transition(i, k)
				
				if track_type == Animation.TYPE_TRANSFORM:
					var loc = original_anim.track_get_key_value(i, k)
					var rot = original_anim.track_get_key_value(i, k)
					var scale = original_anim.track_get_key_value(i, k)
					new_anim.track_insert_key(i, time, loc, rot, scale)
				elif track_type == Animation.TYPE_VALUE:
					var value = original_anim.track_get_key_value(i, k)
					new_anim.track_insert_key(i, time, value, transition)
				elif track_type == Animation.TYPE_METHOD:
					var method = original_anim.track_get_key_value(i, k)
					var params = original_anim.track_get_key_value(i, k)
					new_anim.track_insert_key(i, time, method, params)
				elif track_type == Animation.TYPE_BEZIER:
					var value = original_anim.track_get_key_value(i, k)
					var in_handle = original_anim.track_get_key_value(i, k)
					var out_handle = original_anim.track_get_key_value(i, k)
					new_anim.track_insert_key(i, time, value, in_handle, out_handle, transition)
				elif track_type == Animation.TYPE_AUDIO:
					var stream = original_anim.track_get_key_value(i, k)
					var start_offset = original_anim.track_get_key_value(i, k)
					var end_offset = original_anim.track_get_key_value(i, k)
					new_anim.track_insert_key(i, time, stream, start_offset, end_offset)
				elif track_type == Animation.TYPE_ANIMATION:
					var anim_name = original_anim.track_get_key_value(i, k)
					new_anim.track_insert_key(i, time, anim_name)
		
		ResourceSaver.save(new_anim, target_path)
		
		var saved_anim = load(target_path)
		var all_tracks_not_imported = true
		for i in range(saved_anim.get_track_count()):
			if saved_anim.track_is_imported(i):
				all_tracks_not_imported = false
				break
		
		var report = {
			"name": anim_file,
			"original_tracks": track_count,
			"original_imported_tracks": imported_track_count,
			"new_tracks": saved_anim.get_track_count(),
			"all_tracks_local": all_tracks_not_imported,
			"length_match": abs(saved_anim.length - original_anim.length) < 0.001,
		}
		conversion_report.append(report)
		
		var anim_name = anim_file.replace("player_", "").replace(".tres", "")
		anim_name = _convert_to_library_name(anim_name)
		new_library_data[anim_name] = ExtResource(target_path)
		
		print("  Done: " + str(report))
	
	var new_library = AnimationLibrary.new()
	new_library._data = new_library_data
	ResourceSaver.save(new_library, "res://player_animation_library.tres")
	
	print("\n=== CONVERSION REPORT ===")
	for r in conversion_report:
		print(r)
	print("\nUpdated AnimationLibrary saved.")
	print("All animations saved to: " + target_dir)
	
func _convert_to_library_name(file_name: String) -> String:
	var name = file_name
	if name.begins_with("armed_"):
		name = name.replace("armed_", "Armed")
		name = _capitalize_segments(name)
	elif name.begins_with("unarmed_"):
		name = name.replace("unarmed_", "")
		name = _capitalize_segments(name)
	elif name.begins_with("draw_"):
		name = "Draw" + name.replace("draw_", "")
	elif name.begins_with("sheathe_"):
		name = "Sheathe" + name.replace("sheathe_", "")
	elif name.begins_with("idle_long_"):
		name = "Long" + name.replace("idle_long_", "")
	return name

func _capitalize_segments(name: String) -> String:
	var parts = name.split("_")
	for i in range(parts.size()):
		if parts[i].size() > 0:
			parts[i] = parts[i][0].to_upper() + parts[i].substr(1)
	return "".join(parts)