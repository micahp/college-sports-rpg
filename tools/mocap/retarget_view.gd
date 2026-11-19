extends Node3D
## Retargets a CMU glb clip onto the campus student with the game's own MocapRetarget and renders front and side.
## Args after --: <clip glb> <clip anim name> <out dir> <times in seconds, comma list>
const STUDENT: String = "res://assets/court/students/Male_Casual.fbx"
const Retarget = preload("res://scripts/court/mocap_retarget.gd")

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var src: Node = (load(args[0]) as PackedScene).instantiate()
	var cmu_sk: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0]
	var player: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
	var cmu_anim: Animation = player.get_animation(args[1])
	var out: String = args[2]
	var times: PackedStringArray = args[3].split(",")
	DisplayServer.window_set_size(Vector2i(600, 600))
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.72, 0.82)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.9
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	add_child(sun)
	var fm := MeshInstance3D.new()
	fm.mesh = PlaneMesh.new()
	(fm.mesh as PlaneMesh).size = Vector2(30, 30)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.75, 0.5)
	fm.material_override = mat
	add_child(fm)
	var cam := Camera3D.new()
	add_child(cam)
	var st: Node3D = (load(STUDENT) as PackedScene).instantiate()
	add_child(st)
	var sk: Skeleton3D = st.find_children("*", "Skeleton3D", true, false)[0]
	var target := Animation.new()
	target.length = cmu_anim.length
	Retarget.apply(target, cmu_sk, cmu_anim, sk)
	var tracks: Array = []
	for t in target.get_track_count():
		tracks.append([target.track_get_type(t), str(target.track_get_path(t).get_concatenated_subnames()), t])
	var hips_i: int = sk.find_bone("Hips")
	for tm in times:
		var tt: float = float(tm)
		sk.reset_bone_poses()
		for tr in tracks:
			var bi: int = sk.find_bone(tr[1])
			if bi < 0:
				continue
			if tr[0] == Animation.TYPE_ROTATION_3D:
				sk.set_bone_pose_rotation(bi, target.rotation_track_interpolate(tr[2], tt))
			elif tr[0] == Animation.TYPE_POSITION_3D:
				sk.set_bone_pose_position(bi, target.position_track_interpolate(tr[2], tt) * sk.motion_scale)
		var c: Vector3 = sk.get_bone_global_pose(hips_i).origin + sk.global_position
		for view in ["front", "side"]:
			var off: Vector3 = Vector3(0, 0, -2.6) if view == "front" else Vector3(2.6, 0, 0)
			cam.position = c + off + Vector3(0, 0.6, 0)
			cam.look_at(c + Vector3(0, 0.6, 0))
			for k in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out, view, tm])
	get_tree().quit(0)
