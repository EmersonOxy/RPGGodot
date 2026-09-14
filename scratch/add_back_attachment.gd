extends SceneTree

func _init() -> void:
	var path = "res://player_visual.tscn"
	var scene = ResourceLoader.load(path) as PackedScene
	if not scene:
		quit()
		return
		
	var inst = scene.instantiate()
	var skel = inst.find_child("GeneralSkeleton", true, false)
	if skel:
		var ba = BoneAttachment3D.new()
		ba.name = "BackAttachment"
		ba.bone_name = "Spine"
		skel.add_child(ba)
		ba.owner = inst
		
		var socket = Node3D.new()
		socket.name = "BackSwordSocket"
		# Set an approximate position on the back
		socket.position = Vector3(-0.0, 0.4, -0.2)
		socket.rotation_degrees = Vector3(15, 0, -45)
		ba.add_child(socket)
		socket.owner = inst
		
		var sword = ResourceLoader.load("res://player_sword.tscn").instantiate()
		sword.name = "Sword"
		socket.add_child(sword)
		sword.owner = inst
		
		var new_scene = PackedScene.new()
		new_scene.pack(inst)
		ResourceSaver.save(new_scene, path)
		print("Added BackAttachment to player_visual.tscn")
		
	inst.queue_free()
	quit()
