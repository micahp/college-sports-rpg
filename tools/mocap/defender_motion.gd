extends Node3D
## Mesh-only look at court players: defenders in the stance and sliding, an offensive player beside them,
## from a high three-quarter camera like the phone view.
const Actor = preload("res://scripts/court/court_actor.gd")

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
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

	var defender = Actor.new()
	add_child(defender)
	defender.setup("", kit, 0, 0.0)
	defender.team = 1
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.6
	var stages := ["walk", "run"] if "forward" in OS.get_cmdline_user_args() else ["idle", "right", "left", "stop"]
	if "clap" in OS.get_cmdline_user_args():
		stages = ["clap"]
		defender.team = 0
		defender.action("Clap", 1.6)
		cam.size = 1.35
	for stage in stages:
		var speed := 2.4 if stage == "right" else (-2.4 if stage == "left" else 0.0)
		for frame in 60:
			defender.pose_reset()
			defender.lock_face(defender.position + Vector3.FORWARD * 8.0)
			var velocity := Vector3.RIGHT * speed
			if stage in ["walk", "run"]:
				velocity = Vector3.FORWARD * (1.0 if stage == "walk" else 3.9)
			defender.move_with(velocity, 1.0/60.0)
			defender.animate(1.0/60.0)
			var center: Vector3 = defender.position + Vector3.UP * 0.95
			if stage == "clap": center.y = 1.32
			cam.position = center + Vector3(1, 0.3, -4)
			cam.look_at(center)
			await get_tree().process_frame
			if frame == 59:
				print(stage, " ", defender._gait, " stride arms ", defender._stride_arms.influence)
			if frame % 10 == 9:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(out.path_join("%s_%02d.png" % [stage, frame]))
	get_tree().quit()
