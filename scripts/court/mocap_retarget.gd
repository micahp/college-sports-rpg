class_name MocapRetarget
extends RefCounted
## CMU basketball mocap onto the campus student, computed from the two
## skeletons as this game imports them (both carry the humanoid profile's bone
## names). Ported from the gridiron-physics student lab (student-lab.html),
## where it was checked frame by frame against the CMU source skeleton.
##
## For each body segment the student bone takes the CMU bone's rotation since
## its rest (that carries the twist about the bone), turned into the student's
## facing, then a small swing makes the segment point exactly where the CMU
## segment points. The hips' height change is scaled by leg length, so jumps
## leave the floor. The engine's own import retarget is kept for every other
## mocap clip; it folds the chest in these three (the CMU Spine sits on Hips
## and Neck on UpperChest, zero-length bones) and drops the jump.

const FPS: float = 60.0
const SKEL: String = "%GeneralSkeleton:"

## Bones driven by the retarget, parents first, and the joints their direction
## is taken toward: the first one that is apart from the bone in the CMU
## skeleton is used (zero-length CMU bones are skipped). No joint: rotation only.
const SEGMENTS: Array = [
	# Hips: rotation only. CMU's Spine sits on its root (zero length), so aiming
	# fell through to Chest and the student's pelvis (which carries the legs)
	# tilted with the performer's lower back instead of with his pelvis.
	["Hips", []], ["Spine", ["Chest"]], ["Chest", ["UpperChest"]],
	["UpperChest", ["Neck"]], ["Neck", ["Head"]], ["Head", []],
	["LeftShoulder", ["LeftUpperArm"]], ["LeftUpperArm", ["LeftLowerArm"]], ["LeftLowerArm", ["LeftHand"]], ["LeftHand", []],
	["RightShoulder", ["RightUpperArm"]], ["RightUpperArm", ["RightLowerArm"]], ["RightLowerArm", ["RightHand"]], ["RightHand", []],
	["LeftUpperLeg", ["LeftLowerLeg"]], ["LeftLowerLeg", ["LeftFoot"]], ["LeftFoot", []],
	["RightUpperLeg", ["RightLowerLeg"]], ["RightLowerLeg", ["RightFoot"]], ["RightFoot", []],
]


## The spine. CMU's has three segments from the hip joints to the neck (hip
## joints -> Hips, Hips -> Chest, Chest -> UpperChest, where its Neck also
## sits); the student's has four, split differently (its UpperChest -> Neck is
## 36 cm, the upper thorax and shoulders). Copying CMU segment directions one
## for one put the recording's bend at the wrong joint; aiming the top segment
## to put the neck on the recorded trunk line (an earlier fix) made it stand
## back up over a bent mid-back: chest out, shoulders back, an arch the
## performer never made. Instead the student's spine joints are laid along the
## recorded spine curve at the same fraction of its length, turned by the bend
## from rest, so the curve keeps its shape on the longer, differently split
## spine (tests/jumpshot_fidelity, build/probe roll check).
const SPINE_SEGMENTS: Array[String] = ["Spine", "Chest", "UpperChest"]


