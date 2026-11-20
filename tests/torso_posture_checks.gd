extends SceneTree
## Verifies TorsoPosture compresses side-bend and forward lean by the same
## amount, so defender locomotion cannot fold the torso along one axis.

const TorsoPosture = preload("res://scripts/court/torso_posture.gd")
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sk := Skeleton3D.new()
	root.add_child(sk)
	sk.add_bone("Hips")
	sk.add_bone("Spine")
	sk.add_bone("Neck")
	sk.set_bone_parent(1, 0)
	sk.set_bone_parent(2, 1)
	var hips := Transform3D.IDENTITY
	var spine := Transform3D.IDENTITY
	spine.origin = Vector3.UP
	var neck := Transform3D.IDENTITY
	neck.origin = Vector3.UP * 0.6
	sk.set_bone_rest(0, hips)
	sk.set_bone_rest(1, spine)
	sk.set_bone_rest(2, neck)
	var posture = TorsoPosture.new()
	sk.add_child(posture)
	for axis: Vector3 in [Vector3.RIGHT, Vector3.FORWARD]:
		sk.reset_bone_poses()
		sk.set_bone_pose_rotation(1, Quaternion(axis, deg_to_rad(30.0)))
		sk.force_update_all_bone_transforms()
		posture._process_modification_with_delta(0.0)
		_check(absf(posture.last_raw - 30.0) < 0.5, "detects 30-degree lean on axis %s" % axis)
		_check(absf(posture.last_out - (6.0 + 24.0 * 0.27)) < 0.5, "compresses lean on axis %s" % axis)
		sk.force_update_all_bone_transforms()
		var line: Vector3 = sk.get_bone_global_pose(2).origin - sk.get_bone_global_pose(1).origin
		_check(rad_to_deg(line.normalized().angle_to(Vector3.UP)) < 13.0, "keeps torso below 13 degrees on axis %s" % axis)
	sk.queue_free()
	print("Torso posture checks: %d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
