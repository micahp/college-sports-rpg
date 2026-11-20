extends Node
## Swipe validator, the basketball counterpart of tools/validate-tackles.mjs in
## gridiron-physics: one interaction (a defender swiping at the dribble) run
## across a sweep of conditions with the same runtime the game uses, measured
## on the final drawn pose (a SkeletonModifier3D tap after every modifier):
##   arms   every frame of every swipe and of the guarding stance between
##          swipes, both arms inside human elbow/wrist limits (body_metrics.gd)
##   palm   when a swipe pokes the ball loose, the swiping palm is on the ball
##          (gap <= PALM_GAP_M), not sunk in (<= PALM_SINK_M), palm side
##          toward it (facing >= PALM_FACING)
## Sweep: handler movement x guarding gap (opponent aggression) x defender
## size, SWIPES_EACH swipes per scenario. Nothing is teleported during a
## scenario; the game moves everyone from its own inputs.
##
##   godot --headless --fixed-fps 60 res://tests/swipe_pose_checks.tscn [-- quick]

const CourtScene: PackedScene = preload("res://scenes/court/court_game.tscn")
const CourtGame = preload("res://scripts/court/court_game.gd")
const Actor = preload("res://scripts/court/court_actor.gd")
const BodyMetrics = preload("res://tests/body_metrics.gd")

const MOVES: Array = ["stand", "lateral", "drive_back", "diagonal"]
const AGGR: Array = [0.6, 1.0, 1.4]       # guarding gap 1.20 / 1.10 / 1.00 m
const SIZES: Array = [0.95, 1.0, 1.06]
const SWIPES_EACH: int = 3
const SETTLE_S: float = 0.8
const EVERY_S: float = 1.5
const PALM_GAP_M: float = 0.04
const PALM_SINK_M: float = 0.02
const PALM_FACING: float = 0.5   # palm normal within 60 deg of the ball centre
const MISS_CLEAR_M: float = 0.03  # a missed swipe's palm stays at least this far off the ball
const BALL_R: float = 0.12

var _court: Node3D
var _bm: BodyMetrics = BodyMetrics.new()
var _final: Dictionary = {}
var _tapped: bool = false
var _scenarios: Array = []
var _si: int = -1
var _sc: Dictionary = {}
var _t: float = 0.0
var _move_t: float = 0.0
var _swipes: int = 0
var _was_resolved: bool = false
var _prev_ball: Vector3 = Vector3.ZERO
var _results: Array = []
var _calib: String = ""
var _pred_err: Array = []
var _win_gap: float = INF
var _win_facing: float = -1.0
var _res: Dictionary = {}
var _finalized: bool = false


func _ready() -> void:
	GameState.reset()
	GameState.look_id = "look_a"
	CourtGame.auto_play = false
	var quick: bool = "quick" in OS.get_cmdline_user_args()
	for mv: String in MOVES:
		for ag: float in (AGGR if not quick else [1.0]):
			for sz: float in (SIZES if not quick else [1.0]):
				_scenarios.append({"move": mv, "aggr": ag, "size": sz})
	_court = CourtScene.instantiate()
	_court.scenario = CourtGame.demo_scenario()
	add_child(_court)
	process_physics_priority = -100  # inputs before the game reads them
	var probe: Node = Node.new()
	probe.process_priority = 1000
	var s: GDScript = GDScript.new()
	s.source_code = "extends Node\nvar qa: Node\nfunc _process(delta: float) -> void:\n\tqa.measure(delta)\n"
	s.reload()
	probe.set_script(s)
	probe.set("qa", self)
	add_child(probe)
	var timeout: SceneTreeTimer = get_tree().create_timer(900.0, true, false, true)
	timeout.timeout.connect(func() -> void:
		print("SWIPE VALIDATOR FAILED: timeout")
		get_tree().quit(1))


