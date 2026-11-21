extends Node
## Does the recorded jump shot survive from the CMU file to the drawn player?
## Measures the same pose at the same clip time at four stages:
##   A source:  the CMU clip on its own skeleton (assets/court/jumpshot.glb)
##   B clip:    the retargeted student clip, AnimationPlayer only (no tree, no modifiers)
##   C tree:    in the game (the contested-shot fixture), AnimationTree output,
##              before the first skeleton modifier
##   D drawn:   in the game, after the last skeleton modifier
## Every quantity is in the body's own frame (hip line, up) and lengths are
## divided by leg or arm length, so different skeletons and axes compare.
##   godot --headless --path . res://tests/jumpshot_fidelity.tscn -- [no_torso_posture] [csv=path]
## no_torso_posture: switch that one modifier off (active = false) on the
## shooter, nothing else changed.
const CourtScene: PackedScene = preload("res://scenes/court/court_game.tscn")
const CourtGame = preload("res://scripts/court/court_game.gd")
const SOURCE: String = "res://assets/court/jumpshot.glb"
const SOURCE_ANIM: String = "jumpshot"
const CLIP: String = "JumpShot"
## Clip times reported in the table: the gather, the load (lowest hips), the
## takeoff, the release, the top, the landing and the end.
const MOMENTS: Array = [["gather", 0.40], ["load", 0.60], ["takeoff", 0.72], ["rise", 0.86], ["release", 1.00], ["fall", 1.15], ["landing", 1.32], ["recover", 1.45]]


