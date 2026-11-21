extends Node
## Acceptance check for the shot contest, from the reference photos (Arizona #35,
## Springfield College #11): both arms straight up over the shoulders.
## Reads the drawn pose (pose_tap) every frame of a contested jump shot, from the
## moment the arms are up (frame 16) through the defender's landing (frame 80).
##   godot --headless --fixed-fps 60 --path . res://tests/contest_pose_check.tscn
## Also checks the raise as a motion: no drop before it starts, the arm on the
## shooter's side leads, no snapping up, and the arms come down after landing.
## Limits, per arm, per frame:
##   elbow bend under 20 deg (straight arm)
##   elbow at least 0.18 m above the shoulder, at most 0.06 m out to the side
##   hand at least 0.45 m above the shoulder, at most 0.20 m in front of it
##   palm faces the ball at the shooter's release point (CONTEST_PALM_AT_Y over his
##   feet): within 30 deg, and never turned out to the side by more than 0.30
## Pass `verbose` to print every frame.
const CourtScene: PackedScene = preload("res://scenes/court/court_game.tscn")
const CourtGame = preload("res://scripts/court/court_game.gd")
## The top of the contest: from when both arms have finished rising (the raise
## starts after CONTEST_REACT and the trailing arm finishes CONTEST_TRAIL after
## the lead) until the defender lands.
const FROM: int = 40
const TO: int = 66
## The raise itself (court_game contest: an arm swing, not a sliding target).
const RAISE_FRAMES: int = 40
const MAX_DROP: float = 0.05      # m a hand may sink below its start while the raise begins
const MAX_RAISE_SPEED: float = 6.0  # m/s, no snapping up
const LOWERED_BY: int = 96        # frames: arms back down after the landing (~F70)
const MAX_FLEX: float = 20.0
const MIN_ELBOW_UP: float = 0.18
const MAX_ELBOW_OUT: float = 0.06
const MIN_HAND_UP: float = 0.45
const MAX_HAND_FWD: float = 0.20
const MAX_PALM_OFF: float = 30.0
const MAX_PALM_OUT: float = 0.30


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
	var verbose: bool = OS.get_cmdline_user_args().has("verbose")
	var sk: Skeleton3D = CourtPlayerModel.find_skeleton(d.get("_model"))
	var palm_local: Dictionary = {}
	for side: String in ["R", "L"]:
		var bone: int = sk.find_bone("RightHand" if side == "R" else "LeftHand")
		palm_local[side] = sk.get_bone_global_rest(bone).basis.orthonormalized().inverse() * Vector3.DOWN
	var worst_palm := 0.0
	var fails: Array[String] = []
	var worst_flex := 0.0
	var start_y: Dictionary = {}
	var prev: Dictionary = {}
	var top_y: Dictionary = {}
	var at90: Dictionary = {}
	var fastest := 0.0
	var fastest_at := ""
	var high_side: String = ""
	for frame in range(1, LOWERED_BY + 1):
		await get_tree().physics_frame
		if frame == 30:
			court._release_shot()
		await get_tree().process_frame
		for side: String in ["R", "L"]:
			if not at90.has(side) and start_y.has(side):
				var hy: float = (tap.call("world", side, "hand") as Vector3).y
				var sy: float = (tap.call("world", side, "shoulder") as Vector3).y
				if hy > sy + 0.9 * 0.50:
					at90[side] = frame
		if frame <= RAISE_FRAMES or frame == LOWERED_BY:
			if high_side == "":
				high_side = str(court._contest.get(d, {}).get("lead", ""))
			for side: String in ["R", "L"]:
				var hnd: Vector3 = tap.call("world", side, "hand")
				var sh: Vector3 = tap.call("world", side, "shoulder")
				# Relative to the shoulder: the body sinks into its crouch over the
				# same frames, and that is not the arms dropping.
				if frame == 1:
					start_y[side] = hnd.y - sh.y
				if frame <= 8 and hnd.y - sh.y < float(start_y[side]) - MAX_DROP:
					fails.append("F%02d %s: hand dropped %.2f m (relative to the shoulder) before rising" % [frame, side, float(start_y[side]) - (hnd.y - sh.y)])
				if prev.has(side) and frame <= RAISE_FRAMES:
					var sp: float = hnd.distance_to(prev[side]) * 60.0
					if OS.get_cmdline_user_args().has("speeds"):
						print("SPD F%02d %s %.1f m/s  hand-shoulder (%.2f, %.2f, %.2f)" % [frame, side, sp, (hnd - sh).dot(d.right()), (hnd - sh).dot(d.facing()), hnd.y - sh.y])
					if sp > fastest:
						fastest = sp
						fastest_at = "F%02d %s" % [frame, side]
				prev[side] = hnd
				if frame == LOWERED_BY and hnd.y > (tap.call("world", side, "shoulder") as Vector3).y + 0.10:
					fails.append("F%02d %s: arm still up after the landing (hand %.2f m over the shoulder)" % [frame, side, hnd.y - sh.y])
		if frame == RAISE_FRAMES:
			for side: String in ["R", "L"]:
				top_y[side] = (tap.call("world", side, "hand") as Vector3).y
		if frame > TO or frame < FROM:
			continue
		for side: String in ["R", "L"]:
			var sg: float = 1.0 if side == "R" else -1.0
			var s: Vector3 = tap.call("world", side, "shoulder")
			var e: Vector3 = tap.call("world", side, "elbow")
			var h: Vector3 = tap.call("world", side, "hand")
			var flex: float = 180.0 - rad_to_deg((s - e).normalized().angle_to((h - e).normalized()))
			worst_flex = maxf(worst_flex, flex)
			var e_out: float = (e - s).dot(d.right()) * sg
			var palm: Vector3 = (tap.call("hand_basis", side) as Basis) * (palm_local[side] as Vector3)
			var to_shooter: Vector3 = (user.global_position * Vector3(1, 0, 1) + Vector3.UP * CourtGame.CONTEST_PALM_AT_Y) - h
			var palm_off: float = rad_to_deg(palm.angle_to(to_shooter))
			worst_palm = maxf(worst_palm, palm_off)
			if verbose:
				print("F%02d %s flex=%3.0f palm_off=%3.0f palm=(out %+.2f fwd %+.2f up %+.2f)" % [frame, side, flex, palm_off, palm.dot(d.right()) * sg, palm.dot(d.facing()), palm.y])
			var problems: Array[String] = []
			if palm_off > MAX_PALM_OFF:
				problems.append("palm %.0f deg off the ball" % palm_off)
			if absf(palm.dot(d.right())) > MAX_PALM_OUT:
				problems.append("palm turned %.2f to the side" % (palm.dot(d.right()) * sg))
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
	var low_side: String = "L" if high_side == "R" else "R"
	print("RAISE: lead (%s) at 90%% of its rise F%s, trail (%s) F%s; fastest hand %.1f m/s (%s)" % [high_side, at90.get(high_side, "-"), low_side, at90.get(low_side, "-"), fastest, fastest_at])
	if not at90.has(high_side) or not at90.has(low_side) or int(at90[high_side]) >= int(at90[low_side]):
		fails.append("raise: the arm on the shooter's side does not lead")
	if fastest > MAX_RAISE_SPEED:
		fails.append("raise: a hand snapped up at %.1f m/s" % fastest)
	for f in fails:
		print("  FAIL ", f)
	print("CONTEST POSE: %d failing arm-frames over frames %d-%d, worst elbow bend %.0f deg, worst palm %.0f deg off -> %s" % [fails.size(), FROM, TO, worst_flex, worst_palm, "ok" if fails.is_empty() else "FAILED"])
	get_tree().quit(0 if fails.is_empty() else 1)
