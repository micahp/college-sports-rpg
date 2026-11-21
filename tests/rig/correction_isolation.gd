extends Node
## Gate 5: automatic corrections, each on its own (docs/animation/RIG_CERTIFICATION.md).
## For every correction the game's modifier chain runs, three experiments:
##   A  valid pose, correction off: the pose is what it should be (the input)
##   B  valid pose, correction on: little or no change (<= KEEP_DEG / KEEP_CM
##      on every body bone and foot control)
##   C  a pose with the defect it exists for, correction on: the defect is
##      fixed and no new one appears
## Valid poses: recorded clip frames whose motion is verified (JumpShot against
## its CMU recording, tests/jumpshot_fidelity), the library Idle, and poses
## built with known anatomical joint angles (rig_fixture.posed). Only the
## correction under test runs (plus, where named, the layer it reads after:
## foot_floor_body reads the shoe controls student_feet places). Its own change
## is measured between the taps before and after it.
## Pose generators (crouch, reach_lean, defender_stride_arms) and pose_tap
## must do nothing at all at their idle setting.
##   godot --headless --fixed-fps 60 --path . res://tests/rig/correction_isolation.tscn [-- fault=rogue]
const F = preload("res://tests/rig/rig_fixture.gd")

const KEEP_DEG: float = 1.0
const KEEP_CM: float = 0.5

var f: F
var poses: Dictionary = {}
var _body: Array = []


## A correction that turns a valid forearm by 3 deg, every frame: the sensitivity fault.
class Rogue extends SkeletonModifier3D:
	func _process_modification_with_delta(_delta: float) -> void:
		var sk := get_skeleton()
		var b := sk.find_bone("RightLowerArm")
		var g := sk.get_bone_global_pose(b)
		sk.set_bone_global_pose(b, Transform3D(Basis(Vector3.UP, deg_to_rad(3.0)) * g.basis, g.origin))


func _ready() -> void:
	f = F.new()
	f.build(self)
	if F.fault() == "rogue":
		var r := Rogue.new()
		r.name = "Rogue"
		f.sk.add_child(r)
		f.sk.move_child(r, f.last.get_index())
		f.mods.append(r)
		var t := F.Tap.new()
		f.sk.add_child(t)
		f.sk.move_child(t, r.get_index() + 1)
		f.taps["Rogue"] = t
	_body = F.all_body() + ["Foot.L", "Foot.R"]
	await f.settle()
	_build_poses()
	print("GATE 5 corrections in isolation: B limit %.1f deg / %.1f cm on every body bone and shoe control" % [KEEP_DEG, KEEP_CM])
	await _generators()
	await _foot_floor()
	await _foot_floor_body()
	await _student_feet()
	await _torso_posture()
	await _arm_clearance()
	await _hand_aim()
	await _elbow_hinge()
	if F.fault() == "rogue":
		await _keeps("Rogue", ["idle", "t_pose", "elbow_90_hinge"])
	await _no_scale()
	print("FAILED_CHECKS: " + ",".join(f.failures))
	f.finish(get_tree(), "GATE 5")


# ------------------------------------------------------------------ poses

func _hinge(side: String) -> Array:
	var up: String = F.ARM[side][1]
	var lo: String = F.ARM[side][2]
	var e0: Vector3 = f.sk.get_bone_global_rest(f.bone(lo)).origin
	var a0: Vector3 = (e0 - f.sk.get_bone_global_rest(f.bone(up)).origin).normalized()
	var f0: Vector3 = (f.sk.get_bone_global_rest(f.bone(F.ARM[side][3])).origin - e0).normalized()
	return [a0.cross((Vector3.BACK - a0 * a0.dot(Vector3.BACK)).normalized()).normalized(), f0]


