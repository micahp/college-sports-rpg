extends Node
## Renders one contested jump shot on the real skinned players, for before /
## after comparison of the contesting defender. Three views per sampled frame:
## the gameplay camera, and two side cameras aimed at the defender's chest.
##   godot --path . res://tests/contest_views.tscn -- tag=before
## Frames go to build/contest_views/<tag>/<view>_f<NN>.png. The shot starts
## at frame 0 and is released at frame 30 (RELEASE_AT).

const CourtScene: PackedScene = preload("res://scenes/court/court_game.tscn")
const CourtGame = preload("res://scripts/court/court_game.gd")
const FRAMES: Array[int] = [4, 8, 12, 16, 20, 26, 36, 48]
const RELEASE_AT: int = 30
const SIDE_DISTANCE: float = 2.6


func _ready() -> void:
	var tag: String = "run"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
	var out: String = "res://build/contest_views/%s/" % tag
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	GameState.reset()
	GameState.look_id = "look_a"
	CourtGame.auto_play = false
	var court: Node3D = CourtScene.instantiate()
	court.scenario = CourtGame.demo_scenario()
	# This runner keeps processing while the tree is paused for the screenshots;
	# the game must not, or each extra view would be taken frames later.
	court.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(court)
	while court._phase != CourtGame.Phase.LIVE:
		await get_tree().physics_frame
	court._catch_grace = 99.0
	var user: Node3D = court._user
	user.position = CourtGame.HOOP_FLAT + Vector3(-2.2, 0, 4.6)
	user.vel = Vector3.ZERO
	var toward: Vector3 = (CourtGame.HOOP_FLAT - user.flat()).normalized()
	# The shooter's own man contests from a metre in front; the rest stay away.
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
	court._begin_shot()
	var side_cam: Camera3D = Camera3D.new()
	side_cam.fov = 40.0
	add_child(side_cam)
	for frame in range(1, FRAMES.back() + 1):
		await get_tree().physics_frame
		if frame == RELEASE_AT:
			court._release_shot()
		if not FRAMES.has(frame):
			continue
		get_tree().paused = true
		var game_cam: Camera3D = get_viewport().get_camera_3d()
		await _shoot(out + "game_f%02d.png" % frame)
		var chest: Vector3 = d.global_position + Vector3.UP * 1.25
		for view: Array in [["right", 1.0], ["left", -1.0]]:
			side_cam.global_position = chest + d.right() * float(view[1]) * SIDE_DISTANCE + Vector3.UP * 0.25
			side_cam.look_at(chest, Vector3.UP)
			side_cam.make_current()
			await _shoot(out + "%s_f%02d.png" % [view[0], frame])
		if game_cam != null:
			game_cam.make_current()
		get_tree().paused = false
	print("CONTEST VIEWS saved to ", ProjectSettings.globalize_path(out))
	get_tree().quit(0)


func _shoot(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
