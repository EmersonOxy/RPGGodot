extends SceneTree

func _init() -> void:
	var path = "res://player_animation_state_machine.tres"
	var sm = ResourceLoader.load(path) as AnimationNodeStateMachine
	if not sm:
		quit()
		return
		
	# Create BlendTree for UnarmedAttack
	var bt = AnimationNodeBlendTree.new()
	var anim_node = AnimationNodeAnimation.new()
	anim_node.animation = &"character/UnarmedAttack"
	var ts_node = AnimationNodeTimeScale.new()
	
	bt.add_node("Clip", anim_node)
	bt.add_node("Speed", ts_node)
	bt.connect_node("Speed", 0, "Clip")
	bt.connect_node("output", 0, "Speed")
	
	if not sm.has_node("UnarmedAttack"):
		sm.add_node("UnarmedAttack", bt, Vector2(620, -50))
		
		# Add transitions
		var tr1 = AnimationNodeStateMachineTransition.new()
		tr1.xfade_time = 0.15
		sm.add_transition("Idle", "UnarmedAttack", tr1)
		
		var tr2 = AnimationNodeStateMachineTransition.new()
		tr2.xfade_time = 0.15
		sm.add_transition("Walk", "UnarmedAttack", tr2)
		
		var tr3 = AnimationNodeStateMachineTransition.new()
		tr3.xfade_time = 0.15
		tr3.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
		tr3.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
		tr3.advance_condition = &"stopped"
		sm.add_transition("UnarmedAttack", "Idle", tr3)
		
		var tr4 = AnimationNodeStateMachineTransition.new()
		tr4.xfade_time = 0.15
		tr4.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
		tr4.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
		tr4.advance_condition = &"moving"
		sm.add_transition("UnarmedAttack", "Walk", tr4)
		
		ResourceSaver.save(sm, path)
		print("Added UnarmedAttack to FSM!")
	
	quit()
