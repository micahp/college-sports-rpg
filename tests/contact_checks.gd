extends Node
## Contact checks: plays the court game on auto and measures, every frame, from
## the final drawn pose (a SkeletonModifier3D tap after every modifier), whether
## ball and body contact is physically real:
##   dribble_hand   each dribble, the dribbling hand actually meets the ball
##   dribble_floor  each bounce, the ball actually reaches the floor
##   ball_in_body   the ball never passes through a torso, head or leg
##   ball_jump      the ball never moves faster than a thrown ball (a teleport)
##   catch          on a catch, a hand is on the ball
##   poke           when a swipe knocks it loose, the swiping hand is on the ball
##   pickup         a loose ball is picked up by someone whose hand reaches it
##   pick_off       an intercepted pass is reachable by the defender
##   body_overlap   two players' torsos never pass through each other
## Each check prints how many times it was exercised; one that never happened
## is reported as NOT EXERCISED, not as a pass.
##
##   godot --headless --fixed-fps 60 res://tests/contact_checks.tscn

const CourtScene: PackedScene = preload("res://scenes/court/court_game.tscn")
const CourtGame = preload("res://scripts/court/court_game.gd")
const Actor = preload("res://scripts/court/court_actor.gd")

const GAME_SECONDS: float = 150.0
const BALL_R: float = 0.12
## Tolerances, physical: skin and capsule approximation, not tuned to pass.
const HAND_TOUCH_M: float = 0.10   # wrist bone to ball surface when the palm/fingers are on it
const FLOOR_TOL_M: float = 0.03
const PENETRATE_TOL_M: float = 0.03
const BODY_TOL_M: float = 0.05
const MAX_BALL_MPS: float = 20.0   # a hard pass is ~17 m/s

const TORSO_R: float = 0.13
const HEAD_R: float = 0.11
const THIGH_R: float = 0.08
const SHIN_R: float = 0.055
const BONES: Array[String] = ["Hips", "Neck", "Head", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
	"RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftHand", "RightHand"]

var _court: Node3D
var _joints: Dictionary = {}  # actor -> {bone: world pos} from the final pose
var _stats: Dictionary = {}   # check -> {n, fail, worst, examples}
var _prev_ball: Vector3
var _prev_mode: String = ""
var _prev_holder: Actor = null
var _prev_reach: Dictionary = {}
var _cycle_min: float = INF
var _cycle_floor: float = INF
var _cycle_live: bool = false
var _elapsed: float = 0.0
var _started: bool = false


func _ready() -> void:
	GameState.reset()
	GameState.look_id = "look_a"
	CourtGame.auto_play = true
	for k: String in ["dribble_hand", "dribble_floor", "ball_in_body", "ball_jump", "catch", "poke",
			"pickup", "pick_off", "body_overlap"]:
		_stats[k] = {"n": 0, "fail": 0, "worst": 0.0, "examples": []}
	_court = CourtScene.instantiate()
	_court.scenario = CourtGame.demo_scenario()
	add_child(_court)
	var probe: Node = Node.new()
	probe.process_priority = 1000
	var s: GDScript = GDScript.new()
	s.source_code = "extends Node\nvar qa: Node\nfunc _process(delta: float) -> void:\n\tqa.measure(delta)\n"
	s.reload()
	probe.set_script(s)
	probe.set("qa", self)
	add_child(probe)


func _tap(a: Actor) -> void:
	var sk: Skeleton3D = a.get("_skeleton")
	if sk == null:
		return
	var tap: SkeletonModifier3D = SkeletonModifier3D.new()
	var ts: GDScript = GDScript.new()
	ts.source_code = "extends SkeletonModifier3D\nvar qa: Node\nvar who: Node\nfunc _process_modification_with_delta(_d: float) -> void:\n\tqa.final_pose(who, get_skeleton())\n"
	ts.reload()
	tap.set_script(ts)
	tap.set("qa", self)
	tap.set("who", a)
	sk.add_child(tap)


func final_pose(a: Actor, sk: Skeleton3D) -> void:
	var j: Dictionary = {}
	for b: String in BONES:
		var i: int = sk.find_bone(b)
		if i >= 0:
			j[b] = sk.global_transform * sk.get_bone_global_pose(i).origin
	_joints[a] = j


