extends Node
## Swipe MOTION report: where the movement of a swipe comes from. The pose
## validator checks joint limits and the palm at contact; a wrist flick passes
## that. This measures what the whole body does between the start of the swipe
## and the end of the follow-through (t 0 .. WINDOW_S), on the final drawn pose:
##   palm_disp    furthest the palm gets from where it started (m)
##   palm_peak    fastest palm speed (m/s)
##   rel_disp     how far the palm moves relative to the SHOULDER (m): the arm
##   shoulder_mv  how far the swinging shoulder travels (m): trunk, hips, step
##   swing        upper arm swing relative to the chest (deg): the shoulder joint
##   elbow, wrist range of elbow flexion / wrist bend (deg)
##   twist        shoulder line vs hip line, range (deg): trunk rotation
##   tilt         hips-to-neck angle from vertical, range (deg)
##   hips_drop    how far the hips sink (m)      step  root travel (m)
##   godot --headless --fixed-fps 60 res://tests/swipe_motion_checks.tscn

const CourtScene: PackedScene = preload("res://scenes/court/court_game.tscn")
const CourtGame = preload("res://scripts/court/court_game.gd")
const Actor = preload("res://scripts/court/court_actor.gd")
const BodyMetrics = preload("res://tests/body_metrics.gd")
const WINDOW_S: float = 0.48
const MOVES: Array = ["stand", "lateral", "drive_back", "diagonal"]

var _court: Node3D
var _bm: BodyMetrics = BodyMetrics.new()
var _final: Dictionary = {}
var _tapped: bool = false
var _si: int = -1
var _move: String = "stand"
var _t: float = 0.0
var _move_t: float = 0.0
var _swipes: int = 0
var _series: Array = []
var _rows: Array = []
var _tracking: bool = false


func _ready() -> void:
	GameState.reset()
	GameState.look_id = "look_a"
	CourtGame.auto_play = false
	_court = CourtScene.instantiate()
	_court.scenario = CourtGame.demo_scenario()
	add_child(_court)
	process_physics_priority = -100
	var probe: Node = Node.new()
	probe.process_priority = 1000
	var s: GDScript = GDScript.new()
	s.source_code = "extends Node\nvar qa: Node\nfunc _process(delta: float) -> void:\n\tqa.measure(delta)\n"
	s.reload()
	probe.set_script(s)
	probe.set("qa", self)
	add_child(probe)
	var to: SceneTreeTimer = get_tree().create_timer(600.0, true, false, true)
	to.timeout.connect(func() -> void: get_tree().quit(1))


func _tap_all() -> void:
	_tapped = true
	for a: Actor in _court._all:
		var sk: Skeleton3D = a.get("_skeleton")
		var tap: SkeletonModifier3D = SkeletonModifier3D.new()
		var ts: GDScript = GDScript.new()
		ts.source_code = "extends SkeletonModifier3D\nvar qa: Node\nvar who: Node\nfunc _process_modification_with_delta(_d: float) -> void:\n\tget_skeleton().force_update_all_bone_transforms()\n\tqa.final_pose(who, get_skeleton())\n"
		ts.reload()
		tap.set_script(ts)
		tap.set("qa", self)
		tap.set("who", a)
		sk.add_child(tap)


func final_pose(a: Actor, sk: Skeleton3D) -> void:
	var g: Transform3D = sk.global_transform
	var d: Dictionary = {"R": _bm.arm(sk, "R"), "L": _bm.arm(sk, "L")}
	for b: String in ["Hips", "Neck", "RightUpperLeg", "LeftUpperLeg", "RightUpperArm", "LeftUpperArm"]:
		d[b] = g * sk.get_bone_global_pose(sk.find_bone(b)).origin
	_final[a] = d


func _next() -> void:
	_si += 1
	for act: String in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(act)
	if _si >= MOVES.size():
		_report()
		return
	_move = MOVES[_si]
	_court._opp["aggr"] = 1.0
	_court._give_ball(_court._user)
	_court._user.position = Vector3(0, 0, -6.5)
	_court._user.vel = Vector3.ZERO
	_t = -0.8
	_move_t = 0.0
	_swipes = 0