## Pose metrics from one skeleton (world space), comparable across rigs.
class Rig:
	var sk: Skeleton3D
	var ids: Dictionary = {}
	var front_rest: Dictionary = {}  # bone -> the body's front in that bone's rest frame
	var palm_rest: Dictionary = {}   # hand bone -> palm normal (palm down at rest) in its frame
	var leg: float = 1.0
	var arm: Dictionary = {}

	func _init(s: Skeleton3D) -> void:
		sk = s
		for b in ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand",
				"RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
				"RightUpperLeg", "RightLowerLeg", "RightFoot"]:
			ids[b] = sk.find_bone(b)
		var lat: Vector3 = _rest("LeftUpperLeg").origin - _rest("RightUpperLeg").origin
		lat.y = 0.0
		var fwd: Vector3 = lat.normalized().cross(Vector3.UP).normalized()
		for b in ["Chest", "UpperChest", "Head", "Spine"]:
			if ids[b] >= 0:
				front_rest[b] = _rest(b).basis.orthonormalized().inverse() * fwd
		for b in ["LeftHand", "RightHand"]:
			palm_rest[b] = _rest(b).basis.orthonormalized().inverse() * Vector3.DOWN
		# World units: the skeletons are scaled (the student rig imports ~4.8 m tall).
		var g: Transform3D = sk.global_transform
		leg = (g * _rest("LeftUpperLeg").origin).distance_to(g * _rest("LeftLowerLeg").origin) + (g * _rest("LeftLowerLeg").origin).distance_to(g * _rest("LeftFoot").origin)
		for side in ["Left", "Right"]:
			arm[side] = (g * _rest(side + "UpperArm").origin).distance_to(g * _rest(side + "LowerArm").origin) + (g * _rest(side + "LowerArm").origin).distance_to(g * _rest(side + "Hand").origin)

	func _halfway(pts: Array) -> Vector3:
		var total := 0.0
		for i in range(1, pts.size()):
			total += (pts[i] as Vector3).distance_to(pts[i - 1])
		var left := total * 0.5
		for i in range(1, pts.size()):
			var seg: float = (pts[i] as Vector3).distance_to(pts[i - 1])
			if left <= seg:
				return (pts[i - 1] as Vector3).lerp(pts[i], left / maxf(seg, 1e-6))
			left -= seg
		return pts.back()

	func _rest(b: String) -> Transform3D:
		return sk.get_bone_global_rest(ids[b])

	func p(b: String) -> Vector3:
		return sk.global_transform * sk.get_bone_global_pose(ids[b]).origin

	func basis(b: String) -> Basis:
		return (sk.global_transform.basis * sk.get_bone_global_pose(ids[b]).basis).orthonormalized()

	## Everything for one frame. Read after the skeleton has the pose in it.
	func metrics(hip0: float) -> Dictionary:
		var lat := p("LeftUpperLeg") - p("RightUpperLeg")
		lat.y = 0.0
		lat = lat.normalized()
		var fwd := lat.cross(Vector3.UP).normalized()
		var m := {}
		# The trunk from where the spine leaves the pelvis (the Spine bone: on CMU
		# it sits on the root) to the neck. Not from the hip joints: CMU's sit
		# 10 cm below and in front of its spine root and the student's almost
		# level with it, so pelvis tilt swings that line differently on the two
		# rigs (it made an arched spine read as a correct one).
		var pelvis := (p("LeftUpperLeg") + p("RightUpperLeg")) * 0.5
		var spine := (p("Neck") - p("Spine")).normalized()
		# Spine shape: the lower and upper halves of the spine by length. An arch
		# or a counter-bend shows as the two disagreeing with the recording.
		var pts: Array = []
		for b in ["Spine", "Chest", "UpperChest", "Neck"]:
			if ids.has(b) and ids[b] >= 0 and (pts.is_empty() or p(b).distance_to(pts.back()) > 1e-4):
				pts.append(p(b))
		var mid: Vector3 = _halfway(pts)
		var lower := (mid - (pts[0] as Vector3)).normalized()
		var upper := ((pts.back() as Vector3) - mid).normalized()
		m["spine_lower_pitch"] = rad_to_deg(atan2(lower.dot(fwd), lower.y))
		m["spine_upper_pitch"] = rad_to_deg(atan2(upper.dot(fwd), upper.y))
		m["trunk_pitch"] = rad_to_deg(atan2(spine.dot(fwd), spine.y))
		m["trunk_roll"] = rad_to_deg(atan2(spine.dot(lat), spine.y))
		var neck := (p("Head") - p("Neck")).normalized()
		m["neck_pitch"] = rad_to_deg(atan2(neck.dot(fwd), neck.y))
		for b in ["Chest", "Head"]:
			if front_rest.has(b):
				var f: Vector3 = basis(b) * (front_rest[b] as Vector3)
				m[b.to_lower() + "_pitch"] = rad_to_deg(asin(clampf(-f.y, -1.0, 1.0)))  # facing down = forward bow
				m[b.to_lower() + "_yaw"] = rad_to_deg(atan2(f.dot(-lat), f.dot(fwd)))
		m["hip_y"] = pelvis.y / leg  # in leg lengths; hip_rise is set against the first sample
		m["hip_rise"] = 0.0
		for side in ["Left", "Right"]:
			var s := p(side + "UpperArm")
			var e := p(side + "LowerArm")
			var w := p(side + "Hand")
			var sg: float = 1.0 if side == "Left" else -1.0
			var a: float = arm[side]
			var k: String = side.substr(0, 1)
			var rel: Vector3 = (w - s) / a
			m[k + "_wrist_out"] = rel.dot(lat) * sg
			m[k + "_wrist_fwd"] = rel.dot(fwd)
			m[k + "_wrist_up"] = rel.y
			m[k + "_elbow_flex"] = 180.0 - rad_to_deg((s - e).normalized().angle_to((w - e).normalized()))
			var up_arm: Vector3 = (e - s).normalized()
			var fore: Vector3 = (w - e).normalized()
			# Segment directions: independent of how each rig splits the arm's length.
			m[k + "_upper_up"] = up_arm.y
			m[k + "_upper_fwd"] = up_arm.dot(fwd)
			m[k + "_fore_up"] = fore.y
			m[k + "_fore_fwd"] = fore.dot(fwd)
			m[k + "_shoulder_elev"] = rad_to_deg(up_arm.angle_to(Vector3.DOWN))
			var palm: Vector3 = basis(side + "Hand") * (palm_rest[side + "Hand"] as Vector3)
			m[k + "_palm_fwd"] = palm.dot(fwd)
			m[k + "_palm_up"] = palm.y
			m[k + "_palm_out"] = palm.dot(lat) * sg
			var hip := p(side + "UpperLeg")
			var knee := p(side + "LowerLeg")
			var ankle := p(side + "Foot")
			m[k + "_knee_flex"] = 180.0 - rad_to_deg((hip - knee).normalized().angle_to((ankle - knee).normalized()))
		return m


