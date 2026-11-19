extends Node3D
## Defender arm motion: the game's AI defender in each defensive gait vs the CMU recordings.
## Wrist and elbow in the player's own frame (right, up, forward), in arm lengths, relative to the shoulder midpoint.
const Actor = preload("res://scripts/court/court_actor.gd")
const Tap = preload("res://tests/court_joint_tap.gd")
const R = preload("res://scripts/court/mocap_retarget.gd")
const UPV := Vector3.UP
var _frames: Array = []   # per frame: {joint: Vector3 in skeleton/world space}
var _yaw: float = 0.0
var _scale: float = 1.0

func final_pose(sk: Skeleton3D) -> void:
	var row: Dictionary = {}
	for j in ["LeftShoulder", "RightShoulder", "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand", "Hips", "Head"]:
		row[j] = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(j)).origin
	row["yaw"] = _yaw
	_frames.append(row)

func _stats(label: String, rows: Array, arm: float) -> void:
	var out: PackedStringArray = []
	for side in ["Left", "Right"]:
		var w: Array = []
		var e: Array = []
		for r in rows:
			var fwd: Vector3 = Vector3(sin(r["yaw"]), 0, cos(r["yaw"]))
			var right: Vector3 = fwd.cross(UPV)
			var mid: Vector3 = (r["LeftShoulder"] + r["RightShoulder"]) * 0.5
			for pair in [["Hand", w], ["LowerArm", e]]:
				var rel: Vector3 = r[side + pair[0]] - mid
				pair[1].append(Vector3(rel.dot(right), rel.y, rel.dot(fwd)) / arm)
		var mean := Vector3.ZERO
		for v in w: mean += v
		mean /= w.size()
		var sd := Vector3.ZERO
		for v in w: sd += Vector3((v.x - mean.x) ** 2, (v.y - mean.y) ** 2, (v.z - mean.z) ** 2)
		sd = Vector3(sqrt(sd.x / w.size()), sqrt(sd.y / w.size()), sqrt(sd.z / w.size()))
		var travel := 0.0
		var path := 0.0
		for i in range(1, w.size()):
			path += (w[i] - w[i - 1]).length()
		for a in w:
			for b in w:
				travel = maxf(travel, (a - b).length())
		var emean := Vector3.ZERO
		for v in e: emean += v
		emean /= e.size()
		out.append("%s wrist mean(r,u,f) %+.2f %+.2f %+.2f sd %.2f %.2f %.2f reach-span %.2f | elbow mean %+.2f %+.2f %+.2f" % [side[0], mean.x, mean.y, mean.z, sd.x, sd.y, sd.z, travel, emean.x, emean.y, emean.z])
	var lean := 0.0
	for r in rows:
		var f2: Vector3 = Vector3(sin(r["yaw"]), 0, cos(r["yaw"]))
		var d2: Vector3 = r["Head"] - r["Hips"]
		lean += rad_to_deg(atan2(d2.dot(f2), d2.y))
	out.append("torso lean fwd(+)/back(-) %+.1f deg" % (lean / maxf(rows.size(), 1)))
	print("DEF %-14s %s" % [label, "\n    ".join(out)])

func _game(label: String, vel: Vector3, team: int, secs: float) -> void:
	var a = Actor.new()
	add_child(a)
	a.setup("", {}, 0, 0.0)
	var sk: Skeleton3D = a.get("_skeleton")
	var tap: SkeletonModifier3D = Tap.new()
	tap.qa = self
	sk.add_child(tap)
	var arm: float = 0.0
	_frames = []
	var n: int = int(secs * 60)
	for i in n:
		a.call("pose_reset")
		a.set("team", team)
		if team == 1:
			a.call("lock_face", a.position + Vector3(0, 0, -8.0))
		a.call("move_with", vel, 1.0 / 60.0, 16.0)
		_yaw = (a.get("_model") as Node3D).rotation.y
		a.call("animate", 1.0 / 60.0)
		await get_tree().process_frame
		if i == 20:
			var sc: float = sk.global_transform.basis.get_scale().x
			arm = ((sk.get_bone_global_rest(sk.find_bone("LeftLowerArm")).origin - sk.get_bone_global_rest(sk.find_bone("LeftUpperArm")).origin).length() + (sk.get_bone_global_rest(sk.find_bone("LeftHand")).origin - sk.get_bone_global_rest(sk.find_bone("LeftLowerArm")).origin).length()) * sc
		if i < 60:
			_frames.pop_back() if i >= 0 and _frames.size() > 0 else null
	_stats("GAME " + label + " [" + str(a.get("_gait")) + "]", _frames, arm)
	a.queue_free()
	await get_tree().process_frame

func _cmu(label: String, path: String) -> void:
	var src: Node = (load(path) as PackedScene).instantiate()
	var csk: Skeleton3D = CourtPlayerModel.find_skeleton(src)
	var ap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
	var nm: String = ""
	for n in ap.get_animation_list():
		if str(n) != "RESET" and not str(n).ends_with("_001"):
			nm = str(n)
	var anim: Animation = ap.get_animation(nm)
	var tr: Dictionary = R._tracks_by_bone(anim)
	var rest: Array = R._global_rests(csk)
	var arm: float = ((rest[csk.find_bone("LeftLowerArm")] as Transform3D).origin.distance_to((rest[csk.find_bone("LeftUpperArm")] as Transform3D).origin) + (rest[csk.find_bone("LeftHand")] as Transform3D).origin.distance_to((rest[csk.find_bone("LeftLowerArm")] as Transform3D).origin))
	var rows: Array = []
	var steps: int = int(anim.length * 30)
	for f in steps:
		var g: Array = R._pose_globals(csk, anim, tr, anim.length * f / steps)
		var row: Dictionary = {}
		for j in ["LeftShoulder", "RightShoulder", "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand", "Hips", "Head"]:
			row[j] = (g[csk.find_bone(j)] as Transform3D).origin
		# facing from the hip line: left x up = forward
		var lat: Vector3 = (g[csk.find_bone("LeftUpperLeg")] as Transform3D).origin - (g[csk.find_bone("RightUpperLeg")] as Transform3D).origin
		lat.y = 0.0
		var fwd: Vector3 = lat.normalized().cross(UPV)
		row["yaw"] = atan2(fwd.x, fwd.z)
		rows.append(row)
	_stats("CMU  " + label + " (" + nm + ", %.1fs)" % anim.length, rows, arm)
	src.free()

func _ready() -> void:
	await _game("stance idle", Vector3.ZERO, 1, 4.0)
	await _game("slide R", Vector3(2.63, 0, 0), 1, 4.0)
	await _game("slide L", Vector3(-2.24, 0, 0), 1, 4.0)
	await _game("backpedal", Vector3(0, 0, 1.22), 1, 4.0)
	_cmu("slide_r", "res://assets/court/slide_r.glb")
	_cmu("slide_l", "res://assets/court/slide_l.glb")
	_cmu("backpedal", "res://assets/court/backpedal.glb")
	for t in range(22, 30):
		_cmu("102_%d" % t, "res://assets/court/defense_102_%d.glb" % t)
	get_tree().quit(0)
