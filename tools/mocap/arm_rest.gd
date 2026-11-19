extends Node3D
const Actor = preload("res://scripts/court/court_actor.gd")

func _bend(sk: Skeleton3D, side: String, use_pose: bool) -> float:
	var f := func(n: String) -> Vector3:
		return (sk.get_bone_global_pose(sk.find_bone(n)) if use_pose else Transform3D(sk.get_bone_global_rest(sk.find_bone(n)))).origin
	var sh: Vector3 = f.call(side + "UpperArm")
	var el: Vector3 = f.call(side + "LowerArm")
	var wr: Vector3 = f.call(side + "Hand")
	var ua := (el - sh).normalized()
	var fa := (wr - el).normalized()
	return rad_to_deg(acos(clampf(-ua.dot(fa), -1.0, 1.0)))

func _ready() -> void:
	var a = Actor.new()
	add_child(a)
	a.setup("", {}, 0, 0.0)
	await get_tree().process_frame
	var sk: Skeleton3D = a.get("_skeleton")
	print("REST bend L %.1f R %.1f" % [_bend(sk, "Left", false), _bend(sk, "Right", false)])
	for i in 30:
		a.call("pose_reset")
		a.call("animate", 1.0 / 60.0)
		await get_tree().process_frame
	print("IDLE pose bend L %.1f R %.1f" % [_bend(sk, "Left", true), _bend(sk, "Right", true)])
	var fl := sk.get_bone_global_rest(sk.find_bone("LeftLowerArm")).basis.get_euler()
	var fr := sk.get_bone_global_rest(sk.find_bone("RightLowerArm")).basis.get_euler()
	print("REST lower-arm euler L %s R %s" % [fl * 57.3, fr * 57.3])
	get_tree().quit(0)