func measure(delta: float) -> void:
	if delta <= 0.0:
		return
	if not _started:
		if _court._phase != CourtGame.Phase.LIVE:
			return
		_started = true
		for a: Actor in _court._all:
			_tap(a)
		_prev_ball = _court._ball.position
		_prev_mode = _court._ball_mode
		return
	_elapsed += delta
	var ball: Vector3 = _court._ball.position
	var mode: String = _court._ball_mode
	var holder: Actor = _court._holder
	var t: String = "t=%.2f" % _elapsed

	# ball_jump: no teleports. A shot starting from the hand is real; so is a
	# dead ball being reset for the next possession (not a contact).
	var speed: float = ball.distance_to(_prev_ball) / delta
	if mode != "dead" and _prev_mode != "dead":
		_record("ball_jump", speed - MAX_BALL_MPS, "%s %.1f m/s (%s->%s)" % [t, speed, _prev_mode, mode])

	# Transitions
	if _prev_mode == "pass" and mode == "held" and holder != null:
		_record("catch", _hand_gap(holder, ball) - HAND_TOUCH_M * 1.5, "%s hand %.2f m from ball" % [t, _hand_gap(holder, ball)])
	if _prev_mode == "held" and mode == "loose" and not _prev_reach.is_empty():
		var d: Actor = _prev_reach["d"]
		var side: String = "RightHand" if str(_prev_reach["side"]) == "R" else "LeftHand"
		var g: float = _bone_gap(d, side, _prev_ball)
		_record("poke", g - HAND_TOUCH_M * 1.5, "%s swiping hand %.2f m from ball" % [t, g])
	if _prev_mode == "loose" and (mode == "held" or mode == "dead"):
		var who: Actor = holder if mode == "held" else _court._nearest_to(Vector3(_prev_ball.x, 0, _prev_ball.z), _court._defense)
		if who != null:
			var m: float = who.reach_margin(_prev_ball, BALL_R)
			_record("pickup", -m, "%s %s reach margin %.2f m" % [t, "picker" if mode == "held" else "stealer", m])
	if _prev_mode == "pass" and mode == "dead":
		var d2: Actor = _court._nearest_to(Vector3(_prev_ball.x, 0, _prev_ball.z), _court._defense)
		if d2 != null and d2.flat().distance_to(Vector3(_prev_ball.x, 0, _prev_ball.z)) < 0.7:
			var m2: float = d2.reach_margin(_prev_ball, BALL_R)
			_record("pick_off", -m2, "%s reach margin %.2f m" % [t, m2])

	# Dribble: one cycle per floor hit.
	var dribbling: bool = mode == "held" and holder != null and holder == _prev_holder \
		and not _court._charging and not _court._layup
	if dribbling:
		var side2: String = "RightHand" if _dribble_side(holder) == "R" else "LeftHand"
		_cycle_min = minf(_cycle_min, minf(_bone_gap(holder, "RightHand", ball), _bone_gap(holder, "LeftHand", ball)))
		_cycle_floor = minf(_cycle_floor, ball.y)
		if holder.ball_hit_floor:
			if _cycle_live:
				_record("dribble_hand", _cycle_min - HAND_TOUCH_M, "%s closest hand %.2f m from ball over the dribble (%s)" % [t, _cycle_min, side2])
				_record("dribble_floor", _cycle_floor - (CourtGame.BALL_FLOOR + FLOOR_TOL_M), "%s lowest ball %.3f m" % [t, _cycle_floor])
			_cycle_live = true
			_cycle_min = INF
			_cycle_floor = INF
	else:
		_cycle_live = false
		_cycle_min = INF
		_cycle_floor = INF

	# ball_in_body: every player, every frame the ball is in play.
	if mode != "dead" and mode != "shot":
		for a: Actor in _court._all:
			var pen: float = _ball_penetration(a, ball)
			if pen > -1.0:
				_record("ball_in_body", pen - PENETRATE_TOL_M, "%s %s ball %.2f m into %s (%s)" % [
					t, a.name, pen, _last_part, mode], false)

	# body_overlap: torso against torso.
	var all: Array = _court._all
	for i in all.size():
		for k in range(i + 1, all.size()):
			var o: float = _torso_overlap(all[i], all[k])
			if o > -1.0:
				_record("body_overlap", o - BODY_TOL_M, "%s %s/%s torsos overlap %.2f m" % [t, all[i].name, all[k].name, o], false)

	_prev_ball = ball
	_prev_mode = mode
	_prev_holder = holder
	_prev_reach = _court._reach.duplicate()
	if _elapsed >= GAME_SECONDS or _court._phase == CourtGame.Phase.FINAL:
		_report()


