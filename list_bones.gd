extends SceneTree
func _init():
    var scene = load("res://player_visual.tscn").instantiate()
    var sk = scene.find_children("*", "Skeleton3D", true, false)[0]
    for i in range(sk.get_bone_count()):
        print(sk.get_bone_name(i))
    quit()
