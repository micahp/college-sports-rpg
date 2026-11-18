extends SkeletonModifier3D
## Last in the modifier chain: remembers where the arms really ended up this
## frame, after the IK, the torso clearance, the palm aim, the hinge pass and
## the palm contact. Game code reading Skeleton3D.get_bone_global_pose() between
## frames gets the animation pose from BEFORE those modifiers, not what is
## drawn (measured: hands up to 0.32 m off, shoulders up to 0.29 m off once the
## trunk leans or the hips sink). Everything that places a hand or measures
## reach from the arm reads this instead.
##
## Positions are stored relative to the model (its position and facing), so
## reading them a frame later, after the actor has moved or turned, still lands
## on the body: `world(side, what)` re-expresses them in the model's frame now.

const ARMS: Dictionary = {"R": ["RightUpperArm", "RightLowerArm", "RightHand"],
	"L": ["LeftUpperArm", "LeftLowerArm", "LeftHand"]}

var model: Node3D  # set by the actor: the node whose frame positions are stored in

var _ids: Dictionary = {}
var _local: Dictionary = {}   # "R_shoulder" -> Vector3 in the model's frame
var _hand_basis: Dictionary = {}  # side -> Basis in the model's frame (rotation only)


func _process_modification_with_delta(_delta: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null or model == null:
		return
	if _ids.is_empty():
		for side: String in ARMS:
			var ids: Array = []
			for b: String in ARMS[side]:
				ids.append(sk.find_bone(b))
			_ids[side] = ids
	sk.force_update_all_bone_transforms()
	var to_model: Transform3D = model.global_transform.affine_inverse() * sk.global_transform
	for side: String in ARMS:
		var ids: Array = _ids[side]
		if ids.has(-1):
			continue
		for i in 3:
			var key: String = side + "_" + ["shoulder", "elbow", "hand"][i]
			_local[key] = to_model * sk.get_bone_global_pose(ids[i]).origin
		_hand_basis[side] = (to_model.basis * sk.get_bone_global_pose(ids[2]).basis).orthonormalized()


func has_pose() -> bool:
	return not _local.is_empty()


## World position of "shoulder" / "elbow" / "hand" of `side`, as last drawn.
func world(side: String, what: String) -> Vector3:
	return model.global_transform * (_local.get(side + "_" + what, Vector3.ZERO) as Vector3)


## The hand's orientation in the world, as last drawn.
func hand_basis(side: String) -> Basis:
	return (model.global_transform.basis.orthonormalized() * (_hand_basis.get(side, Basis.IDENTITY) as Basis)).orthonormalized()
