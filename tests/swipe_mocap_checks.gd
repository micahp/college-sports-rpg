extends SceneTree
## Checks that the CMU swipe imports as a whole-arm upper-body action for
## both sides, with torso motion contained and arm motion retained.

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var library: AnimationLibrary = CourtPlayerModel.library()
	for name: String in ["SwipeCMU", "SwipeCMU_R", "SwipeCMU_L"]:
		_check(library.has_animation(name), "%s exists in the court animation library" % name)
	if _failures == 0:
		var right: Animation = library.get_animation("SwipeCMU_R")
		var left: Animation = library.get_animation("SwipeCMU_L")
		_check(right.length >= 1.39 and right.length <= 1.41, "swipe beat keeps the 1.4 second CMU timing")
		_check(_has_bone(right, "RightShoulder") and _has_bone(right, "RightUpperArm") and _has_bone(right, "RightLowerArm"), "right swipe drives shoulder, upper arm and elbow")
		_check(_has_bone(left, "LeftShoulder") and _has_bone(left, "LeftUpperArm") and _has_bone(left, "LeftLowerArm"), "mirrored swipe drives the left arm chain")
		_check(not _has_bone(right, "Hips"), "upper-body swipe does not pull the hips or legs")
		_check(not _has_bone(right, "Spine") and not _has_bone(right, "Chest") and not _has_bone(right, "UpperChest"), "posture system retains control of the torso")
		_check(not _has_bone(right, "LeftUpperArm"), "free arm remains outside the swipe and clear of the torso")
		_check(_max_delta(right, "RightShoulder") < 0.55, "clavicle swing stays within a controlled range")
		_check(_max_delta(right, "RightUpperArm") > 0.15 and _max_delta(right, "RightUpperArm") < 1.3, "recorded upper-arm reach remains visible without overextension")
		_check(_max_delta(right, "RightLowerArm") > 0.08 and _max_delta(right, "RightLowerArm") < 1.2, "elbow action remains articulated without a hard fold")
		_check(_max_delta(right, "RightHand") < 0.3, "wrist stays close to its neutral rotation")
		_check(_max_delta(left, "LeftUpperArm") > 0.15, "mirrored left reach keeps its arm travel")
		_check(absf(_max_delta(left, "LeftUpperArm") - _max_delta(right, "RightUpperArm")) < 0.1, "left and right clips mirror the same arm travel")
	print("Swipe mocap checks: %d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)


func _has_bone(anim: Animation, bone: String) -> bool:
	for t in anim.get_track_count():
		if str(anim.track_get_path(t).get_concatenated_subnames()) == bone:
			return true
	return false


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


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
