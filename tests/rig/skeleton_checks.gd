extends Node
## Gate 1: skeleton integrity (docs/animation/RIG_CERTIFICATION.md).
## The campus student rig with no animation and no modifier running: hierarchy,
## rest scale and handedness, body frame, bone axes and their left/right mirror
## convention, the elbow and knee hinge axes (and that the arm IK pole axis is
## the elbow tip), bilateral symmetry, proportions against human anthropometry,
## and whether each joint sits where the skin bends.
##   godot --headless --fixed-fps 60 --path . res://tests/rig/skeleton_checks.tscn [-- fault=<name>]
## Faults (the gate must fail on each): bone_offset (left knee joint moved
## 5 cm down), axis_roll (right forearm rest rolled 90 deg), pole_axis (the IK
## pole axis read as +Z).
const F = preload("res://tests/rig/rig_fixture.gd")
const Actor = preload("res://scripts/court/court_actor.gd")

## Joint heights and segment lengths as a share of stature, adult male
## (Winter, Biomechanics and Motor Control of Human Movement, 4th ed., fig. 4.1,
## after Drillis & Contini). A game body is stylised: TOL is the share either
## way it may differ before the gate fails.
const ANTHRO: Dictionary = {
	"shoulder_h": 0.818, "hip_h": 0.530, "knee_h": 0.285, "ankle_h": 0.039,
	"upper_arm": 0.186, "forearm": 0.146, "thigh": 0.245, "shin": 0.246,
}
const TOL: float = 0.20
const SYM_CM: float = 1.0      # mirrored joint positions may differ this much
const SYM_LEN: float = 0.02    # and left/right segment lengths this share
const AXIS_DEG: float = 2.0