var _last_part: String = ""


func _dribble_side(h: Actor) -> String:
	return "R" if float(_court._ball_side) > 0.0 else "L"


func _bone_gap(a: Actor, bone: String, p: Vector3) -> float:
	var j: Dictionary = _joints.get(a, {})
	if not j.has(bone):
		return INF
	return (j[bone] as Vector3).distance_to(p) - BALL_R


func _hand_gap(a: Actor, p: Vector3) -> float:
	return minf(_bone_gap(a, "RightHand", p), _bone_gap(a, "LeftHand", p))


## Depth of the ball into the deepest body part, or -INF-ish when clear.
func _ball_penetration(a: Actor, p: Vector3) -> float:
	var j: Dictionary = _joints.get(a, {})
	if j.is_empty():
		return -2.0
	var best: float = -2.0
	var parts: Array = [["torso", "Hips", "Neck", TORSO_R], ["head", "Head", "Head", HEAD_R],
		["L thigh", "LeftUpperLeg", "LeftLowerLeg", THIGH_R], ["L shin", "LeftLowerLeg", "LeftFoot", SHIN_R],
		["R thigh", "RightUpperLeg", "RightLowerLeg", THIGH_R], ["R shin", "RightLowerLeg", "RightFoot", SHIN_R]]
	for part: Array in parts:
		if not j.has(part[1]) or not j.has(part[2]):
			continue
		var c: Vector3 = Geometry3D.get_closest_point_to_segment(p, j[part[1]], j[part[2]])
		var pen: float = float(part[3]) + BALL_R - c.distance_to(p)
		if pen > best:
			best = pen
			_last_part = part[0]
	return best if best > 0.0 else -2.0


func _torso_overlap(a: Actor, b: Actor) -> float:
	var ja: Dictionary = _joints.get(a, {})
	var jb: Dictionary = _joints.get(b, {})
	if not (ja.has("Hips") and ja.has("Neck") and jb.has("Hips") and jb.has("Neck")):
		return -2.0
	if (ja["Hips"] as Vector3).distance_to(jb["Hips"]) > 1.5:
		return -2.0
	var pts: PackedVector3Array = Geometry3D.get_closest_points_between_segments(ja["Hips"], ja["Neck"], jb["Hips"], jb["Neck"])
	var o: float = TORSO_R * 2.0 - pts[0].distance_to(pts[1])
	return o if o > 0.0 else -2.0


## excess > 0 is a failure, by that many metres (or m/s).
func _record(check: String, excess: float, note: String, counts: bool = true) -> void:
	var s: Dictionary = _stats[check]
	if counts:
		s["n"] = int(s["n"]) + 1
	if excess > 0.0:
		if not counts:
			s["n"] = int(s["n"]) + 1
		s["fail"] = int(s["fail"]) + 1
		s["worst"] = maxf(float(s["worst"]), excess)
		if (s["examples"] as Array).size() < 4:
			(s["examples"] as Array).append(note)
	elif not counts:
		pass


var _done: bool = false


func _report() -> void:
	if _done:
		return
	_done = true
	print("contact checks over %.0f s of auto play" % _elapsed)
	print("check          samples  fails  worst_excess")
	var failed: int = 0
	for k: String in _stats:
		var s: Dictionary = _stats[k]
		var frame_check: bool = k == "ball_in_body" or k == "body_overlap"
		var status: String = "ok"
		if int(s["fail"]) > 0:
			status = "FAIL"
			failed += 1
		elif int(s["n"]) == 0 and not frame_check:
			status = "NOT EXERCISED"
		print("%-14s %7s  %5d  %8.3f   %s" % [k, "frames" if frame_check else str(s["n"]), int(s["fail"]), float(s["worst"]), status])
		for e: String in s["examples"]:
			print("      " + e)
	print("CONTACT CHECKS PASSED" if failed == 0 else "CONTACT CHECKS FAILED (%d checks)" % failed)
	get_tree().quit(0 if failed == 0 else 1)
