extends SkeletonModifier3D
## Mocap comes from a performer with a different chest. Retargeted onto a
## body with a thicker torso, the elbows and forearms cut through the ribs
## and the arms read as folded into the torso. This runs after the
## animation (and the hand IK) and swings each arm out until the elbow and
## the middle of the forearm sit outside an ellipse around the torso.
## Hands are left alone, so a ball held in front still reaches the hands.

const ARMS: Array = [["RightUpperArm", "RightLowerArm", "RightHand", 1.0],
	["LeftUpperArm", "LeftLowerArm", "LeftHand", -1.0]]
## Torso ellipse, as multiples of the half distance between the shoulder joints.
const HALF_WIDTH: float = 1.0
const HALF_DEPTH: float = 0.85

var _ids: Array = []
var _hips: int = -1
var _neck: int = -1


func _process_modification_with_delta(_delta: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		return
	if _ids.is_empty():
		_hips = sk.find_bone("Hips")
		_neck = sk.find_bone("Neck")
		for arm: Array in ARMS:
			_ids.append([sk.find_bone(arm[0]), sk.find_bone(arm[1]), sk.find_bone(arm[2])])
		if _hips < 0 or _neck < 0:
			_ids.clear()
			_ids.append([-1, -1, -1])
	if _ids[0][0] < 0 or _hips < 0 or _neck < 0:
		return
	var up_r: Vector3 = sk.get_bone_global_pose(_ids[0][0]).origin
	var up_l: Vector3 = sk.get_bone_global_pose(_ids[1][0]).origin
	var half: float = up_r.distance_to(up_l) * 0.5
	var centre: Vector3 = (up_r + up_l) * 0.5
	var lat: Vector3 = (up_r - up_l).normalized()
	var hip: Vector3 = sk.get_bone_global_pose(_hips).origin
	var axis: Vector3 = (centre - hip)
	var axis_len: float = axis.length()
	if axis_len < 0.01:
		return
	axis /= axis_len
	lat = (lat - axis * lat.dot(axis)).normalized()
	var fwd: Vector3 = lat.cross(axis).normalized()
	for i in ARMS.size():
		var ids: Array = _ids[i]
		_limit_sideways(sk, ids[0], ids[1], ARMS[i][3], lat)
		_clear_joint(sk, ids[0], ids[1], 1.0, hip, axis, axis_len, lat, fwd, half)  # elbow, by turning the upper arm
		_clear_joint(sk, ids[1], ids[2], 0.5, hip, axis, axis_len, lat, fwd, half)  # forearm middle, by turning the forearm


## Turn `bone` about its own origin so the point `frac` of the way along to
## `child` leaves the torso ellipse. (For frac = 1 that point is the child joint.)
func _clear_joint(sk: Skeleton3D, bone: int, child: int, frac: float, hip: Vector3, axis: Vector3,
		axis_len: float, lat: Vector3, fwd: Vector3, half: float) -> void:
	var pivot_t: Transform3D = sk.get_bone_global_pose(bone)
	var tip: Vector3 = sk.get_bone_global_pose(child).origin
	var p: Vector3 = pivot_t.origin.lerp(tip, frac)
	var rel: Vector3 = p - hip
	var along: float = rel.dot(axis) / axis_len
	if along < 0.05 or along > 1.05:
		return  # below the hips or above the shoulders
	var x: float = rel.dot(lat)
	var z: float = rel.dot(fwd)
	var a: float = half * HALF_WIDTH
	var b: float = half * HALF_DEPTH
	var d: float = sqrt((x / a) * (x / a) + (z / b) * (z / b))
	if d >= 1.0 or d < 0.0001:
		return
	# Nearest point on the ellipse along the same ray from the torso axis.
	var out_x: float = x / d
	var out_z: float = z / d
	var want: Vector3 = p + lat * (out_x - x) + fwd * (out_z - z)
	var from_dir: Vector3 = (p - pivot_t.origin)
	var to_dir: Vector3 = (want - pivot_t.origin)
	if from_dir.length() < 0.001 or to_dir.length() < 0.001:
		return
	var swing: Quaternion = Quaternion(from_dir.normalized(), to_dir.normalized())
	var new_basis: Basis = Basis(swing) * pivot_t.basis
	var parent: int = sk.get_bone_parent(bone)
	var parent_basis: Basis = sk.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(bone, (parent_basis.inverse() * new_basis).get_rotation_quaternion())


## An arm flung out to the side reads as a wing (the shot and layup follow-
## throughs do it). The sideways share of the upper arm's direction is left
## alone up to SIDE_FREE, and beyond that squeezed to SIDE_KEEP of the excess.
## Arms forward or overhead have little sideways share and are unaffected.
const SIDE_FREE: float = 0.45
const SIDE_KEEP: float = 0.35


func _limit_sideways(sk: Skeleton3D, bone: int, child: int, side: float, lat: Vector3) -> void:
	var pivot_t: Transform3D = sk.get_bone_global_pose(bone)
	var dir: Vector3 = sk.get_bone_global_pose(child).origin - pivot_t.origin
	if dir.length() < 0.001:
		return
	dir = dir.normalized()
	var out: float = dir.dot(lat) * side
	if out <= SIDE_FREE:
		return
	var squeezed: float = SIDE_FREE + (out - SIDE_FREE) * SIDE_KEEP
	var rest: Vector3 = dir - lat * dir.dot(lat)
	if rest.length() < 0.001:
		return
	var want: Vector3 = rest.normalized() * sqrt(1.0 - squeezed * squeezed) + lat * side * squeezed
	var swing: Quaternion = Quaternion(dir, want.normalized())
	var new_basis: Basis = Basis(swing) * pivot_t.basis
	var parent: int = sk.get_bone_parent(bone)
	var parent_basis: Basis = sk.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(bone, (parent_basis.inverse() * new_basis).get_rotation_quaternion())
