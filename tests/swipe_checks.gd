extends Node
## Swipe checks: a defender reaches at the ball handler and the ball is either
## poked loose or not. For each distance and ball height it measures how often
## a poke lands and fails if one lands where the defender's hand can't get to
## the ball (shoulder to ball, against the model's measured arm + hand + lean).
## It also fails if the poke rate doesn't fall as the ball gets farther away.
##
##   godot --headless res://tests/swipe_checks.tscn

const CourtScene: PackedScene = preload("res://scenes/court/court_game.tscn")
const CourtGame = preload("res://scripts/court/court_game.gd")
const Actor = preload("res://scripts/court/court_actor.gd")

const TRIALS: int = 400
const DISTANCES: Array = [0.4, 0.6, 0.8, 0.95, 1.1, 1.2, 1.35]
const BALL_HEIGHTS: Array = [0.9, 0.3]  # top of the dribble, just off the floor

var _failures: int = 0
var _court: Node3D


func _ready() -> void:
	GameState.reset()
	GameState.look_id = "look_a"
	CourtGame.auto_play = false
	Engine.time_scale = 3.0
	var timeout: SceneTreeTimer = get_tree().create_timer(120.0, true, false, true)
	timeout.timeout.connect(func() -> void:
		print("SWIPE CHECKS FAILED: timeout")
		get_tree().quit(1))

	_court = CourtScene.instantiate()
	_court.scenario = CourtGame.demo_scenario()
	add_child(_court)
	while _court._phase != CourtGame.Phase.LIVE:
		await get_tree().physics_frame
	_court._rng.seed = 12345

	var holder: Actor = _court._user
	var d: Actor = _court._defense[0]
	print("defender shoulder-to-palm: R %.2f m, L %.2f m (palm %.2f m past the wrist)" % [
		d.reach_length("R"), d.reach_length("L"), Actor.PALM_M])
	for bh: float in BALL_HEIGHTS:
		print("\nball height %.2f m" % bh)
		print("distance_m  reach_margin_m  pokes/trials  poke_rate  mean_knock_mps  result")
		var prev_rate: float = INF
		for dist: float in DISTANCES:
			var pokes: int = 0
			var speed_sum: float = 0.0
			var margin: float = 0.0
			for i in TRIALS:
				_stage(holder, d, dist, bh)
				margin = d.reach_margin(_court._ball.position, CourtGame.BALL_FLOOR)
				_court._resolve_reach(d)
				if _court._ball_mode == "loose":
					pokes += 1
					var v: Vector3 = _court._loose_vel
					speed_sum += Vector3(v.x, 0, v.z).length()
			var rate: float = float(pokes) / TRIALS
			var bad: String = ""
			if margin <= 0.0 and pokes > 0:
				bad = "FAIL: poke beyond reach"
			elif rate > prev_rate + 0.06:
				bad = "FAIL: rate rose with distance"
			print("%9.2f  %13.2f  %5d/%d     %8.3f   %12.2f    %s" % [
				dist, margin, pokes, TRIALS, rate, speed_sum / maxf(1.0, float(pokes)),
				bad if bad != "" else "ok"])
			if bad != "":
				_failures += 1
			prev_rate = rate

	print("SWIPE CHECKS PASSED" if _failures == 0 else "SWIPE CHECKS FAILED (%d rows)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


## Handler at the origin with the ball out in front of his right hand; the
## defender at a flat distance from the ball, facing the handler. Resets the
## state a poke or a foul changes.
func _stage(holder: Actor, d: Actor, dist: float, ball_h: float) -> void:
	_court._ball_mode = "held"
	_court._holder = holder
	_court._catch_grace = 0.0
	_court._cross_t = -1.0
	_court._reach = {}
	holder.position = Vector3(0, 0, 0)
	_court._ball.position = Vector3(0.25, ball_h, 0)
	d.position = Vector3(0.25 + dist, 0, 0.1)
	d.face_point(holder.position)
	d.reach_cd = 0.0
	d.stagger = 0.0
