extends SkeletonModifier3D
## The arm IK only places the wrist; the palm just inherits the forearm's
## twist. This turns one hand so its palm faces `target` (world space),
## blended by `weight`: first a twist about the forearm (how a real hand turns
## its palm), then the small wrist bend that is left. One shortest rotation
## instead folded the wrist over when the palm had to turn ~180 deg (a contest
## arm raised with the palm facing back): the hinge then held that bend to its
## limit and the palm ended up facing the sky. The palm direction is taken
## from the rest pose, where the humanoid hand lies flat with the palm down.

var bone_name: String = "RightHand"
var target: Vector3 = Vector3.ZERO
var weight: float = 0.0
## Twist about the forearm first (see above). On for the shot contest only:
## the dribbling hand keeps the single shortest rotation until it has its own
## pose check (turning it on there added pose pops in court_runtime_qa).
var twist_first: bool = false

var _bone: int = -1
var _palm_local: Vector3 = Vector3.DOWN


func _process_modification_with_delta(_delta: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null or weight <= 0.001:
		return
	if _bone < 0:
		_bone = sk.find_bone(bone_name)
		if _bone < 0:
			weight = 0.0
			return
		_palm_local = sk.get_bone_global_rest(_bone).basis.inverse() * Vector3.DOWN
	var pose: Transform3D = sk.get_bone_global_pose(_bone)
	var want: Vector3 = sk.global_transform.affine_inverse() * target - pose.origin
	if want.length() < 0.001:
		return
	var parent: int = sk.get_bone_parent(_bone)
	var w: Vector3 = want.normalized()
	var start: Basis = pose.basis
	if twist_first and parent >= 0:
		var along: Vector3 = pose.origin - sk.get_bone_global_pose(parent).origin
		if along.length() > 0.001:
			along = along.normalized()
			var p_perp: Vector3 = (pose.basis * _palm_local).slide(along)
			var w_perp: Vector3 = w.slide(along)
			if p_perp.length() > 0.05 and w_perp.length() > 0.05:
				start = Basis(along, p_perp.signed_angle_to(w_perp, along)) * start
	var palm_now: Vector3 = (start * _palm_local).normalized()
	var bend: Quaternion = Quaternion(palm_now, w)
	# Blend from the pose: weight scales the twist and the bend together.
	var full: Basis = Basis(bend) * start
	var turn: Quaternion = (full.orthonormalized() * pose.basis.orthonormalized().inverse()).get_rotation_quaternion()
	turn = Quaternion.IDENTITY.slerp(turn, clampf(weight, 0.0, 1.0))
	var new_basis: Basis = Basis(turn) * pose.basis
	var parent_basis: Basis = sk.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(_bone, (parent_basis.inverse() * new_basis).get_rotation_quaternion())