func _tap_all() -> void:
	_tapped = true
	var off: Array = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("off="):
			off = Array(arg.substr(4).split(","))
	for a: Actor in _court._all:
		var sk: Skeleton3D = a.get("_skeleton")
		if sk == null:
			continue
		for ch: Node in sk.get_children():
			var nm: String = ch.get_script().resource_path.get_file().get_basename() if ch.get_script() else ch.get_class()
			if nm in off and ch is SkeletonModifier3D:
				(ch as SkeletonModifier3D).active = false
		var tap: SkeletonModifier3D = SkeletonModifier3D.new()
		var ts: GDScript = GDScript.new()
		ts.source_code = "extends SkeletonModifier3D\nvar qa: Node\nvar who: Node\nfunc _process_modification_with_delta(_d: float) -> void:\n\tget_skeleton().force_update_all_bone_transforms()
	qa.final_pose(who, get_skeleton())\n"
		ts.reload()
		tap.set_script(ts)
		tap.set("qa", self)
		tap.set("who", a)
		sk.add_child(tap)
	var sk0: Skeleton3D = _court._defense[0].get("_skeleton")
	var saved: Array = []
	for i in sk0.get_bone_count():
		saved.append(sk0.get_bone_pose(i))
		sk0.set_bone_pose(i, sk0.get_bone_rest(i))
	var parts: Array[String] = []
	for side: String in ["R", "L"]:
		var m: Dictionary = _bm.arm(sk0, side)
		parts.append("%s flex %.1f off %.1f bend %.1f twist %.1f shoulder twist %.1f back %.1f" % [side, m["flex"], m["off"], m["bend"], m["twist"], m["sh_twist"], m["sh_back"]])
	_calib = "rest pose (should read ~0): " + "; ".join(parts)
	for i in sk0.get_bone_count():
		sk0.set_bone_pose(i, saved[i])


func final_pose(a: Actor, sk: Skeleton3D) -> void:
	_final[a] = {"R": _bm.arm(sk, "R"), "L": _bm.arm(sk, "L")}


func _next_scenario() -> void:
	if not _sc.is_empty():
		_results.append(_sc)
	_si += 1
	for act: String in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(act)
	if _si >= _scenarios.size():
		_report()
		return
	_sc = (_scenarios[_si] as Dictionary).duplicate()
	_sc.merge({"pokes": 0, "misses": 0, "arm_frames": 0, "arm_bad": 0, "stance_frames": 0, "stance_bad": 0,
		"palm_bad": 0, "gaps": [], "facings": [], "notes": [], "reach_n": 0, "reach_bad": 0, "reach_gaps": [],
		"handler_frames": 0, "handler_bad": 0, "defender_frames": 0, "defender_bad": 0, "others_frames": 0, "others_bad": 0})
	_court._opp["aggr"] = float(_sc["aggr"])
	var d: Actor = _court._on_ball_defender()
	for dd: Actor in _court._defense:
		dd.set_height(1.0)
	if d != null:
		d.set_height(float(_sc["size"]))
	_court._give_ball(_court._user)
	_court._user.position = Vector3(0, 0, -6.5)
	_court._user.vel = Vector3.ZERO
	_t = -SETTLE_S
	_move_t = 0.0
	_swipes = 0


func _physics_process(delta: float) -> void:
	if _court._phase != CourtGame.Phase.LIVE:
		return
	if not _tapped:
		_tap_all()
		_next_scenario()
		return
	if _si >= _scenarios.size():
		return
	_court._shot_clock = 20.0
	_court._clock = maxf(_court._clock, 60.0)
	var u: Actor = _court._user
	if _court._ball_mode == "loose" and _court._loose_t > 0.6:
		_court._give_ball(u)
	if _court._ball_mode == "dead" or (_court._ball_mode == "held" and _court._holder != u):
		_court._give_ball(u)
	_drive_input(delta)
	_t += delta
	if _t >= EVERY_S and _court._reach.is_empty() and _court._ball_mode == "held":
		if _swipes >= SWIPES_EACH:
			_next_scenario()
			return
		var d: Actor = _court._on_ball_defender()
		if d == null:
			return
		_t = 0.0
		_swipes += 1
		d.reach_cd = 0.0
		d.stagger = 0.0
		_court._start_reach(d)  # the game's own swipe start (rolls its outcome)
		_win_gap = INF
		_win_facing = -1.0
		_res = {}
		_finalized = false
		_was_resolved = false


