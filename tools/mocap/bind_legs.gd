extends SceneTree
func _init() -> void:
	var n: Node = (load("res://assets/court/students/Male_Casual.fbx") as PackedScene).instantiate()
	var sk: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = n.find_children("*", "MeshInstance3D", true, false)[0]
	var skin: Skin = mi.skin
	for i in skin.get_bind_count():
		var nm: String = skin.get_bind_name(i)
		var bi: int = skin.get_bind_bone(i)
		if nm == "" and bi >= 0:
			nm = sk.get_bone_name(bi)
		if nm in ["UpperLegL", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "Hips"]:
			var bind_world: Vector3 = skin.get_bind_pose(i).affine_inverse().origin
			var rest_world: Vector3 = sk.get_bone_global_rest(sk.find_bone(nm)).origin
			print("BIND %-14s bind %s  rest %s  gap %.3f" % [nm, bind_world.snapped(Vector3.ONE * 0.001), rest_world.snapped(Vector3.ONE * 0.001), bind_world.distance_to(rest_world)])
	n.free()
	quit(0)
