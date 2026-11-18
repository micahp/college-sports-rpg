extends Node3D
## Shows the player build range side by side: bulk 0, 0.33, 0.66, 1.
##   godot tests/court_build_view.tscn -- shots <dir>

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[args.find("shots") + 1] if args.find("shots") >= 0 else "user://build_view"
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
	var cam: Camera3D = Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0.0, 1.05, 3.6)
	for i in 4:
		var m: Node3D = CourtPlayerModel.build({"Shirt": Color(0.92, 0.72, 0.3), "Pants": Color(0.12, 0.2, 0.42),
			"Skin": Color(0.48, 0.34, 0.24), "Socks": Color(0.95, 0.95, 0.95)}, 0, i / 3.0)
		add_child(m)
		m.position.x = -1.5 + i * 1.0
		(m.get_node("AnimationPlayer") as AnimationPlayer).play("Idle")
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/builds.png")
	get_tree().quit(0)
