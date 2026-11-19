extends Node3D
## Thumb direction (perpendicular to the forearm, world-up component) through the slide, game vs CMU source.
const Actor = preload("res://scripts/court/court_actor.gd")
const Tap = preload("res://tests/court_joint_tap.gd")
const R = preload("res://scripts/court/mocap_retarget.gd")
var _tu: Dictionary = {"L": [], "R": []}

func _up(axis_from: Vector3, axis_to: Vector3, thumb_from: Vector3, thumb_to: Vector3) -> float:
	var axis: Vector3 = (axis_to - axis_from).normalized()
	var th: Vector3 = thumb_to - thumb_from
	var perp: Vector3 = th - axis * th.dot(axis)
	return perp.normalized().y if perp.length() > 1e-6 else 0.0

func final_pose(sk: Skeleton3D) -> void:
	for side in ["L", "R"]:
		var s: String = "Left" if side == "L" else "Right"
		var lo := sk.get_bone_global_pose(sk.find_bone(s + "LowerArm")).origin
		var ha := sk.get_bone_global_pose(sk.find_bone(s + "Hand")).origin
		var th := sk.get_bone_global_pose(sk.find_bone("Thumb1." + side)).origin
		_tu[side].append(_up(lo, ha, ha, th))

func _stats(a: Array) -> String:
	var down := 0
	var sum := 0.0
	for v in a:
		sum += v
		if v < 0.0: down += 1
	return "mean %+.2f  thumb-down frames %d%%" % [sum / maxf(a.size(), 1), 100 * down / maxi(a.size(), 1)]

func _ready() -> void:
	var a = Actor.new()
	add_child(a)
	a.setup("", {}, 0, 0.0)
	a.set("team", 1)
	var sk: Skeleton3D = a.get("_skeleton")
	var tap: SkeletonModifier3D = Tap.new()
	tap.qa = self
	sk.add_child(tap)
	for stage in ["idle","clap","recovery","walk","run"]:
		if stage == "clap": a.action("Clap", 1.6)
		for i in (72 if stage == "clap" else 120):
			a.pose_reset()
			var speed := 1.0 if stage == "walk" else (3.9 if stage == "run" else 0.0)
			a.lock_face(a.position + Vector3.FORWARD * 8.0)
			a.move_with(Vector3.FORWARD * speed,1.0/60.0)
			a.animate(1.0/60.0)
			await get_tree().process_frame
			if i == 30 and stage != "clap":
				_tu["L"].clear()
				_tu["R"].clear()
		print(stage, " L ",_stats(_tu["L"]), " R ",_stats(_tu["R"]), " override ",a._elbow_hinge.clap_forward)
		_tu["L"].clear()
		_tu["R"].clear()
	get_tree().quit()
