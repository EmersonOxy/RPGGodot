extends SceneTree

func _init() -> void:
	var a1 = ResourceLoader.load("res://assets/player/player_armed_attack.tres") as Animation
	var a2 = ResourceLoader.load("res://assets/player/player_attack.tres") as Animation
	
	print("ArmedAttack length: ", a1.length if a1 else "null")
	print("UnarmedAttack length: ", a2.length if a2 else "null")
	
	quit()
