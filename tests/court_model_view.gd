extends Node3D
## Animation QA for the court player model. For every clip it measures
## things a still can't show and saves a strip of evenly spaced frames:
##   - loop seam: how far the pose jumps from the last frame to the first
##   - feet: lowest and highest the lower foot gets (sinking / floating)
##   - drift: how far the hips wander (clips are meant to be in place)
##
##   godot tests/court_model_view.tscn -- shots <dir>

const FRAMES: int = 12

var _bad: int = 0
const FEET: Array[String] = ["LeftFoot", "RightFoot", "LeftToes", "RightToes"]


func _bone(sk: Skeleton3D, name: String) -> int:
	var i: int = sk.find_bone(name)
	return i if i >= 0 else sk.find_bone(name.replace("Toes", "Foot"))


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[args.find("shots") + 1] if args.find("shots") >= 0 else "user://model_view"
	DirAccess.make_dir_recursive_absolute(out)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.2, 0.22, 0.28)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	(floor_mesh.mesh as PlaneMesh).size = Vector2(6, 6)
	add_child(floor_mesh)
	var cam: Camera3D = Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0.0, 1.05, 2.6)
	var build_fn: Callable = CourtPlayerModel.build_student if args.has("student") else CourtPlayerModel.build
	var model: Node3D = build_fn.call({"Shirt": Color(0.92, 0.72, 0.3), "Pants": Color(0.12, 0.2, 0.42),
		"Skin": Color(0.48, 0.34, 0.24), "Socks": Color(0.95, 0.95, 0.95)})
	add_child(model)
	model.rotation.y = 0.0 if args.has("front") else (1.5708 if args.has("side") else 0.7)
	var sk: Skeleton3D = CourtPlayerModel.find_skeleton(model)
	var ap: AnimationPlayer = model.get_node("AnimationPlayer")
	if not args.has("noposture"):
		sk.add_child(load("res://scripts/court/torso_posture.gd").new())
	if not args.has("noclear"):
		sk.add_child(load("res://scripts/court/arm_clearance.gd").new())
	print("clip          len   loop  seam(m)  foot_min  foot_max  drift(m)  hips_y_range")
	for clip: String in ap.get_animation_list():
		var anim: Animation = ap.get_animation(clip)
		var length: float = anim.length
		var loops: bool = anim.loop_mode != Animation.LOOP_NONE
		ap.play(clip)
		ap.seek(0.0, true)
		sk.force_update_all_bone_transforms()
		var first: Array[Vector3] = _joints(sk)
		var foot_min: float = INF
		var foot_max: float = -INF
		var hips_min: Vector3 = Vector3(INF, INF, INF)
		var hips_max: Vector3 = -hips_min
		var steps: int = 40
		var planted: float = INF  # lowest foot while it should be on the floor
		# Stride phase: when the left foot lands, and how many times per loop.
		if loops and clip != "Idle":
			var strikes: Array[float] = []
			var was_down: bool = true
			var lowest: float = INF
			for i in 240:
				ap.seek(length * i / 240.0, true)
				sk.force_update_all_bone_transforms()
				lowest = minf(lowest, sk.get_bone_global_pose(_bone(sk, "LeftToes")).origin.y)
			for i in 480:  # two passes so a strike at the seam is caught
				ap.seek(length * (i % 240) / 240.0, true)
				sk.force_update_all_bone_transforms()
				var down: bool = sk.get_bone_global_pose(_bone(sk, "LeftToes")).origin.y < lowest + 0.025
				if down and not was_down and i >= 240:
					strikes.append(length * (i % 240) / 240.0)
				was_down = down
			print("   PHASE %s: left foot lands %d time(s) per loop, first at %.3fs of %.3fs" % [clip, strikes.size(),
				strikes[0] if not strikes.is_empty() else -1.0, length])
		for i in steps + 1:
			ap.seek(length * i / steps, true)
			sk.force_update_all_bone_transforms()
			var low: float = INF
			for f: String in FEET:
				low = minf(low, sk.get_bone_global_pose(_bone(sk, f)).origin.y)
			foot_min = minf(foot_min, low)
			foot_max = maxf(foot_max, low)
			if loops or i <= steps / 4:
				planted = minf(planted, low)
			var h: Vector3 = sk.get_bone_global_pose(sk.find_bone("Hips")).origin
			hips_min = hips_min.min(h)
			hips_max = hips_max.max(h)
		var last: Array[Vector3] = _joints(sk)
		var seam: float = 0.0
		for j in first.size():
			seam = maxf(seam, first[j].distance_to(last[j]))
		var drift: float = Vector2(hips_max.x - hips_min.x, hips_max.z - hips_min.z).length()
		print("%-12s %5.2f  %-5s %6.3f   %7.3f   %7.3f   %6.3f    %6.3f" % [clip, length, str(loops),
			seam, foot_min, foot_max, drift, hips_max.y - hips_min.y])
		var mocap: bool = CourtPlayerModel.CLIPS[clip][3]
		if mocap:
			var off: float = 0.012 - planted
			print("   planted foot %.3f -> needs offset %+.3f%s" % [planted, off, "" if absf(off) <= 0.02 else "   <-- NOT GROUNDED"])
			if absf(off) > 0.02 and clip != "Layup":  # the layup clip starts mid-stride
				_bad += 1
		if loops and seam > 0.03:
			print("   <-- LOOP POPS (%.3f m)" % seam)
			_bad += 1
		for i in FRAMES:
			ap.seek(length * i / (FRAMES - 1), true)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s_%02d.png" % [out, clip, i])
	print("ANIMATION QA PASSED" if _bad == 0 else "ANIMATION QA FAILED (%d)" % _bad)
	get_tree().quit(0 if _bad == 0 else 1)


## Model-space positions of the joints that show a pop.
func _joints(sk: Skeleton3D) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	for b: String in ["Hips", "Head", "LeftHand", "RightHand", "LeftFoot", "RightFoot", "LeftLowerLeg", "RightLowerLeg"]:
		pts.append(sk.get_bone_global_pose(sk.find_bone(b)).origin)
	return pts