func _build_poses() -> void:
	var idle := f.clip_pose("Idle", 0.0)
	poses["idle"] = idle
	poses["t_pose"] = f.rest_local.duplicate()
	for t: float in [0.45, 0.75, 1.0, 1.15]:
		poses["jumpshot_%.2f" % t] = f.clip_pose("JumpShot", t)
	# Arms forward (90 deg), elbows bent 90 about their real hinge.
	var ops: Array = []
	var ops_pro: Array = []
	var ops_side: Array = []
	var ops_hyper: Array = []
	var ops_over: Array = []
	var ops_abduct: Array = []
	for side: String in ["L", "R"]:
		var s: float = 1.0 if side == "L" else -1.0
		var up: String = F.ARM[side][1]
		var lo: String = F.ARM[side][2]
		var hf: Array = _hinge(side)
		var fwd := Basis(Vector3.UP, deg_to_rad(-90.0 * s))
		ops += [[up, Vector3.UP, -90.0 * s], [lo, fwd * (hf[0] as Vector3), 90.0]]
		ops_pro += [[up, Vector3.UP, -90.0 * s], [lo, fwd * (hf[0] as Vector3), 90.0], [lo, fwd * (Basis(hf[0], deg_to_rad(90.0)) * (hf[1] as Vector3)), 60.0 * s]]
		ops_side += [[up, Vector3.UP, -90.0 * s], [lo, fwd * (hf[1] as Vector3).cross(hf[0]).normalized(), 30.0]]
		ops_hyper += [[up, Vector3.UP, -90.0 * s], [lo, fwd * (hf[0] as Vector3), -20.0]]
		ops_over += [[up, Vector3.BACK, 80.0 * s]]
		ops_abduct += [[up, Vector3.BACK, -30.0 * s]]
	poses["elbow_90_hinge"] = f.posed(ops)
	poses["elbow_90_pronated_60"] = f.posed(ops_pro)
	poses["elbow_sideways_30"] = f.posed(ops_side)
	poses["elbow_hyperextended_20"] = f.posed(ops_hyper)
	poses["arms_overhead"] = f.posed(ops_over)
	poses["arms_out_60"] = f.posed(ops_abduct)
	poses["lean_15"] = f.posed([["Spine", Vector3.RIGHT, 8.0], ["Chest", Vector3.RIGHT, 7.0]])
	poses["fold_40"] = f.posed([["Spine", Vector3.RIGHT, 20.0], ["Chest", Vector3.RIGHT, 20.0]])
	# Elbows driven into the ribs: arms down, then carried in past the body's side.
	var ops_in: Array = []
	for side: String in ["L", "R"]:
		var s: float = 1.0 if side == "L" else -1.0
		ops_in += [[F.ARM[side][1], Vector3.BACK, -95.0 * s], [F.ARM[side][1], Vector3.UP, 10.0 * s]]
	poses["elbows_in_ribs"] = f.posed(ops_in)
	poses["arms_down"] = f.posed([[F.ARM["L"][1], Vector3.BACK, -75.0], [F.ARM["R"][1], Vector3.BACK, 75.0]])
	var m := f.metres_per_unit()
	poses["idle_sunk_4cm"] = f.shifted(idle, "Hips", Vector3(0, -0.04 / m, 0))
	poses["idle_raised_30cm"] = f.shifted(idle, "Hips", Vector3(0, 0.30 / m, 0))
	poses["knee_lift"] = f.posed([["LeftUpperLeg", "x", 70.0], ["LeftLowerLeg", "x", 80.0]], idle)


## Run `label` (after `pre`) on a pose; its own change: [deg, bone, cm, bone].
func _run(label: String, pose_name: String, pre: Array = []) -> Array:
	f.only(pre + [label])
	f.use(poses[pose_name])
	await f.settle(2)
	var before: F.Tap = f.first
	for p: String in pre:
		before = f.taps[p]
	return f.change(_body, before, f.taps[label])


## B on every listed valid pose.
func _keeps(label: String, valid: Array, pre: Array = []) -> void:
	var worst := [0.0, "", 0.0, ""]
	var at_deg := ""
	var at_cm := ""
	for p: String in valid:
		var c: Array = await _run(label, p, pre)
		print("      %-16s on %-22s %6.2f deg (%s)  %6.2f cm (%s)" % [label, p, c[0], c[1], c[2], c[3]])
		if float(c[0]) > float(worst[0]):
			worst[0] = c[0]
			worst[1] = c[1]
			at_deg = p
		if float(c[2]) > float(worst[2]):
			worst[2] = c[2]
			worst[3] = c[3]
			at_cm = p
	f.check(float(worst[0]) <= KEEP_DEG and float(worst[2]) <= KEEP_CM, label + " leaves valid poses alone",
		"worst %.1f deg (%s, %s) / %.1f cm (%s, %s) over %s" % [worst[0], worst[1], at_deg, worst[2], worst[3], at_cm, valid])


