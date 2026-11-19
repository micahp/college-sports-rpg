extends Node3D
## Front torso and legs of a stance defender and a slider, with one skeleton modifier off per run.
const Actor = preload("res://scripts/court/court_actor.gd")
var _out: String

func _mods(sk: Skeleton3D) -> Array:
	var m: Array = []
	for c in sk.get_children():
		if c is SkeletonModifier3D: m.append(c)
	return m

func _name(c: Node) -> String:
	return str(c.get_script().resource_path.get_file().get_basename()) if c.get_script() != null else str(c.get_class())

func _ready() -> void:
	_out = OS.get_cmdline_user_args()[0]
	DisplayServer.window_set_size(Vector2i(300, 360))
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
	var cam := Camera3D.new()
	add_child(cam)
	var probe = Actor.new()
	add_child(probe)
	probe.setup("", {}, 0, 0.0)
	var names: Array = []
	for c in _mods(probe.get("_skeleton")): names.append(_name(c))
	probe.queue_free()
	await get_tree().process_frame
	print("MODS ", names)
	var variants: Array = ["all", "none"]
	for i in names.size(): variants.append("minus_%02d_%s" % [i, names[i]])
	for v: String in variants:
		var a = Actor.new()
		add_child(a)
		a.setup("", {"Shirt": Color(0.8, 0.15, 0.2), "Pants": Color(1, 1, 1), "Skin": Color(0.48, 0.34, 0.24), "Socks": Color(0.95, 0.95, 0.95)}, 0, 0.0)
		a.set("team", 1)
		var sk: Skeleton3D = a.get("_skeleton")
		var mods: Array = _mods(sk)
		if v == "none":
			for m in mods: m.active = false
		elif v.begins_with("minus_"):
			mods[int(v.split("_")[1])].active = false
		var shots := 0
		for i in 200:
			a.call("pose_reset")
			a.set("team", 1)
			a.call("lock_face", a.position + Vector3(0, 0, -8.0))
			a.call("move_with", Vector3(2.63, 0, 0) if i > 100 else Vector3.ZERO, 1.0 / 60.0, 16.0)
			a.call("animate", 1.0 / 60.0)
			var p: Vector3 = a.position
			cam.position = p + Vector3(0.0, 1.05, -1.5)
			cam.look_at(p + Vector3(0, 1.0, 0))
			await get_tree().process_frame
			if i in [60, 180]:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [_out, v, shots])
				shots += 1
		a.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)
