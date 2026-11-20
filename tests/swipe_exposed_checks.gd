extends Node
## Two moving handlers' exposed high dribbles. Start from known spacing, then
## advance the same actor animation, ball curve and reach resolver as the court.
const Court = preload("res://scripts/court/court_game.gd")
const Scene = preload("res://scenes/court/court_game.tscn")
const Actor = preload("res://scripts/court/court_actor.gd")
const Metrics = preload("res://tests/body_metrics.gd")
const DT := 1.0 / 60.0
var court: Node3D
var metrics := Metrics.new()
var arms: Dictionary = {}

func _ready() -> void:
	GameState.reset()
	GameState.look_id = "look_a"
	court = Scene.instantiate()
	court.scenario = Court.demo_scenario()
	add_child(court)
	court.set_physics_process(false)
	var defender: Actor = court._defense[0]
	var sk: Skeleton3D = defender.get("_skeleton")
	sk.skeleton_updated.connect(func() -> void:
		for side: String in ["R", "L"]:
			arms[side] = metrics.arm(sk, side))
	var failures := 0
	for side: String in ["R", "L"]:
		if not await _attempt(side, defender):
			failures += 1
	get_tree().quit(1 if failures else 0)

func _attempt(side: String, defender: Actor) -> bool:
	var handler: Actor = court._user
	handler.position = Vector3.ZERO
	handler.face_point(Vector3.BACK)
	handler.vel = Vector3.BACK * 0.5
	court._give_ball(handler)
	court._reach.clear()
	defender.face_point(defender.position + Vector3.FORWARD)
	var ready := false
	for tick in 220:
		handler.position += handler.vel * DT
		handler.pose_reset()
		handler.has_ball = true
		handler.animate(DT)
		court._update_ball(DT)
		defender.pose_reset()
		defender.pressure_stance = true
		defender.lock_face(defender.position + Vector3.FORWARD)
		defender.animate(DT)
		await get_tree().physics_frame
		var prediction := handler.predict_ball(Court.SWIPE_HIT_T, Court.BALL_FLOOR)
		var near := handler.predict_ball(Court.SWIPE_HIT_T - 0.05, Court.BALL_FLOOR)
		if tick > 75 and minf(prediction.y, near.y) > 0.89:
			var lateral := 0.32 if side == "R" else -0.32
			defender.position = Vector3(prediction.x, 0, prediction.z) - defender.right() * lateral - defender.facing() * 0.33
			ready = true
			break
	if not ready:
		push_error("No exposed high dribble")
		return false
	court._start_reach(defender)
	court._reach["roll"] = 0.0
	var chosen: String = court._reach["side"]
	for tick in 16:
		handler.position += handler.vel * DT
		handler.animate(DT)
		court._update_ball(DT)
		court._tick_reach(DT)
		defender.pose_reset()
		court._pose_swipe(defender, court._ball.position)
		defender.animate(DT)
		await get_tree().physics_frame

	var contact := Metrics.palm_on_ball(arms[chosen], court._reach["ball_at"], CourtDribble.RADIUS)
	print("%s chose %s mode=%s contact=%s odds=%s" % [side, chosen, court._ball_mode, contact, court._reach["odds"]])
	return chosen == side and court._ball_mode == "loose" and float(contact["gap"]) >= -0.02 and float(contact["gap"]) <= 0.04 and float(contact["facing"]) >= 0.5
