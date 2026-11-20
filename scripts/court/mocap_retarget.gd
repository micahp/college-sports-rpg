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
	["Hips", ["Spine", "Chest"]], ["Spine", ["Chest"]], ["Chest", ["UpperChest"]],
	["UpperChest", ["Neck"]], ["Neck", ["Head"]], ["Head", []],
	["LeftShoulder", ["LeftUpperArm"]], ["LeftUpperArm", ["LeftLowerArm"]], ["LeftLowerArm", ["LeftHand"]], ["LeftHand", []],
	["RightShoulder", ["RightUpperArm"]], ["RightUpperArm", ["RightLowerArm"]], ["RightLowerArm", ["RightHand"]], ["RightHand", []],
	["LeftUpperLeg", ["LeftLowerLeg"]], ["LeftLowerLeg", ["LeftFoot"]], ["LeftFoot", []],
	["RightUpperLeg", ["RightLowerLeg"]], ["RightLowerLeg", ["RightFoot"]], ["RightFoot", []],
]


## The student's top trunk segment (UpperChest -> Neck, 36 cm) has no CMU
## counterpart: CMU's Neck sits on its UpperChest (zero length). Aiming it at
## the next CMU joint (Head) gave the upper torso the head's tilt, up to 9 deg
## of extra trunk roll in JumpShot; copying the CMU upper spine instead leaned
## the trunk up to 14 deg too far forward, because the two spines split their
## length differently. It is aimed so the student's neck lies on the source's
## pelvis-to-neck line (tests/jumpshot_fidelity): the lower segments keep the
## CMU spine's curve and the trunk as a whole points where the performer's did.
const TRUNK_TOP: String = "UpperChest"


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
			if bone == TRUNK_TOP:
				q = _trunk_top(sk, s_rest, want, turn, cmu_sk, cg, face)
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


## TRUNK_TOP's rotation: its CMU rotation since rest, swung so the student's
## Neck lands on the line from the student's pelvis (hip-joint midpoint) along
## the source's pelvis-to-neck direction, at the student's rest trunk length.
static func _trunk_top(sk: Skeleton3D, s_rest: Array, want: Dictionary, turn: Quaternion, cmu_sk: Skeleton3D, cg: Array, face: Quaternion) -> Quaternion:
	var top: int = sk.find_bone(TRUNK_TOP)
	var neck: int = sk.find_bone("Neck")
	var q: Quaternion = turn * s_rest[top].basis.get_rotation_quaternion()
	var c_pelvis: Vector3 = (cg[cmu_sk.find_bone("LeftUpperLeg")].origin + cg[cmu_sk.find_bone("RightUpperLeg")].origin) * 0.5
	var c_dir: Vector3 = (cg[cmu_sk.find_bone("Neck")].origin - c_pelvis)
	if c_dir.length() < 1e-4:
		return q
	c_dir = face * c_dir.normalized()
	var rest_pelvis: Vector3 = (s_rest[sk.find_bone("LeftUpperLeg")].origin + s_rest[sk.find_bone("RightUpperLeg")].origin) * 0.5
	var length: float = rest_pelvis.distance_to(s_rest[neck].origin)
	var pelvis: Vector3 = (_posed(sk, s_rest, want, "LeftUpperLeg") + _posed(sk, s_rest, want, "RightUpperLeg")) * 0.5
	var top_at: Vector3 = _posed(sk, s_rest, want, TRUNK_TOP)
	var aim: Vector3 = (pelvis + c_dir * length - top_at).normalized()
	var now: Vector3 = (q * s_rest[top].basis.get_rotation_quaternion().inverse() * (s_rest[neck].origin - s_rest[top].origin)).normalized()
	return Quaternion(now, aim) * q


## Where `bone` is (skeleton space) with the global rotations in `want` on its
## ancestors (rest rotation where `want` has none), from the root's rest place.
static func _posed(sk: Skeleton3D, s_rest: Array, want: Dictionary, bone: String) -> Vector3:
	var chain: Array = []
	var i: int = sk.find_bone(bone)
	while i >= 0:
		chain.push_front(i)
		i = sk.get_bone_parent(i)
	var pos: Vector3 = s_rest[chain[0]].origin
	for k in range(1, chain.size()):
		var par: int = chain[k - 1]
		var rot: Quaternion = want.get(sk.get_bone_name(par), s_rest[par].basis.get_rotation_quaternion())
		var offset: Vector3 = s_rest[chain[k]].origin - s_rest[par].origin
		pos += rot * (s_rest[par].basis.get_rotation_quaternion().inverse() * offset)
	return pos


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
