extends Node
## Renders head-and-shoulders portraits for every NPC and player look, plus
## the title-screen background, from the real 3D rigs:
##   xvfb-run godot --rendering-driver opengl3 tools/render_portraits.tscn
## Writes assets/portraits/<id>.png (256px) and assets/branding/title_bg.png.

const SIZE: int = 256


func _ready() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.24, 0.4)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.82, 0.9)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-25, -35, 0)
	key.light_color = Color(1.0, 0.93, 0.84)
	key.light_energy = 1.2
	add_child(key)
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 150, 0)
	rim.light_color = Color(0.92, 0.72, 0.3)
	rim.light_energy = 0.8
	add_child(rim)
	var camera: Camera3D = Camera3D.new()
	camera.fov = 20
	camera.position = Vector3(0.12, 1.6, 2.6)
	camera.rotation_degrees = Vector3(-1, 3, 0)
	add_child(camera)
	camera.make_current()

	var jobs: Array = []
	var npcs: Dictionary = ContentDB.get_npcs()
	for id: String in npcs.keys():
		jobs.append([id, npcs[id]])
	for look: Dictionary in ContentDB.get_looks():
		jobs.append([look["id"], look])
	for job: Array in jobs:
		var info: Dictionary = job[1]
		var model: Node3D = CharacterAppearance.build(str(info["model"]), {
			"Shirt": Color(str(info["shirt"])), "Pants": Color(str(info["pants"])),
			"Skin": CharacterAppearance.SKIN_TONES[str(info["skin"])], "Hair": Color(str(info["hair"])),
		})
		add_child(model)
		model.rotation_degrees.y = 18
		var anim: AnimationPlayer = model.get_node("AnimationPlayer")
		anim.play("HumanArmature|%s_Idle" % CharacterAppearance.anim_prefix(str(info["model"])))
		anim.seek(0.3, true)
		anim.pause()
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		var side: int = img.get_height()
		img = img.get_region(Rect2i((img.get_width() - side) / 2, 0, side, side))
		img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		img.save_png(ProjectSettings.globalize_path("res://assets/portraits/%s.png" % job[0]))
		print("portrait ", job[0])
		model.queue_free()
		await get_tree().process_frame
	camera.queue_free()
	world.queue_free()
	key.queue_free()
	rim.queue_free()
	await _title_background()
	get_tree().quit(0)


## A wide, people-free-ish evening view of the quad for the title screen.
func _title_background() -> void:
	GameState.reset()
	TimeSystem.reset()
	TimeSystem.period = TimeSystem.Period.EVENING
	Game.arrival = "start"
	var campus: Node3D = load(Game.SCENES["campus"]).instantiate()
	add_child(campus)
	for i in 10:
		await get_tree().process_frame
	campus.ui.visible = false
	campus.player.visible = false
	var rig: Node3D = campus.get_node("CameraRig")
	campus.set_process(false)
	rig.global_position = Vector3(0, 0, -6)
	rig.get_child(0).rotation_degrees = Vector3(-22, 12, 0)
	var cam: Camera3D = rig.get_child(0).get_child(0)
	cam.position.z = 24
	cam.fov = 45
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://assets/branding/title_bg.png"))
	print("title background")
