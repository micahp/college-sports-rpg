extends RefCounted
## Anatomy measured from a skeleton's final pose (read inside a modifier tap,
## after every modifier), the same way the football validator measures palms:
##   elbow   flexion about the elbow's own hinge (0 straight, + toward the
##           front of the arm; a real elbow goes ~-5..150 deg), and how far the
##           forearm leaves the hinge plane (a real elbow barely does).
##   wrist   bend between hand and forearm, and twist of the hand about the
##           forearm (pronation/supination, about +-90 deg from neutral).
##   palm    centre point, outward normal (palm side), gap to a ball surface.
## Rest-pose conventions (checked on this rig): Y up, arms out to the sides,
## hands flat with the palm down, feet pointing forward.

const ARMS: Dictionary = {"R": ["RightUpperArm", "RightLowerArm", "RightHand"],
	"L": ["LeftUpperArm", "LeftLowerArm", "LeftHand"]}

## Limits, from human range of motion (not from what this game produces).
const ELBOW_FLEX_MIN: float = -10.0   # hyperextension beyond 10 deg is "bent the wrong way"
const ELBOW_FLEX_MAX: float = 150.0
const ELBOW_OFF_PLANE_MAX: float = 25.0
const WRIST_BEND_MAX: float = 80.0
const WRIST_TWIST_MAX: float = 100.0
## Shoulder (glenohumeral) range, relative to the chest, from the T-pose:
## rotation of the upper arm about its own length (internal/external) and
## how far the arm swings back behind the body or up past vertical.
const SHOULDER_TWIST_MAX: float = 95.0
const SHOULDER_BACK_MAX: float = 50.0   # extension behind the chest's side plane
const PALM_FROM_WRIST_M: float = 0.08  # wrist joint to the middle of the palm
const PALM_SKIN_M: float = 0.02

var _rest: Dictionary = {}  # skeleton id -> per-side rest data


func _rest_of(sk: Skeleton3D) -> Dictionary:
	var id: int = sk.get_instance_id()
	if _rest.has(id):
		return _rest[id]
	var r: Dictionary = {}
	# The body's front from the game itself, not from a rig convention: the
	# player's facing (court_actor.facing() is the model's +Z), brought into
	# skeleton space. A convention mistake in the game can't hide from this.
	var fwd: Vector3 = _front_from_model(sk)
	for side: String in ARMS:
		var ids: Array = []
		for b: String in ARMS[side]:
			ids.append(sk.find_bone(b))
		if ids.has(-1):
			continue
		var chest: int = sk.get_bone_parent(ids[0])  # shoulder/clavicle bone
		while chest >= 0 and not sk.get_bone_name(chest).contains("Chest") and sk.get_bone_parent(chest) >= 0:
			chest = sk.get_bone_parent(chest)
		var u0: Transform3D = sk.get_bone_global_rest(ids[0])
		var l0: Transform3D = sk.get_bone_global_rest(ids[1])
		var w0: Transform3D = sk.get_bone_global_rest(ids[2])
		var a0: Vector3 = (l0.origin - u0.origin).normalized()
		var f0: Vector3 = (w0.origin - l0.origin).normalized()
		var ub: Basis = u0.basis.orthonormalized().inverse()
		var wb: Basis = w0.basis.orthonormalized().inverse()
		r[side] = {
			"ids": ids,
			"hinge_l": (ub * a0).cross(ub * fwd).normalized(),  # in upper-arm space
			"hand_axis_l": wb * f0,                              # in hand space
			"palm_l": wb * Vector3.DOWN,                         # in hand space
			"rel0": (l0.basis.orthonormalized().inverse() * w0.basis.orthonormalized()),
			"zero_flex": 0.0, "zero_off": 0.0,
			"chest": chest,
			# upper arm relative to the chest at rest, and the arm/front axes in chest space
			"urel0": (sk.get_bone_global_rest(chest).basis.orthonormalized().inverse() * ub.inverse()) if chest >= 0 else Basis.IDENTITY,
			"a_c": (sk.get_bone_global_rest(chest).basis.orthonormalized().inverse() * a0) if chest >= 0 else a0,
			"front_c": (sk.get_bone_global_rest(chest).basis.orthonormalized().inverse() * fwd) if chest >= 0 else fwd,
		}
		# The rest (T-pose) arm is straight by definition: zero against it.
		var h0: Vector3 = (u0.basis.orthonormalized() * (r[side]["hinge_l"] as Vector3)).normalized()
		var front0: Vector3 = h0.cross(a0).normalized()
		r[side]["zero_flex"] = rad_to_deg(atan2(f0.dot(front0), f0.dot(a0)))
		r[side]["zero_off"] = rad_to_deg(asin(clampf(f0.dot(h0), -1.0, 1.0)))
	_rest[id] = r
	return r


static func _front_from_model(sk: Skeleton3D) -> Vector3:
	var n: Node = sk
	while n != null and n.get_parent() != null and not n.get_parent().has_method("facing"):
		n = n.get_parent()
	if n == null or not (n is Node3D) or n.get_parent() == null:
		return Vector3.BACK
	var facing_w: Vector3 = (n as Node3D).global_transform.basis.z.normalized()
	var f: Vector3 = sk.global_transform.basis.inverse() * facing_w
	f.y = 0.0
	return f.normalized()


