extends SceneTree
func _init() -> void:
	var n: Node = (load("res://assets/court/students/Male_Casual.fbx") as PackedScene).instantiate()
	var sk: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = n.find_children("*", "MeshInstance3D", true, false)[0]
	var skin: Skin = mi.skin
	var bind_of: Dictionary = {}
	for i in skin.get_bind_count():
		var nm: String = skin.get_bind_name(i)
		var bi: int = skin.get_bind_bone(i)
		if nm == "" and bi >= 0:
			nm = sk.get_bone_name(bi)
		bind_of[nm] = skin.get_bind_pose(i).affine_inverse().origin
	for side in ["Left", "Right"]:
		for b in ["UpperLeg", "LowerLeg", "Foot"]:
			var nm: String = side + b
			var i: int = sk.find_bone(nm)
			if i < 0:
				print("MISSING ", nm)
				continue
			var r: Vector3 = sk.get_bone_global_rest(i).origin
			var bd: Vector3 = bind_of.get(nm, Vector3.INF)
			print("%-14s rest %s  bind %s" % [nm, r.snapped(Vector3.ONE * 0.001), bd.snapped(Vector3.ONE * 0.001)])
	var h: int = sk.find_bone("Hips")
	print("Hips rest ", sk.get_bone_global_rest(h).origin.snapped(Vector3.ONE * 0.001), " bind ", bind_of.get("Hips", Vector3.INF).snapped(Vector3.ONE * 0.001))
	n.free()
	quit(0)