class Tap extends SkeletonModifier3D:
	var rig: Rig
	var last: Dictionary = {}
	var hip0: float = -1000.0
	var elapsed: float = 0.0  # animation time since `counting` began
	var counting: bool = false
	func _process_modification_with_delta(delta: float) -> void:
		if counting:
			elapsed += delta
		get_skeleton().force_update_all_bone_transforms()
		last = rig.metrics(hip0)


const KEYS: Array = ["trunk_pitch", "trunk_roll", "spine_lower_pitch", "spine_upper_pitch", "neck_pitch", "chest_pitch", "head_pitch", "head_yaw", "hip_rise",
	"R_wrist_out", "R_wrist_fwd", "R_wrist_up", "L_wrist_out", "L_wrist_fwd", "L_wrist_up",
	"R_elbow_flex", "L_elbow_flex", "R_shoulder_elev", "L_shoulder_elev",
	"R_upper_up", "R_upper_fwd", "R_fore_up", "R_fore_fwd", "L_upper_up", "L_upper_fwd", "L_fore_up", "L_fore_fwd",
	"R_palm_fwd", "R_palm_up", "L_palm_fwd", "L_palm_up", "R_knee_flex", "L_knee_flex"]
const ANGLE_TOL: float = 5.0
const RATIO_TOL: float = 0.06  # of leg or arm length (about 5 cm on the arm, 5 cm on the hips)
const UNIT_TOL: float = 0.17   # palm direction components (about 10 deg)


func _tol(key: String) -> float:
	if key.contains("palm") or key.contains("_up") and not key.contains("wrist") or key.contains("_fwd") and not key.contains("wrist"):
		return UNIT_TOL
	if key.contains("wrist") or key == "hip_rise":
		return RATIO_TOL
	return ANGLE_TOL