# ------------------------------------------------------------------ generators

func _generators() -> void:
	print("Pose generators at rest (amount 0) and the read-only tap")
	for g: String in ["crouch", "reach_lean", "defender_stride_arms", "pose_tap"]:
		await _keeps(g, ["idle", "jumpshot_1.00"])


# ------------------------------------------------------------------ feet

func _floor_gap(g: Array) -> float:
	# How far the lowest ankle / toe bone is above its resting height (cm); toes if the rig has them.
	var m := f.metres_per_unit()
	var low := INF
	for side: String in ["Left", "Right"]:
		var i := f.bone(side + "Foot")
		low = minf(low, f.world((g[i] as Transform3D).origin).y - float(f.mod("foot_floor").get("ankle_rest")) * m)
	return low * 100.0


func _foot_floor() -> void:
	print("foot_floor: lift a foot the animation leaves under the floor (only raises, at most 6 cm, never pins)")
	await _keeps("foot_floor", ["idle", "idle_raised_30cm", "jumpshot_1.00"])
	var c: Array = await _run("foot_floor", "idle_sunk_4cm")
	var before := _floor_gap(f.first.g)
	var after := _floor_gap(f.taps["foot_floor"].g)
	if f.bone("LeftToes") < 0:
		# The rig's feet are shoe controls; foot contact is tested below
		# (foot_floor_body). foot_floor cannot act here: a candidate for removal.
		f.note("foot_floor is inert", "it needs LeftToes/RightToes, which this rig does not have: a sunk ankle stays %.1f cm under (changed %.1f cm). Foot contact on this rig is foot_floor_body" % [before, c[2]])
	else:
		f.check(after >= -0.3, "foot_floor fixes a sunk foot", "ankle %.1f cm from its resting height before, %.1f cm after" % [before, after])


func _lowest_vertex(g: Array) -> float:
	var mi: MeshInstance3D = CharacterAppearance.find_mesh(f.actor.get("_model"))
	var skin: Skin = mi.skin
	var low := INF
	for s in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per: int = bones.size() / verts.size()
		for v in verts.size():
			var p := Vector3.ZERO
			for k in per:
				var w: float = wts[v * per + k]
				if w <= 0.0:
					continue
				var bi: int = bones[v * per + k]
				p += (g[f.sk.find_bone(skin.get_bind_name(bi))] as Transform3D) * (skin.get_bind_pose(bi) * verts[v]) * w
			low = minf(low, f.world(p).y)
	return low * 100.0


func _foot_floor_body() -> void:
	print("foot_floor_body: raise the whole body so no shoe vertex is under the floor (at most 12 cm); reads the shoes student_feet places")
	await _keeps("foot_floor_body", ["idle", "idle_raised_30cm", "jumpshot_1.00"], ["student_feet"])
	await _run("foot_floor_body", "idle_sunk_4cm", ["student_feet"])
	var before := _lowest_vertex(f.taps["student_feet"].g)
	var after := _lowest_vertex(f.taps["foot_floor_body"].g)
	f.check(after >= -0.3 and after <= 0.5, "foot_floor_body fixes a sunk body", "lowest shoe vertex %.1f cm before, %.1f cm after (wanted on the floor, 0)" % [before, after])


