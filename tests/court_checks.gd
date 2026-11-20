extends Node
## Court situation checks: forces each mechanic and asserts the outcome,
## instead of hoping an auto-played stretch happens to hit it.
##
##   godot --headless tests/court_checks.tscn

const CourtScene: PackedScene = preload("res://scenes/court/court_game.tscn")
const CourtGame = preload("res://scripts/court/court_game.gd")

var _failures: int = 0
var _court: Node3D


func _ready() -> void:
	GameState.reset()
	GameState.look_id = "look_a"
	CourtGame.auto_play = false
	Engine.time_scale = 3.0
	var timeout: SceneTreeTimer = get_tree().create_timer(120.0, true, false, true)
	timeout.timeout.connect(func() -> void:
		print("COURT CHECKS FAILED: timeout")
		get_tree().quit(1))

	_check_input_map()
	_court = CourtScene.instantiate()
	_court.scenario = CourtGame.demo_scenario()
	add_child(_court)
	_check_contest_levels()
	await _check_pause()
	await _wait_live()
	_court._catch_grace = 99.0  # no steals while we stage things
	await _check_wasd()
	await _check_pick()
	_check_blowby()
	await _check_shot_arc(false)
	await _check_shot_arc(true)
	await _check_layup()

	print("COURT CHECKS PASSED" if _failures == 0 else "COURT CHECKS FAILED (%d)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		_failures += 1


func _wait_live() -> void:
	while _court._phase != CourtGame.Phase.LIVE:
		await get_tree().physics_frame


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check_input_map() -> void:
	for action: String in ["shoot", "pass", "pick", "sprint", "pause"]:
		var has_key: bool = false
		var has_pad: bool = false
		for e: InputEvent in InputMap.action_get_events(action):
			has_key = has_key or e is InputEventKey
			has_pad = has_pad or e is InputEventJoypadButton or e is InputEventJoypadMotion
		_check(has_key and has_pad, "action '%s' has keyboard and controller bindings" % action)


## Regression: WASD must move the player, and nothing but keys may sit on
## the keyboard movement actions.
func _check_wasd() -> void:
	for action: String in ["move_left", "move_right", "move_up", "move_down"]:
		var only_keys: bool = true
		for e: InputEvent in InputMap.action_get_events(action):
			only_keys = only_keys and e is InputEventKey
		_check(only_keys and InputMap.action_get_events(action).size() == 2, "'%s' is keyboard only (letter + arrow)" % action)
	# Real key events, the same path a keyboard takes.
	var user: Node3D = _court._user
	for case: Array in [[KEY_A, "x", -1.0, "A"], [KEY_D, "x", 1.0, "D"], [KEY_W, "z", -1.0, "W"], [KEY_S, "z", 1.0, "S"]]:
		var start: Vector3 = user.position
		_key(case[0], true)
		await _wait_frames(30)
		_key(case[0], false)
		await _wait_frames(4)
		var moved: float = (user.position.x - start.x) if case[1] == "x" else (user.position.z - start.z)
		_check(moved * float(case[2]) > 0.3, "holding %s moves the player (%.2f m)" % [case[3], absf(moved)])


func _key(code: Key, pressed: bool) -> void:
	var e: InputEventKey = InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


func _check_contest_levels() -> void:
	# NBA tracking buckets: under 2 ft, 2-4 ft, 4-6 ft, 6 ft and beyond.
	_check(_court._contest_level(0.5) == 0, "0.5 m is smothered")
	_check(_court._contest_level(1.0) == 1, "1.0 m is contested")
	_check(_court._contest_level(1.5) == 2, "1.5 m is open")
	_check(_court._contest_level(2.5) == 3, "2.5 m is wide open")


func _press(action: String) -> void:
	for pressed: bool in [true, false]:
		var e: InputEventAction = InputEventAction.new()
		e.action = action
		e.pressed = pressed
		Input.parse_input_event(e)
		await get_tree().process_frame
		await get_tree().process_frame


func _check_pause() -> void:
	await _press("pause")
	_check(get_tree().paused, "pause action pauses the tree")
	var t: float = _court._time
	for i in 5:
		await get_tree().process_frame
	_check(is_equal_approx(_court._time, t), "game time does not advance while paused")
	await _press("pause")
	_check(not get_tree().paused, "pause action again resumes")


func _check_pick() -> void:
	_court._end_pick()  # the big may already have come on his own
	_court._pick_used = false
	_court._user.position = Vector3(0, 0, -4.0)
	_court._call_pick()
	var screener: Node3D = _court._screener()
	_check(screener != null and screener.role == "screen_come", "calling a pick sends a screener")
	var set_seen: bool = false
	for i in 400:
		await get_tree().physics_frame
		if screener.role == "screen_set":
			set_seen = true
			break
	_check(set_seen, "the screener arrives and sets the screen")
	if set_seen:
		var d: Node3D = _court._defender_of(_court._user)
		_check(screener.flat().distance_to(d.flat()) < 1.6, "the screen is set next to the ball handler's defender")


func _check_blowby() -> void:
	var user: Node3D = _court._user
	var d: Node3D = _court._defender_of(user)
	user.position = Vector3(0, 0, -5.0)  # top of the key, inside blow-by range
	var to_hoop: Vector3 = (CourtGame.HOOP_FLAT - user.flat()).normalized()
	var lat: Vector3 = Vector3(-to_hoop.z, 0, to_hoop.x)
	d.beaten = 0.0
	d.position = user.position + to_hoop * 1.2  # squarely in front
	user.vel = to_hoop * 4.0
	_court._check_blowby(0.016)
	_check(d.beaten <= 0.0, "a defender squarely in front is not beaten")
	d.position = user.position + lat * 0.8 - to_hoop * 0.1  # hip to hip
	_court._check_blowby(0.016)
	_check(d.beaten > 0.0, "getting your hip past the defender beats him")


## A three-pointer in real life: about 1.0-1.4 s in the air, peaking 4-5 m up.
func _check_shot_arc(autoplay: bool) -> void:
	var user: Node3D = _court._user
	if _court._holder != user or _court._ball_mode != "held":
		_court._give_ball(user)
	user.position = CourtGame.HOOP_FLAT + Vector3(0, 0, 6.9)
	_court._ball.position = user.position + Vector3(0, 2.4, 0)
	CourtGame.auto_play = autoplay
	_court._take_shot(user, true, "three")
	var top: float = 0.0
	var frames: int = 0
	while _court._phase == CourtGame.Phase.SHOT and frames < 400:
		await get_tree().physics_frame
		top = maxf(top, _court._ball.position.y)
		frames += 1
	CourtGame.auto_play = false
	_check(_court._flight_dur > 1.0 and _court._flight_dur < 1.4, "a three is in the air %.2f s (real: 1.0-1.4)" % _court._flight_dur)
	_check(top > 4.0 and top < 5.0, "a three peaks at %.1f m (real: 4-5)" % top)
	await _wait_live()
	_court._catch_grace = 99.0


func _check_layup() -> void:
	var user: Node3D = _court._user
	if _court._holder != user or _court._ball_mode != "held":
		_court._give_ball(user)
	user.position = CourtGame.HOOP_FLAT + Vector3(0.5, 0, 2.6)
	user.vel = Vector3.ZERO
	for d: Node3D in _court._defense:
		d.position = Vector3(d.position.x, 0, 6.0)  # clear the lane
		d.track = d.position
	_check(_court._in_layup_range(), "2.6 m from the rim is layup range")
	var fga: int = int(_court._stats["fga"])
	_court._begin_layup()
	_check(_court._layup, "shooting there starts a layup, not a jumper")
	_check(not _court._charging, "a layup has no shot meter")
	for i in 200:
		await get_tree().physics_frame
		if not _court._layup:
			break
	_check(_court._phase == CourtGame.Phase.SHOT, "the layup releases a shot")
	_check(int(_court._stats["fga"]) == fga + 1, "the layup counts as one attempt")
	_check(user.flat().distance_to(CourtGame.HOOP_FLAT) < 1.5, "he finishes at the rim")
	var before: int = _court._team_score
	var made: bool = _court._shot_made
	for i in 400:
		await get_tree().physics_frame
		if _court._phase != CourtGame.Phase.SHOT:
			break
	_check(_court._team_score == before + (2 if made else 0), "a made layup is worth 2, a miss 0")
