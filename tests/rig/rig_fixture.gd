extends RefCounted
## Shared fixture for the rig certification gates (docs/animation/RIG_CERTIFICATION.md).
##
## Builds a real court actor (court_actor.gd, the campus student rig with every
## modifier the game adds, in the game's order) and takes the game's control
## away from it: the AnimationTree is off, the actor's animate() is never
## called, and a PoseSource modifier at the head of the chain writes an exact
## input pose every frame. Taps after every modifier record what each one did.
## A gate then turns on only the layers it is testing.
##
## Spaces: "skeleton space" is the Skeleton3D's own space (+Y up, +Z the body's
## front, +X the body's left, checked by gate 1). World = skeleton global_transform.

const Actor = preload("res://scripts/court/court_actor.gd")

## The humanoid bones the gates measure, with the parent each must have.
const HIERARCHY: Dictionary = {
	"Hips": "", "Spine": "Hips", "Chest": "Spine", "UpperChest": "Chest", "Neck": "UpperChest", "Head": "Neck",
	"LeftShoulder": "UpperChest", "LeftUpperArm": "LeftShoulder", "LeftLowerArm": "LeftUpperArm", "LeftHand": "LeftLowerArm",
	"RightShoulder": "UpperChest", "RightUpperArm": "RightShoulder", "RightLowerArm": "RightUpperArm", "RightHand": "RightLowerArm",
	# The legs hang off Hips (the body controller), not Spine (the pelvis): see RIG_SPEC.md.
	"LeftUpperLeg": "Hips", "LeftLowerLeg": "LeftUpperLeg", "LeftFoot": "LeftLowerLeg",
	"RightUpperLeg": "Hips", "RightLowerLeg": "RightUpperLeg", "RightFoot": "RightLowerLeg",
}
const ARM: Dictionary = {"L": ["LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand"],
	"R": ["RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand"]}
const LEG: Dictionary = {"L": ["LeftUpperLeg", "LeftLowerLeg", "LeftFoot"],
	"R": ["RightUpperLeg", "RightLowerLeg", "RightFoot"]}


## Writes `pose` (bone index -> local Transform3D) first thing every frame, so
## every frame starts from exactly the same input whatever ran last frame.
class PoseSource extends SkeletonModifier3D:
	var pose: Dictionary = {}
	func _process_modification_with_delta(_delta: float) -> void:
		var sk := get_skeleton()
		for i: int in pose:
			sk.set_bone_pose(i, pose[i])
		sk.force_update_all_bone_transforms()


## Records every bone's skeleton-space global pose at its place in the chain.
class Tap extends SkeletonModifier3D:
	var g: Array = []  # bone index -> Transform3D, skeleton space
	var frames: int = 0
	func _process_modification_with_delta(_delta: float) -> void:
		var sk := get_skeleton()
		sk.force_update_all_bone_transforms()
		g.resize(sk.get_bone_count())
		for i in sk.get_bone_count():
			g[i] = sk.get_bone_global_pose(i)
		frames += 1


var actor: Node3D
var sk: Skeleton3D
var source: PoseSource
var first: Tap   # after the pose source: the input
var last: Tap    # after every modifier: what is drawn
var mods: Array = []  # the game's modifiers, in chain order
var taps: Dictionary = {}  # modifier label -> Tap right after it
var rest_local: Dictionary = {}


static func label(m: Node) -> String:
	if m is TwoBoneIK3D:
		var b: String = (m as TwoBoneIK3D).get_root_bone_name(0)
		return "arm_ik_" + ("L" if b.begins_with("Left") else "R")
	if m.get_script() == null:
		return m.get_class()
	var n: String = (m.get_script() as Script).resource_path.get_file().get_basename()
	if n == "":
		return str(m.name)  # a script without a file (a test's own modifier): its node name
	if n == "foot_floor" and bool(m.get("body_mode")):
		return "foot_floor_body"
	if n == "hand_aim":
		return "hand_aim_" + ("L" if str(m.get("bone_name")).begins_with("Left") else "R")
	return n


