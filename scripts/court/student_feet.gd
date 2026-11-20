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

var stride_amount: float = 0.0
var _legs: Array = []
var _contact_point: Dictionary = {}
var _swing_offset: Dictionary = {}


func _process_modification_with_delta(delta: float) -> void:
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
		# Follow the ankle through swing. Pinning the root-level control to
		# the court pulls the shoe away from the rising shin and stretches the cuff.
		var shoe_basis := yaw
		if stride_amount > 0.0:
			# A lifted heel rolls with the shin. At contact the outsole settles
			# flat. Keep the toes facing forward through the high-knee swing.
			var knee := sk.get_bone_global_pose(sk.get_bone_parent(leg[1])).origin
			var shin := knee - ankle.origin
			var roll_angle := clampf(atan2(shin.z, shin.y), -0.32, 1.10)
			var clearance := maxf(0.0, ankle.origin.y + SHOE_BELOW_ANKLE - SHOE_FLOOR_Y)
			var swing := smoothstep(0.0, 0.35, clearance)
			var stride_basis := Basis(Vector3.RIGHT, roll_angle * swing)
			shoe_basis = yaw.slerp(stride_basis, stride_amount)
		var origin := ankle.origin + shoe_basis * Vector3(0.0, 0.0, SHOE_AHEAD)
		origin.y = maxf(SHOE_FLOOR_Y, ankle.origin.y + SHOE_BELOW_ANKLE)
		# During forward single support the shoe should stay over the same
		# court point while the body passes it. Limit ankle/cuff separation.
		var id: int = leg[0]
		var world := sk.global_transform * origin
		var flat := Vector2(world.x, world.z)
		var lift := ankle.origin.y + SHOE_BELOW_ANKLE - SHOE_FLOOR_Y
		var offset: Vector2 = _swing_offset.get(id, Vector2.ZERO)
		if stride_amount > 0.5 and lift < (0.10 if _contact_point.has(id) else 0.045):
			if not _contact_point.has(id):
				_contact_point[id] = flat + offset
			offset = (Vector2(_contact_point[id]) - flat).limit_length(0.045)
		else:
			_contact_point.erase(id)
			offset = offset.move_toward(Vector2.ZERO, maxf(delta, 0.0) * 0.9)
		_swing_offset[id] = offset
		origin = sk.global_transform.affine_inverse() * (world + Vector3(offset.x, 0, offset.y))
		var pose := Transform3D((shoe_basis * foot_rest.basis).scaled(Vector3.ONE * SHOE_SCALE), origin)
		sk.set_bone_global_pose(leg[0], pose)