## Rebuilds `target` (the game's clip, track paths kept) from the CMU clip
## `cmu_anim` played on `cmu_sk`, for the student skeleton `sk`.
static func apply(target: Animation, cmu_sk: Skeleton3D, cmu_anim: Animation, sk: Skeleton3D) -> void:
	var cmu_tracks: Dictionary = _tracks_by_bone(cmu_anim)
	var c_rest: Array = _global_rests(cmu_sk)
	var s_rest: Array = _global_rests(sk)
	# Facing: a yaw about up that turns the CMU hip line onto the student's.
	var lat_c: Vector3 = _flat(c_rest[cmu_sk.find_bone("LeftUpperLeg")].origin - c_rest[cmu_sk.find_bone("RightUpperLeg")].origin)
	var lat_s: Vector3 = _flat(s_rest[sk.find_bone("LeftUpperLeg")].origin - s_rest[sk.find_bone("RightUpperLeg")].origin)
	var face: Quaternion = Quaternion(Vector3.UP, PI) if lat_c.dot(lat_s) < -0.9999 else Quaternion(lat_c, lat_s)
	# Size: student leg length over CMU leg length, for the vertical motion.
	var k: float = _leg(s_rest, sk) / _leg(c_rest, cmu_sk)
	var length: float = cmu_anim.length
	var n: int = maxi(2, roundi(length * FPS) + 1)
	var rot_keys: Dictionary = {}
	for seg: Array in SEGMENTS:
		rot_keys[seg[0]] = []
	var hips_keys: Array = []
	var hips_i: int = sk.find_bone("Hips")
	var hips_rest_local: Vector3 = sk.get_bone_rest(hips_i).origin
	var hips_parent_basis: Basis = s_rest[sk.get_bone_parent(hips_i)].basis if sk.get_bone_parent(hips_i) >= 0 else Basis.IDENTITY
	var hip0: float = 0.0
	for f in n:
		var t: float = minf(length, f / FPS)
		var cg: Array = _pose_globals(cmu_sk, cmu_anim, cmu_tracks, t)
		var want: Dictionary = {}  # student bone -> global rotation
		for seg: Array in SEGMENTS:
			var bone: String = seg[0]
			var si: int = sk.find_bone(bone)
			var ci: int = cmu_sk.find_bone(bone)
			if si < 0 or ci < 0:
				continue
			var turn: Quaternion = face * cg[ci].basis.get_rotation_quaternion() * c_rest[ci].basis.get_rotation_quaternion().inverse() * face.inverse()
			var q: Quaternion = turn * s_rest[si].basis.get_rotation_quaternion()
			for joint: String in seg[1]:
				var cj: int = cmu_sk.find_bone(joint)
				var sj: int = sk.find_bone(joint)
				if cj < 0 or sj < 0:
					continue
				var seg_c: Vector3 = cg[cj].origin - cg[ci].origin
				if seg_c.length() < 1e-4:
					continue
				var aim: Vector3 = face * seg_c.normalized()
				var now: Vector3 = turn * (s_rest[sj].origin - s_rest[si].origin).normalized()
				q = Quaternion(now, aim) * q
				break
			if bone in SPINE_SEGMENTS:
				q = _spine_segment(bone, sk, s_rest, turn, cmu_sk, cg, face)
			want[bone] = q
		for seg: Array in SEGMENTS:
			var bone: String = seg[0]
			if not want.has(bone):
				continue
			var p: int = sk.get_bone_parent(sk.find_bone(bone))
			var pq: Quaternion = Quaternion.IDENTITY
			if p >= 0:
				pq = want.get(sk.get_bone_name(p), s_rest[p].basis.get_rotation_quaternion())
			(rot_keys[bone] as Array).append([t, (pq.inverse() * (want[bone] as Quaternion)).normalized()])
		var hy: float = cg[cmu_sk.find_bone("Hips")].origin.y
		if f == 0:
			hip0 = hy
		# keys are skeleton-space positions divided by motion_scale (the player multiplies them back)
		hips_keys.append([t, (hips_rest_local + hips_parent_basis.inverse() * Vector3(0, (hy - hip0) * k, 0)) / sk.motion_scale])
	# Keep the clip's floor height: its lowest ankle lands where the old clip's did.
	var lift: float = _lowest_ankle(target, sk, {}, []) - _lowest_ankle(target, sk, rot_keys, hips_keys)
	for key: Array in hips_keys:
		key[1] = (key[1] as Vector3) + hips_parent_basis.inverse() * Vector3(0, lift, 0) / sk.motion_scale
	for bone: String in rot_keys:
		var tr: int = _track(target, Animation.TYPE_ROTATION_3D, bone)
		for key: Array in rot_keys[bone]:
			target.rotation_track_insert_key(tr, key[0], key[1])
	var ht: int = _track(target, Animation.TYPE_POSITION_3D, "Hips")
	for key: Array in hips_keys:
		target.position_track_insert_key(ht, key[0], key[1])


