extends Node
## Records defender swipes at the ball handler, close up, from the side.
## The game runs as normal; this only starts a reach every 2 s and hands the
## ball back after a poke so the next swipe can be filmed.
##
##   godot --write-movie swipe.avi --fixed-fps 30 --resolution 960x540 res://tests/swipe_clip.tscn

const CourtScene: PackedScene = preload("res://scenes/court/court_game.tscn")
const CourtGame = preload("res://scripts/court/court_game.gd")
const Actor = preload("res://scripts/court/court_actor.gd")
const SWIPES: int = 6
const EVERY: float = 2.0

var _court: Node3D
var _cam: Camera3D
var _t: float = 0.0
var _n: int = 0
var _label: Label
var _outcome: String = ""


func _ready() -> void:
	GameState.reset()
	GameState.look_id = "look_a"
	CourtGame.auto_play = false
	_court = CourtScene.instantiate()
	_court.scenario = CourtGame.demo_scenario()
	add_child(_court)
	_cam = Camera3D.new()
	_cam.fov = 38.0
	add_child(_cam)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(20, 14)
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_label)
	process_physics_priority = 100
	process_priority = 100


func _physics_process(delta: float) -> void:
	if _court._phase != CourtGame.Phase.LIVE:
		return
	_court._shot_clock = 20.0
	_t += delta
	var u: Actor = _court._user
	var d: Actor = _court._on_ball_defender()
	if d == null:
		return
	if _court._ball_mode == "loose" and _court._loose_t > 1.2:
		_court._give_ball(u)
	if "shuffle" in OS.get_cmdline_user_args():
		for defender: Actor in _court._defense:
			defender.reach_cd = 10.0
		var left := int(_t / 0.85) % 2 == 0
		Input.action_release("move_right" if left else "move_left")
		Input.action_press("move_left" if left else "move_right")
		_n = 1 if _t < 3.4 else 2
		return
	if _t >= EVERY and _court._reach.is_empty() and _court._ball_mode == "held":
		_t = 0.0
		_n += 1
		if _n > SWIPES:
			get_tree().quit(0)
			return
		d.reach_cd = 0.0
		d.stagger = 0.0
		var forced_side: String = "R" if "force_right" in OS.get_cmdline_user_args() else ("L" if "force_left" in OS.get_cmdline_user_args() else "")
		if forced_side != "":
			_court._reach = {"d": d, "t": 0.0, "side": forced_side, "resolved": false, "roll": 0.0,
				"b_pred": _court._holder.predict_ball(CourtGame.SWIPE_HIT_T, CourtGame.BALL_FLOOR) if _court._holder != null else _court._ball.position}
			d.action("SwipeCMU_" + forced_side, 1.0)
		else:
			_court._start_reach(d)  # the game's own swipe start (rolls its outcome)
		_outcome = ""
	if not _court._reach.is_empty() and bool(_court._reach.get("resolved", false)) and _outcome == "":
		_outcome = "poked loose" if _court._ball_mode == "loose" else ("foul" if d.reach_cd >= 3.0 else "missed")
	var gap: float = d.flat().distance_to(Vector3(_court._ball.position.x, 0, _court._ball.position.z))
	_label.text = "swipe %d/%d   ball-defender %.2f m   %s" % [mini(_n, SWIPES), SWIPES, gap, _outcome]


func _process(_delta: float) -> void:
	var u: Actor = _court._user
	var d: Actor = _court._on_ball_defender()
	if u == null or d == null:
		return
	var mid: Vector3 = (u.position + d.position) * 0.5
	var across: Vector3 = (d.position - u.position)
	across.y = 0
	var side: Vector3 = across.normalized().cross(Vector3.UP) if across.length() > 0.1 else Vector3.RIGHT
	_cam.current = true
	var flip: float = -1.0 if "otherside" in OS.get_cmdline_user_args() else 1.0
	_cam.position = mid + side * 3.2 * flip + Vector3(0, 1.1, 0)
	_cam.look_at(mid + Vector3(0, 0.8, 0), Vector3.UP)

	if "solo" in OS.get_cmdline_user_args():
		for actor: Actor in _court._all:
			actor.visible = actor == d
		_court._layer.hide()
		_label.hide()
		_court._ball.hide()
		var focus := d.position + Vector3.UP * 0.95
		_cam.position = focus + (side * 0.72 + d.facing() * 0.7).normalized() * 3.6
		_cam.look_at(focus, Vector3.UP)
		if _n == 1:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP") + ("/shufflearm_%04d.png" if "shuffle" in OS.get_cmdline_user_args() else "/soloarm_%04d.png") % Engine.get_process_frames())
		elif _n > 1:
			get_tree().quit()