func _student_feet() -> void:
	print("student_feet: the shoe control bone follows its ankle, flat on the floor")
	# B: idempotent. Its own output fed back in must come out unchanged.
	f.only(["student_feet"])
	f.use(poses["idle"])
	await f.settle(2)
	var placed: Dictionary = (poses["idle"] as Dictionary).duplicate()
	for c: String in ["Foot.L", "Foot.R"]:
		var i := f.bone(c)
		var g: Transform3D = f.taps["student_feet"].g[i]
		var par := f.sk.get_bone_parent(i)
		placed[i] = (f.taps["student_feet"].g[par] as Transform3D).affine_inverse() * g
	poses["idle_shoes_placed"] = placed
	await _keeps("student_feet", ["idle_shoes_placed"])
	# The shoe it places, against the shoe the skin was modelled with.
	var mi: MeshInstance3D = CharacterAppearance.find_mesh(f.actor.get("_model"))
	var bind_d: Vector3 = _bind_offset(mi, "Foot.L", "LeftFoot")
	var rest_d: Vector3 = f.sk.get_bone_global_rest(f.bone("Foot.L")).origin - f.sk.get_bone_global_rest(f.bone("LeftFoot")).origin
	var placed_d: Vector3 = (f.taps["student_feet"].g[f.bone("Foot.L")] as Transform3D).origin - (f.taps["student_feet"].g[f.bone("LeftFoot")] as Transform3D).origin
	var m := f.metres_per_unit() * 100.0
	f.note("student_feet shoe offset", "shoe control from the ankle (cm, x left, y up, z front): modelled (bind) %s, rig rest %s, placed %s" % [(bind_d * m).snapped(Vector3.ONE * 0.1), (rest_d * m).snapped(Vector3.ONE * 0.1), (placed_d * m).snapped(Vector3.ONE * 0.1)])
	f.check((placed_d - bind_d).length() * m <= 2.0, "student_feet puts the shoe where it was modelled", "placed %.1f cm from the bind-pose offset" % ((placed_d - bind_d).length() * m))
	# C: the leg lifts; the control left at rest must come with it.
	await _run("student_feet", "knee_lift")
	var ankle: Vector3 = (f.taps["student_feet"].g[f.bone("LeftFoot")] as Transform3D).origin
	var shoe: Vector3 = (f.taps["student_feet"].g[f.bone("Foot.L")] as Transform3D).origin
	var gap: float = ((shoe - ankle) - placed_d).length() * m
	f.check(gap <= 2.0, "student_feet follows a lifted leg", "with the knee lifted the shoe sits %.1f cm from where it sits under a planted ankle" % gap)


func _bind_offset(mi: MeshInstance3D, a: String, b: String) -> Vector3:
	var skin: Skin = mi.skin
	var mesh_to_sk := Transform3D.IDENTITY
	var pa := Transform3D.IDENTITY
	var pb := Transform3D.IDENTITY
	var have_b := false
	for i in skin.get_bind_count():
		var n := str(skin.get_bind_name(i))
		if n == "Spine":
			mesh_to_sk = f.sk.get_bone_global_rest(f.bone("Spine")) * skin.get_bind_pose(i)
		if n == a:
			pa = skin.get_bind_pose(i)
		if n == b:
			pb = skin.get_bind_pose(i)
			have_b = true
	var ja: Vector3 = mesh_to_sk * (pa.affine_inverse() * Vector3.ZERO)
	# The ankle (LeftFoot) has no skin of its own: take it from the shin's bind and its rest offset.
	var jb: Vector3
	if have_b:
		jb = mesh_to_sk * (pb.affine_inverse() * Vector3.ZERO)
	else:
		var shin := f.bone("LeftLowerLeg")
		for i in skin.get_bind_count():
			if str(skin.get_bind_name(i)) == "LeftLowerLeg":
				var shin_bind: Transform3D = mesh_to_sk * skin.get_bind_pose(i).affine_inverse()
				jb = shin_bind * f.sk.get_bone_rest(f.bone(b)).origin
	return ja - jb


# ------------------------------------------------------------------ trunk

func _lean(g: Array) -> float:
	var s: Vector3 = (g[f.bone("Spine")] as Transform3D).origin
	var n: Vector3 = (g[f.bone("Neck")] as Transform3D).origin
	return rad_to_deg((n - s).angle_to(Vector3.UP))