## Points of a spine, from where it leaves the pelvis up to the neck.
static func _spine_points(sk: Skeleton3D, poses: Array, chain: Array) -> Array:
	var pts: Array = []
	for b: String in chain:
		var p: Vector3 = (poses[sk.find_bone(b)] as Transform3D).origin
		if pts.is_empty() or p.distance_to(pts.back()) > 1e-5:
			pts.append(p)
	return pts


## Cumulative length fractions along a polyline (0 .. 1).
static func _fractions(pts: Array) -> Array:
	var acc: Array = [0.0]
	for i in range(1, pts.size()):
		acc.append(float(acc.back()) + (pts[i] as Vector3).distance_to(pts[i - 1]))
	var total: float = maxf(float(acc.back()), 1e-6)
	return acc.map(func(a): return float(a) / total)


## The point at length fraction f along a polyline.
static func _along(pts: Array, fr: Array, f: float) -> Vector3:
	for i in range(1, pts.size()):
		if f <= float(fr[i]) or i == pts.size() - 1:
			var span: float = maxf(float(fr[i]) - float(fr[i - 1]), 1e-6)
			return (pts[i - 1] as Vector3).lerp(pts[i], clampf((f - float(fr[i - 1])) / span, 0.0, 1.0))
	return pts.back()


## A student spine bone's rotation: its CMU-matched rotation, swung so the
## segment from it to the next spine joint points along the recorded spine
## between the same two length fractions.
## Both start where the spine leaves the pelvis: CMU's root (its Spine sits on
## it) and the student's Spine bone (its Hips is a controller below the hip
## joints, so starting lower adds a zigzag). The pelvis itself follows CMU's.
const STUDENT_SPINE: Array[String] = ["Spine", "Chest", "UpperChest", "Neck"]
const CMU_SPINE: Array[String] = ["Hips", "Chest", "UpperChest"]
static func _spine_segment(bone: String, sk: Skeleton3D, s_rest: Array, turn: Quaternion, cmu_sk: Skeleton3D, cg: Array, face: Quaternion) -> Quaternion:
	var si: int = sk.find_bone(bone)
	var q: Quaternion = turn * s_rest[si].basis.get_rotation_quaternion()
	var s_pts: Array = _spine_points(sk, s_rest, STUDENT_SPINE)
	var s_fr: Array = _fractions(s_pts)
	var c_pts: Array = _spine_points(cmu_sk, cg, CMU_SPINE)
	var c_rest_pts: Array = _spine_points(cmu_sk, _global_rests(cmu_sk), CMU_SPINE)
	if c_pts.size() < 2 or c_pts.size() != c_rest_pts.size():
		return q
	var c_fr: Array = _fractions(c_rest_pts)  # fractions from the rest spine (lengths do not change)
	var k: int = STUDENT_SPINE.find(bone)
	var posed: Vector3 = _along(c_pts, c_fr, float(s_fr[k + 1])) - _along(c_pts, c_fr, float(s_fr[k]))
	var rest: Vector3 = _along(c_rest_pts, c_fr, float(s_fr[k + 1])) - _along(c_rest_pts, c_fr, float(s_fr[k]))
	if posed.length() < 1e-6 or rest.length() < 1e-6:
		return q
	# The recorded spine's own curve and posture, at the same length fractions:
	# the student's rest spine is not straight (its Chest segment leans 11 deg
	# forward, its top stands back up), and carrying that rest shape left a
	# slight arch in every pose. Both curves start where the spine leaves the
	# pelvis, so the directions line up without a pelvis zigzag.
	var child: int = sk.find_bone(STUDENT_SPINE[STUDENT_SPINE.find(bone) + 1])
	var rest_dir: Vector3 = (s_rest[child].origin - s_rest[si].origin).normalized()
	var now: Vector3 = (turn * rest_dir).normalized()
	var aim: Vector3 = (face * posed.normalized()).normalized()
	return Quaternion(now, aim) * q


