extends Node
## Renders the shooter's whole jump shot on the real skinned players, from the
## gather through the release, landing and return to idle, for before / after
## comparison. Same fixture as tests/contest_views (contested jump shot,
## release at frame 30). Three views per frame: the gameplay camera, and two
## cameras placed once at the start and never moved (a side view and a front
## three-quarter view of the shooter), so the jump's height and the trunk's
## lean read against the floor and the background.
##   godot --path . res://tests/shot_views.tscn -- tag=before
## Frames go to build/shot_views/<tag>/<view>_f<NN>.png.
const CourtScene: PackedScene = preload("res://scenes/court/court_game.tscn")
const CourtGame = preload("res://scripts/court/court_game.gd")
const FRAMES: Array[int] = [0, 6, 12, 18, 24, 30, 36, 42, 48, 54, 60, 66, 72, 84, 96]
const RELEASE_AT: int = 30


func _ready() -> void:
	var tag: String = "run"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
	var out: String = "res://build/shot_views/%s/" % tag
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	GameState.reset()
	GameState.look_id = "look_a"
	CourtGame.auto_play = false
	var court: Node3D = CourtScene.instantiate()
	court.scenario = CourtGame.demo_scenario()
	court.process_mode = Node.PROCESS_MODE_PAUSABLE  # the runner keeps going while the game is paused
	add_child(court)
	while court._phase != CourtGame.Phase.LIVE:
		await get_tree().physics_frame
	court._catch_grace = 99.0
	var user: Node3D = court._user
	user.position = CourtGame.HOOP_FLAT + Vector3(-2.2, 0, 4.6)
	user.vel = Vector3.ZERO
	var toward: Vector3 = (CourtGame.HOOP_FLAT - user.flat()).normalized()
	var d: Node3D = court._defense[0]
	for o: Node3D in court._defense:
		if o.man == user:
			d = o
	for o: Node3D in court._defense:
		if o != d:
			o.position = Vector3(o.position.x, 0, 4.0)
			o.track = o.position
	d.position = user.flat() + toward * 1.0
	d.track = d.position
	for i in 40:
		await get_tree().physics_frame
	# Cameras fixed at the start: side (the shooter's right) and front three-quarter.
	var chest: Vector3 = user.global_position + Vector3.UP * 1.1
	var side := Camera3D.new()
	side.fov = 42.0
	add_child(side)
	side.global_position = chest - user.right() * 4.2 + Vector3.UP * 0.2
	side.look_at(chest + Vector3.UP * 0.25, Vector3.UP)
	var front := Camera3D.new()
	front.fov = 42.0
	add_child(front)
	front.global_position = chest + (user.facing() * 0.8 + user.right() * 0.6).normalized() * 4.2 + Vector3.UP * 0.3
	front.look_at(chest + Vector3.UP * 0.25, Vector3.UP)
	court._begin_shot()
	for frame in range(0, FRAMES.back() + 1):
		if frame > 0:
			await get_tree().physics_frame
		if frame == RELEASE_AT:
			court._release_shot()
		if not FRAMES.has(frame):
			continue
		get_tree().paused = true
		var game_cam: Camera3D = get_viewport().get_camera_3d()
		await _shoot(out + "game_f%02d.png" % frame)
		for view: Array in [["side", side], ["front", front]]:
			(view[1] as Camera3D).make_current()
			await _shoot(out + "%s_f%02d.png" % [view[0], frame])
		if game_cam != null:
			game_cam.make_current()
		get_tree().paused = false
	print("SHOT VIEWS saved to ", ProjectSettings.globalize_path(out))
	get_tree().quit(0)


func _shoot(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
