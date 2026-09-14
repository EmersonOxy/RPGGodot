extends SceneTree

var mixamo_to_godot = {
	"mixamorig_Hips": "Hips",
	"mixamorig_Spine": "Spine",
	"mixamorig_Spine1": "Chest",
	"mixamorig_Spine2": "UpperChest",
	"mixamorig_Neck": "Neck",
	"mixamorig_Head": "Head",
	"mixamorig_LeftShoulder": "LeftShoulder",
	"mixamorig_LeftArm": "LeftUpperArm",
	"mixamorig_LeftForeArm": "LeftLowerArm",
	"mixamorig_LeftHand": "LeftHand",
	"mixamorig_LeftHandThumb1": "LeftThumbMetacarpal",
	"mixamorig_LeftHandThumb2": "LeftThumbProximal",
	"mixamorig_LeftHandThumb3": "LeftThumbDistal",
	"mixamorig_LeftHandIndex1": "LeftIndexProximal",
	"mixamorig_LeftHandIndex2": "LeftIndexIntermediate",
	"mixamorig_LeftHandIndex3": "LeftIndexDistal",
	"mixamorig_LeftHandMiddle1": "LeftMiddleProximal",
	"mixamorig_LeftHandMiddle2": "LeftMiddleIntermediate",
	"mixamorig_LeftHandMiddle3": "LeftMiddleDistal",
	"mixamorig_LeftHandRing1": "LeftRingProximal",
	"mixamorig_LeftHandRing2": "LeftRingIntermediate",
	"mixamorig_LeftHandRing3": "LeftRingDistal",
	"mixamorig_LeftHandPinky1": "LeftLittleProximal",
	"mixamorig_LeftHandPinky2": "LeftLittleIntermediate",
	"mixamorig_LeftHandPinky3": "LeftLittleDistal",
	"mixamorig_RightShoulder": "RightShoulder",
	"mixamorig_RightArm": "RightUpperArm",
	"mixamorig_RightForeArm": "RightLowerArm",
	"mixamorig_RightHand": "RightHand",
	"mixamorig_RightHandThumb1": "RightThumbMetacarpal",
	"mixamorig_RightHandThumb2": "RightThumbProximal",
	"mixamorig_RightHandThumb3": "RightThumbDistal",
	"mixamorig_RightHandIndex1": "RightIndexProximal",
	"mixamorig_RightHandIndex2": "RightIndexIntermediate",
	"mixamorig_RightHandIndex3": "RightIndexDistal",
	"mixamorig_RightHandMiddle1": "RightMiddleProximal",
	"mixamorig_RightHandMiddle2": "RightMiddleIntermediate",
	"mixamorig_RightHandMiddle3": "RightMiddleDistal",
	"mixamorig_RightHandRing1": "RightRingProximal",
	"mixamorig_RightHandRing2": "RightRingIntermediate",
	"mixamorig_RightHandRing3": "RightRingDistal",
	"mixamorig_RightHandPinky1": "RightLittleProximal",
	"mixamorig_RightHandPinky2": "RightLittleIntermediate",
	"mixamorig_RightHandPinky3": "RightLittleDistal",
	"mixamorig_LeftUpLeg": "LeftUpperLeg",
	"mixamorig_LeftLeg": "LeftLowerLeg",
	"mixamorig_LeftFoot": "LeftFoot",
	"mixamorig_LeftToeBase": "LeftToes",
	"mixamorig_RightUpLeg": "RightUpperLeg",
	"mixamorig_RightLeg": "RightLowerLeg",
	"mixamorig_RightFoot": "RightFoot",
	"mixamorig_RightToeBase": "RightToes"
}

func _init() -> void:
	var dir = DirAccess.open("res://assets/player/approved")
	if not dir:
		quit()
		return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			_fix_bones("res://assets/player/approved/" + file_name)
		file_name = dir.get_next()
		
	quit()

func _fix_bones(path: String) -> void:
	var anim = ResourceLoader.load(path) as Animation
	if not anim: return
	
	var modified = false
	for i in range(anim.get_track_count()):
		var track_path = str(anim.track_get_path(i))
		if track_path.begins_with("Skeleton3D:"):
			var mix_bone = track_path.replace("Skeleton3D:", "")
			if mixamo_to_godot.has(mix_bone):
				var hum_bone = mixamo_to_godot[mix_bone]
				anim.track_set_path(i, NodePath("%GeneralSkeleton:" + hum_bone))
				modified = true
				
	if modified:
		ResourceSaver.save(anim, path)
		print("Fixed bones in: ", path)
