extends Node3D
## Per-frame leg trace through the right slide: thigh and shin angles and foot offset for both legs,
## in the actor's own frame (x = character's right, y = up, -z = facing).
const Actor = preload("res://scripts/court/court_actor.gd")

func _ready() -> void:
	var a = Actor.new()
	add_child(a)
	a.setup("", {"Shirt": Color(0.8, 0.15, 0.2), "Pants": Color(1, 1, 1), "Skin": Color(0.48, 0.34, 0.24), "Socks": Color(0.95, 0.95, 0.95)}, 0, 0.0)
	a.set("team", 1)
	var sk: Skeleton3D = a.find_children("*", "Skeleton3D", true, false)[0]
	var names: Dictionary = {}
	names["Hips"] = sk.find_bone("Hips")
	for side in ["Left", "Right"]:
		for b in ["UpperLeg", "LowerLeg", "Foot"]:
			names[side + b] = sk.find_bone(side + b)
	print("bones ", names)
	for side in ["L", "R"]:
		var c: int = sk.find_bone("Foot." + side)
		var an: int = sk.find_bone(("Left" if side == "L" else "Right") + "Foot")
		var d: Vector3 = sk.get_bone_global_rest(c).origin - sk.get_bone_global_rest(an).origin
		print("REST ctrl-ankle %s  xz %.3f  full %.3f" % [side, Vector2(d.x, d.z).length(), d.length()])
	for i in 300:
		a.call("pose_reset")
		a.set("team", 1)
		a.call("lock_face", a.position + Vector3(0, 0, -8.0))
		a.call("move_with", Vector3(2.63, 0, 0), 1.0 / 60.0, 16.0)
		a.call("animate", 1.0 / 60.0)
		await get_tree().process_frame
		if i < 120 or (i - 120) % 15 != 0:
			continue
		var inv: Basis = a.global_transform.basis.inverse()
		var line: String = "f%03d" % i
		for side in ["Left", "Right"]:
			var th: Vector3 = _pos(sk, names[side + "UpperLeg"], inv, a.global_position)
			var kn: Vector3 = _pos(sk, names[side + "LowerLeg"], inv, a.global_position)
			var ft: Vector3 = _pos(sk, names[side + "Foot"], inv, a.global_position)
			var hp: Vector3 = _pos(sk, names["Hips"], inv, a.global_position)
			var thigh_dir: Vector3 = (kn - th).normalized()
			var shin_dir: Vector3 = (ft - kn).normalized()
			var tilt: float = rad_to_deg(acos(clampf(thigh_dir.dot(Vector3.DOWN), -1.0, 1.0)))
			var knee: float = rad_to_deg(acos(clampf(thigh_dir.dot(-shin_dir), -1.0, 1.0)))
			var foot_x: float = ft.x - hp.x
			var foot_z: float = ft.z - hp.z
			var ctrl: int = sk.find_bone("Foot." + side[0])
			var shoe_off: Vector3 = _pos(sk, ctrl, inv, a.global_position) - ft if ctrl >= 0 else Vector3.ZERO
			line += "  %s thigh %5.1f knee %5.1f foot(x %+.2f z %+.2f y %.2f) shoe-ankle(x %+.3f y %+.3f z %+.3f)" % [side[0], tilt, knee, foot_x, foot_z, ft.y, shoe_off.x, shoe_off.y, shoe_off.z]
		print(line + "  ctrlY R %.3f L %.3f" % [_pos(sk, sk.find_bone("Foot.R"), inv, a.global_position).y, _pos(sk, sk.find_bone("Foot.L"), inv, a.global_position).y])
	get_tree().quit(0)

func _pos(sk: Skeleton3D, i: int, inv: Basis, origin: Vector3) -> Vector3:
	return inv * (sk.global_transform * sk.get_bone_global_pose(i).origin - origin)
