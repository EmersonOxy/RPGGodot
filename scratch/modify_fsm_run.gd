extends SceneTree

func _init() -> void:
	var path = "res://player_animation_state_machine.tres"
	var sm = ResourceLoader.load(path) as AnimationNodeStateMachine
	if not sm:
		quit()
		return
		
	_add_state(sm, "ArmedRun", "character/ArmedRun", Vector2(400, 260))
	_add_state(sm, "Run", "character/Run", Vector2(400, -100))
	_add_state(sm, "ArmedHit", "character/ArmedHit", Vector2(800, 150))
	
	# Transitions for Run
	_add_transition(sm, "Walk", "Run", &"running", false)
	_add_transition(sm, "Run", "Walk", &"running", true)
	_add_transition(sm, "Run", "Idle", &"moving", true)
	
	# Transitions for ArmedRun
	_add_transition(sm, "ArmedWalk", "ArmedRun", &"running", false)
	_add_transition(sm, "ArmedRun", "ArmedWalk", &"running", true)
	_add_transition(sm, "ArmedRun", "ArmedIdle", &"moving", true)
	
	# Hit transitions
	_add_transition(sm, "ArmedIdle", "ArmedHit", &"hit", false)
	_add_transition(sm, "ArmedWalk", "ArmedHit", &"hit", false)
	_add_transition(sm, "ArmedRun", "ArmedHit", &"hit", false)
	
	# At the end of Hit, return to Idle automatically
	var tr = AnimationNodeStateMachineTransition.new()
	tr.xfade_time = 0.15
	tr.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	tr.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	sm.add_transition("ArmedHit", "ArmedIdle", tr)
	
	ResourceSaver.save(sm, path)
	print("Added Run and Hit to FSM!")
	
	quit()

func _add_state(sm: AnimationNodeStateMachine, state_name: String, anim_name: String, pos: Vector2):
	if sm.has_node(state_name): return
	var bt = AnimationNodeBlendTree.new()
	var anim_node = AnimationNodeAnimation.new()
	anim_node.animation = anim_name
	var ts_node = AnimationNodeTimeScale.new()
	bt.add_node("Clip", anim_node)
	bt.add_node("Speed", ts_node)
	bt.connect_node("Speed", 0, "Clip")
	bt.connect_node("output", 0, "Speed")
	sm.add_node(state_name, bt, pos)

func _add_transition(sm: AnimationNodeStateMachine, from: String, to: String, condition: StringName, invert: bool):
	var tr = AnimationNodeStateMachineTransition.new()
	tr.xfade_time = 0.15
	tr.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	var cond = condition
	if invert: cond = str("not_", condition) # Custom inverted conditions are not native, so we just use advance_expression or check the inverted condition natively. Wait!
	
	# Godot 4 doesn't have native NOT conditions in the UI, we just check the value
	tr.advance_condition = condition
	
	# Actually, the user's current tree uses specific conditions like "moving" and "stopped".
	if invert and condition == &"running":
		tr.advance_condition = &"walking" # We'll set walking = not running
	elif invert and condition == &"moving":
		tr.advance_condition = &"stopped"
		
	sm.add_transition(from, to, tr)