## parent: a node in the tree. Returns once the actor exists (call await settle()).
func build(parent: Node) -> void:
	actor = Actor.new()
	actor.team = 0
	parent.add_child(actor)
	actor.setup("guard", {})
	sk = CourtPlayerModel.find_skeleton(actor.get("_model"))
	var tree: AnimationTree = actor.get("_tree")
	tree.active = false
	(actor.get("_anim") as AnimationPlayer).stop()
	mods = sk.get_children().filter(func(c): return c is SkeletonModifier3D)
	sk.reset_bone_poses()
	for i in sk.get_bone_count():
		rest_local[i] = sk.get_bone_rest(i)
	source = PoseSource.new()
	source.pose = rest_local.duplicate()
	sk.add_child(source)
	sk.move_child(source, (mods[0] as Node).get_index())
	first = Tap.new()
	sk.add_child(first)
	sk.move_child(first, source.get_index() + 1)
	for m: Node in mods:
		var t := Tap.new()
		sk.add_child(t)
		sk.move_child(t, m.get_index() + 1)
		taps[label(m)] = t
	last = Tap.new()
	sk.add_child(last)
	only([])


func mod(name: String) -> SkeletonModifier3D:
	for m: SkeletonModifier3D in mods:
		if label(m) == name:
			return m
	return null


## Turn on only these modifiers (by label); everything else in the game chain off.
## active = false is the only real off switch (AGENTS.md rule 4).
func only(names: Array) -> void:
	for m: SkeletonModifier3D in mods:
		m.active = label(m) in names


## Let n frames run (modifiers process during the frame), then the taps hold this pose.
func settle(n: int = 2) -> void:
	for i in n:
		await actor.get_tree().process_frame


func bone(name: String) -> int:
	return sk.find_bone(name)


func gin(name: String) -> Transform3D:  # input, skeleton space
	return first.g[bone(name)]


func gout(name: String) -> Transform3D:  # drawn, skeleton space
	return last.g[bone(name)]


## Skeleton space -> world metres.
func world(p: Vector3) -> Vector3:
	return sk.global_transform * p


func to_sk(p: Vector3) -> Vector3:
	return sk.global_transform.affine_inverse() * p


func metres_per_unit() -> float:
	return sk.global_transform.basis.get_scale().x


# ---------------------------------------------------------------- poses

## Local poses of a clip at `time` (AnimationPlayer applied directly, tree off).
func clip_pose(clip: String, time: float) -> Dictionary:
	var ap: AnimationPlayer = actor.get("_anim")
	sk.reset_bone_poses()
	ap.play(clip)
	ap.seek(time, true)
	ap.advance(0)
	var out: Dictionary = {}
	for i in sk.get_bone_count():
		out[i] = sk.get_bone_pose(i)
	ap.stop()
	sk.reset_bone_poses()
	return out


## Builds a pose from the rest pose by turning bones about skeleton-space axes
## through their own joint, parents first. ops: [[bone, axis, degrees], ...]
## applied in order (a later op on a child sees the parent already turned).
func posed(ops: Array, from: Dictionary = {}) -> Dictionary:
	var base: Dictionary = rest_local if from.is_empty() else from
	for i: int in base:
		sk.set_bone_pose(i, base[i])
	sk.force_update_all_bone_transforms()
	for op: Array in ops:
		var b: int = bone(op[0])
		var g: Transform3D = sk.get_bone_global_pose(b)
		# Axis: a skeleton-space Vector3, or "x"/"y"/"z" = the bone's own axis as it lies now.
		var ax: Vector3 = g.basis["xyz".find(op[1])].normalized() if op[1] is String else (op[1] as Vector3).normalized()
		var r := Basis(ax, deg_to_rad(float(op[2])))
		var p: int = sk.get_bone_parent(b)
		var pg: Transform3D = sk.get_bone_global_pose(p) if p >= 0 else Transform3D.IDENTITY
		var want := Transform3D(r * g.basis, g.origin)
		sk.set_bone_pose(b, pg.affine_inverse() * want)
		sk.force_update_all_bone_transforms()
	var out: Dictionary = {}
	for i in sk.get_bone_count():
		out[i] = sk.get_bone_pose(i)
	sk.reset_bone_poses()
	return out