func _pose_at(ap: AnimationPlayer, rig: Rig, anim: String, t: float, hip0: float) -> Dictionary:
	ap.play(anim)
	ap.seek(t, true)
	ap.advance(0)
	rig.sk.force_update_all_bone_transforms()
	return rig.metrics(hip0)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var no_tp: bool = args.has("no_torso_posture")
	var csv_path := ""
	for a in args:
		if a.begins_with("csv="):
			csv_path = a.substr(4)
	# A: source
	var src: Node3D = (load(SOURCE) as PackedScene).instantiate()
	add_child(src)
	var sap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
	var srig := Rig.new(CourtPlayerModel.find_skeleton(src))
	var s_hip0: float = _pose_at(sap, srig, SOURCE_ANIM, 0.0, -1000.0)["hip_y"]
	# B: retargeted clip on the student, no tree
	var stu: Node3D = CourtPlayerModel.build_student({})
	add_child(stu)
	var bap: AnimationPlayer = stu.get_node("AnimationPlayer")
	var brig := Rig.new(CourtPlayerModel.find_skeleton(stu))
	var b_hip0: float = _pose_at(bap, brig, CLIP, 0.0, -1000.0)["hip_y"]
	# C, D: the game
	GameState.reset()
	GameState.look_id = "look_a"
	CourtGame.auto_play = false
	var court: Node3D = CourtScene.instantiate()
	court.scenario = CourtGame.demo_scenario()
	add_child(court)
	while court._phase != CourtGame.Phase.LIVE:
		await get_tree().physics_frame
	court._catch_grace = 99.0
	var user: Node3D = court._user
	user.position = CourtGame.HOOP_FLAT + Vector3(-2.2, 0, 4.6)
	user.vel = Vector3.ZERO
	var toward: Vector3 = (CourtGame.HOOP_FLAT - user.flat()).normalized()
	var d: Node3D = court._defense[0]
	for o: Node3D in court._defense:
		if o.man == user:
			d = o
	for o: Node3D in court._defense:
		if o != d:
			o.position = Vector3(o.position.x, 0, 4.0)
			o.track = o.position
	d.position = user.flat() + toward * 1.0
	d.track = d.position
	var sk: Skeleton3D = CourtPlayerModel.find_skeleton(user.get("_model"))
	var grig := Rig.new(sk)
	var mods: Array = sk.get_children().filter(func(c): return c is SkeletonModifier3D)
	var tree_tap := Tap.new()
	tree_tap.rig = grig
	sk.add_child(tree_tap)
	sk.move_child(tree_tap, mods[0].get_index())
	var drawn_tap := Tap.new()
	drawn_tap.rig = grig
	sk.add_child(drawn_tap)
	if no_tp:
		(user.get("_torso_posture") as SkeletonModifier3D).active = false
	for i in 40:
		await get_tree().physics_frame
	court._begin_shot()
	var act_node: AnimationNodeAnimation = user.get("_act_node")
	var start: float = act_node.start_offset if act_node.use_custom_timeline else 0.0
	var clip_len: float = (user.get("_anim") as AnimationPlayer).get_animation(CLIP).length
	tree_tap.counting = true
	var rows: Array = []  # [clip_t, A, B, C, D]
	var hip_set := false
	for frame in range(1, 121):
		await get_tree().physics_frame
		if frame == 30:
			court._release_shot()
		await get_tree().process_frame
		var t: float = start + tree_tap.elapsed
		if t > clip_len:
			break
		rows.append([t, _pose_at(sap, srig, SOURCE_ANIM, t, s_hip0), _pose_at(bap, brig, CLIP, t, b_hip0), tree_tap.last.duplicate(), drawn_tap.last.duplicate()])
	for r in rows:
		for si in range(1, 5):
			r[si]["hip_rise"] = float(r[si]["hip_y"]) - float(rows[0][si]["hip_y"])
	print("JUMPSHOT FIDELITY  start %.2f s, clip %.2f s, %d frames, torso_posture %s" % [start, clip_len, rows.size(), "OFF" if no_tp else "on"])
	# Per moment table.
	for key: String in ["trunk_pitch", "trunk_roll", "spine_lower_pitch", "spine_upper_pitch", "chest_pitch", "head_pitch", "hip_rise", "R_upper_up", "R_fore_up", "R_fore_fwd", "R_elbow_flex", "R_shoulder_elev", "R_palm_fwd", "L_fore_up", "L_elbow_flex", "R_knee_flex"]:
		var line := "  %-15s" % key
		for mo in MOMENTS:
			var best: Array = []
			for r in rows:
				if best.is_empty() or absf(r[0] - mo[1]) < absf(best[0] - mo[1]):
					best = r
			if best.is_empty() or absf(best[0] - mo[1]) > 0.05:
				line += " | %-7s      -      " % mo[0]
				continue
			line += " | %-7s %s" % [mo[0], "/".join([best[1], best[2], best[3], best[4]].map(func(m): return ("%.2f" if key.contains("wrist") or key.contains("palm") or key.contains("_up") or key.contains("_fwd") or key == "hip_rise" else "%.0f") % float(m.get(key, 0.0))))]
		print(line)
	print("  (each cell: source / clip / tree / drawn)")
	# Stage-to-stage worst differences over the whole clip.
	var fails: Array = []
	for pair in [[1, 2, "source->clip (retarget)"], [2, 3, "clip->tree (blending)"], [3, 4, "tree->drawn (modifiers)"], [1, 4, "source->drawn (total)"]]:
		var worst: Dictionary = {}
		for r in rows:
			for key: String in KEYS:
				var dv: float = absf(float(r[pair[1]].get(key, 0.0)) - float(r[pair[0]].get(key, 0.0)))
				if not worst.has(key) or dv > worst[key][0]:
					worst[key] = [dv, r[0]]
		var over: Array = []
		for key: String in KEYS:
			if worst.has(key) and float(worst[key][0]) > _tol(key):
				over.append("%s %.2f@%.2fs" % [key, worst[key][0], worst[key][1]])
		print("  %-26s %s" % [pair[2], "within tolerance" if over.is_empty() else ", ".join(over)])
		if pair[0] == 1 and pair[1] == 4:
			fails = over
	if csv_path != "":
		var f := FileAccess.open(csv_path, FileAccess.WRITE)
		f.store_line("t,stage," + ",".join(KEYS))
		for r in rows:
			for si in 4:
				f.store_line("%.4f,%s,%s" % [r[0], ["source", "clip", "tree", "drawn"][si], ",".join(KEYS.map(func(k): return "%.4f" % float(r[si + 1].get(k, 0.0))))])
		f.close()
	get_tree().quit(0)
