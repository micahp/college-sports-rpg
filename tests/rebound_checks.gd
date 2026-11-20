extends Node
## Positions are staged at rim contact. Live pursuit, reach, input and landing
## run in the actual court physics loop.
const Court = preload("res://scripts/court/court_game.gd")
const Scene = preload("res://scenes/court/court_game.tscn")
const Actor = preload("res://scripts/court/court_actor.gd")
var court: Node3D
var failures := 0

func _ready() -> void:
	GameState.reset()
	GameState.look_id = "look_a"
	court = Scene.instantiate()
	court.scenario = Court.demo_scenario()
	add_child(court)
	while court._phase != Court.Phase.LIVE:
		await get_tree().physics_frame
	for kind: String in ["user", "defender", "teammate"]:
		await _run_board(kind)
	print("Rebound checks: %d failure(s)" % failures)
	get_tree().quit(1 if failures else 0)

func _run_board(kind: String) -> void:
	var winner: Actor = court._user if kind == "user" else (court._defense[0] if kind == "defender" else court._mates[0])
	var user_rebounds: int = court._stats["reb"]
	var pts: int = court._team_score
	court._rng.seed = 2001
	for i in court._all.size():
		var a: Actor = court._all[i]
		a.position = Vector3(i - 4.5, 0, 3)
		a.stop()
	court._flight_to = Court.HOOP + Vector3(0.30, 0.08, 0)
	court._clock = 100.0
	court._shot_clock = 2.0
	court._begin_rebound()
	var landing := Vector3(court._ball.position.x, 0, court._ball.position.z) + Vector3(court._loose_vel.x, 0, court._loose_vel.z) * 0.66
	winner.position = landing
	var early_missed := false
	var checked_gather := false
	var worst_palm_angle := 0.0
	var worst_gap := 0.0
	var min_elbow := 180.0
	var least_elbow_forward := INF
	var least_hand_forward := INF
	if kind == "defender":
		court._user.position = landing + Vector3(0.75, 0, 0)
		court._on_shoot_down()
	for frame in 300:
		await get_tree().physics_frame
		if not checked_gather and court._holder == winner and court._ball_mode == "secured" and court._recovery_t < 0.20:
			var before: Vector3 = court._ball.position
			var shift := Vector3(0.09, -0.12, 0.04)
			winner.position += shift
			court._update_ball(0.0)
			_check(court._ball.position.distance_to(before + shift) < 0.002, "secured ball follows landing body")
			winner.position -= shift
			court._update_ball(0.0)
			checked_gather = true
		if court._holder == winner and court._ball_mode == "secured" and court._recovery_t > 0.20:
			for side: String in ["L", "R"]:
				var wrist := winner.hand_position(side)
				var elbow := winner.elbow_position(side)
				min_elbow = minf(min_elbow, rad_to_deg((winner.shoulder_position(side)-elbow).angle_to(wrist-elbow)))
				var bone := winner._skeleton.find_bone(Actor.ARM_BONES[side][2])
				var local_normal := winner._skeleton.get_bone_global_rest(bone).basis.inverse() * Vector3.DOWN
				var normal: Vector3 = winner._pose_tap.hand_basis(side) * local_normal
				var palm := wrist + winner.palm_offset(side)
				var toward_ball: Vector3 = court._ball.position - palm
				worst_palm_angle = maxf(worst_palm_angle, rad_to_deg(normal.angle_to(toward_ball)))
				worst_gap = maxf(worst_gap, absf(toward_ball.length() - Court.BALL_FLOOR))
		var jump_t := float(court._board_jumps.get(winner, -1.0))
		if jump_t > 0.08 and jump_t < 0.32:
			for side: String in ["R", "L"]:
				var shoulder := winner.shoulder_position(side)
				least_elbow_forward = minf(least_elbow_forward, (winner.elbow_position(side) - shoulder).dot(winner.facing()))
				least_hand_forward = minf(least_hand_forward, (winner.hand_position(side) - shoulder).dot(winner.facing()))
		if kind == "user" and frame == 25:
			Input.action_press("shoot")
		if kind == "user" and frame == 26:
			Input.action_release("shoot")
		if kind == "defender" and frame > 35 and court._holder != court._user:
			early_missed = true
		if court._phase != Court.Phase.REBOUND:
			break
	print(kind, " palm angle/gap/min elbow ", Vector3(worst_palm_angle, worst_gap, min_elbow))
	_check(min_elbow < 180.0 and worst_palm_angle < 30.0 and worst_gap < 0.015, "both drawn palms face and contact the secured ball")
	_check(checked_gather, "sampled gather during landing")
	print(kind, " rise minimum forward elbow %.3f m, wrist %.3f m" % [least_elbow_forward, least_hand_forward])
	_check(is_finite(least_hand_forward) and least_hand_forward > 0.04 and least_elbow_forward > -0.015, "both arms rise in front of the rebounder")
	_check(court._holder == winner, kind + " secures ball")
	_check(winner.position.y < 0.001, kind + " lands")
	_check(court._team_score == pts, "rebound adds no points")
	_check(int(court._stats["reb"]) == user_rebounds + int(kind == "user"), "user board credited once")
	if kind == "defender":
		_check(early_missed and court._phase == Court.Phase.DEAD and court._ball_mode == "secured", "early user jump loses contested board")
	else:
		_check(court._phase == Court.Phase.LIVE and court._ball_mode == "held" and is_equal_approx(court._shot_clock, 10.0), "offense resumes on ten seconds")
	print(kind, " holder matches ", court._holder == winner, " phase ", court._phase, " clock ", court._shot_clock)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
