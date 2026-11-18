extends SkeletonModifier3D
## Several clips arrive with the whole torso folded far forward, on every
## body. Each frame this measures how far the line from hips to neck leans
## from vertical and eases the excess back: up to FREE degrees are left alone
## (an athletic lean, a defensive crouch), anything beyond is compressed to
## KEEP of itself. The turn is about the Spine bone, so the legs and hips
## are untouched.

const FREE: float = 6.0
const KEEP: float = 0.27
const MAX_PITCH: float = 60.0

var _hips: int = -1
var _spine: int = -1
var _neck: int = -1
var last_raw: float = 0.0
var last_out: float = 0.0


func _process_modification_with_delta(_delta: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		return
	if _hips < 0:
		_hips = sk.find_bone("Hips")
		_spine = sk.find_bone("Spine")
		_neck = sk.find_bone("Neck")
		if _hips < 0 or _spine < 0 or _neck < 0:
			_hips = -2
			return
	if _hips < 0:
		return
	var from: Vector3 = sk.get_bone_global_pose(_spine).origin
	var line: Vector3 = sk.get_bone_global_pose(_neck).origin - from
	if line.length() < 0.001:
		return
	var pitch: float = rad_to_deg(atan2(line.z, line.y))  # forward is +z in the skeleton
	last_raw = pitch
	var out: float = pitch
	if pitch > FREE:
		out = FREE + (pitch - FREE) * KEEP
	elif pitch < -FREE:
		out = -FREE + (pitch + FREE) * KEEP
	last_out = out
	var turn: float = deg_to_rad(out - pitch)
	if absf(turn) < 0.0005:
		return
	var pose: Transform3D = sk.get_bone_global_pose(_spine)
	var new_basis: Basis = Basis(Vector3.RIGHT, turn) * pose.basis
	var parent: int = sk.get_bone_parent(_spine)
	var parent_basis: Basis = sk.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(_spine, (parent_basis.inverse() * new_basis).get_rotation_quaternion())
