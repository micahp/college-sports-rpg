extends Node3D
## The defender guarding a dribbler (game loop: _holder == d.man, ball "held", "shade" hands), mesh only.
const Actor = preload("res://scripts/court/court_actor.gd")

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DisplayServer.window_set_size(Vector2i(500, 600))
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
	var off := {"Shirt": Color(0.95, 0.75, 0.2), "Pants": Color(0.12, 0.2, 0.42), "Skin": Color(0.48, 0.34, 0.24), "Socks": Color(0.95, 0.95, 0.95)}
	var o = Actor.new(); add_child(o); o.setup("", off, 0, 0.0); o.position = Vector3(0, 0, 0)
	var d = Actor.new(); add_child(d); d.setup("", kit, 0, 0.0); d.position = Vector3(0, 0, -0.9)
	for i in 120:
		o.call("pose_reset")
		o.call("animate", 1.0 / 60.0)
		d.set("team", 1)
		d.call("pose_reset")
		d.set("guard_elbow", true)
		d.call("lock_face", o.position)
		# the game's shading hands while guarding a held ball (court_game.gd, held branch), ball at the dribbler's right
		var shade := 0.0
		for side in ["L", "R"]:
			var lateral := 1.0 if side == "R" else -1.0
			var near_ball := (1.0 + lateral * shade) * 0.5
			var palm: Vector3 = d.body_point(0.18 + 0.02 * near_ball, lateral * (0.20 - 0.02 * near_ball), 0.90 + 0.02 * near_ball)
			d.call("hand", side, palm - d.facing() * 0.08, 1.0)
			d.call("palm_on", side, palm, palm + d.facing() - Vector3.UP * 0.3 - d.right() * lateral * 0.5, 1.0)
		d.set("guard_elbow", true)
		d.call("animate", 1.0 / 60.0)
		await get_tree().process_frame
	cam.position = Vector3(0.9, 1.5, -2.6)
	cam.look_at(Vector3(0, 1.1, -0.4))
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/guard.png")
	get_tree().quit(0)
