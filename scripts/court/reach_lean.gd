extends SkeletonModifier3D
## A swipe is thrown from the hips: the trunk bends toward the ball so the
## shoulder travels before the arm does. Bends the Spine about the hips toward
## `target` (world), across the floor, by up to MAX_LEAN at `amount` 1.
## Runs after TorsoPosture (which would straighten it) and before the arm IK
## (so the arm reaches from where the shoulder really is).

const MAX_LEAN: float = deg_to_rad(42.0)

var target: Vector3 = Vector3.ZERO
var amount: float = 0.0
## Trunk rotation about the vertical, radians, + turns the body's left side
## forward (so the right shoulder leads a right-handed swipe). The trunk turns
## ahead of the arm: the shoulder is carried through the swing, not just the arm.
var twist: float = 0.0

var _spine: int = -1
var _neck: int = -1
## How much of the trunk's forward lean the neck takes back out (the head stays up).
const HEAD_UP: float = 0.65


func _process_modification_with_delta(_delta: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null or (amount <= 0.001 and absf(twist) <= 0.001):
		return
	if _spine < 0:
		_spine = sk.find_bone("Spine")
		if _spine < 0:
			amount = 0.0
			return
	var pose: Transform3D = sk.get_bone_global_pose(_spine)
	var to: Vector3 = sk.global_transform.affine_inverse() * target - pose.origin
	to.y = 0.0
	var new_global: Basis = pose.basis
	var lean_axis: Vector3 = Vector3.ZERO
	var lean_ang: float = 0.0
	if to.length() >= 0.05 and amount > 0.001:
		lean_axis = Vector3.UP.cross(to.normalized()).normalized()
		lean_ang = MAX_LEAN * clampf(amount, 0.0, 1.0)
		new_global = Basis(lean_axis, lean_ang) * new_global
	if absf(twist) > 0.001:
		new_global = Basis(Vector3.UP, twist) * new_global
	# Written as a local rotation (as torso_posture.gd does), so the modifiers
	# after this, the arm IK above all, see the bent and turned trunk.
	var parent: int = sk.get_bone_parent(_spine)
	var pb: Basis = sk.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(_spine, (pb.inverse() * new_global).get_rotation_quaternion())
	# A local write leaves the chest, shoulders and arms' global poses stale
	# until the end of the frame, so the arm IK after this would reach from
	# the un-leaned shoulder (tests/swipe_pose_checks.gd caught the chest
	# reading upright inside the modifier pass). Refresh everything below.
	sk.force_update_bone_child_transform(_spine)
	# The head stays up: a defender bends at the waist but keeps his eyes on the
	# ball and the handler's hips. Take most of the lean back out at the neck.
	if lean_ang > 0.001:
		if _neck < 0:
			_neck = sk.find_bone("Neck")
		if _neck >= 0:
			var np: Transform3D = sk.get_bone_global_pose(_neck)
			sk.set_bone_global_pose(_neck, Transform3D(Basis(lean_axis, -lean_ang * HEAD_UP) * np.basis, np.origin))
			sk.force_update_bone_child_transform(_neck)
