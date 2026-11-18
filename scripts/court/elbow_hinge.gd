extends SkeletonModifier3D
## Runs last on the arms. The IK, the torso clearance and the palm aim each
## turn arm bones by the shortest rotation, which puts the shoulder, elbow and
## wrist where they should be but leaves the elbow bent about whatever axis
## that rotation happened to use: sideways, or backwards. A real elbow is a
## hinge. This keeps the three joint positions and rebuilds the arm as a body
## could make it:
##   1. turn the upper arm about its own length so the elbow's hinge lies
##      across the plane of the arm and the forearm folds toward the front
##   2. the forearm is the rest forearm bent about that hinge (0-150 deg)
##   3. the hand keeps its orientation, but its twist about the forearm is
##      moved into the forearm (pronation/supination, +-TWIST_MAX of neutral)
##      and its bend off the forearm is held to WRIST_BEND_MAX.
## Rest-pose conventions: the T-pose arm is straight, palm down (forearm
## neutral), and the feet point forward.

const ARMS: Dictionary = {"R": ["RightUpperArm", "RightLowerArm", "RightHand"],
	"L": ["LeftUpperArm", "LeftLowerArm", "LeftHand"]}
const TWIST_MAX: float = deg_to_rad(88.0)
const WRIST_BEND_MAX: float = deg_to_rad(70.0)
const FLEX_MAX: float = deg_to_rad(148.0)

## Optional palm contact per side, solved here, last, from where the body
## ended up (like the football tackler's palms in gridiron pair.js):
## {"point": world palm-centre goal, "face": world point the palm faces,
##  "weight": 0..1}. Set by court_actor each frame; empty = off.
var palm_goal: Dictionary = {}
var debug_print: bool = false
const PALM_FROM_WRIST: float = 0.08  # same palm point as tests/body_metrics.gd
const PALM_SKIN: float = 0.02

var _d: Dictionary = {}
var _ready_done: bool = false


func _setup(sk: Skeleton3D) -> void:
	_ready_done = true
	for side: String in ARMS:
		var fwd: Vector3 = front_of(sk, side)
		var ids: Array = []
		for b: String in ARMS[side]:
			ids.append(sk.find_bone(b))
		if ids.has(-1):
			continue
		var u0: Transform3D = sk.get_bone_global_rest(ids[0])
		var l0: Transform3D = sk.get_bone_global_rest(ids[1])
		var w0: Transform3D = sk.get_bone_global_rest(ids[2])
		var ub: Basis = u0.basis.orthonormalized()
		var lb: Basis = l0.basis.orthonormalized()
		var wb: Basis = w0.basis.orthonormalized()
		var a0: Vector3 = (l0.origin - u0.origin).normalized()
		var f0: Vector3 = (w0.origin - l0.origin).normalized()
		var front: Vector3 = (fwd - a0 * a0.dot(fwd)).normalized()
		# The chest: the shoulder's range is measured against it.
		var chest: int = sk.get_bone_parent(ids[0])
		while chest >= 0 and not sk.get_bone_name(chest).contains("Chest") and sk.get_bone_parent(chest) >= 0:
			chest = sk.get_bone_parent(chest)
		var cb0: Basis = sk.get_bone_global_rest(chest).basis.orthonormalized() if chest >= 0 else Basis.IDENTITY
		_d[side] = {
			"chest": chest,
			"urel0": cb0.inverse() * ub,       # upper arm relative to the chest at rest
			"a_c0": cb0.inverse() * a0,        # rest arm direction, chest space
			"front_c": cb0.inverse() * fwd,    # the body's front, chest space
			"len_u": u0.origin.distance_to(l0.origin),
			"len_l": l0.origin.distance_to(w0.origin),
			"ids": ids,
			"hinge_l": ub.inverse() * a0.cross(front).normalized(),
			"lrel0": ub.inverse() * lb,        # forearm relative to upper arm, straight & neutral
			"fdir_l": lb.inverse() * f0,       # forearm direction in forearm space
			"hrel0": lb.inverse() * wb,        # hand relative to forearm, flat & untwisted
			"palm_l": wb.inverse() * Vector3.DOWN,  # palm side, in hand space (palm down at rest)
		}


