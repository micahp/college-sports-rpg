extends Node
## Per clip: is the trunk on the student what it is in the recording, and what
## does torso_posture take out of it?
##   source: the clip on its own file's skeleton (CMU or library performer)
##   game:   the clip on the court's student rig, animation only (no modifiers)
## Trunk = Spine (where the spine leaves the pelvis) to Neck; bend = the
## spine's upper half minus its lower half, by length (an arch is negative). Pitch is forward
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
	# From where the spine leaves the pelvis (Spine; CMU's sits on its root).
	# Not from the hip joints: CMU's sit 10 cm below and in front of its spine
	# root, so pelvis tilt swings that line differently on the two rigs.
	var root: Vector3 = p.call("Spine")
	var neck: Vector3 = p.call("Neck")
	var spine: Vector3 = (neck - root).normalized()
	var hips_line: Vector3 = (neck - (p.call("Hips") as Vector3)).normalized()
	# Spine shape: upper half pitch minus lower half pitch (by length). Negative
	# = the top stands back over the bottom (an arch), positive = rounded.
	var pts: Array = []
	for b in ["Spine", "Chest", "UpperChest", "Neck"]:
		var q: Vector3 = p.call(b)
		if pts.is_empty() or q.distance_to(pts.back()) > 1e-4:
			pts.append(q)
	var total := 0.0
	for i in range(1, pts.size()):
		total += (pts[i] as Vector3).distance_to(pts[i - 1])
	var left := total * 0.5
	var mid: Vector3 = pts.back()
	for i in range(1, pts.size()):
		var seg: float = (pts[i] as Vector3).distance_to(pts[i - 1])
		if left <= seg:
			mid = (pts[i - 1] as Vector3).lerp(pts[i], left / maxf(seg, 1e-6))
			break
		left -= seg
	var lo := (mid - root).normalized()
	var up := (neck - mid).normalized()
	_last_bend = rad_to_deg(atan2(up.dot(fwd), up.y)) - rad_to_deg(atan2(lo.dot(fwd), lo.y))
	return Vector3(rad_to_deg(atan2(spine.dot(fwd), spine.y)), rad_to_deg(atan2(spine.dot(lat), spine.y)), rad_to_deg(hips_line.angle_to(Vector3.UP)))


var _last_bend := 0.0


func _series(ap: AnimationPlayer, sk: Skeleton3D, anim_name: String) -> Array:
	var a: Animation = ap.get_animation(anim_name)
	var out: Array = []
	var t := 0.0
	while t <= a.length + 0.0001:
		ap.play(anim_name)
		ap.seek(t, true)
		ap.advance(0)
		sk.force_update_all_bone_transforms()
		var v := _trunk(sk)
		out.append(Vector4(v.x, v.y, v.z, _last_bend))
		t += 1.0 / 30.0
	return out


func _ready() -> void:
	var m: Node3D = CourtPlayerModel.build_student({})
	add_child(m)
	var ap: AnimationPlayer = m.get_node("AnimationPlayer")
	var sk: Skeleton3D = CourtPlayerModel.find_skeleton(m)
	print("clip         retarget | worst |game-source| pitch, roll, spine bend (deg) | torso_posture removes: mean, max (deg)")
	for clip: String in CourtPlayerModel.CLIPS:
		if not ap.has_animation(clip):
			continue
		var spec: Array = CourtPlayerModel.CLIPS[clip]
		var how: String = "ours" if clip in CourtPlayerModel.RETARGETED else ("library" if spec[0] == CourtPlayerModel.UAL else "engine")
		var game := _series(ap, sk, clip)
		var removed_sum := 0.0
		var removed_max := 0.0
		for v: Vector4 in game:
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
			var wb := 0.0
			for i in mini(game.size(), source.size()):
				wp = maxf(wp, absf((game[i] as Vector4).x - (source[i] as Vector4).x))
				wr = maxf(wr, absf((game[i] as Vector4).y - (source[i] as Vector4).y))
				wb = maxf(wb, absf((game[i] as Vector4).w - (source[i] as Vector4).w))
			cmp = "pitch %5.1f  roll %5.1f  bend %5.1f" % [wp, wr, wb]
		src.queue_free()
		print("%-12s %-8s | %s | %5.1f  %5.1f" % [clip, how, cmp, removed_sum / maxf(1.0, game.size()), removed_max])
	get_tree().quit(0)
