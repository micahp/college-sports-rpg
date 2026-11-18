extends Node
## Plays one jump shot and one layup through the real control path (hold,
## release at the middle of the meter) for recording and frame review.
##   godot --write-movie out.avi --fixed-fps 60 tests/court_shot_demo.tscn -- close

const CourtScene: PackedScene = preload("res://scenes/court/court_game.tscn")
const CourtGame = preload("res://scripts/court/court_game.gd")


func _ready() -> void:
	GameState.reset()
	GameState.look_id = "look_a"
	CourtGame.auto_play = false
	CourtGame.debug_close_cam = OS.get_cmdline_user_args().has("close")
	var court: Node3D = CourtScene.instantiate()
	court.scenario = CourtGame.demo_scenario()
	add_child(court)
	while court._phase != CourtGame.Phase.LIVE:
		await get_tree().physics_frame
	court._catch_grace = 99.0
	var user: Node3D = court._user
	for d: Node3D in court._defense:
		d.position = Vector3(d.position.x, 0, 4.0)
		d.track = d.position
	if OS.get_cmdline_user_args().has("layup"):
		# A drive: he arrives at the right side of the lane at speed.
		user.position = CourtGame.HOOP_FLAT + Vector3(2.2, 0, 5.6)
		var toward: Vector3 = (CourtGame.HOOP_FLAT - user.flat()).normalized()
		for i in 50:  # run at the rim so he is really moving when the layup starts
			court._user.has_ball = true
			user.move_with(toward * 4.6, 1.0 / 60.0, 22.0)
			await get_tree().physics_frame
		print("LAYUP begin at frame ", Engine.get_frames_drawn(), " speed ", snappedf(user.vel.length(), 0.1), " m/s, ", snappedf(user.flat().distance_to(CourtGame.HOOP_FLAT), 0.01), " m out")
		court._begin_layup()
		while not court._layup_air and court._layup:
			await get_tree().physics_frame
		print("LAYUP takeoff at frame ", Engine.get_frames_drawn(), " from ", snappedf(user.flat().distance_to(CourtGame.HOOP_FLAT), 0.01), " m out, jump covers ", snappedf(court._layup_from.distance_to(court._layup_to), 0.01), " m")
		while court._layup:
			await get_tree().physics_frame
		print("LAYUP release at frame ", Engine.get_frames_drawn(), " ball at ", snappedf(court._ball.position.y, 0.01), " m, ", snappedf(user.flat().distance_to(CourtGame.HOOP_FLAT), 0.01), " m from the rim")
		for i in 120:
			await get_tree().physics_frame
		get_tree().quit(0)
		return
	# Jump shot from the elbow, defenders cleared out.
	user.position = CourtGame.HOOP_FLAT + Vector3(-2.2, 0, 4.6)
	user.vel = Vector3.ZERO
	for d: Node3D in court._defense:
		d.position = Vector3(d.position.x, 0, 4.0)
		d.track = d.position
	for i in 40:
		await get_tree().physics_frame
	print("SHOT begin at frame ", Engine.get_frames_drawn())
	court._begin_shot()
	while court._meter_pos < CourtGame.METER_CENTER:
		await get_tree().physics_frame
	court._release_shot()
	print("SHOT button released at frame ", Engine.get_frames_drawn())
	while court._ball_mode == "windup":
		await get_tree().physics_frame
	print("SHOT ball left the hand at frame ", Engine.get_frames_drawn(), " from ", snappedf(court._ball.position.y, 0.01), " m, flight ", snappedf(court._flight_dur, 0.01), " s")
	for i in 150:
		await get_tree().physics_frame
	get_tree().quit(0)
