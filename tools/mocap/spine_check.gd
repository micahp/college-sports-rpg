extends Node3D
## Prints the torso's up direction (Hips to UpperChest, world) for the CMU glb clip and for the retargeted student.
const STUDENT: String = "res://assets/court/students/Male_Casual.fbx"
const Retarget = preload("res://scripts/court/mocap_retarget.gd")

func _ready() -> void:
	var src: Node = (load("res://tools/mocap/cmu_clips/clip77_03.glb") as PackedScene).instantiate()
	add_child(src)
	var cmu_sk: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0]
	var player: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
	var cmu_anim: Animation = player.get_animation("clip77_03")
	var st: Node3D = (load(STUDENT) as PackedScene).instantiate()
	add_child(st)
	var sk: Skeleton3D = st.find_children("*", "Skeleton3D", true, false)[0]
	var target := Animation.new()
	target.length = cmu_anim.length
	Retarget.apply(target, cmu_sk, cmu_anim, sk)
	var tracks: Array = []
	for t in target.get_track_count():
		tracks.append([target.track_get_type(t), str(target.track_get_path(t).get_concatenated_subnames()), t])
	print("CMU rest  torso up ", _up(cmu_sk, cmu_sk.find_bone("Hips"), cmu_sk.find_bone("UpperChest")))
	print("STU rest  torso up ", _up(sk, sk.find_bone("Hips"), sk.find_bone("UpperChest")))
	for tm in ["2.0", "3.0", "4.0", "5.5"]:
		var tt: float = float(tm)
		# CMU source, sampled from its own clip
		cmu_player_seek(player, tt)
		print("t=%s CMU  torso up %s" % [tm, _up(cmu_sk, cmu_sk.find_bone("Hips"), cmu_sk.find_bone("UpperChest"))])
		sk.reset_bone_poses()
		for tr in tracks:
			var bi: int = sk.find_bone(tr[1])
			if bi < 0:
				continue
			if tr[0] == Animation.TYPE_ROTATION_3D:
				sk.set_bone_pose_rotation(bi, target.rotation_track_interpolate(tr[2], tt))
			elif tr[0] == Animation.TYPE_POSITION_3D:
				sk.set_bone_pose_position(bi, target.position_track_interpolate(tr[2], tt) * sk.motion_scale)
		print("t=%s STU  torso up %s" % [tm, _up(sk, sk.find_bone("Hips"), sk.find_bone("UpperChest"))])
	get_tree().quit(0)

func cmu_player_seek(p: AnimationPlayer, t: float) -> void:
	p.play("clip77_03")
	p.seek(t, true)
	p.advance(0.0)

func _up(sk: Skeleton3D, a: int, b: int) -> String:
	var pa: Vector3 = sk.get_bone_global_pose(a).origin
	var pb: Vector3 = sk.get_bone_global_pose(b).origin
	var d: Vector3 = (pb - pa).normalized()
	return "(%.2f, %.2f, %.2f)" % [d.x, d.y, d.z]
