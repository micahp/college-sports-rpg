extends SceneTree
func _init() -> void:
	var n: Node = (load("res://assets/court/students/Male_Casual.fbx") as PackedScene).instantiate()
	var sk: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
	var a := sk.get_bone_global_rest(sk.find_bone("LeftUpperLeg")).origin
	var b := sk.get_bone_global_rest(sk.find_bone("LeftLowerLeg")).origin
	var c := sk.get_bone_global_rest(sk.find_bone("LeftFoot")).origin
	print("NOW thigh %.3f shin %.3f" % [a.distance_to(b), b.distance_to(c)])
	n.free()
	quit(0)
