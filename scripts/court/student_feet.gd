extends SkeletonModifier3D
## The campus student rig keeps its feet on separate control bones that hang
## off the root instead of the leg, and its ankle ("LeftFoot"/"RightFoot"
## after retargeting) is a leaf that only inherits the shin's tilt. Left
## alone, a leaning shin would point the shoe at the floor. Each frame the
## control bone goes to its ankle and stays flat on the floor, turning only
## with the leg's heading. (The skeleton stands upright: +Y is up.)

## How far below the shin end the shoe control sits when the foot is planted, in skeleton units
## (measured at idle: shin end 0.069, control 0.054 with the shoes flat on the floor).
const SHOE_BELOW_ANKLE: float = -0.015
## How far in front of the ankle the shoe centre sits, in skeleton units. The rest offset (0.41 m, with the rig fit off)
## put the shoe a full shoe-length and more ahead of the ankle, so any ankle yaw swung it about 0.4 m sideways.
const SHOE_AHEAD: float = 0.10
## Shoe control height above the floor, in skeleton units: the standing reference (flat shoes at idle).
## Set absolutely, not relative to the ankle: the ankle moves with the slide and the soles dropped ~3.5 cm.
const SHOE_FLOOR_Y: float = 0.054

## Court sneaker volume relative to the imported student shoe.
const SHOE_SCALE := 1.14

var _legs: Array = []


func _process_modification_with_delta(_delta: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		return
	if _legs.is_empty():
		for pair: Array in [["Foot.L", "LeftFoot"], ["Foot.R", "RightFoot"]]:
			var ctrl: int = sk.find_bone(pair[0])
			var ankle: int = sk.find_bone(pair[1])
			if ctrl >= 0 and ankle >= 0:
				_legs.append([ctrl, ankle, sk.get_bone_global_rest(ankle), sk.get_bone_global_rest(ctrl)])
		if _legs.is_empty():
			_legs.append([-1, -1, Transform3D.IDENTITY, Transform3D.IDENTITY])
	for leg: Array in _legs:
		if leg[0] < 0:
			continue
		var ankle_rest: Transform3D = leg[2]
		var foot_rest: Transform3D = leg[3]
		var ankle: Transform3D = sk.get_bone_global_pose(leg[1])
		var turned: Basis = ankle.basis * ankle_rest.basis.inverse()
		var heading: Vector3 = turned * Vector3.BACK
		var yaw: Basis = Basis(Vector3.UP, atan2(heading.x, heading.z))
		# Horizontally the shoe keeps its rest offset from the ankle (shin end). Vertically it hangs a
		# small fixed distance below it: the rig fit lengthens the shin, so the rest offset (the shin end
		# sits 0.44 below the shoe) is not what the animated pose has (the legs bend and the shin end is
		# already at the shoe's height), and applying it lifted the shoes ~16 cm, onto their toes.
		var pose: Transform3D = Transform3D((yaw * foot_rest.basis).scaled(Vector3.ONE * SHOE_SCALE),
			ankle.origin + yaw * Vector3(0.0, 0.0, SHOE_AHEAD) + Vector3(0.0, SHOE_FLOOR_Y - ankle.origin.y, 0.0))
		sk.set_bone_global_pose(leg[0], pose)