## Handler movement for the scenario, through the game's own input actions.
func _drive_input(delta: float) -> void:
	_move_t += delta
	for act: String in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(act)
	var flip: bool = int(_move_t / 1.1) % 2 == 1
	match str(_sc.get("move", "stand")):
		"lateral":
			Input.action_press("move_right" if flip else "move_left")
		"drive_back":
			Input.action_press("move_down" if flip else "move_up")
		"diagonal":
			Input.action_press("move_up")
			Input.action_press("move_left" if flip else "move_right")


func measure(_delta: float) -> void:
	if not _tapped or _sc.is_empty() or _court._phase != CourtGame.Phase.LIVE or _t < 0.0:
		_prev_ball = _court._ball.position
		return
	var r: Dictionary = _court._reach
	if not r.is_empty():
		var rd: Actor = r["d"]
		var fm: Dictionary = _final.get(rd, {})
		var tt: float = float(r["t"])
		if tt >= CourtGame.SWIPE_HIT_T - 0.06 and tt <= CourtGame.SWIPE_HIT_T + 0.07:
			# The closest the swinging palm gets to the ball around contact (the
			# ball held where it was struck): the palm moves 7-8 m/s through it, so
			# one frame's gap says little.
			var ms: Dictionary = fm.get(str(r["side"]), {})
			if not ms.is_empty():
				var pbw: Dictionary = BodyMetrics.palm_on_ball(ms, r.get("ball_at", _court._ball.position), BALL_R)
				if float(pbw["gap"]) < _win_gap:
					_win_gap = float(pbw["gap"])
					_win_facing = float(pbw["facing"])
		elif tt > CourtGame.SWIPE_HIT_T + 0.07 and not _finalized and not _res.is_empty():
			_finalized = true
			_finalize_contact()
		for side: String in ["R", "L"]:
			var f: String = BodyMetrics.arm_faults(fm.get(side, {}))
			_sc["arm_frames"] = int(_sc["arm_frames"]) + 1
			if f != "" and OS.get_cmdline_user_args().has("why"):
				var tg: Vector3 = (rd.hand_r if side == "R" else rd.hand_l) - rd.shoulder_position(side)
				var mm: Dictionary = fm.get(side, {})
				var el: Vector3 = (mm["elbow"] as Vector3) - rd.shoulder_position(side)
				var skw: Skeleton3D = rd.get("_skeleton")
				var rest: Dictionary = _bm._rest_of(skw)[side]
				var cbw: Basis = skw.global_transform.basis.orthonormalized() * skw.get_bone_global_pose(int(rest["chest"])).basis.orthonormalized()
				var chest_front_w: Vector3 = (cbw * (rest["front_c"] as Vector3)).normalized()
				var now_m: Dictionary = _bm.arm(skw, side)
				print("  recorded sh_back %.0f | recomputed now %.0f" % [float(mm["sh_back"]), float(now_m["sh_back"])])
				print("  chest bone %s  chest front (world) fwd %.2f up %.2f side %.2f | arm dir fwd %.2f up %.2f | arm.chestfront %.2f" % [skw.get_bone_name(int(rest["chest"])), chest_front_w.dot(rd.facing()), chest_front_w.y, chest_front_w.dot(rd.right()), el.normalized().dot(rd.facing()), el.normalized().y, el.normalized().dot(chest_front_w)])
				print("WHYSWIPE t=%.2f %s %s target fwd %.2f side %.2f up %.2f | elbow fwd %.2f side %.2f up %.2f | lean %.2f crouch %.2f | %s" % [float(r["t"]), side, "SWING" if side == str(r["side"]) else "off", tg.dot(rd.facing()), tg.dot(rd.right()), tg.y, el.dot(rd.facing()), el.dot(rd.right()), el.y, float(rd.get("_lean_amount")), float(rd.get("_crouch_now")), f])
			if f != "":
				_sc["arm_bad"] = int(_sc["arm_bad"]) + 1
				_note("swipe %d t=%.2f %s arm: %s" % [_swipes, float(r["t"]), side, f])
		if bool(r["resolved"]) and not _was_resolved:
			_was_resolved = true
			var m: Dictionary = fm.get(str(r["side"]), {})
			var hit_ball: Vector3 = r.get("ball_at", _prev_ball)
			if r.has("b_pred"):
				_pred_err.append(hit_ball.distance_to(r["b_pred"] as Vector3))
			_res = {"poked": _court._ball_mode == "loose", "fouled": rd.reach_cd >= 3.0}
			if bool(_res["poked"]):
				_sc["pokes"] = int(_sc["pokes"]) + 1
			else:
				_sc["misses"] = int(_sc["misses"]) + 1
	elif _court._ball_mode == "held":
		var d: Actor = _court._on_ball_defender()
		if d != null and d.reach_cd <= 0.0 or (d != null and r.is_empty()):
			var fm2: Dictionary = _final.get(d, {})
			for side2: String in ["R", "L"]:
				var f2: String = BodyMetrics.arm_faults(fm2.get(side2, {}))
				_sc["stance_frames"] = int(_sc["stance_frames"]) + 1
				if f2 != "":
					_sc["stance_bad"] = int(_sc["stance_bad"]) + 1
					_note("guarding %s arm: %s" % [side2, f2])
	for a: Actor in _court._all:
		var who: String = "handler" if a == _court._holder else ("defender" if a == _court._on_ball_defender() else "others")
		var fa: Dictionary = _final.get(a, {})
		for s3: String in ["R", "L"]:
			var f3: String = BodyMetrics.arm_faults(fa.get(s3, {}))
			_sc[who + "_frames"] = int(_sc.get(who + "_frames", 0)) + 1
			if f3 != "":
				_sc[who + "_bad"] = int(_sc.get(who + "_bad", 0)) + 1
				if who != "defender":
					_note("%s %s arm: %s" % [who, s3, f3])
				if OS.get_cmdline_user_args().has("why") and f3.contains("behind"):
					var tgt: Vector3 = (a.hand_r if s3 == "R" else a.hand_l) - a.shoulder_position(s3)
					print("WHY %s %s team %d role %s elbow_up %s busy %s w %.2f gait %s target-from-shoulder fwd %.2f side %.2f up %.2f  %s" % [who, s3, a.team, a.role, a.elbow_up, a.busy(), float(a.get("w_r") if s3 == "R" else a.get("w_l")), str(a.get("_gait")), tgt.dot(a.facing()), tgt.dot(a.right()), tgt.y, f3])
	_prev_ball = _court._ball.position


