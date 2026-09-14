extends SceneTree

func _init() -> void:
	var scene = ResourceLoader.load("res://player_visual.tscn") as PackedScene
	if not scene:
		print("Cannot load scene")
		quit()
		return
	
	var inst = scene.instantiate()
	
	# Check if GeneralSkeleton has unique_name_in_owner
	var skels = inst.find_children("*", "Skeleton3D", true, false)
	if skels.size() > 0:
		var skel = skels[0]
		print("unique_name_in_owner: ", skel.unique_name_in_owner)
		
	# Check AnimationPlayer
	var aps = inst.find_children("*", "AnimationPlayer", true, false)
	if aps.size() > 0:
		var ap = aps[0]
		print("AP libraries: ", ap.get_animation_library_list())
		for lib_name in ap.get_animation_library_list():
			var lib = ap.get_animation_library(lib_name)
			var anims = lib.get_animation_list()
			print("  Library '", lib_name, "' has ", anims.size(), " animations")
			for a in anims:
				print("    - ", a)
	
	# Check AnimationTree
	var ats = inst.find_children("*", "AnimationTree", true, false)
	if ats.size() > 0:
		var at = ats[0]
		print("AnimationTree active: ", at.active)
		print("AnimationTree root_node: ", at.root_node)
		print("AnimationTree anim_player: ", at.anim_player)
		
		# Check the tree root 
		var tree_root = at.tree_root
		if tree_root is AnimationNodeStateMachine:
			var sm = tree_root as AnimationNodeStateMachine
			# Check first state's animation name
			# Get node list not available easily. Let's check a known node
			var idle_node = sm.get_node("Idle")
			if idle_node:
				print("Idle node type: ", idle_node.get_class())
				if idle_node is AnimationNodeBlendTree:
					var bt = idle_node as AnimationNodeBlendTree
					var clip = bt.get_node("Clip")
					if clip is AnimationNodeAnimation:
						var an = clip as AnimationNodeAnimation
						print("Idle clip animation name: '", an.animation, "'")
						
	inst.queue_free()
	quit()