func _ready() -> void:
	var f := F.new()
	f.build(self)
	var sk := f.sk
	var flt := F.fault()
	if flt == "bone_offset":
		var i := sk.find_bone("LeftLowerLeg")
		var r := sk.get_bone_rest(i)
		r.origin += Vector3(0, 0.05 / f.metres_per_unit(), 0)  # along the thigh (its +Y): the knee 5 cm lower
		sk.set_bone_rest(i, r)
	elif flt == "axis_roll":
		var i := sk.find_bone("RightLowerArm")
		var r := sk.get_bone_rest(i)
		r.basis = r.basis * Basis(Vector3.UP, PI / 2)
		sk.set_bone_rest(i, r)
		# keep the hand where it was (only the forearm's axes turn)
		var h := sk.find_bone("RightHand")
		var hr := sk.get_bone_rest(h)
		sk.set_bone_rest(h, Transform3D(Basis(Vector3.UP, -PI / 2), Vector3.ZERO) * hr)
	await f.settle()
	f.only([])
	var m := f.metres_per_unit()
	var G := func(n: String) -> Transform3D: return sk.get_bone_global_rest(sk.find_bone(n))
	var P := func(n: String) -> Vector3: return (G.call(n) as Transform3D).origin
	print("GATE 1 skeleton integrity: campus student rig (%s), %d bones, %.4f m per skeleton unit" % [CourtPlayerModel.STUDENT.get_file(), sk.get_bone_count(), m])

	print("Hierarchy")
	var bad: Array = []
	for b: String in F.HIERARCHY:
		var i := sk.find_bone(b)
		var want: String = F.HIERARCHY[b]
		var par: String = sk.get_bone_name(sk.get_bone_parent(i)) if i >= 0 and sk.get_bone_parent(i) >= 0 else ""
		if i < 0:
			bad.append(b + " missing")
		elif want != "" and par != want:
			bad.append("%s parent %s (want %s)" % [b, par, want])
	f.check(bad.is_empty(), "hierarchy", "%d humanoid bones, parents as RIG_SPEC.md %s" % [F.HIERARCHY.size(), bad])
	var toes: bool = sk.find_bone("LeftToes") >= 0 and sk.find_bone("RightToes") >= 0
	# Not a requirement: the student's feet are shoe control bones (Foot.L/R).
	# Gate 5 tests the foot contact the rig supports.
	f.note("toe bones", "LeftToes/RightToes %s; feet are the shoe controls Foot.L/Foot.R (foot_floor.gd needs toe bones and is inert on this rig)" % ("present" if toes else "absent"))

	print("Rest transforms")
	var scaled: Array = []
	for i in sk.get_bone_count():
		var b: Basis = sk.get_bone_global_rest(i).basis
		var s := b.get_scale()
		if absf(s.x - 1) > 1e-3 or absf(s.y - 1) > 1e-3 or absf(s.z - 1) > 1e-3 or b.determinant() < 0.0:
			scaled.append(sk.get_bone_name(i))
	f.check(scaled.is_empty(), "rest scale and handedness", "every bone unit scale, right-handed %s" % [scaled])
	# The rest pose must be the pose the skin was bound in: then every bone a
	# vertex is weighted to puts it in the same place at rest. Where they
	# disagree, the joints were moved after binding (the mesh is distorted at
	# rest and bends about the wrong points).
	var mi0: MeshInstance3D = CharacterAppearance.find_mesh(f.actor.get("_model"))
	var bind := bind_mismatch(sk, mi0)
	var bind_bad: Array = []
	for k: String in bind:
		var cm: float = float(bind[k]) * m * 100.0
		if cm > 0.5:
			bind_bad.append([cm, k])
	bind_bad.sort_custom(func(a, b): return a[0] > b[0])
	for e: Array in bind_bad.slice(0, 12):
		print("    %-30s bones disagree by %.1f cm at rest" % [e[1], e[0]])
	f.check(bind_bad.is_empty(), "rest pose = skin bind pose", "%d bone pairs place a shared vertex more than 0.5 cm apart at rest%s" % [bind_bad.size(), "" if bind_bad.is_empty() else " (worst %.1f cm, %s)" % [bind_bad[0][0], bind_bad[0][1]]])
	for b: String in ["LeftUpperLeg", "LeftLowerLeg", "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm", "Foot.L"]:
		var d: Vector3 = bind_joint(sk, mi0, b) - sk.get_bone_global_rest(sk.find_bone(b)).origin
		f.note("bind joint " + b, "the skin was bound with this joint %s cm from its rest position (x left, y up, z front)" % (d * m * 100.0).snapped(Vector3.ONE * 0.1))
	# Clips must not write scale or mirror the bones either (the "bones carry scale" trap).
	var ap: AnimationPlayer = f.actor.get("_anim")
	var clip_scaled: Array = []
	for clip: String in ap.get_animation_list():
		var a: Animation = ap.get_animation(clip)
		for k in a.get_track_count():
			if a.track_get_type(k) != Animation.TYPE_SCALE_3D:
				continue
			for key in a.track_get_key_count(k):
				var v: Vector3 = a.track_get_key_value(k, key)
				if (v - Vector3.ONE).length() > 1e-3:
					clip_scaled.append("%s:%s" % [clip, a.track_get_path(k)])
					break
	f.check(clip_scaled.is_empty(), "clips write no bone scale", "%d clips, scale keys off 1: %s" % [ap.get_animation_list().size(), clip_scaled])

	print("Body frame (skeleton space)")
	var up: bool = P.call("Head").y > P.call("Hips").y and P.call("Hips").y > P.call("LeftFoot").y
	var left: bool = P.call("LeftUpperLeg").x > 0.0 and P.call("LeftUpperArm").x > 0.0 and P.call("RightUpperArm").x < 0.0
	var front: bool = (P.call("Foot.L_end") as Vector3).z > (P.call("Foot.L") as Vector3).z and (P.call("Thumb2.L") as Vector3).z > (P.call("LeftHand") as Vector3).z
	f.check(up and left and front, "body frame", "+Y up %s, +X the body's left %s, +Z its front (toes, thumbs) %s" % [up, left, front])
	var rest_arm_down: float = rad_to_deg(((P.call("LeftLowerArm") as Vector3) - P.call("LeftUpperArm")).angle_to(Vector3.RIGHT))
	f.note("rest pose", "T-pose: upper arms %.1f deg off horizontal, legs vertical and straight (a straight leg has no bend plane: the leg IK needs a pole)" % rest_arm_down)

	print("Bone axes")
	var along: Array = []
	var trunk_axes: Array = []
	for b: String in F.HIERARCHY:
		var i := sk.find_bone(b)
		var child := -1
		for c in sk.get_bone_count():
			if sk.get_bone_parent(c) == i and F.HIERARCHY.has(sk.get_bone_name(c)) and not sk.get_bone_name(c).ends_with("Shoulder") and not sk.get_bone_name(c).ends_with("UpperLeg"):
				child = c
		if child < 0 or b in ["Hips", "LeftFoot", "RightFoot"]:
			continue
		var dir := (sk.get_bone_global_rest(child).origin - sk.get_bone_global_rest(i).origin).normalized()
		var y := sk.get_bone_global_rest(i).basis.y.normalized()
		var off := rad_to_deg(y.angle_to(dir))
		if b in ["Spine", "Chest", "UpperChest", "Neck", "Head"]:
			trunk_axes.append("%s %.0f" % [b, off])
		elif off > 10.0:
			along.append("%s +Y %.0f deg off %s" % [b, off, sk.get_bone_name(child)])
	f.check(along.is_empty(), "limb +Y points at the child joint", "arms and legs %s" % [along])
	f.note("trunk axes", "trunk bones are world-aligned (identity rest), +Y vs the next joint (deg): %s; the spine curves forward, the axes do not follow it" % ", ".join(trunk_axes))
	var mirror := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
	var mir_bad: Array = []
	for pair: Array in [["LeftShoulder", "RightShoulder"], ["LeftUpperArm", "RightUpperArm"], ["LeftLowerArm", "RightLowerArm"],
			["LeftHand", "RightHand"], ["LeftUpperLeg", "RightUpperLeg"], ["LeftLowerLeg", "RightLowerLeg"], ["LeftFoot", "RightFoot"]]:
		var lb: Basis = (G.call(pair[0]) as Transform3D).basis.orthonormalized()
		var rb: Basis = (G.call(pair[1]) as Transform3D).basis.orthonormalized()
		# Right = the left mirrored across the body's midplane, local X negated.
		var want := mirror * lb * mirror
		var d := F.angle(want, rb)
		if d > AXIS_DEG:
			mir_bad.append("%s %.0f deg" % [pair[1], d])
	f.check(mir_bad.is_empty(), "left/right axis mirror convention", "right bone = left mirrored, local X negated %s" % [mir_bad])

	print("Hinge axes and the IK pole convention")
	for side: String in ["L", "R"]:
		var lower: String = F.ARM[side][2]
		var lb: Basis = (G.call(lower) as Transform3D).basis.orthonormalized()
		var tip := lb * Vector3(0, 0, -1)
		f.check(tip.dot(Vector3.FORWARD) > 0.98, "elbow tip axis %s" % side, "forearm local -Z points %s (want the body's back, (0,0,-1))" % tip.snapped(Vector3.ONE * 0.01))
		var r := f.limb_rest("arm", side)
		var hinge_fore := lb.inverse() * ((G.call(F.ARM[side][1]) as Transform3D).basis.orthonormalized() * (r["hinge_u"] as Vector3))
		f.check(hinge_fore.dot(Vector3.RIGHT) > 0.98, "elbow hinge axis %s" % side, "flexion is about forearm local %s (want +X)" % hinge_fore.snapped(Vector3.ONE * 0.01))
		# Experiment: fold the forearm about its own +X by 60 deg: the hand must go to the front.
		var pose := f.posed([[lower, lb.x, 60.0]])
		for i: int in pose:
			sk.set_bone_pose(i, pose[i])
		sk.force_update_all_bone_transforms()
		var hand := sk.get_bone_global_pose(sk.find_bone(F.ARM[side][3])).origin - sk.get_bone_global_pose(sk.find_bone(lower)).origin
		sk.reset_bone_poses()
		f.check(hand.z > 0.0, "elbow folds forward %s" % side, "+60 deg about forearm +X puts the hand %.2f units in front of the elbow" % hand.z)
		var shin: String = F.LEG[side][1]
		var sb: Basis = (G.call(shin) as Transform3D).basis.orthonormalized()
		var ktip := sb * Vector3(0, 0, -1)
		f.check(ktip.dot(Vector3.BACK) > 0.98, "knee tip axis %s" % side, "shin local -Z points %s (want the body's front, (0,0,1))" % ktip.snapped(Vector3.ONE * 0.01))
		var kpose := f.posed([[shin, sb.x, 60.0]])
		for i: int in kpose:
			sk.set_bone_pose(i, kpose[i])
		sk.force_update_all_bone_transforms()
		var foot := sk.get_bone_global_pose(sk.find_bone(F.LEG[side][2])).origin - sk.get_bone_global_pose(sk.find_bone(shin)).origin
		sk.reset_bone_poses()
		f.check(foot.z < 0.0, "knee folds back %s" % side, "+60 deg about shin +X puts the foot %.2f units behind the knee" % -foot.z)
	var pole: int = Actor.POLE_AXIS_STUDENT if flt != "pole_axis" else SkeletonModifier3D.SECONDARY_DIRECTION_PLUS_Z
	f.check(pole == SkeletonModifier3D.SECONDARY_DIRECTION_MINUS_Z, "arm IK pole axis", "court_actor.POLE_AXIS_STUDENT = %s, the measured elbow tip is -Z" % ["none", "+X", "-X", "+Y", "-Y", "+Z", "-Z", "custom"][pole])
	var ik: TwoBoneIK3D = f.mod("arm_ik_R")
	f.check(ik != null and ik.get_pole_direction(0) == SkeletonModifier3D.SECONDARY_DIRECTION_MINUS_Z, "arm IK built with that pole axis", "TwoBoneIK3D pole direction %d" % (ik.get_pole_direction(0) if ik else -1))

	print("Bilateral symmetry")
	var mid_x: float = (P.call("Spine") as Vector3).x
	for pair: Array in [["LeftShoulder", "RightShoulder"], ["LeftUpperArm", "RightUpperArm"], ["LeftLowerArm", "RightLowerArm"], ["LeftHand", "RightHand"],
			["LeftUpperLeg", "RightUpperLeg"], ["LeftLowerLeg", "RightLowerLeg"], ["LeftFoot", "RightFoot"]]:
		var lp: Vector3 = P.call(pair[0])
		var rp: Vector3 = P.call(pair[1])
		var mirrored := Vector3(2.0 * mid_x - rp.x, rp.y, rp.z)
		var cm := lp.distance_to(mirrored) * m * 100.0
		var joint: String = {"Shoulder": "clavicle", "UpperArm": "shoulder", "LowerArm": "elbow", "Hand": "wrist", "UpperLeg": "hip", "LowerLeg": "knee", "Foot": "ankle"}[pair[0].substr(4)]
		f.check(cm <= SYM_CM, "%s joints mirror" % joint, "left %s, right mirrored %s: %.1f cm apart (limit %.0f)" % [(lp * m).snapped(Vector3.ONE * 0.001), (mirrored * m).snapped(Vector3.ONE * 0.001), cm, SYM_CM])
	var seg := func(a: String, b: String) -> float: return (P.call(a) as Vector3).distance_to(P.call(b)) * m
	for s: Array in [["upper arm", "UpperArm", "LowerArm"], ["forearm", "LowerArm", "Hand"], ["thigh", "UpperLeg", "LowerLeg"], ["shin", "LowerLeg", "Foot"]]:
		var l: float = seg.call("Left" + s[1], "Left" + s[2])
		var r: float = seg.call("Right" + s[1], "Right" + s[2])
		f.check(absf(l / r - 1.0) <= SYM_LEN, "%s length matches left/right" % s[0], "left %.1f cm, right %.1f cm (%+.1f%%, limit %.0f%%)" % [l * 100, r * 100, (l / r - 1.0) * 100.0, SYM_LEN * 100])

	print("Proportions (share of stature; Winter / Drillis & Contini)")
	var mi: MeshInstance3D = CharacterAppearance.find_mesh(f.actor.get("_model"))
	var verts := _rest_vertices(sk, mi)
	var top := -INF
	var floor_y := INF
	for v: Array in verts:
		top = maxf(top, (v[0] as Vector3).y)
		floor_y = minf(floor_y, (v[0] as Vector3).y)
	var stature: float = top - floor_y
	var have: Dictionary = {
		"shoulder_h": ((P.call("LeftUpperArm") as Vector3).y - floor_y) / stature,
		"hip_h": ((P.call("LeftUpperLeg") as Vector3).y - floor_y) / stature,
		"knee_h": ((P.call("LeftLowerLeg") as Vector3).y - floor_y) / stature,
		"ankle_h": ((P.call("LeftFoot") as Vector3).y - floor_y) / stature,
		"upper_arm": (seg.call("LeftUpperArm", "LeftLowerArm") + seg.call("RightUpperArm", "RightLowerArm")) * 0.5 / (stature * m),
		"forearm": (seg.call("LeftLowerArm", "LeftHand") + seg.call("RightLowerArm", "RightHand")) * 0.5 / (stature * m),
		"thigh": (seg.call("LeftUpperLeg", "LeftLowerLeg") + seg.call("RightUpperLeg", "RightLowerLeg")) * 0.5 / (stature * m),
		"shin": (seg.call("LeftLowerLeg", "LeftFoot") + seg.call("RightLowerLeg", "RightFoot")) * 0.5 / (stature * m),
	}
	print("    stature (mesh, floor to crown) %.3f m" % (stature * m))
	var prop_bad: Array = []
	for k: String in ANTHRO:
		var rel: float = float(have[k]) / float(ANTHRO[k]) - 1.0
		print("    %-10s %.3f  (human %.3f, %+.0f%%)%s" % [k, have[k], ANTHRO[k], rel * 100.0, "  <-" if absf(rel) > TOL else ""])
		if absf(rel) > TOL:
			prop_bad.append("%s %+.0f%%" % [k, rel * 100.0])
	f.check(prop_bad.is_empty(), "proportions", "within %.0f%% of human %s" % [TOL * 100, prop_bad])

	print("Joints against the skin (where each bone's vertices start, along the bone from its joint)")
	# A bone's skin should begin at its joint: skin that a bone carries from
	# well before its own joint swings the wrong way when the joint turns
	# (vertices above a hip pivot move backward as the knee lifts).
	var skin_bad: Array = []
	for b: String in ["LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm", "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg"]:
		var i := sk.find_bone(b)
		var g: Transform3D = sk.get_bone_global_rest(i)
		var y := g.basis.y.normalized()
		var lo := INF
		var hi := -INF
		var before := 0
		var n := 0
		var length := 0.0
		for c in sk.get_bone_count():
			if sk.get_bone_parent(c) == i:
				length = maxf(length, sk.get_bone_global_rest(c).origin.distance_to(g.origin))
		for v: Array in verts:
			if int(v[1]) != i or float(v[2]) < 0.6:
				continue
			var t: float = ((v[0] as Vector3) - g.origin).dot(y)
			lo = minf(lo, t)
			hi = maxf(hi, t)
			n += 1
			if t < -0.10 * length:
				before += 1
		print("    %-14s %3d verts from %+.1f cm to %+.1f cm along a %.1f cm bone; %d start more than 10%% before the joint" % [b, n, lo * m * 100, hi * m * 100, length * m * 100, before])
		if lo < -0.15 * length:
			skin_bad.append("%s skin starts %.1f cm before its joint" % [b, -lo * m * 100])
	# Where the skin bends: halfway between the last vertex the parent bone
	# dominates and the first the child does, along the parent. The joint
	# should be there.
	for j: Array in [["elbow L", "LeftUpperArm", "LeftLowerArm"], ["elbow R", "RightUpperArm", "RightLowerArm"],
			["knee L", "LeftUpperLeg", "LeftLowerLeg"], ["knee R", "RightUpperLeg", "RightLowerLeg"],
			["hip L", "Spine", "LeftUpperLeg"], ["hip R", "Spine", "RightUpperLeg"]]:
		var pi := sk.find_bone(j[1])
		var ci := sk.find_bone(j[2])
		var c0: Vector3 = sk.get_bone_global_rest(ci).origin
		var axis: Vector3 = (c0 - sk.get_bone_global_rest(pi).origin).normalized() if not j[0].begins_with("hip") else Vector3.DOWN
		var p_end := -INF
		var c_start := INF
		for v: Array in verts:
			if float(v[2]) < 0.6:
				continue
			var t: float = ((v[0] as Vector3) - c0).dot(axis)
			if int(v[1]) == pi:
				p_end = maxf(p_end, t)
			elif int(v[1]) == ci:
				c_start = minf(c_start, t)
		var skin_joint := (p_end + c_start) * 0.5
		var cm := skin_joint * m * 100.0
		print("    %-8s skin bends %+.1f cm from the joint (%s ends %+.1f, %s starts %+.1f; + = toward the %s)" % [j[0], cm, j[1], p_end * m * 100, j[2], c_start * m * 100, "hand" if j[0].begins_with("elbow") else "foot"])
		if absf(cm) > 3.0:
			skin_bad.append("%s joint %.1f cm from where the skin bends" % [j[0], absf(cm)])
	f.check(skin_bad.is_empty(), "joints where the skin bends", "%s" % [skin_bad])
	# The mesh's own midplane: the x that best mirrors it (scan around the spine).
	var best_x := mid_x
	var best_p := INF
	for k in range(-20, 21):
		var x := mid_x + float(k) * 0.005
		var s := _mesh_symmetry(verts, x, sk)
		if float(s["arm_p95"]) < best_p:
			best_p = float(s["arm_p95"])
			best_x = x
	var sym := _mesh_symmetry(verts, best_x, sk)
	print("    mesh midplane x %+.2f cm from the spine joint; mirror distance: all p95 %.2f cm max %.2f cm; arms p95 %.2f cm max %.2f cm" % [(best_x - mid_x) * m * 100, sym["all_p95"] * m * 100, sym["all_max"] * m * 100, sym["arm_p95"] * m * 100, sym["arm_max"] * m * 100])
	f.note("mesh symmetry", "95%% of arm vertices lie within %.2f cm of their mirror image: a left/right joint difference well beyond that is joint placement, not the body" % (float(sym["arm_p95"]) * m * 100.0))
	var flist := ",".join(f.failures)
	print("FAILED_CHECKS: " + flist)
	f.finish(get_tree(), "GATE 1")


