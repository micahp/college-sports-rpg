extends SkeletonModifier3D
## Keep space under each upper arm and let the elbow travel opposite the knee.
var forward := Vector3.FORWARD
var _limbs: Array = []

func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or influence <= 0.0:
		return
	if _limbs.is_empty():
		for side in ["Left", "Right"]:
			var ids := PackedInt32Array()
			for part in ["UpperArm", "LowerArm", "UpperLeg", "LowerLeg"]:
				ids.append(sk.find_bone(side + part))
			if not ids.has(-1):
				_limbs.append([ids, -1.0 if side == "Left" else 1.0])
	var inverse := sk.global_transform.basis.inverse()
	var front := (inverse * forward).normalized()
	var down := (inverse * Vector3.DOWN).normalized()
	var right := front.cross(-down).normalized()
	for limb in _limbs:
		var ids: PackedInt32Array = limb[0]
		var shoulder := sk.get_bone_global_pose(ids[0])
		var arm := (sk.get_bone_global_pose(ids[1]).origin - shoulder.origin).normalized()
		var thigh := (sk.get_bone_global_pose(ids[3]).origin - sk.get_bone_global_pose(ids[2]).origin).normalized()
		var lateral := right * float(limb[1])
		var swing := clampf(0.45 * arm.dot(front) - 0.8 * thigh.dot(front), -0.72, 0.72)
		var aim := (down * 0.85 + lateral * maxf(0.32, arm.dot(lateral)) + front * swing).normalized()
		shoulder.basis = Basis(Quaternion(arm, aim)) * shoulder.basis
		sk.set_bone_global_pose(ids[0], shoulder)