## Moves a bone by a skeleton-space offset (its local translation), e.g. the hips.
func shifted(pose: Dictionary, bone_name: String, offset: Vector3) -> Dictionary:
	var out := pose.duplicate()
	var b := bone(bone_name)
	var p := sk.get_bone_parent(b)
	for i: int in pose:
		sk.set_bone_pose(i, pose[i])
	sk.force_update_all_bone_transforms()
	var g: Transform3D = sk.get_bone_global_pose(b)
	g.origin += offset
	var pg: Transform3D = sk.get_bone_global_pose(p) if p >= 0 else Transform3D.IDENTITY
	out[b] = pg.affine_inverse() * g
	sk.reset_bone_poses()
	return out


## The input pose. Written into the skeleton as well as the pose source: game
## code that reads get_bone_global_pose() between frames (shoulder_position,
## _clamp_hand_target) must see it, as it sees the AnimationTree's pose in the
## game. The pose source then re-applies it inside every modifier pass.
func use(pose: Dictionary) -> void:
	source.pose = pose
	for i: int in pose:
		sk.set_bone_pose(i, pose[i])
	sk.force_update_all_bone_transforms()


# ---------------------------------------------------------------- measures

## Degrees between two bases, whole matrices (bones carry scale, some mirrored):
## the rotation in a^-1 * b. 999 = handedness flipped.
static func angle(a: Basis, b: Basis) -> float:
	var m: Basis = a.orthonormalized().inverse() * b.orthonormalized()
	if m.determinant() < 0.0:
		return 999.0
	var d := rad_to_deg(m.get_rotation_quaternion().get_angle())
	return minf(d, 360.0 - d)


## Largest change any listed bone made between the input and the drawn pose:
## [max deg, bone, max cm, bone].
func change(bones: Array, from: Tap = null, to: Tap = null) -> Array:
	var a: Tap = first if from == null else from
	var b: Tap = last if to == null else to
	var worst := [0.0, "", 0.0, ""]
	var k := metres_per_unit() * 100.0
	for n: String in bones:
		var i := bone(n)
		if i < 0:
			continue
		var d := angle((a.g[i] as Transform3D).basis, (b.g[i] as Transform3D).basis)
		var cm := (a.g[i] as Transform3D).origin.distance_to((b.g[i] as Transform3D).origin) * k
		if d > worst[0]:
			worst[0] = d
			worst[1] = n
		if cm > worst[2]:
			worst[2] = cm
			worst[3] = n
	return worst


static func all_body() -> Array:
	return HIERARCHY.keys()


# ---------------------------------------------------------------- anatomy
## Joint angles of a limb as an anatomist would read them, from skeleton-space
## globals (a Tap's g array). Conventions (RIG_SPEC.md, checked by gate 1):
##   elbow: hinge axis = upper-arm direction x body front (at rest); flex 0 =
##     the rest arm, + folds the forearm toward the front.
##   knee: hinge axis = thigh direction x body back; + folds the shin back.
##   off_hinge: how far the distal segment leaves the hinge plane (a sideways
##     bend: not anatomical). twist: distal bone's roll about its own length
##     relative to neutral (forearm pronation / shin rotation).
##   humeral: upper arm's roll about its length relative to the chest, measured
##     after the shortest swing from the rest arm (the same reference
##     elbow_hinge.gd uses). wrist: hand's turn off the forearm, from rest.

func limb_rest(kind: String, side: String) -> Dictionary:
	var names: Array = (ARM if kind == "arm" else LEG)[side]
	var b0: String = names[1] if kind == "arm" else names[0]
	var b1: String = names[2] if kind == "arm" else names[1]
	var b2: String = names[3] if kind == "arm" else names[2]
	var u0: Transform3D = sk.get_bone_global_rest(bone(b0))
	var l0: Transform3D = sk.get_bone_global_rest(bone(b1))
	var w0: Transform3D = sk.get_bone_global_rest(bone(b2))
	var a0 := (l0.origin - u0.origin).normalized()
	var f0 := (w0.origin - l0.origin).normalized()
	var fold: Vector3 = Vector3.BACK if kind == "arm" else Vector3.FORWARD  # +Z is the body front; FORWARD is -Z
	var h0 := a0.cross((fold - a0 * a0.dot(fold)).normalized()).normalized()
	var ub := u0.basis.orthonormalized()
	var lb := l0.basis.orthonormalized()
	var ref: int = bone("UpperChest") if kind == "arm" else bone("Hips")
	var cb := sk.get_bone_global_rest(ref).basis.orthonormalized()
	return {"b": [bone(b0), bone(b1), bone(b2)], "ref": ref,
		"hinge_u": ub.inverse() * h0, "f0_u": ub.inverse() * f0,
		"rel0": ub.inverse() * lb, "hrel0": lb.inverse() * w0.basis.orthonormalized(),
		"a_c0": cb.inverse() * a0, "urel0": cb.inverse() * ub,
		"len": u0.origin.distance_to(l0.origin) + l0.origin.distance_to(w0.origin)}