## Per pair of bones sharing a vertex: the largest distance between where each
## puts that vertex at rest (skeleton units). 0 everywhere when rest = bind.
static func bind_mismatch(sk: Skeleton3D, mi: MeshInstance3D) -> Dictionary:
	var skin: Skin = mi.skin
	var out: Dictionary = {}
	for s in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per: int = bones.size() / verts.size()
		for v in verts.size():
			var ps: Array = []
			for k in per:
				if wts[v * per + k] <= 0.01:
					continue
				var bi: int = bones[v * per + k]
				var b := sk.find_bone(skin.get_bind_name(bi))
				ps.append([sk.get_bone_name(b), sk.get_bone_global_rest(b) * (skin.get_bind_pose(bi) * verts[v])])
			for i in ps.size():
				for j in range(i + 1, ps.size()):
					if ps[i][0] == ps[j][0]:
						continue
					var key: String = "%s/%s" % ([ps[i][0], ps[j][0]] if str(ps[i][0]) < str(ps[j][0]) else [ps[j][0], ps[i][0]])
					out[key] = maxf(float(out.get(key, 0.0)), (ps[i][1] as Vector3).distance_to(ps[j][1]))
	return out


## Where a joint was when the skin was bound, in skeleton space (through the
## Spine's bind, which agrees with its rest).
static func bind_joint(sk: Skeleton3D, mi: MeshInstance3D, bone_name: String) -> Vector3:
	var skin: Skin = mi.skin
	var mesh_to_sk := Transform3D.IDENTITY
	var bp := Transform3D.IDENTITY
	for i in skin.get_bind_count():
		if skin.get_bind_name(i) == &"Spine":
			mesh_to_sk = sk.get_bone_global_rest(sk.find_bone("Spine")) * skin.get_bind_pose(i)
		if skin.get_bind_name(i) == StringName(bone_name):
			bp = skin.get_bind_pose(i)
	return mesh_to_sk * (bp.affine_inverse() * Vector3.ZERO)