func _physics_process(delta: float) -> void:
	if _court._phase != CourtGame.Phase.LIVE:
		return
	if not _tapped:
		_tap_all()
		_next()
		return
	if _si >= MOVES.size():
		return
	_court._shot_clock = 20.0
	_court._clock = maxf(_court._clock, 60.0)
	var u: Actor = _court._user
	if (_court._ball_mode == "loose" and _court._loose_t > 0.6) or _court._ball_mode == "dead" or _court._holder != u:
		_court._give_ball(u)
	_move_t += delta
	for act: String in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(act)
	var flip: bool = int(_move_t / 1.1) % 2 == 1
	match _move:
		"lateral":
			Input.action_press("move_right" if flip else "move_left")
		"drive_back":
			Input.action_press("move_down" if flip else "move_up")
		"diagonal":
			Input.action_press("move_up")
			Input.action_press("move_left" if flip else "move_right")
	_t += delta
	if _t >= 1.5 and _court._reach.is_empty() and _court._ball_mode == "held":
		if _swipes >= 3:
			_next()
			return
		var d: Actor = _court._on_ball_defender()
		if d == null:
			return
		_t = 0.0
		_swipes += 1
		_court._start_reach(d)
		if OS.get_cmdline_user_args().has("noclip"):
			d._tree.set("parameters/upper/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)  # experiment: no Reach clip
		_series = []
		_tracking = true


func measure(delta: float) -> void:
	if not _tracking:
		return
	var r: Dictionary = _court._reach
	if r.is_empty():
		_tracking = false
		_summarize()
		return
	var rd: Actor = r["d"]
	var side: String = str(r["side"])
	var f: Dictionary = _final.get(rd, {})
	var m: Dictionary = f.get(side, {})
	if m.is_empty() or float(r["t"]) > WINDOW_S:
		return
	if OS.get_cmdline_user_args().has("first") and _series.size() < 4 and _rows.size() < 2:
		var tgt: Vector3 = rd.hand_r if side == "R" else rd.hand_l
		var pg: Dictionary = (rd.get("_palm_goals") as Dictionary).get(side, {})
		var ikn: Node3D = (rd.get("_ik") as Dictionary)[side]["target"]
		print("READ  game-code hand_position %s vs drawn wrist %s (gap %.2f m) | shoulder game-code %s vs drawn %s" % [
			rd.hand_position(side).snapped(Vector3.ONE * 0.01), (m["wrist"] as Vector3).snapped(Vector3.ONE * 0.01),
			rd.hand_position(side).distance_to(m["wrist"]), rd.shoulder_position(side).snapped(Vector3.ONE * 0.01),
			(f["RightUpperArm"] as Vector3 if side == "R" else f["LeftUpperArm"] as Vector3).snapped(Vector3.ONE * 0.01)])
		print("FIRST f%d t %.3f side %s | palm %s | p_start %s | palm_goal %s w %.2f | wrist target %s | ik target %s | goal_w %.2f w %.2f" % [
			_series.size(), float(r["t"]), side, (m["palm"] as Vector3).snapped(Vector3.ONE * 0.01), (r.get("p_start", Vector3.ZERO) as Vector3).snapped(Vector3.ONE * 0.01),
			(pg.get("point", Vector3.ZERO) as Vector3).snapped(Vector3.ONE * 0.01), float(pg.get("weight", 0.0)), tgt.snapped(Vector3.ONE * 0.01),
			ikn.global_position.snapped(Vector3.ONE * 0.01), float(rd.get("goal_w_r") if side == "R" else rd.get("goal_w_l")), float(rd.get("w_r") if side == "R" else rd.get("w_l"))])
	var sh_line: Vector3 = (f["LeftUpperArm"] as Vector3) - (f["RightUpperArm"] as Vector3)
	var hp_line: Vector3 = (f["LeftUpperLeg"] as Vector3) - (f["RightUpperLeg"] as Vector3)
	var yaw_sh: float = atan2(sh_line.z, sh_line.x)
	var yaw_hp: float = atan2(hp_line.z, hp_line.x)
	var goal: Dictionary = (rd.get("_palm_goals") as Dictionary).get(side, {})
	_series.append({"state": "ball=%s gait=%s stagger=%.2f drib_w=%.2f act=%.2f resolved=%s" % [_court._ball_mode, str(rd.get("_gait")), rd.stagger,
			float(rd.get("_drib_w")), float(rd.get("_action_time")), str(r.get("resolved"))],
		"goal": (goal.get("point", Vector3.ZERO) as Vector3) - rd.shoulder_position(side), "gw": float(goal.get("weight", 0.0)),
		"dt": delta, "palm": m["palm"], "sh": rd.shoulder_position(side), "dir": m["arm_dir_c"], "flex": m["flex"],
		"bend": m["bend"], "twist": rad_to_deg(wrapf(yaw_sh - yaw_hp, -PI, PI)),
		"tilt": rad_to_deg(((f["Neck"] as Vector3) - (f["Hips"] as Vector3)).angle_to(Vector3.UP)),
		"hips_y": (f["Hips"] as Vector3).y, "root": rd.position, "t": float(r["t"]), "connects": _court._swipe_connects(rd)})


func _summarize() -> void:
	if _series.size() < 6:
		return
	if OS.get_cmdline_user_args().has("trace") and _rows.size() < 3:
		print("TRACE swipe %d (%s)" % [_rows.size() + 1, _move])
		for i in range(1, _series.size()):
			var a: Dictionary = _series[i]
			var b: Dictionary = _series[i - 1]
			print("  t %.3f  palm %.1f m/s (%.2f m)  arm swing %.1f deg/frame  elbow %.0f  wrist %.0f  trunk twist %.0f  tilt %.0f" % [
				float(a["t"]), (a["palm"] as Vector3).distance_to(b["palm"]) / maxf(float(a["dt"]), 0.0001), (a["palm"] as Vector3).distance_to(b["palm"]),
				rad_to_deg((a["dir"] as Vector3).angle_to(b["dir"])), float(a["flex"]), float(a["bend"]), float(a["twist"]), float(a["tilt"])])
	if OS.get_cmdline_user_args().has("pops"):
		for i in range(1, _series.size()):
			var ra: Vector3 = (_series[i]["palm"] as Vector3) - (_series[i]["sh"] as Vector3)
			var rb: Vector3 = (_series[i - 1]["palm"] as Vector3) - (_series[i - 1]["sh"] as Vector3)
			if ra.distance_to(rb) > 0.2:
				print("POP swipe %d (%s) t %.3f: palm moved %.2f m relative to shoulder | GOAL moved %.2f m (weight %.2f -> %.2f) | elbow %.0f -> %.0f | wrist %.0f -> %.0f | arm swing %.0f deg | shoulder moved %.2f m" % [
					_rows.size() + 1, _move, float(_series[i]["t"]), ra.distance_to(rb), (_series[i]["goal"] as Vector3).distance_to(_series[i - 1]["goal"]),
					float(_series[i - 1]["gw"]), float(_series[i]["gw"]), float(_series[i - 1]["flex"]), float(_series[i]["flex"]),
					float(_series[i - 1]["bend"]), float(_series[i]["bend"]), rad_to_deg((_series[i]["dir"] as Vector3).angle_to(_series[i - 1]["dir"])),
					(_series[i]["sh"] as Vector3).distance_to(_series[i - 1]["sh"])])
				print("      before: %s\n      after:  %s" % [_series[i - 1]["state"], _series[i]["state"]])
	var p0: Vector3 = _series[0]["palm"]
	var s0: Vector3 = _series[0]["sh"]
	var d0: Vector3 = _series[0]["dir"]
	var pd: float = 0.0
	var peak: float = 0.0
	var rel: float = 0.0
	var smv: float = 0.0
	var swing: float = 0.0
	var fl: Array = []
	var bd: Array = []
	var tw: Array = []
	var tl: Array = []
	var hy: Array = []
	var root_d: float = 0.0
	var rel_peak: float = 0.0
	var snap: float = 0.0
	for i in _series.size():
		var e: Dictionary = _series[i]
		pd = maxf(pd, (e["palm"] as Vector3).distance_to(p0))
		if i > 0:
			peak = maxf(peak, (e["palm"] as Vector3).distance_to(_series[i - 1]["palm"]) / maxf(float(e["dt"]), 0.0001))
			var a_rel: Vector3 = (e["palm"] as Vector3) - (e["sh"] as Vector3)
			var b_rel: Vector3 = (_series[i - 1]["palm"] as Vector3) - (_series[i - 1]["sh"] as Vector3)
			snap = maxf(snap, a_rel.distance_to(b_rel))
			rel_peak = maxf(rel_peak, a_rel.distance_to(b_rel) / maxf(float(e["dt"]), 0.0001))
		rel = maxf(rel, ((e["palm"] as Vector3) - (e["sh"] as Vector3)).distance_to(p0 - s0))
		smv = maxf(smv, (e["sh"] as Vector3).distance_to(s0))
		swing = maxf(swing, rad_to_deg((e["dir"] as Vector3).angle_to(d0)))
		fl.append(e["flex"])
		bd.append(e["bend"])
		tw.append(e["twist"])
		tl.append(e["tilt"])
		hy.append(e["hips_y"])
		root_d = maxf(root_d, (e["root"] as Vector3).distance_to(_series[0]["root"]))
	_rows.append({"move": _move, "connects": _series[_series.size() - 1]["connects"], "palm_disp": pd, "palm_peak": peak, "rel_disp": rel,
		"rel_peak": rel_peak, "snap": snap, "shoulder_mv": smv, "swing": swing, "elbow": float(fl.max()) - float(fl.min()), "wrist": float(bd.max()) - float(bd.min()),
		"twist": float(tw.max()) - float(tw.min()), "tilt": float(tl.max()) - float(tl.min()), "hips_drop": float(hy[0]) - float(hy.min()), "step": root_d})


## A swipe is a whole-body lunge, not a wrist flick. These limits are my own
## estimates from the kinematics (no measured basketball data was found; the
## sources were coaching text), so they are the thing to correct if wrong:
##  - the arm (palm relative to the shoulder) moves 0.4 m or more, and its peak
##    speed is 3-10 m/s: fast, but no hand goes faster than that, and nothing
##    teleports (no single frame moves it more than 0.20 m relative to the shoulder)
##  - the shoulder joint does the swinging: 45 deg or more of upper-arm swing
##    against the chest, and the wrist bends no more than 60 deg across the swipe
##  - the trunk turns: 12 deg or more of shoulder-line vs hip-line rotation
const MIN_REL_DISP: float = 0.4
const SPEED_RANGE: Vector2 = Vector2(3.0, 10.0)
const MAX_SNAP_M: float = 0.20
const MIN_SWING_DEG: float = 45.0
const MAX_WRIST_DEG: float = 60.0
const MIN_TWIST_DEG: float = 12.0


func _faults(r: Dictionary) -> Array[String]:
	var f: Array[String] = []
	if float(r["rel_disp"]) < MIN_REL_DISP:
		f.append("arm moves only %.2f m" % float(r["rel_rel"] if r.has("rel_rel") else r["rel_disp"]))
	if float(r["rel_peak"]) < SPEED_RANGE.x or float(r["rel_peak"]) > SPEED_RANGE.y:
		f.append("arm peak %.1f m/s" % float(r["rel_peak"]))
	if float(r["snap"]) > MAX_SNAP_M:
		f.append("snaps %.2f m in one frame" % float(r["snap"]))
	if float(r["swing"]) < MIN_SWING_DEG:
		f.append("shoulder swings only %.0f deg" % float(r["swing"]))
	if float(r["wrist"]) > MAX_WRIST_DEG:
		f.append("wrist bends %.0f deg" % float(r["wrist"]))
	if float(r["twist"]) < MIN_TWIST_DEG:
		f.append("trunk turns only %.0f deg" % float(r["twist"]))
	return f


func _report() -> void:
	print("move        hit  palm_disp palm_peak rel_disp rel_peak snap_m shoulder_mv swing_deg elbow_deg wrist_deg trunk_twist trunk_tilt hips_drop step_m")
	var keys: Array = ["palm_disp", "palm_peak", "rel_disp", "rel_peak", "snap", "shoulder_mv", "swing", "elbow", "wrist", "twist", "tilt", "hips_drop", "step"]
	var acc: Dictionary = {}
	for k: String in keys:
		acc[k] = []
	var bad: int = 0
	for r: Dictionary in _rows:
		var fl: Array[String] = _faults(r)
		if not fl.is_empty():
			bad += 1
		print("%-10s  %3s  %8.2f  %8.1f  %7.2f  %7.1f  %6.2f  %10.2f  %8.0f  %8.0f  %8.0f  %10.0f  %9.0f  %8.2f  %5.2f  %s" % [r["move"], "yes" if r["connects"] else "no",
			r["palm_disp"], r["palm_peak"], r["rel_disp"], r["rel_peak"], r["snap"], r["shoulder_mv"], r["swing"], r["elbow"], r["wrist"], r["twist"], r["tilt"], r["hips_drop"], r["step"],
			"ok" if fl.is_empty() else "FAIL: " + ", ".join(fl)])
		for k: String in keys:
			(acc[k] as Array).append(r[k])
	print("swipes that move like a swipe: %d / %d" % [_rows.size() - bad, _rows.size()])
	print("SWIPE MOTION PASSED" if bad == 0 and _rows.size() > 0 else "SWIPE MOTION FAILED")
	var med: Array[String] = []
	for k: String in keys:
		var a: Array = acc[k]
		a.sort()
		med.append("%s %.2f" % [k, float(a[a.size() / 2])])
	print("MEDIAN  " + "  ".join(med))
	get_tree().quit(0)