## Everything for one arm, in world space (positions) and degrees (angles).
func arm(sk: Skeleton3D, side: String) -> Dictionary:
	var r: Dictionary = _rest_of(sk)
	if not r.has(side):
		return {}
	var d: Dictionary = r[side]
	var ids: Array = d["ids"]
	var u: Transform3D = sk.get_bone_global_pose(ids[0])
	var l: Transform3D = sk.get_bone_global_pose(ids[1])
	var w: Transform3D = sk.get_bone_global_pose(ids[2])
	var a: Vector3 = (l.origin - u.origin).normalized()
	var f: Vector3 = (w.origin - l.origin).normalized()
	var h: Vector3 = (u.basis.orthonormalized() * (d["hinge_l"] as Vector3)).normalized()
	var toward_front: Vector3 = h.cross(a).normalized()
	var flex: float = rad_to_deg(atan2(f.dot(toward_front), f.dot(a))) - float(d["zero_flex"])
	var off: float = rad_to_deg(asin(clampf(f.dot(h), -1.0, 1.0))) - float(d["zero_off"])
	var wb: Basis = w.basis.orthonormalized()
	var hand_axis: Vector3 = (wb * (d["hand_axis_l"] as Vector3)).normalized()
	var bend: float = rad_to_deg(hand_axis.angle_to(f))
	# Twist of the hand about its own axis relative to the forearm, vs rest.
	var rel: Basis = l.basis.orthonormalized().inverse() * wb
	var dq: Quaternion = (rel * (d["rel0"] as Basis).inverse()).get_rotation_quaternion()
	var ax: Vector3 = (l.basis.orthonormalized().inverse() * hand_axis).normalized()
	var proj: float = Vector3(dq.x, dq.y, dq.z).dot(ax)
	var twist: float = rad_to_deg(2.0 * atan2(proj, dq.w))
	twist = wrapf(twist, -180.0, 180.0)
	# Shoulder: the upper arm's rotation relative to the chest, against rest,
	# split into swing (where the arm points) and twist (about its length).
	var sh_twist: float = 0.0
	var sh_back: float = 0.0
	var arm_dir_c: Vector3 = Vector3.ZERO
	if int(d["chest"]) >= 0:
		var cb: Basis = sk.get_bone_global_pose(int(d["chest"])).basis.orthonormalized()
		var urel: Basis = cb.inverse() * ub_now(u)
		var dqs: Quaternion = (urel * (d["urel0"] as Basis).inverse()).get_rotation_quaternion()
		var a_c: Vector3 = (cb.inverse() * a).normalized()       # arm direction now, chest space
		arm_dir_c = a_c
		var a_c0: Vector3 = d["a_c"]
		# twist about the arm's own axis (rest axis rotated by the swing)
		var swing: Quaternion = Quaternion(a_c0, a_c)
		var tw: Quaternion = swing.inverse() * dqs
		var proj_s: float = Vector3(tw.x, tw.y, tw.z).dot(a_c0)
		sh_twist = rad_to_deg(wrapf(2.0 * atan2(proj_s, tw.w), -PI, PI))
		# swing behind the body: arm pointing backward of the chest's side plane
		var front_c: Vector3 = d["front_c"]
		sh_back = rad_to_deg(asin(clampf(-a_c.dot(front_c), -1.0, 1.0)))
	var to_world: Transform3D = sk.global_transform
	var wrist_w: Vector3 = to_world * w.origin
	var elbow_w: Vector3 = to_world * l.origin
	var palm_n: Vector3 = (to_world.basis * (wb * (d["palm_l"] as Vector3))).normalized()
	var axis_w: Vector3 = (to_world.basis * hand_axis).normalized()
	var palm_c: Vector3 = wrist_w + axis_w * PALM_FROM_WRIST_M + palm_n * PALM_SKIN_M
	return {"flex": flex, "off": off, "bend": bend, "twist": twist, "sh_twist": sh_twist, "sh_back": sh_back, "arm_dir_c": arm_dir_c,
		"wrist": wrist_w, "elbow": elbow_w, "palm": palm_c, "palm_n": palm_n}


static func ub_now(u: Transform3D) -> Basis:
	return u.basis.orthonormalized()


## Which human limits one arm breaks, as text ("" when none).
static func arm_faults(m: Dictionary) -> String:
	if m.is_empty():
		return ""
	var out: Array[String] = []
	if float(m["flex"]) < ELBOW_FLEX_MIN:
		out.append("elbow hyperextended %.0f deg" % float(m["flex"]))
	if float(m["flex"]) > ELBOW_FLEX_MAX:
		out.append("elbow over-flexed %.0f deg" % float(m["flex"]))
	if absf(float(m["off"])) > ELBOW_OFF_PLANE_MAX:
		out.append("elbow bends sideways %.0f deg" % float(m["off"]))
	if float(m["bend"]) > WRIST_BEND_MAX:
		out.append("wrist bent %.0f deg" % float(m["bend"]))
	if absf(float(m["twist"])) > WRIST_TWIST_MAX:
		out.append("wrist twisted %.0f deg" % float(m["twist"]))
	if absf(float(m.get("sh_twist", 0.0))) > SHOULDER_TWIST_MAX:
		out.append("upper arm rotated %.0f deg at the shoulder" % float(m["sh_twist"]))
	if float(m.get("sh_back", 0.0)) > SHOULDER_BACK_MAX:
		out.append("arm %.0f deg behind the body" % float(m["sh_back"]))
	return ", ".join(out)


## Palm against a ball: gap off the surface (+) or sunk into it (-), and how
## squarely the palm side faces the ball (1 = flat on it, < 0 = back of hand).
static func palm_on_ball(m: Dictionary, ball: Vector3, radius: float) -> Dictionary:
	var to_ball: Vector3 = ball - (m["palm"] as Vector3)
	return {"gap": to_ball.length() - radius, "facing": (m["palm_n"] as Vector3).dot(to_ball.normalized())}