func _finalize_contact() -> void:
	if bool(_res["poked"]):
		(_sc["gaps"] as Array).append(_win_gap)
		(_sc["facings"] as Array).append(_win_facing)
		var bad: Array[String] = []
		if _win_gap > PALM_GAP_M:
			bad.append("palm never closer than %.2f m to the ball" % _win_gap)
		if _win_gap < -PALM_SINK_M:
			bad.append("palm %.2f m inside the ball" % -_win_gap)
		if _win_facing < PALM_FACING:
			bad.append("palm turned %.0f deg from the ball" % rad_to_deg(acos(clampf(_win_facing, -1.0, 1.0))))
		if not bad.is_empty():
			_sc["palm_bad"] = int(_sc["palm_bad"]) + 1
			_note("poke %d: %s" % [_swipes, ", ".join(bad)])
	elif not bool(_res["fouled"]):
		# A swipe that did not knock it loose must not have touched it: the hand
		# stops short. (A reach-in foul is contact by definition, so skipped.)
		_sc["reach_n"] = int(_sc.get("reach_n", 0)) + 1
		(_sc["reach_gaps"] as Array).append(_win_gap)
		if _win_gap < MISS_CLEAR_M:
			_sc["reach_bad"] = int(_sc.get("reach_bad", 0)) + 1
			_note("missed swipe %d touched the ball: palm came within %.2f m" % [_swipes, _win_gap])


