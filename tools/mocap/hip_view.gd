extends Node3D
## Defender in the slide: hips close-up from four sides, at three moments of the stride.
const Actor = preload("res://scripts/court/court_actor.gd")

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DisplayServer.window_set_size(Vector2i(300, 300))
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.72, 0.82)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.9
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var fm := MeshInstance3D.new()
	fm.mesh = PlaneMesh.new()
	(fm.mesh as PlaneMesh).size = Vector2(30, 30)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.79, 0.6, 0.36)
	fm.material_override = mat
	add_child(fm)
	var cam := Camera3D.new()
	add_child(cam)
	var a = Actor.new()
	add_child(a)
	a.setup("", {"Shirt": Color(0.8, 0.15, 0.2), "Pants": Color(1, 1, 1), "Skin": Color(0.48, 0.34, 0.24), "Socks": Color(0.95, 0.95, 0.95)}, 0, 0.0)
	a.set("team", 1)
	var views := {"front": Vector3(0, 0.0, -0.95), "back": Vector3(0, 0.0, 0.95), "side": Vector3(0.95, 0.0, 0.0), "diag": Vector3(0.7, 0.0, 0.7)}
	var gait: String = OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "slide"
	var shots := 0
	for i in 240:
		a.call("pose_reset")
		if gait == "jog":
			a.set("team", 0)
			a.call("move_with", Vector3(0, 0, -2.68), 1.0 / 60.0, 16.0)
		else:
			a.set("team", 1)
			a.call("lock_face", a.position + Vector3(0, 0, -8.0))
			if gait == "slide": a.call("move_with", Vector3(2.63, 0, 0), 1.0 / 60.0, 16.0)
			elif gait == "backpedal": a.call("move_with", Vector3(0, 0, 1.22), 1.0 / 60.0, 16.0)
			elif gait == "jumpshot" and i == 100: a.set("has_ball", false); a.call("action", "JumpShot", 1.0, 0.3)
		a.call("animate", 1.0 / 60.0)
		var p: Vector3 = a.position
		await get_tree().process_frame
		if i >= 100 and (i - 100) % (12 if gait != "jumpshot" else 22) == 0 and shots < 3:
			for v: String in views:
				cam.position = p + views[v] + Vector3(0, 0.6, 0)
				cam.look_at(p + Vector3(0, 0.55, 0))
				for k in 2:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [out, v, shots])
			shots += 1
	get_tree().quit(0)