## The side of the arm the forearm folds toward, in skeleton space at rest.
## The rig's elbow convention is the IK pole axis (court_actor POLE_AXIS):
## the elbow bends toward the forearm's local +Z, which on this rig is the
## body's front (checked against the player's facing: the mocap's elbows
## fold along +Z, and +Z is where the player faces).
static func front_of(sk: Skeleton3D, side: String) -> Vector3:
	var lower: int = sk.find_bone(ARMS[side][1])
	if lower < 0:
		return Vector3.BACK
	return (sk.get_bone_global_rest(lower).basis.orthonormalized() * Vector3.BACK).normalized()


func _process_modification_with_delta(_delta: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		return
	if not _ready_done:
		_setup(sk)
	# Modifiers before this write local poses; the global poses they leave
	# behind can be stale until the frame ends (a leaned or crouched trunk
	# would still read upright here). Bring every bone up to date first.
	sk.force_update_all_bone_transforms()
	for side: String in _d:
		_fix_arm(sk, _d[side])
		var g: Dictionary = palm_goal.get(side, {})
		if not g.is_empty() and float(g.get("weight", 0.0)) > 0.001:
			for i in 3:
				_palm_contact(sk, _d[side], g)
				_fix_arm(sk, _d[side])


## World -> skeleton space.
func _to_sk(sk: Skeleton3D, p: Vector3) -> Vector3:
	return sk.global_transform.affine_inverse() * p


## Palm centre of the hand as posed (skeleton space), and its outward normal.
func _palm(sk: Skeleton3D, d: Dictionary) -> Array:
	var ids: Array = d["ids"]
	var w: Transform3D = sk.get_bone_global_pose(ids[2])
	var hrel0: Basis = d["hrel0"]
	var fdir_l: Vector3 = d["fdir_l"]
	var wb: Basis = w.basis.orthonormalized()
	var axis: Vector3 = (wb * (hrel0.inverse() * fdir_l)).normalized()
	var normal: Vector3 = (wb * (d["palm_l"] as Vector3)).normalized()
	# Distances are in world metres; the skeleton space is scaled.
	var k: float = 1.0 / sk.global_transform.basis.get_scale().x
	return [w.origin + axis * PALM_FROM_WRIST * k + normal * PALM_SKIN * k, normal]


## One pass of palm contact: face the palm at the goal's face point (within
## the wrist's range), bend the elbow about its hinge so the palm is as far
## from the shoulder as the goal, then swing the whole arm about the shoulder
## so the palm lands on the goal. Weighted by the goal's weight.
func _palm_contact(sk: Skeleton3D, d: Dictionary, g: Dictionary) -> void:
	var ids: Array = d["ids"]
	var wgt: float = clampf(float(g["weight"]), 0.0, 1.0)
	var goal: Vector3 = _to_sk(sk, g["point"])
	var face: Vector3 = _to_sk(sk, g["face"])
	# 1. Palm toward the face point (hand about the wrist).
	var w: Transform3D = sk.get_bone_global_pose(ids[2])
	var pn: Array = _palm(sk, d)
	var want_n: Vector3 = (face - (pn[0] as Vector3)).normalized()
	var turn: Quaternion = Quaternion((pn[1] as Vector3), want_n)
	turn = Quaternion.IDENTITY.slerp(turn, wgt)
	sk.set_bone_global_pose(ids[2], Transform3D(Basis(turn) * w.basis, w.origin))
	_fix_arm(sk, d)  # keeps the wrist inside its limits, twist into the forearm
	# 2. Elbow: hinge angle so |shoulder -> palm| matches |shoulder -> goal|.
	var u: Transform3D = sk.get_bone_global_pose(ids[0])
	var l: Transform3D = sk.get_bone_global_pose(ids[1])
	var s: Vector3 = u.origin
	var e: Vector3 = l.origin
	var h: Vector3 = (u.basis.orthonormalized() * (d["hinge_l"] as Vector3)).normalized()
	var p0: Vector3 = _palm(sk, d)[0]
	var want_len: float = s.distance_to(goal)
	var flex_now: float = _flex(sk, d)
	var lo: float = -flex_now
	var hi: float = FLEX_MAX - flex_now
	var best: float = 0.0
	var best_err: float = INF
	for i in 24:  # coarse-to-fine scan over the allowed hinge range
		var tdelta: float = lerpf(lo, hi, float(i) / 23.0)
		var p: Vector3 = e + Basis(h, tdelta) * (p0 - e)
		var err: float = absf(s.distance_to(p) - want_len)
		if err < best_err:
			best_err = err
			best = tdelta
	var step: float = (hi - lo) / 23.0
	for i in 12:
		for cand: float in [best - step, best + step]:
			if cand < lo or cand > hi:
				continue
			var p2: Vector3 = e + Basis(h, cand) * (p0 - e)
			var err2: float = absf(s.distance_to(p2) - want_len)
			if err2 < best_err:
				best_err = err2
				best = cand
		step *= 0.5
	best *= wgt
	# (children follow their parent's pose: only the forearm is written)
	sk.set_bone_global_pose(ids[1], Transform3D(Basis(h, best) * l.basis, l.origin))
	# 3. Swing the arm about the shoulder so the palm points at the goal.
	var p1: Vector3 = _palm(sk, d)[0]
	var swing: Quaternion = Quaternion((p1 - s).normalized(), (goal - s).normalized())
	swing = Quaternion.IDENTITY.slerp(swing, wgt)
	var u2: Transform3D = sk.get_bone_global_pose(ids[0])
	sk.set_bone_global_pose(ids[0], Transform3D(Basis(swing) * u2.basis, u2.origin))


## Elbow flexion in radians about the hinge, from the straight rest arm.
func _flex(sk: Skeleton3D, d: Dictionary) -> float:
	var ids: Array = d["ids"]
	var u: Transform3D = sk.get_bone_global_pose(ids[0])
	var l: Transform3D = sk.get_bone_global_pose(ids[1])
	var w: Transform3D = sk.get_bone_global_pose(ids[2])
	var h: Vector3 = (u.basis.orthonormalized() * (d["hinge_l"] as Vector3)).normalized()
	var lb: Basis = u.basis.orthonormalized() * (d["lrel0"] as Basis)
	return (lb * (d["fdir_l"] as Vector3)).signed_angle_to((w.origin - l.origin).normalized(), h)


func _fix_arm(sk: Skeleton3D, d: Dictionary) -> void:
	var ids: Array = d["ids"]
	var u: Transform3D = sk.get_bone_global_pose(ids[0])
	var l: Transform3D = sk.get_bone_global_pose(ids[1])
	var w: Transform3D = sk.get_bone_global_pose(ids[2])
	var a: Vector3 = (l.origin - u.origin).normalized()
	var f: Vector3 = (w.origin - l.origin).normalized()
	if a.length() < 0.5 or f.length() < 0.5:
		return
	var hinge_l: Vector3 = d["hinge_l"]
	# 1. Upper arm, chosen the way a real arm is: the wrist stays where the
	#    pose put it, the elbow may move around the shoulder-wrist line (the
	#    swivel), and the upper arm's rotation about its own length stays in
	#    the shoulder's range. Closest swivel to the pose's elbow wins.
	var sol: Dictionary = _solve_upper(sk, d, u, l, w)
	var ub: Basis = sol["ub"]
	a = sol["a"]
	f = sol["f"]
	var h: Vector3 = (ub * hinge_l).normalized()
	# 2. Forearm: straight-and-neutral, bent about the hinge to point along f.
	var lb: Basis = ub * (d["lrel0"] as Basis)
	var fdir_l: Vector3 = d["fdir_l"]
	var raw: float = (lb * fdir_l).signed_angle_to(f, h)
	var theta: float = clampf(raw, 0.0, FLEX_MAX)
	lb = Basis(h, theta) * lb
	var now_dir: Vector3 = (lb * fdir_l).normalized()
	if is_equal_approx(theta, raw) and now_dir.angle_to(f) > 0.001:
		lb = Basis(Quaternion(now_dir, f)) * lb  # small residual (rest arm not dead straight)
	# (when the bend was clamped the wrist moves with it: an elbow can't fold further)
	var neutral: Basis = lb
	# 3. Hand: wanted orientation is what the pose has now. Its twist about the
	#    forearm (relative to a flat, untwisted hand) goes into the forearm.
	var hrel0: Basis = d["hrel0"]
	var hb_want: Basis = w.basis.orthonormalized()
	var flat: Basis = neutral * hrel0
	# Twist about the forearm as it now lies (not the pose's direction: if the
	# bend was clamped they differ, and twisting about the old one swings the
	# forearm back past straight).
	var fa: Vector3 = (neutral * fdir_l).normalized()
	var dq: Quaternion = (hb_want * flat.inverse()).get_rotation_quaternion()
	var proj: float = Vector3(dq.x, dq.y, dq.z).dot(fa)
	var twist: float = wrapf(2.0 * atan2(proj, dq.w), -PI, PI)
	twist = clampf(twist, -TWIST_MAX, TWIST_MAX)
	lb = Basis(fa, twist) * neutral
	# Hand: same wanted orientation, minus any twist the forearm couldn't take,
	# and bent off the forearm by at most WRIST_BEND_MAX.
	var flat_tw: Basis = lb * hrel0
	var hand_axis_l: Vector3 = hrel0.inverse() * fdir_l  # hand's own axis, in hand space
	var want_axis: Vector3 = (hb_want * hand_axis_l).normalized()
	var swing: Quaternion = Quaternion((flat_tw * hand_axis_l).normalized(), want_axis)
	var ang: float = swing.get_angle()
	if ang > WRIST_BEND_MAX:
		swing = Quaternion.IDENTITY.slerp(swing, WRIST_BEND_MAX / ang)
	var hb: Basis = Basis(swing) * flat_tw
	# Write back as whole global poses, parent first, keeping each bone's own
	# scale (the rig's bones carry build scale) and its joint position: only
	# the orientation changes, so shoulder, elbow and wrist stay where they were.
	# Each joint's position is read back from its parent after the parent is
	# written, so no bone is ever stretched.
	sk.set_bone_global_pose(ids[0], Transform3D(ub * _scale_of(u.basis), u.origin))
	sk.set_bone_global_pose(ids[1], Transform3D(lb * _scale_of(l.basis), sk.get_bone_global_pose(ids[1]).origin))
	sk.set_bone_global_pose(ids[2], Transform3D(hb * _scale_of(w.basis), sk.get_bone_global_pose(ids[2]).origin))


const SHOULDER_TWIST_MAX: float = deg_to_rad(85.0)  # humeral rotation, either way of neutral
const SWIVEL_STEP: float = deg_to_rad(10.0)
const SHOULDER_BACK_OK_DEG: float = 25.0  # past this behind the body, an elbow choice costs more
const STRAIGHT_DEADBAND: float = deg_to_rad(10.0)  # within this of straight, the bend can't set the twist


## Upper-arm orientation for one arm: swing from the rest (chest-relative)
## to point at the elbow, then the twist about the arm that makes the elbow's
## hinge fold the forearm toward the wrist. Tries the pose's own elbow first,
## then elbows swivelled around the shoulder-wrist line, until that twist is
## inside SHOULDER_TWIST_MAX. Returns {"ub", "a", "f"} (skeleton space).
func _solve_upper(sk: Skeleton3D, d: Dictionary, u: Transform3D, l: Transform3D, w: Transform3D) -> Dictionary:
	var s: Vector3 = u.origin
	var e0: Vector3 = l.origin
	var wr: Vector3 = w.origin
	var cb: Basis = sk.get_bone_global_pose(int(d["chest"])).basis.orthonormalized() if int(d["chest"]) >= 0 else Basis.IDENTITY
	var urel0: Basis = d["urel0"]
	var a_c0: Vector3 = d["a_c0"]
	var hinge_l: Vector3 = d["hinge_l"]
	var f0_u: Vector3 = ((d["lrel0"] as Basis) * (d["fdir_l"] as Vector3)).normalized()  # rest forearm, upper-arm space
	var l1: float = s.distance_to(e0)
	var l2: float = e0.distance_to(wr)
	var sw: Vector3 = wr - s
	var dist: float = clampf(sw.length(), absf(l1 - l2) + 0.0001, l1 + l2 - 0.0001)
	var k: Vector3 = sw.normalized()
	var x: float = (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var r: float = sqrt(maxf(0.0, l1 * l1 - x * x))
	var u1: Vector3 = (e0 - s) - k * (e0 - s).dot(k)
	if u1.length() < 0.0001:
		u1 = k.cross(Vector3.UP) if absf(k.dot(Vector3.UP)) < 0.9 else k.cross(Vector3.RIGHT)
	u1 = u1.normalized()
	var u2: Vector3 = k.cross(u1)
	var best: Dictionary = {}
	var best_cost: float = INF
	var steps: int = int(PI / SWIVEL_STEP)
	# Torso, for keeping the elbow outside it: an elliptic cylinder up the
	# hips-to-neck line, sized from the shoulder joints (as arm_clearance.gd).
	var torso: Dictionary = _torso(sk)
	# Last frame's upper-arm direction (chest space): a shoulder moves
	# continuously, so a candidate that jumps from it costs. Without this the
	# solver flips between near-equal elbows from one frame to the next.
	var prev_ac: Vector3 = d.get("prev_ac", Vector3.ZERO)
	for i in range(0, 2 * steps + 1):
		var phi: float = (float((i + 1) / 2) * SWIVEL_STEP) * (1.0 if i % 2 == 1 else -1.0)
		var e: Vector3 = s + k * x + (u1 * cos(phi) + u2 * sin(phi)) * r
		var a: Vector3 = (e - s).normalized()
		var f: Vector3 = (wr - e).normalized()
		var a_c: Vector3 = (cb.inverse() * a).normalized()
		var u_swing: Basis = cb * Basis(Quaternion(a_c0, a_c)) * urel0  # no twist
		# The pose's own twist (only meaningful at the pose's elbow).
		var cur_c: Basis = cb.inverse() * u.basis.orthonormalized()
		var dq: Quaternion = (cur_c * urel0.inverse()).get_rotation_quaternion()
		var tw: Quaternion = Quaternion(a_c0, a_c).inverse() * dq
		var tau_pose: float = wrapf(2.0 * atan2(Vector3(tw.x, tw.y, tw.z).dot(a_c0), tw.w), -PI, PI)
		# Bend is measured from the rest forearm, not the upper arm's line: this
		# rig's T-pose forearm already sits ~7 deg off it, and measuring from the
		# line reads a nearly straight arm as bent backwards (and "fixes" it by
		# spinning the upper arm ~160 deg).
		var tau: float = tau_pose
		var straight: Vector3 = (Basis(a, tau) * u_swing * f0_u).normalized()
		if straight.angle_to(f) > STRAIGHT_DEADBAND:
			for it in 3:  # the rest forearm turns with the twist: converge
				straight = (Basis(a, tau) * u_swing * f0_u).normalized()
				var perp: Vector3 = f - straight * straight.dot(f)
				if perp.length() < 0.0001:
					break
				var front: Vector3 = (Basis(a, tau) * u_swing * hinge_l).normalized().cross(straight).normalized()
				tau = wrapf(tau + front.signed_angle_to(perp.normalized(), straight), -PI, PI)
		else:
			tau = clampf(tau_pose, -SHOULDER_TWIST_MAX, SHOULDER_TWIST_MAX)  # nearly straight: keep its twist
		var over: float = maxf(0.0, absf(tau) - SHOULDER_TWIST_MAX)
		# A body holds its arm with little shoulder rotation when it can: cost
		# grows with rotation and with distance from the pose's elbow, and an
		# elbow inside the torso is ruled out.
		# Shoulder extension: an upper arm well behind the body's side plane is
		# out of range (about 50 deg); a relaxed arm hangs only a little back.
		var back: float = asin(clampf(-a_c.dot(d["front_c"]), -1.0, 1.0))
		var back_over: float = maxf(0.0, back - deg_to_rad(SHOULDER_BACK_OK_DEG))
		var cost: float = over * 100.0 + back_over * 6.0 + absf(tau) * 0.7 + absf(phi) * 0.35 \
			+ _inside_torso(torso, e) * 20.0 \
			+ (a_c.angle_to(prev_ac) * 3.0 if prev_ac != Vector3.ZERO else 0.0)
		if debug_print and (i == 0 or cost < best_cost):
			print("  swivel %4.0f  tau %5.0f  back %4.0f  torso %.2f  cost %.3f" % [rad_to_deg(phi), rad_to_deg(tau), rad_to_deg(back), _inside_torso(torso, e), cost])
		if cost < best_cost:
			best_cost = cost
			var tau_c: float = clampf(tau, -SHOULDER_TWIST_MAX, SHOULDER_TWIST_MAX)
			best = {"ub": Basis(a, tau_c) * u_swing, "a": a, "f": f, "a_c": a_c}
		if r < 0.0001:
			break  # straight arm: every swivel is the same
	d["prev_ac"] = best["a_c"]
	return best


func _torso(sk: Skeleton3D) -> Dictionary:
	var hips: int = sk.find_bone("Hips")
	var neck: int = sk.find_bone("Neck")
	var r_id: Array = (_d.get("R", {}) as Dictionary).get("ids", [])
	var l_id: Array = (_d.get("L", {}) as Dictionary).get("ids", [])
	if hips < 0 or neck < 0 or r_id.is_empty() or l_id.is_empty():
		return {}
	var ur: Vector3 = sk.get_bone_global_pose(r_id[0]).origin
	var ul: Vector3 = sk.get_bone_global_pose(l_id[0]).origin
	var hp: Vector3 = sk.get_bone_global_pose(hips).origin
	var nk: Vector3 = sk.get_bone_global_pose(neck).origin
	var axis: Vector3 = (nk - hp).normalized()
	var lat: Vector3 = (ur - ul)
	lat = (lat - axis * lat.dot(axis)).normalized()
	return {"hip": hp, "neck": nk, "axis": axis, "lat": lat, "fwd": lat.cross(axis).normalized(),
		"a": ur.distance_to(ul) * 0.5 * 0.9, "b": ur.distance_to(ul) * 0.5 * 0.75}


## How far inside the torso a point is (0 = outside), in torso half-widths.
func _inside_torso(t: Dictionary, p: Vector3) -> float:
	if t.is_empty():
		return 0.0
	var rel: Vector3 = p - (t["hip"] as Vector3)
	var along: float = rel.dot(t["axis"])
	if along < 0.0 or along > (t["neck"] as Vector3).distance_to(t["hip"]):
		return 0.0
	var x: float = rel.dot(t["lat"]) / float(t["a"])
	var z: float = rel.dot(t["fwd"]) / float(t["b"])
	return maxf(0.0, 1.0 - sqrt(x * x + z * z))


## The scale/shear part of a bone basis (what is left after its rotation).
static func _scale_of(b: Basis) -> Basis:
	return b.orthonormalized().inverse() * b