func _note(s: String) -> void:
	if (_sc["notes"] as Array).size() < 4:
		(_sc["notes"] as Array).append(s)


func _median(a: Array) -> float:
	if a.is_empty():
		return NAN
	var b: Array = a.duplicate()
	b.sort()
	return float(b[b.size() / 2])


var _done: bool = false


func _report() -> void:
	if _done:
		return
	_done = true
	print(_calib)
	print("move        aggr  size  pokes miss  swipe_arm_bad  guard_arm_bad  palm_bad  med_gap  med_facing  result")
	var passed: int = 0
	var all_gaps: Array = []
	var all_fac: Array = []
	var tot: Dictionary = {"arm_bad": 0, "arm_frames": 0, "stance_bad": 0, "stance_frames": 0, "palm_bad": 0, "pokes": 0,
		"reach_n": 0, "reach_bad": 0, "handler_frames": 0, "handler_bad": 0, "defender_frames": 0, "defender_bad": 0,
		"others_frames": 0, "others_bad": 0}
	var reach_gaps: Array = []
	for sc: Dictionary in _results:
		for k: String in tot:
			tot[k] = int(tot[k]) + int(sc[k])
		all_gaps.append_array(sc["gaps"])
		all_fac.append_array(sc["facings"])
		reach_gaps.append_array(sc["reach_gaps"])
		var ok: bool = int(sc["arm_bad"]) == 0 and int(sc["stance_bad"]) == 0 and int(sc["palm_bad"]) == 0 \
			and int(sc["reach_bad"]) == 0 and int(sc["handler_bad"]) == 0 and int(sc["defender_bad"]) == 0 			and int(sc["others_bad"]) == 0
		if ok:
			passed += 1
		print("%-10s  %4.1f  %4.2f  %5d %4d  %6d/%-6d  %6d/%-6d  %8d  %7.3f  %10.2f  %s" % [
			sc["move"], sc["aggr"], sc["size"], sc["pokes"], sc["misses"], sc["arm_bad"], sc["arm_frames"],
			sc["stance_bad"], sc["stance_frames"], sc["palm_bad"], _median(sc["gaps"]), _median(sc["facings"]),
			"ok" if ok else "FAIL"])
		for n: String in sc["notes"]:
			print("      " + n)
	print("\nscenarios passing: %d / %d" % [passed, _results.size()])
	print("swipe arm frames outside human limits: %d / %d" % [tot["arm_bad"], tot["arm_frames"]])
	print("guarding arm frames outside human limits: %d / %d" % [tot["stance_bad"], tot["stance_frames"]])
	print("pokes without the palm on the ball: %d / %d   (median gap %.3f m, median facing %.2f)" % [
		tot["palm_bad"], tot["pokes"], _median(all_gaps), _median(all_fac)])
	for who2: String in ["handler", "defender", "others"]:
		print("%s arm frames outside human limits (whole run, every frame): %d / %d" % [who2, tot[who2 + "_bad"], tot[who2 + "_frames"]])
	print("missed swipes that touched the ball: %d / %d   (median palm gap %.3f m)" % [
		tot["reach_bad"], tot["reach_n"], _median(reach_gaps)])
	print("ball prediction error at contact: median %.3f m, worst %.3f m (%d swipes)" % [_median(_pred_err), float(_pred_err.max()) if not _pred_err.is_empty() else 0.0, _pred_err.size()])
	var failed: bool = passed < _results.size() or int(tot["pokes"]) == 0
	if int(tot["pokes"]) == 0:
		print("NOT EXERCISED: no poke landed")
	print("SWIPE VALIDATOR FAILED" if failed else "SWIPE VALIDATOR PASSED")
	get_tree().quit(1 if failed else 0)
