extends Node
## Per clip: is the trunk on the student what it is in the recording, and what
## does torso_posture take out of it?
##   source: the clip on its own file's skeleton (CMU or library performer)
##   game:   the clip on the court's student rig, animation only (no modifiers)
## Trunk = hip-joint midpoint to Neck (the same landmark on both rigs; the
## student's "Hips" is a body controller below its pelvis). Pitch is forward
## (+) / back (-), roll is to the body's left (+). Sampled every 1/30 s.
## torso_posture: the lean it measures (Hips bone to Neck, on the game clip)
## and how much it would remove (it keeps FREE deg, compresses the rest to KEEP).
##   godot --headless --path . res://tests/trunk_lean_audit.tscn
const TorsoPosture = preload("res://scripts/court/torso_posture.gd")


func _trunk(sk: Skeleton3D) -> Vector3:
	var g := sk.global_transform
	var p := func(b: String) -> Vector3: return g * sk.get_bone_global_pose(sk.find_bone(b)).origin
	var l: Vector3 = p.call("LeftUpperLeg")
	var r: Vector3 = p.call("RightUpperLeg")
	var lat := l - r
	lat.y = 0.0
	lat = lat.normalized()
	var fwd := lat.cross(Vector3.UP).normalized()
	var spine: Vector3 = ((p.call("Neck") as Vector3) - (l + r) * 0.5).normalized()
	var hips_line: Vector3 = ((p.call("Neck") as Vector3) - (p.call("Hips") as Vector3)).normalized()
	return Vector3(rad_to_deg(atan2(spine.dot(fwd), spine.y)), rad_to_deg(atan2(spine.dot(lat), spine.y)), rad_to_deg(hips_line.angle_to(Vector3.UP)))


func _series(ap: AnimationPlayer, sk: Skeleton3D, anim_name: String) -> Array:
	var a: Animation = ap.get_animation(anim_name)
	var out: Array = []
	var t := 0.0
	while t <= a.length + 0.0001:
		ap.play(anim_name)
		ap.seek(t, true)
		ap.advance(0)
		sk.force_update_all_bone_transforms()
		out.append(_trunk(sk))
		t += 1.0 / 30.0
	return out


func _ready() -> void:
	var m: Node3D = CourtPlayerModel.build_student({})
	add_child(m)
	var ap: AnimationPlayer = m.get_node("AnimationPlayer")
	var sk: Skeleton3D = CourtPlayerModel.find_skeleton(m)
	print("clip         retarget | worst |game-source| pitch, roll (deg) | torso_posture removes: mean, max (deg)")
	for clip: String in CourtPlayerModel.CLIPS:
		if not ap.has_animation(clip):
			continue
		var spec: Array = CourtPlayerModel.CLIPS[clip]
		var how: String = "ours" if clip in CourtPlayerModel.RETARGETED else ("library" if spec[0] == CourtPlayerModel.UAL else "engine")
		var game := _series(ap, sk, clip)
		var removed_sum := 0.0
		var removed_max := 0.0
		for v: Vector3 in game:
			var raw: float = v.z
			var kept: float = raw if raw <= TorsoPosture.FREE else TorsoPosture.FREE + (raw - TorsoPosture.FREE) * TorsoPosture.KEEP
			removed_sum += raw - kept
			removed_max = maxf(removed_max, raw - kept)
		var cmp := "   no source skeleton   "
		var src: Node3D = (load(spec[0]) as PackedScene).instantiate()
		add_child(src)
		var sap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
		var ssk: Skeleton3D = CourtPlayerModel.find_skeleton(src)
		if sap.has_animation(spec[1]) and ssk != null and ssk.find_bone("Neck") >= 0:
			var source := _series(sap, ssk, spec[1])
			var wp := 0.0
			var wr := 0.0
			for i in mini(game.size(), source.size()):
				wp = maxf(wp, absf((game[i] as Vector3).x - (source[i] as Vector3).x))
				wr = maxf(wr, absf((game[i] as Vector3).y - (source[i] as Vector3).y))
			cmp = "pitch %5.1f  roll %5.1f" % [wp, wr]
		src.queue_free()
		print("%-12s %-8s | %s | %5.1f  %5.1f" % [clip, how, cmp, removed_sum / maxf(1.0, game.size()), removed_max])
	get_tree().quit(0)