static func _twist_about(q: Quaternion, axis: Vector3) -> float:
	var p: float = Vector3(q.x, q.y, q.z).dot(axis.normalized())
	return rad_to_deg(wrapf(2.0 * atan2(p, q.w), -PI, PI))


## g: a Tap's array. Returns flex, off_hinge, twist, humeral (deg) and the joint positions.
func limb(g: Array, r: Dictionary) -> Dictionary:
	var ids: Array = r["b"]
	var u: Transform3D = g[ids[0]]
	var l: Transform3D = g[ids[1]]
	var w: Transform3D = g[ids[2]]
	var ub := u.basis.orthonormalized()
	var lb := l.basis.orthonormalized()
	var h: Vector3 = (ub * (r["hinge_u"] as Vector3)).normalized()
	var straight: Vector3 = (ub * (r["f0_u"] as Vector3)).normalized()
	var f := (w.origin - l.origin).normalized()
	var off := rad_to_deg(asin(clampf(f.dot(h), -1.0, 1.0)) - asin(clampf(straight.dot(h), -1.0, 1.0)))
	var fp := (f - h * f.dot(h)).normalized()
	var sp := (straight - h * straight.dot(h)).normalized()
	var flex := rad_to_deg(sp.signed_angle_to(fp, h))
	# Distal twist: remove the flex, what is left is a roll about the rest distal axis.
	var d: Basis = (ub.inverse() * lb) * (r["rel0"] as Basis).inverse()
	var unflexed: Quaternion = Quaternion(r["hinge_u"], -deg_to_rad(flex)) * d.get_rotation_quaternion()
	var twist := _twist_about(unflexed, r["f0_u"])
	# Humeral / femoral roll against the chest / hips.
	var cb: Basis = (g[r["ref"]] as Transform3D).basis.orthonormalized()
	var a_c: Vector3 = (cb.inverse() * (l.origin - u.origin)).normalized()
	var urel: Basis = cb.inverse() * ub
	var sw := Quaternion(r["a_c0"], a_c)
	var tw: Quaternion = sw.inverse() * (urel * (r["urel0"] as Basis).inverse()).get_rotation_quaternion()
	var roll := _twist_about(tw, r["a_c0"])
	var wrist := angle(lb * (r["hrel0"] as Basis), w.basis)
	return {"flex": flex, "off": off, "twist": twist, "roll": roll, "wrist": wrist,
		"s": u.origin, "e": l.origin, "w": w.origin}


# ---------------------------------------------------------------- reporting

var failures: Array = []
var checks: int = 0


func check(ok: bool, what: String, detail: String) -> bool:
	checks += 1
	print("  %s %s: %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures.append(what)
	return ok


func note(what: String, detail: String) -> void:
	print("  NOTE %s: %s" % [what, detail])


## A capability the game does not require (leg IK): reported, never a gate failure.
func optional(ok: bool, what: String, detail: String) -> void:
	print("  OPTIONAL %s %s: %s" % ["PASS" if ok else "FAIL", what, detail])


## A gameplay policy, not a property of the rig (the reach cap): reported for a decision.
func policy(what: String, detail: String) -> void:
	print("  POLICY %s: %s" % [what, detail])


func finish(tree: SceneTree, gate: String) -> void:
	print("%s: %d checks, %d failed%s" % [gate, checks, failures.size(), "" if failures.is_empty() else " -> FAIL"])
	tree.quit(0 if failures.is_empty() else 1)


## Faults the gates must catch (RIG_CERTIFICATION.md, sensitivity). Passed as
## `-- fault=<name>`; each gate applies the ones it is meant to detect.
static func fault() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("fault="):
			return a.substr(6)
	return ""
