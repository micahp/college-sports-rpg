extends Node3D
## Game-side thumb roll through the slide with one skeleton modifier removed per run.
const Actor = preload("res://scripts/court/court_actor.gd")
const Tap = preload("res://tests/court_joint_tap.gd")
var _tu: Dictionary = {"L": [], "R": []}

func _up(af: Vector3, at: Vector3, tf: Vector3, tt: Vector3) -> float:
	var axis: Vector3 = (at - af).normalized()
	var th: Vector3 = tt - tf
	var perp: Vector3 = th - axis * th.dot(axis)
	return perp.normalized().y if perp.length() > 1e-6 else 0.0

func final_pose(sk: Skeleton3D) -> void:
	for side in ["L", "R"]:
		var s: String = "Left" if side == "L" else "Right"
		var lo := sk.get_bone_global_pose(sk.find_bone(s + "LowerArm")).origin
		var ha := sk.get_bone_global_pose(sk.find_bone(s + "Hand")).origin
		var th := sk.get_bone_global_pose(sk.find_bone("Thumb1." + side)).origin
		_tu[side].append(_up(lo, ha, ha, th))

func _mean(a: Array) -> float:
	var s := 0.0
	for v in a: s += v
	return s / maxf(a.size(), 1)

func _name(c: Node) -> String:
	return str(c.get_script().resource_path.get_file().get_basename()) if c.get_script() != null else str(c.get_class())

func _ready() -> void:
	var cfgs: Array = []
	for out in [0.5, 0.8]:
		for up in [-0.1, 0.1, 0.2, 0.3]:
			for back in [0.3, 0.6, 0.9]:
				cfgs.append(Vector3(out, up, back))
	for cfg: Vector3 in cfgs:
		var a = Actor.new()
		add_child(a)
		a.setup("", {}, 0, 0.0)
		a.set("team", 1)
		a.set("elbow_dbg", cfg)
		var sk: Skeleton3D = a.get("_skeleton")
		var tap: SkeletonModifier3D = Tap.new()
		tap.qa = self
		sk.add_child(tap)
		_tu = {"L": [], "R": []}
		for i in 130:
			a.call("pose_reset")
			a.set("team", 1)
			a.call("lock_face", a.position + Vector3(0, 0, -8.0))
			a.call("move_with", Vector3(2.63, 0, 0), 1.0 / 60.0, 16.0)
			a.call("animate", 1.0 / 60.0)
			await get_tree().process_frame
			if i < 60:
				_tu["L"].clear(); _tu["R"].clear()
		print("TB out %.2f up %+.1f back %.1f   L %+.2f  R %+.2f" % [cfg.x, cfg.y, cfg.z, _mean(_tu["L"]), _mean(_tu["R"])])
		a.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)
