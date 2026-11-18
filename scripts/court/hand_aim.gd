extends SkeletonModifier3D
## The arm IK only places the wrist; the palm just inherits the forearm's
## twist. This turns one hand so its palm faces `target` (world space), by
## the shortest rotation, blended by `weight`. The palm direction is taken
## from the rest pose, where the humanoid hand lies flat with the palm down.

var bone_name: String = "RightHand"
var target: Vector3 = Vector3.ZERO
var weight: float = 0.0

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
	var palm_now: Vector3 = pose.basis * _palm_local
	var turn: Quaternion = Quaternion(palm_now.normalized(), want.normalized())
	turn = Quaternion.IDENTITY.slerp(turn, clampf(weight, 0.0, 1.0))
	var new_basis: Basis = Basis(turn) * pose.basis
	var parent: int = sk.get_bone_parent(_bone)
	var parent_basis: Basis = sk.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(_bone, (parent_basis.inverse() * new_basis).get_rotation_quaternion())
