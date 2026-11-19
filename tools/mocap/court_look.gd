extends Node3D
## Mesh-only look at court players: defenders in the stance and sliding, an offensive player beside them,
## from a high three-quarter camera like the phone view.
const Actor = preload("res://scripts/court/court_actor.gd")

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
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
	var kit := {"Shirt": Color(0.8, 0.15, 0.2), "Pants": Color(1, 1, 1), "Skin": Color(0.48, 0.34, 0.24), "Socks": Color(0.95, 0.95, 0.95)}
	var off_kit := {"Shirt": Color(0.95, 0.75, 0.2), "Pants": Color(0.12, 0.2, 0.42), "Skin": Color(0.48, 0.34, 0.24), "Socks": Color(0.95, 0.95, 0.95)}
	var d1 = Actor.new(); add_child(d1); d1.setup("", kit, 0, 0.0); d1.position = Vector3(0, 0, 0)
	var d2 = Actor.new(); add_child(d2); d2.setup("", kit, 0, 0.0); d2.position = Vector3(3, 0, 0)
	var o1 = Actor.new(); add_child(o1); o1.setup("", off_kit, 0, 0.0); o1.position = Vector3(-3, 0, 0)
	for i in 90:
		for d in [d1, d2]:
			d.set("team", 1)
			d.call("pose_reset")
			d.call("lock_face", d.position + Vector3(0, 0, -8.0))
			d.call("animate", 1.0 / 60.0)
		o1.call("pose_reset")
		o1.call("animate", 1.0 / 60.0)
		await get_tree().process_frame
	cam.position = Vector3(0, 1.2, 2.4)
	cam.look_at(Vector3(0, 1.0, 0))
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/stance_close.png")
	# slide: defender 1 slides right, defender 2 backpedals
	var shots := 0
	for i in 0:
		d1.set("team", 1); d1.call("pose_reset"); d1.call("lock_face", d1.position + Vector3(0, 0, -8.0)); d1.call("move_with", Vector3(2.63, 0, 0), 1.0 / 60.0, 16.0); d1.call("animate", 1.0 / 60.0)
		d2.set("team", 1); d2.call("pose_reset"); d2.call("lock_face", d2.position + Vector3(0, 0, -8.0)); d2.call("move_with", Vector3(0, 0, 1.22), 1.0 / 60.0, 16.0); d2.call("animate", 1.0 / 60.0)
		o1.call("pose_reset"); o1.call("animate", 1.0 / 60.0)
		await get_tree().process_frame
		if i >= 100 and (i - 100) % 20 == 0 and shots < 2:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/slide_%d.png" % [out, shots])
			shots += 1
	get_tree().quit(0)
