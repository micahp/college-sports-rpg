extends SceneTree
## Checks that the CMU swipe imports as a whole-arm upper-body action for
## both sides, with torso motion contained and arm motion retained.

var _failures: int = 0
const Retarget = preload("res://scripts/court/mocap_retarget.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var library: AnimationLibrary = CourtPlayerModel.library()
	for name: String in ["SwipeCMU", "SwipeCMU_R", "SwipeCMU_L"]:
		_check(library.has_animation(name), "%s exists in the court animation library" % name)
	if _failures == 0:
		var right: Animation = library.get_animation("SwipeCMU_R")
		var left: Animation = library.get_animation("SwipeCMU_L")
		_check(right.length >= 1.39 and right.length <= 1.41, "swipe keeps the source clip's fluid load, contact, follow-through and recovery timing")
		_check(_rotation_tracks_only(right), "swipe is authored as linked joint rotations, with no wrist-space target track")
		_check(_has_bone(right, "RightShoulder") and _has_bone(right, "RightUpperArm") and _has_bone(right, "RightLowerArm"), "right swipe drives shoulder, upper arm and elbow")
		_check(_has_bone(left, "LeftShoulder") and _has_bone(left, "LeftUpperArm") and _has_bone(left, "LeftLowerArm"), "mirrored swipe drives the left arm chain")
		_check(_has_bone(right, "Hips") and _has_bone(right, "Chest") and _has_bone(right, "UpperChest"), "swipe carries its body turn through hips and chest with the arm chain")
		_check(_max_delta(right, "LeftUpperLeg") > 0.01 and _max_delta(right, "RightUpperLeg") > 0.01, "swipe carries the recorded step on both legs")
		_check(_has_bone(right, "LeftUpperArm") and _has_bone(left, "RightUpperArm"), "free arm counterbalances inside the same full-body action")
		_check(_is_constant(right, "LeftShoulder") and _is_constant(right, "LeftUpperArm") and _is_constant(right, "LeftLowerArm") and _is_constant(right, "LeftHand"), "off arm holds the idle joint pose instead of folding across the torso")
		_check(_is_constant(left, "RightShoulder") and _is_constant(left, "RightUpperArm") and _is_constant(left, "RightLowerArm") and _is_constant(left, "RightHand"), "mirrored off arm holds the idle joint pose")
		_check(_matches_idle_pose(right, "LeftUpperArm") and _matches_idle_pose(right, "LeftLowerArm"), "right swipe's free arm is anchored to the real student idle pose")
		_check(_matches_idle_pose(left, "RightUpperArm") and _matches_idle_pose(left, "RightLowerArm"), "left swipe's free arm is anchored to the real student idle pose")
		_check(_max_delta(right, "UpperChest") > 0.05, "upper chest contributes to the reach")
		_check(_max_global_delta(right, "Neck") < 0.05 and _max_global_delta(right, "Head") < 0.05, "head stays level while the chest turns")
		_check(_max_step(right, "UpperChest") < 0.5, "torso contribution does not snap between frames")
		_check(_max_step(right, "RightShoulder") < 0.5, "clavicle motion does not snap between frames")
		_check(_max_step(right, "RightUpperArm") < 0.5, "upper-arm motion does not snap between frames")
		_check(_max_step(right, "RightLowerArm") < 0.5, "elbow motion does not snap between frames")
		_check(_max_step(right, "RightHand") < 0.5, "wrist motion does not snap between frames")
		_check(_max_delta(left, "LeftUpperArm") > 0.15, "left reach keeps its arm travel")
		_check(_max_delta_from_guard(right, "RightShoulder") > 0.05 and _max_delta_from_guard(right, "RightShoulder") < 1.0, "right shoulder contributes to the connected reach within joint range")
		_check(_max_delta_from_guard(left, "LeftShoulder") > 0.05 and _max_delta_from_guard(left, "LeftShoulder") < 1.0, "left shoulder contributes to the connected reach within joint range")
		_check(_max_delta_from_guard(right, "RightUpperArm") > 0.15 and _max_delta_from_guard(right, "RightUpperArm") < 1.7, "right upper arm follows the shoulder-led reach within joint range")
		_check(_max_delta_from_guard(left, "LeftUpperArm") > 0.15 and _max_delta_from_guard(left, "LeftUpperArm") < 1.7, "left upper arm follows the shoulder-led reach within joint range")
		_check(_mirrored_hand_path(right, left), "both hands reach down and forward outside their own shoulder at contact")
	print("Swipe mocap checks: %d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)


func _has_bone(anim: Animation, bone: String) -> bool:
	for t in anim.get_track_count():
		if str(anim.track_get_path(t).get_concatenated_subnames()) == bone:
			return true
	return false


func _rotation_tracks_only(anim: Animation) -> bool:
	for track in anim.get_track_count():
		if anim.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			return false
	return true


func _max_delta(anim: Animation, bone: String) -> float:
	var idle: Animation = CourtPlayerModel.library().get_animation("Idle")
	for t in anim.get_track_count():
		if str(anim.track_get_path(t).get_concatenated_subnames()) != bone or anim.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var it: int = idle.find_track(anim.track_get_path(t), Animation.TYPE_ROTATION_3D)
		if it < 0:
			return INF
		var neutral: Quaternion = idle.rotation_track_interpolate(it, 0.0)
		var peak: float = 0.0
		for k in anim.track_get_key_count(t):
			peak = maxf(peak, neutral.angle_to(anim.track_get_key_value(t, k)))
		return peak
	return 0.0


func _is_constant(anim: Animation, bone: String) -> bool:
	for t in anim.get_track_count():
		if str(anim.track_get_path(t).get_concatenated_subnames()) != bone or anim.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var first: Quaternion = anim.track_get_key_value(t, 0)
		for key in anim.track_get_key_count(t):
			if first.angle_to(anim.track_get_key_value(t, key)) > 0.01:
				return false
		return true
	return false


func _matches_idle_pose(anim: Animation, bone: String) -> bool:
	var student: Node = (load(CourtPlayerModel.STUDENT) as PackedScene).instantiate()
	var sk: Skeleton3D = CourtPlayerModel.find_skeleton(student)
	var idle: Animation = CourtPlayerModel.library().get_animation("Idle")
	var idle_pose: Array = CourtPlayerModel._pose_with_overlay(sk, idle, null, 0.0, [])
	var index: int = sk.find_bone(bone)
	var parent: int = sk.get_bone_parent(index)
	var global_q: Quaternion = (idle_pose[index] as Transform3D).basis.get_rotation_quaternion()
	var parent_q: Quaternion = (idle_pose[parent] as Transform3D).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
	var expected: Quaternion = (parent_q.inverse() * global_q).normalized()
	var matched: bool = false
	for track in anim.get_track_count():
		if str(anim.track_get_path(track).get_concatenated_subnames()) != bone or anim.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		matched = true
		for key in anim.track_get_key_count(track):
			if expected.angle_to(anim.track_get_key_value(track, key)) > 0.01:
				student.free()
				return false
	student.free()
	return matched


func _max_delta_from_guard(anim: Animation, bone: String) -> float:
	var student: Node = (load(CourtPlayerModel.STUDENT) as PackedScene).instantiate()
	var sk: Skeleton3D = CourtPlayerModel.find_skeleton(student)
	var idle: Animation = CourtPlayerModel.library().get_animation("Idle")
	var guard: Animation = CourtPlayerModel.library().get_animation("SlideR")
	var guarded: Array = CourtPlayerModel._pose_with_overlay(sk, idle, guard, 0.20,
		["RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand", "LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand"])
	var i: int = sk.find_bone(bone)
	var parent: int = sk.get_bone_parent(i)
	var parent_q: Quaternion = (guarded[parent] as Transform3D).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
	var base_local: Quaternion = parent_q.inverse() * (guarded[i] as Transform3D).basis.get_rotation_quaternion()
	var peak: float = 0.0
	for t in anim.get_track_count():
		if str(anim.track_get_path(t).get_concatenated_subnames()) == bone and anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			for k in anim.track_get_key_count(t):
				peak = maxf(peak, base_local.angle_to(anim.track_get_key_value(t, k)))
	student.free()
	return peak


func _max_step(anim: Animation, bone: String) -> float:
	for t in anim.get_track_count():
		if str(anim.track_get_path(t).get_concatenated_subnames()) != bone or anim.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var peak: float = 0.0
		for k in range(1, anim.track_get_key_count(t)):
			var step: float = (anim.track_get_key_value(t, k - 1) as Quaternion).angle_to(anim.track_get_key_value(t, k))
			peak = maxf(peak, step)
		return peak
	return 0.0


func _max_global_delta(anim: Animation, bone: String) -> float:
	var student: Node = (load(CourtPlayerModel.STUDENT) as PackedScene).instantiate()
	var sk: Skeleton3D = CourtPlayerModel.find_skeleton(student)
	var idle: Animation = CourtPlayerModel.library().get_animation("Idle")
	var base: Array = CourtPlayerModel._pose_with_overlay(sk, idle, null, 0.0, [])
	var all: Array[String] = ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head", "RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand"]
	var peak: float = 0.0
	for f in maxi(2, roundi(anim.length * 30.0) + 1):
		var time: float = anim.length * float(f) / float(maxi(2, roundi(anim.length * 30.0) + 1))
		var pose: Array = CourtPlayerModel._pose_with_overlay(sk, idle, anim, time, all)
		var i: int = sk.find_bone(bone)
		peak = maxf(peak, ((base[i] as Transform3D).basis.get_rotation_quaternion()).angle_to(
			((pose[i] as Transform3D).basis.get_rotation_quaternion())))
	student.free()
	return peak


func _mirrored_hand_path(right: Animation, left: Animation) -> bool:
	var student: Node = (load(CourtPlayerModel.STUDENT) as PackedScene).instantiate()
	var sk: Skeleton3D = CourtPlayerModel.find_skeleton(student)
	var idle: Animation = CourtPlayerModel.library().get_animation("Idle")
	var guard: Animation = CourtPlayerModel.library().get_animation("SlideR")
	var arms: Array[String] = ["RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand",
		"LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand"]
	var idle_globals: Array = CourtPlayerModel._pose_with_overlay(sk, idle, guard, 0.20, arms)
	var right_chain: Array[String] = ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head", "RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand"]
	var left_chain: Array[String] = ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head", "LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand"]
	var ok := true
	for side: String in ["Right", "Left"]:
		var clip := right if side == "Right" else left
		var chain := right_chain if side == "Right" else left_chain
		var pose := CourtPlayerModel._pose_with_overlay(sk, idle, clip, 0.26, chain)
		var hand := sk.find_bone(side + "Hand")
		var shoulder := sk.find_bone(side + "UpperArm")
		var chest := sk.find_bone("Chest")
		var outward := signf((idle_globals[shoulder].origin - idle_globals[chest].origin).x)
		var from_shoulder: Vector3 = pose[hand].origin - pose[shoulder].origin
		ok = ok and from_shoulder.x * outward > 0.0 and from_shoulder.y < 0.0 and from_shoulder.z > 0.0
	student.free()
	return ok


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
