extends SkeletonModifier3D
## The campus student rig keeps its feet on separate control bones that hang
## off the root instead of the leg, and its ankle ("LeftFoot"/"RightFoot"
## after retargeting) is a leaf that only inherits the shin's tilt. Left
## alone, a leaning shin would point the shoe at the floor. Each frame the
## control bone goes to its ankle and stays flat on the floor, turning only
## with the leg's heading. (The skeleton stands upright: +Y is up.)

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
		var pose: Transform3D = Transform3D(yaw * foot_rest.basis,
			ankle.origin + yaw * (foot_rest.origin - ankle_rest.origin))
		sk.set_bone_global_pose(leg[0], pose)
