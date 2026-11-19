extends Node3D
## Drives the campus student's skeleton from a CMU clip's per-bone rotation deltas and renders front and side.
## Args after --: <poses json> <out dir> <frame indices comma list>
const STUDENT: String = "res://assets/court/students/Male_Casual.fbx"

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var out: String = args[1]
	var picks: PackedStringArray = args[2].split(",")
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
	# Pick the bone rests once (before any pose is set).
	var rest: Dictionary = {}
	for i in sk.get_bone_count():
		rest[sk.get_bone_name(i)] = sk.get_bone_global_rest(i)
	var hips_i: int = sk.find_bone("Hips")
	var lu: Vector3 = (rest["LeftUpperArm"] as Transform3D).origin
	var ru: Vector3 = (rest["RightUpperArm"] as Transform3D).origin
	print("STUDENT LeftUpperArm x %.3f  RightUpperArm x %.3f  (left arm at +x means no mirror)" % [lu.x, ru.x])
	var leg_st: float = (rest["LeftUpperLeg"] as Transform3D).origin.distance_to((rest["LeftFoot"] as Transform3D).origin)
	var scale: float = leg_st / float(data["leg_asf"])
	var frames: Array = data["frames"]
	for p in picks:
		var idx: int = int(p)
		if idx < 0 or idx >= frames.size():
			continue
		var fr: Dictionary = frames[idx]
		var rq: Dictionary = data["rest"]
		for b in fr["b"]:
			var bi: int = sk.find_bone(b)
			if bi < 0:
				continue
			var q: Array = fr["b"][b]
			var delta := Basis(Quaternion(q[1], q[2], q[3], q[0]))
			var r: Transform3D = rest[b]
			var origin: Vector3 = r.origin
			if b == "Hips":
				origin += Vector3(0, float(fr["hips_y"]) * scale, 0)
			# CMU bone frame -> student bone frame: C maps the CMU rest onto the student rest (world axes shared).
			var ra: Array = rq[b]
			var ca := Basis(Quaternion(ra[1], ra[2], ra[3], ra[0]))
			var c: Basis = ca.transposed() * r.basis
			sk.set_bone_global_pose(bi, Transform3D(r.basis * c.transposed() * delta * c, origin))
		var c: Vector3 = (rest["Hips"] as Transform3D).origin
		c.y = (sk.get_bone_global_pose(hips_i).origin.y) if hips_i >= 0 else c.y
		for view in ["front", "side"]:
			var off: Vector3 = Vector3(0, 0, -1.8) if view == "front" else Vector3(1.8, 0, 0)
			cam.position = c + off + Vector3(0, 0.3, 0)
			cam.look_at(c + Vector3(0, 0.2, 0))
			for k in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s_%03d.png" % [out, view, idx])
	get_tree().quit(0)
