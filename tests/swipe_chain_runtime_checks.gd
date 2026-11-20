extends SceneTree
## Runtime regression check on the full court character: generic arm actions
## cannot bend the idle torso, while the swipe carries bounded torso motion
## and returns to the same idle pose.

const Actor = preload("res://scripts/court/court_actor.gd")
var failures: int = 0
var actor: Node
var control: Node
var sk: Skeleton3D
var sk_control: Skeleton3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	actor = Actor.new()
	root.add_child(actor)
	actor.setup("", {"Shirt": Color.RED, "Pants": Color.WHITE, "Skin": Color(0.48, 0.34, 0.24), "Socks": Color.WHITE})
	sk = actor.get("_skeleton")
	control = Actor.new()
	root.add_child(control)
	control.setup("", {"Shirt": Color.RED, "Pants": Color.WHITE, "Skin": Color(0.48, 0.34, 0.24), "Socks": Color.WHITE})
	sk_control = control.get("_skeleton")
	await _advance(20)
	var posture: SkeletonModifier3D = actor.get("_torso_posture")
	_check(float(posture.get("last_out")) < 14.0, "neutral idle back remains upright on the full character")
	var idle_back_angle: float = float(posture.get("last_raw"))
	actor.action("Reach")
	await _advance(100)
	var after_reach: Dictionary = _torso_pose(sk)
	var control_pose: Dictionary = _torso_pose(sk_control)
	_check(_torso_delta(control_pose, after_reach) < deg_to_rad(1.5), "generic reach leaves the idle torso pose untouched")
	var arm_ik: SkeletonModifier3D = ((actor.get("_ik") as Dictionary)["R"]["ik"] as SkeletonModifier3D)
	arm_ik.influence = 0.9
	var arm_before_swipe: Array[Vector3] = _arm_chain_points(sk, "R")
	actor.action("SwipeCMU_R")
	await _advance(1)
	_check(arm_ik.influence < 0.01, "hand IK yields immediately to the captured joint animation")
	_check(_max_point_delta(arm_before_swipe, _arm_chain_points(sk, "R")) < 0.20, "captured joint pose keeps the first-frame arm transition within 20 cm")
	await _advance(23)
	var during_swipe: Dictionary = _torso_pose(sk)
	control_pose = _torso_pose(sk_control)
	_check(_torso_delta(control_pose, during_swipe, ["Hips", "Chest", "UpperChest"]) > deg_to_rad(1.0), "swipe carries body rotation from hips through chest with the arm chain")
	_check(_torso_delta(control_pose, during_swipe, ["Neck", "Head"]) < deg_to_rad(6.0), "head stays stable while the body turns")
	_check(arm_ik.influence < 0.01, "the baked chain owns the arm after the handoff")
	_check(not (actor.get("_elbow_hinge") as SkeletonModifier3D).active, "elbow hinge stops rewriting the chain after its blend out")
	_check(not (actor.get("_arm_clearance") as SkeletonModifier3D).active, "arm clearance stops pulling the chain after its blend out")
	_check((actor.get("_torso_posture") as SkeletonModifier3D).influence > 0.9, "upright torso posture stays active through the swipe")
	_check(absf(float(posture.get("last_raw")) - idle_back_angle) < 2.0, "swipe chain keeps the idle back angle instead of writing a new torso bend")
	await _advance(100)
	var recovered: Dictionary = _torso_pose(sk)
	control_pose = _torso_pose(sk_control)
	_check(_torso_delta(control_pose, recovered) < deg_to_rad(1.5), "swipe releases torso back to idle")
	print("Swipe chain runtime checks: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

func _advance(frames: int) -> void:
	for _i in frames:
		actor.pose_reset()
		actor.animate(1.0 / 60.0)
		control.pose_reset()
		control.animate(1.0 / 60.0)
		await physics_frame

func _torso_pose(skeleton: Skeleton3D) -> Dictionary:
	skeleton.force_update_all_bone_transforms()
	var pose: Dictionary = {}
	for bone in ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head"]:
		var i: int = skeleton.find_bone(bone)
		pose[bone] = skeleton.get_bone_global_pose(i).basis.get_rotation_quaternion()
	return pose

func _arm_chain_points(skeleton: Skeleton3D, side: String) -> Array[Vector3]:
	skeleton.force_update_all_bone_transforms()
	var points: Array[Vector3] = []
	var prefix: String = "Right" if side == "R" else "Left"
	for suffix: String in ["UpperArm", "LowerArm", "Hand"]:
		var index: int = skeleton.find_bone(prefix + suffix)
		points.append(skeleton.global_transform * skeleton.get_bone_global_pose(index).origin)
	return points

func _max_point_delta(a: Array[Vector3], b: Array[Vector3]) -> float:
	var peak: float = 0.0
	for index in mini(a.size(), b.size()):
		peak = maxf(peak, a[index].distance_to(b[index]))
	return peak

func _torso_delta(a: Dictionary, b: Dictionary, bones: Array = ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head"]) -> float:
	var peak: float = 0.0
	for bone: String in bones:
		peak = maxf(peak, (a[bone] as Quaternion).angle_to(b[bone] as Quaternion))
	return peak

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
