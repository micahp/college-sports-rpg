extends Node
## Acceptance check for the shot contest, from the reference photos (Arizona #35,
## Springfield College #11): both arms straight up over the shoulders.
## Reads the drawn pose (pose_tap) every frame of a contested jump shot, from the
## moment the arms are up (frame 16) through the defender's landing (frame 80).
##   godot --headless --path . res://tests/contest_pose_check.tscn
## Limits, per arm, per frame:
##   elbow bend under 20 deg (straight arm)
##   elbow at least 0.18 m above the shoulder, at most 0.06 m out to the side
##   hand at least 0.45 m above the shoulder, at most 0.20 m in front of it
const CourtScene: PackedScene = preload("res://scenes/court/court_game.tscn")
const CourtGame = preload("res://scripts/court/court_game.gd")
const FROM: int = 16
const TO: int = 80
const MAX_FLEX: float = 20.0
const MIN_ELBOW_UP: float = 0.18
const MAX_ELBOW_OUT: float = 0.06
const MIN_HAND_UP: float = 0.45
const MAX_HAND_FWD: float = 0.20


func _ready() -> void:
	GameState.reset()
	GameState.look_id = "look_a"
	CourtGame.auto_play = false
	var court: Node3D = CourtScene.instantiate()
	court.scenario = CourtGame.demo_scenario()
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
	court._begin_shot()
	var tap = d.get("_pose_tap")
	var fails: Array[String] = []
	var worst_flex := 0.0
	for frame in range(1, TO + 1):
		await get_tree().physics_frame
		if frame == 30:
			court._release_shot()
		if frame < FROM:
			continue
		await get_tree().process_frame
		for side: String in ["R", "L"]:
			var sg: float = 1.0 if side == "R" else -1.0
			var s: Vector3 = tap.call("world", side, "shoulder")
			var e: Vector3 = tap.call("world", side, "elbow")
			var h: Vector3 = tap.call("world", side, "hand")
			var flex: float = 180.0 - rad_to_deg((s - e).normalized().angle_to((h - e).normalized()))
			worst_flex = maxf(worst_flex, flex)
			var e_out: float = (e - s).dot(d.right()) * sg
			var problems: Array[String] = []
			if flex > MAX_FLEX:
				problems.append("elbow bent %.0f deg" % flex)
			if e.y - s.y < MIN_ELBOW_UP:
				problems.append("elbow only %.2f m above shoulder" % (e.y - s.y))
			if absf(e_out) > MAX_ELBOW_OUT:
				problems.append("elbow %.2f m out to the side" % e_out)
			if h.y - s.y < MIN_HAND_UP:
				problems.append("hand only %.2f m above shoulder" % (h.y - s.y))
			if (h - s).dot(d.facing()) > MAX_HAND_FWD:
				problems.append("hand %.2f m in front" % (h - s).dot(d.facing()))
			if not problems.is_empty():
				fails.append("F%02d %s: %s" % [frame, side, ", ".join(problems)])
	for f in fails:
		print("  FAIL ", f)
	print("CONTEST POSE: %d failing arm-frames over frames %d-%d, worst elbow bend %.0f deg -> %s" % [fails.size(), FROM, TO, worst_flex, "ok" if fails.is_empty() else "FAILED"])
	get_tree().quit(0 if fails.is_empty() else 1)