func _torso_posture() -> void:
	print("torso_posture: ease back a trunk folded past 6 deg (keeps 27% of the excess)")
	for p: String in ["t_pose", "lean_15", "jumpshot_0.45", "jumpshot_0.75", "idle"]:
		f.use(poses[p])
		await f.settle(1)
		f.note("trunk lean " + p, "%.1f deg from vertical (Spine to Neck)" % _lean(f.first.g))
	await _keeps("torso_posture", ["t_pose", "lean_15", "jumpshot_0.45", "jumpshot_0.75", "jumpshot_1.00"])
	await _run("torso_posture", "fold_40")
	var before := _lean(f.first.g)
	var after := _lean(f.taps["torso_posture"].g)
	var legs: Array = f.change(F.LEG["L"] + F.LEG["R"] + ["Hips"], f.first, f.taps["torso_posture"])
	f.check(after <= 20.0 and float(legs[0]) <= KEEP_DEG, "torso_posture fixes a folded trunk", "trunk %.1f deg before, %.1f after; legs and hips changed %.1f deg" % [before, after, legs[0]])


# ------------------------------------------------------------------ arms

## Elbow and forearm-middle depth inside the torso ellipse arm_clearance uses (1 = on it).
func _inside(g: Array, side: String) -> float:
	var ur: Vector3 = (g[f.bone("RightUpperArm")] as Transform3D).origin
	var ul: Vector3 = (g[f.bone("LeftUpperArm")] as Transform3D).origin
	var hip: Vector3 = (g[f.bone("Hips")] as Transform3D).origin
	var centre := (ur + ul) * 0.5
	var axis := (centre - hip)
	var alen := axis.length()
	axis /= alen
	var lat := (ur - ul).normalized()
	lat = (lat - axis * lat.dot(axis)).normalized()
	var fwd := lat.cross(axis).normalized()
	var half := ur.distance_to(ul) * 0.5
	var e: Vector3 = (g[f.bone(F.ARM[side][2])] as Transform3D).origin
	var rel := e - hip
	var along := rel.dot(axis) / alen
	if along < 0.05 or along > 1.05:
		return 9.0
	var x := rel.dot(lat) / half
	var z := rel.dot(fwd) / (half * 0.85)
	return sqrt(x * x + z * z)


func _arm_clearance() -> void:
	print("arm_clearance: swing an arm out of the torso; squeeze an arm flung out sideways past 45% (a 'wing')")
	await _keeps("arm_clearance", ["idle", "t_pose", "arms_down", "arms_out_60", "arms_overhead", "elbow_90_hinge", "jumpshot_0.75", "jumpshot_1.15"])
	await _run("arm_clearance", "elbows_in_ribs")
	var d0 := _inside(f.first.g, "R")
	var d1 := _inside(f.taps["arm_clearance"].g, "R")
	var hand: float = f.world((f.first.g[f.bone("RightHand")] as Transform3D).origin).distance_to(f.world((f.taps["arm_clearance"].g[f.bone("RightHand")] as Transform3D).origin)) * 100.0
	f.check(d0 < 1.0 and d1 >= 0.98, "arm_clearance fixes an elbow in the ribs", "elbow at %.2f of the torso ellipse before, %.2f after (1 = its surface)" % [d0, d1])
	f.check(hand <= 3.0, "arm_clearance keeps the hand", "the hand moved %.1f cm (its stated purpose: hands are left alone)" % hand)


func _palm(g: Array, side: String) -> Vector3:
	var hb: Basis = (g[f.bone(F.ARM[side][3])] as Transform3D).basis.orthonormalized()
	var palm0: Vector3 = f.sk.get_bone_global_rest(f.bone(F.ARM[side][3])).basis.orthonormalized().inverse() * Vector3.DOWN
	return (hb * palm0).normalized()


