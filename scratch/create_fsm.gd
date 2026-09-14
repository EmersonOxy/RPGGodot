extends SceneTree

func _init() -> void:
	var sm = AnimationNodeStateMachine.new()
	
	# UNARMED STATES
	_add_state(sm, "Idle", "player_unarmed_idle")
	_add_state(sm, "Walk", "player_unarmed_walk")
	_add_state(sm, "Run", "player_unarmed_run")
	_add_state(sm, "UnarmedDeath", "player_unarmed_death")
	
	# Let's just create individual nodes in the FSM and have player_visual.gd choose them.
	_add_state(sm, "UnarmedAttack1", "player_unarmed_attack_1")
	_add_state(sm, "UnarmedAttack2", "player_unarmed_attack_2")
	_add_state(sm, "UnarmedAttack3", "player_unarmed_attack_3")
	
	_add_state(sm, "UnarmedHit1", "player_unarmed_hit_1")
	_add_state(sm, "UnarmedHit2", "player_unarmed_hit_2")
	_add_state(sm, "UnarmedHit3", "player_unarmed_hit_3")
	_add_state(sm, "UnarmedHit4", "player_unarmed_hit_4")
	
	# ARMED STATES
	_add_state(sm, "ArmedIdle", "player_armed_idle")
	_add_state(sm, "ArmedWalk", "player_armed_walk")
	_add_state(sm, "ArmedRun", "player_armed_run")
	_add_state(sm, "ArmedAttack", "player_armed_attack")
	
	_add_state(sm, "ArmedIdleLong1", "player_armed_idle_long_1")
	_add_state(sm, "ArmedIdleLong2", "player_armed_idle_long_2")
	
	_add_state(sm, "ArmedHit1", "player_armed_hit_1")
	_add_state(sm, "ArmedHit2", "player_armed_hit_2")
	
	_add_state(sm, "ArmedDeath1", "player_armed_death_1")
	_add_state(sm, "ArmedDeath2", "player_armed_death_2")
	
	# TRANSITIONS
	_add_state(sm, "Draw1", "player_draw_1")
	_add_state(sm, "Draw2", "player_draw_2")
	_add_state(sm, "Sheathe1", "player_sheathe_1")
	_add_state(sm, "Sheathe2", "player_sheathe_2")
	
	# We just need to define transitions that return to Idle/ArmedIdle automatically for things like Hit, Attack, Draw, Sheathe.
	var auto_return = ["UnarmedAttack1", "UnarmedAttack2", "UnarmedAttack3", "UnarmedHit1", "UnarmedHit2", "UnarmedHit3", "UnarmedHit4", "Sheathe1", "Sheathe2"]
	for a in auto_return:
		var tr = AnimationNodeStateMachineTransition.new()
		tr.xfade_time = 0.15
		tr.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
		tr.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
		sm.add_transition(a, "Idle", tr)
		
	var armed_auto_return = ["ArmedAttack", "ArmedHit1", "ArmedHit2", "Draw1", "Draw2", "ArmedIdleLong1", "ArmedIdleLong2"]
	for a in armed_auto_return:
		var tr = AnimationNodeStateMachineTransition.new()
		tr.xfade_time = 0.15
		tr.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
		tr.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
		sm.add_transition(a, "ArmedIdle", tr)
		
	ResourceSaver.save(sm, "res://player_animation_state_machine.tres")
	print("FSM recreated!")
	quit()

func _add_state(sm: AnimationNodeStateMachine, state_name: String, anim_name: String):
	var bt = AnimationNodeBlendTree.new()
	var anim_node = AnimationNodeAnimation.new()
	anim_node.animation = anim_name
	var ts_node = AnimationNodeTimeScale.new()
	bt.add_node("Clip", anim_node)
	bt.add_node("Speed", ts_node)
	bt.connect_node("Speed", 0, "Clip")
	bt.connect_node("output", 0, "Speed")
	sm.add_node(state_name, bt)
