extends Node3D
## Right leg through the defensive slide (all modifiers on): front and side close-ups, several moments.
const Actor = preload("res://scripts/court/court_actor.gd")
var _out: String

func _ready() -> void:
	_out = OS.get_cmdline_user_args()[0]
	DisplayServer.window_set_size(Vector2i(360, 480))
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
	var views := {"front": Vector3(0, 0.0, -1.1), "side": Vector3(1.1, 0.0, 0.0)}
	var shots := 0
	for i in 300:
		a.call("pose_reset")
		a.set("team", 1)
		a.call("lock_face", a.position + Vector3(0, 0, -8.0))
		a.call("move_with", Vector3(-2.63, 0, 0), 1.0 / 60.0, 16.0)
		a.call("animate", 1.0 / 60.0)
		var p: Vector3 = a.position
		await get_tree().process_frame
		if i >= 120 and (i - 120) % 22 == 0 and shots < 6:
			for v: String in views:
				cam.position = p + views[v] + Vector3(0, 0.55, 0)
				cam.look_at(p + Vector3(0, 0.5, 0))
				for k in 2:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [_out, v, shots])
			shots += 1
	get_tree().quit(0)