## Every skinned vertex at rest, skeleton space: [position, dominant bone, its weight].
static func _rest_vertices(sk: Skeleton3D, mi: MeshInstance3D) -> Array:
	var skin: Skin = mi.skin
	var binds: Array = []
	for i in skin.get_bind_count():
		binds.append(sk.find_bone(skin.get_bind_name(i)))
	var out: Array = []
	for s in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per: int = bones.size() / verts.size()
		for v in verts.size():
			var p := Vector3.ZERO
			var best := -1
			var bw := 0.0
			for k in per:
				var w: float = wts[v * per + k]
				if w <= 0.0:
					continue
				var bi: int = bones[v * per + k]
				p += sk.get_bone_global_rest(binds[bi]) * (skin.get_bind_pose(bi) * verts[v]) * w
				if w > bw:
					bw = w
					best = binds[bi]
			out.append([p, best, bw])
	return out


## Distance from each vertex to the nearest vertex of the mirrored mesh:
## 95th percentile and max, over all vertices and over the arms'.
static func _mesh_symmetry(verts: Array, mid_x: float, sk: Skeleton3D) -> Dictionary:
	var arm_bones: Array = []
	for side: String in F.ARM:
		for b: String in F.ARM[side]:
			arm_bones.append(sk.find_bone(b))
	var grid: Dictionary = {}
	var cell := 0.1
	for v: Array in verts:
		var p: Vector3 = v[0]
		var key := Vector3i(floori(p.x / cell), floori(p.y / cell), floori(p.z / cell))
		if not grid.has(key):
			grid[key] = []
		grid[key].append(p)
	var all_d: Array = []
	var arm_d: Array = []
	for v: Array in verts:
		var p: Vector3 = v[0]
		var q := Vector3(2.0 * mid_x - p.x, p.y, p.z)
		var best := INF
		var c := Vector3i(floori(q.x / cell), floori(q.y / cell), floori(q.z / cell))
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for dz in range(-1, 2):
					for o: Vector3 in grid.get(c + Vector3i(dx, dy, dz), []):
						best = minf(best, o.distance_to(q))
		if best == INF:
			best = cell * 2.0
		all_d.append(best)
		if int(v[1]) in arm_bones:
			arm_d.append(best)
	all_d.sort()
	arm_d.sort()
	return {"all_p95": all_d[int(all_d.size() * 0.95)], "all_max": all_d.back(),
		"arm_p95": arm_d[int(arm_d.size() * 0.95)], "arm_max": arm_d.back()}