func _hand_aim() -> void:
	print("hand_aim: turn a palm to face a world point, by weight")
	var aim: SkeletonModifier3D = f.mod("hand_aim_R")
	aim.set("weight", 0.0)
	await _keeps("hand_aim_R", ["idle", "elbow_90_hinge", "jumpshot_1.00"])
	# B with weight: aim at where the palm already faces.
	for p: String in ["elbow_90_hinge", "idle"]:
		f.only([])
		f.use(poses[p])
		await f.settle(2)
		var wrist: Vector3 = f.world((f.first.g[f.bone("RightHand")] as Transform3D).origin)
		aim.set("target", wrist + f.sk.global_transform.basis.orthonormalized() * _palm(f.first.g, "R") * 0.5)
		aim.set("weight", 1.0)
		await _keeps("hand_aim_R", [p])
	# C: palm a quarter turn off its target, about the forearm (a hand that must roll to face it).
	for twist_first: bool in [false, true]:
		aim.set("twist_first", twist_first)
		f.only([])
		f.use(poses["elbow_90_hinge"])
		await f.settle(2)
		var wrist: Vector3 = f.world((f.first.g[f.bone("RightHand")] as Transform3D).origin)
		var fore: Vector3 = ((f.first.g[f.bone("RightHand")] as Transform3D).origin - (f.first.g[f.bone("RightLowerArm")] as Transform3D).origin).normalized()
		var want: Vector3 = Basis(fore, deg_to_rad(90.0)) * _palm(f.first.g, "R")
		aim.set("target", wrist + f.sk.global_transform.basis.orthonormalized() * want * 0.5)
		aim.set("weight", 1.0)
		await _run("hand_aim_R", "elbow_90_hinge")
		var got := _palm(f.taps["hand_aim_R"].g, "R")
		var miss := rad_to_deg(got.angle_to(want))
		var r := f.limb(f.taps["hand_aim_R"].g, f.limb_rest("arm", "R"))
		var arm: Array = f.change(["RightUpperArm", "RightLowerArm"], f.first, f.taps["hand_aim_R"])
		f.check(miss <= 5.0 and float(r["wrist"]) <= 70.0, "hand_aim turns a palm 90 deg%s" % (" (twist_first)" if twist_first else ""),
			"palm %.0f deg from its target after; the wrist bent %.0f deg off the forearm (limit 70); upper arm and forearm changed %.1f deg (the forearm should carry a roll, the hand cannot)" % [miss, r["wrist"], arm[0]])
	aim.set("twist_first", false)
	aim.set("weight", 0.0)


func _elbow_hinge() -> void:
	print("elbow_hinge: rebuild each arm as a hinge elbow (0-148 deg), forearm twist +-88, wrist bend <= 70, keeping joint positions")
	await _keeps("elbow_hinge", ["t_pose", "idle", "arms_down", "elbow_90_hinge", "elbow_90_pronated_60", "arms_overhead", "jumpshot_0.45", "jumpshot_0.75", "jumpshot_1.00", "jumpshot_1.15"])
	for p: String in ["elbow_sideways_30", "elbow_hyperextended_20"]:
		await _run("elbow_hinge", p)
		var r := f.limb_rest("arm", "R")
		var m0 := f.limb(f.first.g, r)
		var m1 := f.limb(f.taps["elbow_hinge"].g, r)
		var wrist: float = f.world(m0["w"]).distance_to(f.world(m1["w"])) * 100.0
		f.check(absf(float(m1["off"])) <= 3.0 and float(m1["flex"]) >= -1.0, "elbow_hinge fixes %s" % p,
			"before: flex %.0f off-hinge %.0f; after: flex %.0f off-hinge %.1f; the wrist moved %.1f cm" % [m0["flex"], m0["off"], m1["flex"], m1["off"], wrist])


# ------------------------------------------------------------------ scale

func _no_scale() -> void:
	print("No correction may scale or mirror a body bone (student_feet scales the shoe controls 1.14: declared)")
	var bad: Array = []
	for m: SkeletonModifier3D in f.mods:
		var label := F.label(m)
		if not f.taps.has(label):
			continue
		f.only([label])
		f.use(poses["idle"])
		await f.settle(2)
		for n: String in F.all_body():
			var b: Basis = (f.taps[label].g[f.bone(n)] as Transform3D).basis
			var s := b.get_scale()
			if b.determinant() < 0.0 or (s - Vector3.ONE).length() > 0.01:
				bad.append("%s on %s (scale %s)" % [label, n, s.snapped(Vector3.ONE * 0.01)])
	f.check(bad.is_empty(), "corrections keep bone scale", "%s" % [bad])
