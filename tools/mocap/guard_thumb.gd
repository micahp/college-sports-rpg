extends Node3D
## Thumb direction (world-up component of the thumb perpendicular to the forearm) for a defender in the
## held-ball guard pose, measured from the final drawn pose, plus the CMU defenders for reference.
const Actor = preload("res://scripts/court/court_actor.gd")
const Tap = preload("res://tests/court_joint_tap.gd")
var cfgs: Array = []
var cfg_i: int = 0
var _rows: Dictionary = {"L": [], "R": []}

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
		_rows[side].append(_up(lo, ha, ha, th))

func _ready() -> void:
	for up in [-0.45, -0.3, -0.15]:
		for inn in [0.5, 0.75, 1.0]:
			cfgs.append(Vector3(up, inn, 0.0))
	for c: Vector3 in cfgs:
		await _one(c)
	get_tree().quit(0)

func _one(c: Vector3) -> void:
	_rows = {"L": [], "R": []}
	var a = Actor.new()
	add_child(a)
	a.setup("", {}, 0, 0.0)
	var d = Actor.new()
	add_child(d)
	d.setup("", {}, 0, 0.0)
	d.position = Vector3(0, 0, -0.9)
	var sk: Skeleton3D = d.get("_skeleton")
	var tap: SkeletonModifier3D = Tap.new()
	tap.qa = self
	sk.add_child(tap)
	for i in 120:
		a.call("pose_reset")
		a.call("animate", 1.0 / 60.0)
		d.set("team", 1)
		d.call("pose_reset")
		d.call("lock_face", a.position)
		var shade := 0.0
		for side in ["L", "R"]:
			var lateral := 1.0 if side == "R" else -1.0
			var near_ball := (1.0 + lateral * shade) * 0.5
			var palm: Vector3 = d.body_point(0.34 + 0.06 * near_ball, lateral * (0.30 - 0.06 * near_ball), 0.98 + 0.05 * near_ball)
			d.call("hand", side, palm - d.facing() * 0.08, 1.0)
			var sg: float = lateral
			d.call("palm_on", side, palm, palm + d.facing() - Vector3.UP * 0.3 - d.right() * sg * 0.5, 1.0)
		d.set("guard_elbow", true)
		d.call("animate", 1.0 / 60.0)
		await get_tree().process_frame
		if i < 40:
			_rows["L"].clear(); _rows["R"].clear()
	var l: float = 0.0; var r: float = 0.0
	for v in _rows["L"]: l += v
	for v in _rows["R"]: r += v
	print("GUARD up %+.1f in %.1f  thumb-up L %+.2f R %+.2f" % [c.x, c.y, l / maxf(_rows["L"].size(), 1), r / maxf(_rows["R"].size(), 1)])
	a.queue_free()
	d.queue_free()
	await get_tree().process_frame
