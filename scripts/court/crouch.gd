extends SkeletonModifier3D
## Athletic stance: sinks the hips by bending both legs (thigh forward, shin
## back, foot flat), so the feet stay where the animation put them and the
## body gets lower. `amount` 0..1 scales a bend of MAX_BEND radians at the hip.
## Runs before the floor and shoe modifiers so they see the lowered pose.

const MAX_BEND: float = 0.62
## Hip abduction at full amount: a wide base.
const MAX_SPREAD: float = 0.22

var amount: float = 0.0

var _ids: Array = []


func _process_modification_with_delta(_delta: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null or amount <= 0.001:
		return
	if _ids.is_empty():
		for side: String in ["Left", "Right"]:
			_ids.append([sk.find_bone(side + "UpperLeg"), sk.find_bone(side + "LowerLeg"), sk.find_bone(side + "Foot")])
		_ids.append([sk.find_bone("Hips")])
	var a: float = MAX_BEND * clampf(amount, 0.0, 1.0)
	var b: float = MAX_SPREAD * clampf(amount, 0.0, 1.0)
	var drop: float = 0.0
	var lowest: float = INF
	for i in 2:
		var sgn: float = 1.0 if i == 0 else -1.0  # left leg is on +x
		var ids: Array = _ids[i]
		if ids[0] < 0 or ids[1] < 0 or ids[2] < 0:
			continue
		var thigh0: Transform3D = sk.get_bone_global_pose(ids[0])
		var shin0: Transform3D = sk.get_bone_global_pose(ids[1])
		var foot0: Transform3D = sk.get_bone_global_pose(ids[2])
		# +z is forward, +y up: a knee goes forward when the thigh turns by -a about x.
		sk.set_bone_global_pose(ids[0], Transform3D(Basis(Vector3.BACK, sgn * b) * Basis(Vector3.RIGHT, -a) * thigh0.basis, thigh0.origin))
		var shin1: Transform3D = sk.get_bone_global_pose(ids[1])
		sk.set_bone_global_pose(ids[1], Transform3D(Basis(Vector3.BACK, -sgn * b) * Basis(Vector3.RIGHT, a) * shin0.basis, shin1.origin))
		var foot1: Transform3D = sk.get_bone_global_pose(ids[2])
		sk.set_bone_global_pose(ids[2], Transform3D(foot0.basis, foot1.origin))
		# Sink by what the planted (lower) foot gained, so it stays on the floor.
		if foot0.origin.y < lowest:
			lowest = foot0.origin.y
			drop = foot1.origin.y - foot0.origin.y
	var hips: int = _ids[2][0]
	if hips >= 0 and drop > 0.0:
		var h: Transform3D = sk.get_bone_global_pose(hips)
		h.origin.y -= drop
		sk.set_bone_global_pose(hips, h)