## An empty track of `type` for `bone` in `anim` (an existing one is cleared).
static func _track(anim: Animation, type: int, bone: String) -> int:
	var path: NodePath = NodePath(SKEL + bone)
	var t: int = anim.find_track(path, type)
	if t < 0:
		t = anim.add_track(type)
		anim.track_set_path(t, path)
	for k in range(anim.track_get_key_count(t) - 1, -1, -1):
		anim.track_remove_key(t, k)
	return t


static func _tracks_by_bone(anim: Animation) -> Dictionary:
	var out: Dictionary = {}
	for t in anim.get_track_count():
		var bone: String = str(anim.track_get_path(t).get_concatenated_subnames())
		if bone == "":
			continue
		if not out.has(bone):
			out[bone] = {}
		(out[bone] as Dictionary)[anim.track_get_type(t)] = t
	return out


static func _global_rests(sk: Skeleton3D) -> Array:
	var out: Array = []
	for i in sk.get_bone_count():
		out.append(sk.get_bone_global_rest(i))
	return out


## Every bone's skeleton-space transform at time `t` of `anim`.
static func _pose_globals(sk: Skeleton3D, anim: Animation, tracks: Dictionary, t: float) -> Array:
	var out: Array = []
	out.resize(sk.get_bone_count())
	for i in sk.get_bone_count():
		var rest: Transform3D = sk.get_bone_rest(i)
		var pos: Vector3 = rest.origin
		var rot: Quaternion = rest.basis.get_rotation_quaternion()
		var scl: Vector3 = rest.basis.get_scale()
		var bt: Dictionary = tracks.get(sk.get_bone_name(i), {})
		if bt.has(Animation.TYPE_POSITION_3D):  # position keys are stored divided by the skeleton's motion_scale
			pos = anim.position_track_interpolate(bt[Animation.TYPE_POSITION_3D], t) * sk.motion_scale
		if bt.has(Animation.TYPE_ROTATION_3D):
			rot = anim.rotation_track_interpolate(bt[Animation.TYPE_ROTATION_3D], t)
		if bt.has(Animation.TYPE_SCALE_3D):
			scl = anim.scale_track_interpolate(bt[Animation.TYPE_SCALE_3D], t)
		var local: Transform3D = Transform3D(Basis(rot).scaled(scl), pos)
		var p: int = sk.get_bone_parent(i)
		out[i] = (out[p] as Transform3D) * local if p >= 0 else local
	return out


## Lowest ankle height over the clip, from `anim`'s own tracks except the
## rotations in `rot_keys` and the hips keys `hips_keys` (when given).
static func _lowest_ankle(anim: Animation, sk: Skeleton3D, rot_keys: Dictionary, hips_keys: Array) -> float:
	var probe: Animation = anim.duplicate()
	for bone: String in rot_keys:
		var tr: int = _track(probe, Animation.TYPE_ROTATION_3D, bone)
		for key: Array in rot_keys[bone]:
			probe.rotation_track_insert_key(tr, key[0], key[1])
	if not hips_keys.is_empty():
		var ht: int = _track(probe, Animation.TYPE_POSITION_3D, "Hips")
		for key: Array in hips_keys:
			probe.position_track_insert_key(ht, key[0], key[1])
	var tracks: Dictionary = _tracks_by_bone(probe)
	var low: float = INF
	var steps: int = maxi(2, roundi(probe.length * FPS))
	for f in steps + 1:
		var g: Array = _pose_globals(sk, probe, tracks, probe.length * f / steps)
		for ankle: String in ["LeftFoot", "RightFoot"]:
			low = minf(low, (g[sk.find_bone(ankle)] as Transform3D).origin.y)
	return low


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z).normalized()


static func _leg(rests: Array, sk: Skeleton3D) -> float:
	var up: Vector3 = (rests[sk.find_bone("LeftUpperLeg")] as Transform3D).origin
	var knee: Vector3 = (rests[sk.find_bone("LeftLowerLeg")] as Transform3D).origin
	var ankle: Vector3 = (rests[sk.find_bone("LeftFoot")] as Transform3D).origin
	return up.distance_to(knee) + knee.distance_to(ankle)
