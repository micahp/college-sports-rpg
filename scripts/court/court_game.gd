extends Node3D
## A playable stretch of a real game. Full-court arena, half-court offense:
## you run North Valley State's possessions live, the other team's trips
## resolve as a banner, and a stop can turn into a fast break. Clock and
## score keep moving, so every shot happens inside a game situation.
##
## Offense follows how the modern game gets shots:
##   - Spacing: teammates fill perimeter spots and relocate away from the
##     ball, so the paint stays open (5-out drive-and-kick).
##   - Pick-and-roll: call a pick (PICK / C) or the big comes on his own.
##     He sets a screen on your man; your man has to fight around it. The
##     opponent's coverage (drop, hedge, switch) decides what's open: pull
##     up or hit the popper vs drop, hit the roller vs hedge, attack the
##     slower big after a switch.
##   - Help and kick: get to the paint and a helper leaves his man open.
##   - Backdoor: a denied teammate cuts to the rim.
## Defense is visible: stance, active hands, closeouts with hands up, and
## real swipes at the ball (steal, deflection into a loose-ball scramble,
## whiff and he's off balance, or a reach-in foul). Contact is a bump, not
## a turnover. The handler crosses over automatically to keep the ball
## away from the defender's side.
##
## Camera: behind your player, never flips (2K "Turbo"-style).
## Usage: set `scenario`, add to the tree, await `finished(result)`.

signal finished(result: Dictionary)

const Actor = preload("res://scripts/court/court_actor.gd")
const SpriteActor = preload("res://scripts/court/court_sprite_actor.gd")
const Arena = preload("res://scripts/court/court_arena.gd")
const JoystickScript = preload("res://scripts/ui/virtual_joystick.gd")
const PauseMenuScene: PackedScene = preload("res://scenes/court/pause_menu.tscn")
const CourtAudio = preload("res://scripts/court/court_audio.gd")

static var auto_play: bool = false
static var auto_quality: String = "good"
static var debug_close_cam: bool = false
## Players and ball are baked sprites (the default). False brings back the
## rigged 3D players for comparison.
static var use_sprites: bool = false

const HALF_W: float = 7.5
const BASELINE: float = 14.0
const HOOP: Vector3 = Vector3(0, 3.05, -12.425)
const HOOP_FLAT: Vector3 = Vector3(0, 0, -12.425)
const ARC_R: float = 6.75
const CORNER_X: float = 6.6

const USER_SPEED: float = 3.9
const SPRINT_SPEED: float = 5.0
const MATE_SPEED: float = 3.8
const SHOT_CLOCK: float = 18.0
const BREAK_CLOCK: float = 8.0
const CLOCK_FACTOR: float = 3.0
const METER_CENTER: float = 0.74
const PERFECT_FRACTION: float = 0.35
const REACH_TIME: float = 0.5
# Shot tuning, indexed by contest level (very tight, tight, open, wide open).
# Sources in docs/PHASE_2.md. Threes: 27/30/35/39% by defender distance.
# Twos: 39/43/47% (wide open extrapolated). Layups: Division I makes 55%
# of all layups; the split by contest is an estimate that averages near it.
const CONTEST_NAMES: Array[String] = ["Smothered", "Contested", "Open", "Wide open"]
const REAL_3P: Array[float] = [0.27, 0.30, 0.35, 0.39]
const REAL_2P: Array[float] = [0.39, 0.43, 0.47, 0.50]
const REAL_LAYUP: Array[float] = [0.36, 0.52, 0.68, 0.80]
const CONTEST_WINDOW: Array[float] = [0.69, 0.77, 0.90, 1.0]  # window width, from the 3P ratios
const BUILDS: Array[float] = [0.1, 0.3, 0.0, 0.2, 0.45]  # college builds, lean to solid
const SHOT_GRAVITY: float = 9.81
const GATHER_TIME: float = 0.16  # picking the ball up off the dribble
const SHOT_RELEASE_AT: float = 1.0  # seconds into the jump-shot clip when the real shooter let go
const BALL_FLOOR: float = 0.13  # ball centre when it rests on the hardwood
const LAYUP_TIME: float = 0.5
const LAYUP_RANGE: float = 4.4  # standing (about the charge circle to the foul line)
const DRIVE_RANGE: float = 5.8  # attacking the rim at speed

## Perimeter spots for spacing (outside the arc, paint left open).
const SPOTS: Array[Vector3] = [
	Vector3(-6.75, 0, -12.6), Vector3(-5.9, 0, -8.1), Vector3(-3.4, 0, -5.5),
	Vector3(0, 0, -4.7), Vector3(3.4, 0, -5.5), Vector3(5.9, 0, -8.1), Vector3(6.75, 0, -12.6),
]

enum Phase { INTRO, SETUP, LIVE, SHOT, DEAD, OPP, FINAL, REBOUND }

var scenario: Dictionary = {}

var _phase: int = Phase.INTRO
var _phase_time: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _user: Actor
var _big: Actor
var _mates: Array = []
var _offense: Array = []
var _defense: Array = []
var _all: Array = []

# Ball
var _ball: MeshInstance3D
var _ball_shadow: MeshInstance3D
var _holder: Actor = null
var _ball_mode: String = "held"  # held, pass, shot, loose, dead
var _flight_from: Vector3
var _flight_to: Vector3
var _flight_vy: float = 0.0  # upward launch speed of the current shot
var _shot_wait: float = 0.0
const BOARD_JUMP_TIME := 0.64
var _board_jumps: Dictionary = {}
var _secure_offset := Vector3.ZERO
var _recovery_t := 0.0
var _gather_from: Vector3 = Vector3.ZERO
var _layup_air: bool = false
var _layup_drive_t: float = 0.0
var _layup_speed: float = 0.0
var _shot_layup: bool = false
var _flight_t: float = 0.0
var _flight_dur: float = 0.5
var _pass_target: Actor = null
var _pass_from: Actor = null
var _pass_checked: Array = []
var _pass_pose_t: float = 0.0
var _shot_made: bool = false
var _shot_points: int = 2
var _shooter: Actor = null
var _follow_t: float = 0.0
var _loose_vel: Vector3 = Vector3.ZERO
var _loose_t: float = 0.0
var _last_touch_team: int = 0
var _last_handler_user: bool = false
var _dribble_t: float = 0.0
var _ball_side: float = 1.0  # +1 right hand, -1 left hand
var _cross_t: float = -1.0
var _cross_from: float = 1.0
var _cross_cd: float = 0.0
var _catch_grace: float = 0.0
var _ai_decide: float = 0.0
var _hold_time: float = 0.0
var _last_pass_by_user_t: float = -10.0
var _shot_assisted := false
var _last_pass_to: Actor = null
var _time: float = 0.0

# Defense state
var _reach: Dictionary = {}  # {d, t, side, resolved}
var _screen_hits: Dictionary = {}  # defender -> time of last screen hit
var _pick_sign: float = 1.0
var _pick_lat: Vector3 = Vector3.RIGHT
var _pick_used: bool = false
var _pick_passed_t: float = -1.0
var _switched: bool = false
var _opp_bonus: float = 0.0
var _spacing_t: float = 0.0

# Game state
var _clock: float = 300.0
var _shot_clock: float = SHOT_CLOCK
var _quarter: int = 4
var _team_score: int = 0
var _opp_score: int = 0
var _possession_kind: String = "half"
var _break_timer: float = 0.0
var _next_is_break: bool = false
var _opp: Dictionary = {}
var _team: Dictionary = {}

# Shooting meter
var _charging: bool = false
var _charge_t: float = 0.0
var _meter_pos: float = 0.0
var _meter_speed: float = 1.2
var _zone_w: float = 0.2
var _shoot_held: bool = false

# Layups: tap SHOOT near the rim and he gathers, takes two steps and finishes.
var _layup: bool = false
var _layup_t: float = 0.0
var _layup_from: Vector3
var _layup_to: Vector3
var _layup_dunk: bool = false
var _shot_line: String = ""
var _pad_rested: bool = false
var _audio: Node
var _dribble_prev: float = 0.0
var _dribble_falling: bool = false
var _made: int = 0
# Beating your man off the dribble
var _dir_prev: Vector3 = Vector3.ZERO
var _dir_sample_t: float = 0.0
var _shake_cd: float = 0.0

var _stats: Dictionary = {"pts": 0, "fgm": 0, "fga": 0, "tpm": 0, "tpa": 0, "ast": 0, "reb": 0, "to": 0}

var _camera: Camera3D
var _cam_focus: Vector3 = Vector3.ZERO

var _layer: CanvasLayer
var _home_label: Label
var _away_label: Label
var _clock_label: Label
var _shot_clock_label: Label
var _banner: Label
var _sub_banner: Label
var _banner_tween: Tween
var _meter: Control
var _joystick: Control
var _shoot_button: Button
var _pass_button: Button
var _pick_button: Button
var _final_panel: PanelContainer
var _target_ring: MeshInstance3D
var _user_ring: MeshInstance3D


func _ready() -> void:
	_rng.randomize()
	if scenario.is_empty():
		scenario = demo_scenario()
	_quarter = int(scenario.get("quarter", 4))
	_clock = float(scenario.get("clock", 300.0))
	_team_score = int(scenario.get("team_score", 0))
	_opp_score = int(scenario.get("opp_score", 0))
	_team = scenario.get("team", {"short": "NVS", "off": 55, "def": 55})
	_opp = scenario.get("opponent", {})
	Arena.new().build(self)
	_build_actors()
	_build_ball()
	_build_ui()
	_build_camera()
	_audio = CourtAudio.new()
	add_child(_audio)
	_set_phase(Phase.INTRO, 2.4)
	var cover: String = {"drop": "Their big sits back in drop.", "hedge": "Their big hedges hard on picks.",
		"switch": "They switch every screen."}.get(str(_opp.get("pnr", "drop")), "")
	var where: String = "\nControls: pause (II)" if UIKit.is_touch() else "\nControls: pause (Esc)"
	_show_banner(_situation_line(), str(scenario.get("note", "")) + ("\n" + cover if cover != "" else "") + where, 2.4)
	_reset_positions("half")
	_give_ball(_user)  # in his hands from the first frame, never loose at centre court
	_refresh_scoreboard()


static func demo_scenario() -> Dictionary:
	return {
		"quarter": 4,
		"clock": 240.0,
		"team_score": 61,
		"opp_score": 64,
		"note": "Delgado: \"Get us a stop and run.\"",
		"team": {"short": "NVS", "off": 55, "def": 55},
		"opponent": {"name": "Ridge Tech", "short": "RTU", "off": 56, "def": 54,
			"speed": 1.0, "aggr": 1.0, "color": "#a3282e", "pnr": "drop"},
	}


# =============================================================================
# Main loop
# =============================================================================

func _physics_process(delta: float) -> void:
	_time += delta
	_phase_time -= delta
	_read_input()
	match _phase:
		Phase.INTRO:
			_idle_actors(delta)
			if _phase_time <= 0.0:
				_start_possession()
		Phase.SETUP:
			_user.step_toward(Vector3(_user.position.x, 0, -1.0), MATE_SPEED, delta)
			_move_mates(delta)
			_move_defense(delta)
			if _phase_time <= 0.0:
				_set_phase(Phase.LIVE, 0.0)
		Phase.LIVE:
			_tick_live(delta)
		Phase.SHOT:
			if _ball_mode == "shot" and _user != _shooter:
				_move_user(delta)
				for a: Actor in _all:
					if a != _user:
						a.move_with(Vector3.ZERO, delta)
				_separate()
				_clamp_all()
			else:
				_idle_actors(delta)
			_tick_shot(delta)
		Phase.REBOUND:
			_tick_rebound(delta)
		Phase.DEAD, Phase.OPP:
			_idle_actors(delta)
			if _phase_time <= 0.0:
				if _clock <= 0.0:
					_finish()
				elif _phase == Phase.DEAD:
					_simulate_opponent()
				else:
					_start_possession()
		Phase.FINAL:
			_idle_actors(delta)
	_update_ball(delta)
	_pose_all(delta)
	for a: Actor in _all:
		a.animate(delta)
	_update_markers()
	_update_camera(delta)
	if _charging:
		_meter.queue_redraw()


func _set_phase(phase: int, seconds: float) -> void:
	_phase = phase
	_phase_time = seconds


func _tick_live(delta: float) -> void:
	_clock = maxf(0.0, _clock - delta * CLOCK_FACTOR)
	if _ball_mode != "shot":
		_shot_clock = maxf(0.0, _shot_clock - delta)
	_catch_grace = maxf(0.0, _catch_grace - delta)
	_cross_cd = maxf(0.0, _cross_cd - delta)
	_pass_pose_t = maxf(0.0, _pass_pose_t - delta)
	if _possession_kind == "break":
		_break_timer += delta
	_refresh_scoreboard()
	# The building gets louder late in a close game.
	_audio.set_crowd_energy((1.0 - clampf(_clock / 240.0, 0.0, 1.0)) * (1.0 - clampf(absf(_team_score - _opp_score) / 10.0, 0.0, 1.0)))

	_move_user(delta)
	_move_mates(delta)
	_move_defense(delta)
	_separate()
	_clamp_all()

	if _layup:
		_tick_layup(delta)
		return
	_shake_cd = maxf(0.0, _shake_cd - delta)
	if _holder == _user and _ball_mode == "held":
		_check_blowby(delta)
	if _charging:
		_charge_t += delta
		_meter_pos += _meter_speed * delta
		if _meter_pos >= 1.0:
			_meter_pos = 1.0
			_release_shot()
		return
	_tick_reach(delta)
	if _phase != Phase.LIVE:
		return
	if _ball_mode == "loose":
		_tick_loose_pickup(delta)
		return
	if _ball_mode == "held" and _holder != null:
		_hold_time += delta
		_update_crossover(delta)
		if _holder.is_user:
			if auto_play:
				_auto_user(delta)
			elif not _pick_used and _possession_kind == "half" and _hold_time > 3.0 \
					and _nearest_defender_dist(_user) < 1.8:
				_call_pick()  # the big comes on his own if you stall
		else:
			_ai_holder(delta)
	if _phase != Phase.LIVE:
		return
	if _shot_clock <= 0.0 and _ball_mode == "held":
		_audio.play("buzzer", -6.0, 0.0)
		_turnover("Shot clock violation", _holder == _user)
		return
	if _clock <= 0.0 and _ball_mode == "held":
		_end_possession("Buzzer", "")


# =============================================================================
# Possessions
# =============================================================================

func _start_possession() -> void:
	var kind: String = "break" if _next_is_break else "half"
	_next_is_break = false
	_possession_kind = kind
	_break_timer = 0.0
	_shot_clock = BREAK_CLOCK if kind == "break" else SHOT_CLOCK
	_pick_used = false
	_pick_passed_t = -1.0
	_reach.clear()
	_layup = false
	_restore_matchups()
	_reset_positions(kind)
	_give_ball(_user)
	_catch_grace = 0.8
	if kind == "break":
		_show_banner("Fast break!", "Numbers. Attack the rim.", 1.0)
		_set_phase(Phase.LIVE, 0.0)
	else:
		_set_phase(Phase.SETUP, 0.7)


func _restore_matchups() -> void:
	_switched = false
	for i in _defense.size():
		var d: Actor = _defense[i]
		d.man = _offense[i]


func _reset_positions(kind: String) -> void:
	var spots: Array[Vector3] = [Vector3(0, 0, -4.7), SPOTS[1], SPOTS[5], SPOTS[6], SPOTS[2]]
	for i in _offense.size():
		var o: Actor = _offense[i]
		o.spot = spots[i]
		o.role = "space"
		o.stop()
		o.stagger = 0.0
	if kind == "break":
		_user.position = Vector3(_rng.randf_range(-1.5, 1.5), 0, 1.5)
		_mates[0].position = Vector3(-4.6, 0, -2.0)
		_mates[1].position = Vector3(4.6, 0, -2.5)
		_mates[2].position = Vector3(3.0, 0, 5.0)
		_mates[3].position = Vector3(-2.0, 0, 6.0)
		for i in _defense.size():
			var d: Actor = _defense[i]
			d.stop()
			d.stagger = 0.0
			d.protect_rim = false
			d.position = _offense[i].position + Vector3(_rng.randf_range(-1.0, 1.0), 0, _rng.randf_range(3.0, 5.0))
		_defense[4].protect_rim = true
		_defense[4].position = Vector3(0.6, 0, -10.6)
		if _rng.randf() < 0.5:
			_defense[1].protect_rim = true
			_defense[1].position = Vector3(-1.4, 0, -8.6)
	else:
		_user.position = Vector3(_rng.randf_range(-1.0, 1.0), 0, 1.0)
		for i in range(1, _offense.size()):
			var o: Actor = _offense[i]
			o.position = o.spot + Vector3(0, 0, 5.5)
		for i in _defense.size():
			var d: Actor = _defense[i]
			d.stop()
			d.stagger = 0.0
			d.protect_rim = false
			var m: Actor = _offense[i]
			d.position = m.spot + (HOOP_FLAT - m.spot).normalized() * 1.4
	for d: Actor in _defense:
		d.track = (d.man as Actor).flat()
		d.reach_cd = 1.2
	for a: Actor in _all:
		a.face_point(HOOP_FLAT if a.team == 0 else _user.position)


func _give_ball(a: Actor) -> void:
	_holder = a
	_last_pass_to = null
	_ball_mode = "held"
	_hold_time = 0.0
	_ai_decide = 0.18
	_last_touch_team = 0
	_last_handler_user = a == _user
	_cross_t = -1.0
	# Catch with the ball away from the nearest defender.
	var d: Actor = _on_ball_defender()
	if d != null:
		_ball_side = -1.0 if (d.flat() - a.flat()).dot(a.right()) > 0.0 else 1.0


func _end_possession(headline: String, sub: String) -> void:
	_charging = false
	_meter.visible = false
	_ball_mode = "dead"
	_reach.clear()
	_end_pick()
	_show_banner(headline, sub, 1.2)
	_set_phase(Phase.DEAD, 1.3)


func _turnover(headline: String, by_user: bool, live_ball: bool = false) -> void:
	if by_user:
		_stats["to"] = int(_stats["to"]) + 1
	if live_ball:
		_opp_bonus = 0.2  # they're running the other way
	_end_possession(headline, "Turnover")


func _simulate_opponent() -> void:
	_clock = maxf(0.0, _clock - _rng.randf_range(11.0, 19.0))
	var p: float = clampf(0.47 + (float(_opp.get("off", 55)) - float(_team.get("def", 55))) / 220.0 + _opp_bonus,
		0.28, 0.8)
	_opp_bonus = 0.0
	var name_short: String = str(_opp.get("name", "They"))
	if _rng.randf() < p:
		var pts: int = 3 if _rng.randf() < 0.3 else 2
		_opp_score += pts
		_show_banner("%s scores %d" % [name_short, pts], "Back the other way.", 1.4)
		_next_is_break = false
	else:
		var stops: Array[String] = ["Stop!", "Got the stop", "Rebound, NVS"]
		_next_is_break = _rng.randf() < 0.4
		_show_banner(stops[_rng.randi() % stops.size()],
			"Steal! Run!" if _next_is_break else "%s comes up empty." % name_short, 1.4)
	_refresh_scoreboard()
	_set_phase(Phase.OPP, 1.5)


func _finish() -> void:
	_set_phase(Phase.FINAL, 0.0)
	_audio.play("buzzer", -4.0, 0.0)
	_charging = false
	_meter.visible = false
	_ball_mode = "dead"
	for b: Control in [_shoot_button, _pass_button, _pick_button, _joystick]:
		b.visible = false
	_show_final(result_dict())


func result_dict() -> Dictionary:
	var r: Dictionary = _stats.duplicate()
	r["team_score"] = _team_score
	r["opp_score"] = _opp_score
	r["start_margin"] = int(scenario.get("team_score", 0)) - int(scenario.get("opp_score", 0))
	r["margin"] = _team_score - _opp_score
	return r


# =============================================================================
# User input
# =============================================================================

## Keyboard first, then a controller stick, then the touch stick. A stick
## only counts once it has been seen at rest, so a device with a stuck axis
## can't steer the player.
func _input_vector() -> Vector2:
	var v: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if v != Vector2.ZERO:
		return v
	var pad: Vector2 = Input.get_vector("pad_left", "pad_right", "pad_up", "pad_down", 0.3)
	if pad.length() < 0.1:
		_pad_rested = true
	elif _pad_rested:
		return pad
	if _joystick.output.length() > 0.15:
		return _joystick.output.limit_length(1.0)
	return Vector2.ZERO


func _move_user(delta: float) -> void:
	if _layup:
		return
	if _charging:
		_user.move_with(Vector3.ZERO, delta, 30.0)
		_user.face_point(HOOP_FLAT)
		return
	if auto_play:
		return
	var v: Vector2 = _input_vector()
	var speed: float = (SPRINT_SPEED if _sprinting() else USER_SPEED) * (0.94 if _holder == _user else 1.0)
	_user.move_with(Vector3(v.x, 0, v.y) * speed, delta, 22.0)
	if v == Vector2.ZERO:
		_user.turn_toward(HOOP_FLAT, delta)


func _read_input() -> void:
	var held: bool = Input.is_action_pressed("shoot") or (_shoot_button != null and _shoot_button.button_pressed)
	if held and not _shoot_held:
		_on_shoot_down()
	elif not held and _shoot_held:
		_on_shoot_up()
	_shoot_held = held
	if Input.is_action_just_pressed("pass"):
		_on_pass()
	if Input.is_action_just_pressed("pick"):
		_on_pick()


## Sprint (2K: RT / R2). On touch, pushing the stick to its edge sprints.
func _sprinting() -> bool:
	if Input.is_physical_key_pressed(KEY_SHIFT) or (_pad_rested and Input.is_action_pressed("sprint")):
		return true
	return _joystick.output.length() > 0.92


func _on_shoot_down() -> void:
	if _phase == Phase.REBOUND and _holder == null:
		_board_jump(_user)
		return
	if _phase == Phase.LIVE and _holder == _user and _ball_mode == "held" and not _charging and not _layup and not auto_play:
		if _in_layup_range():
			_begin_layup()
		else:
			_begin_shot()


func _on_shoot_up() -> void:
	if _charging and not auto_play:
		_release_shot()


func _on_pass() -> void:
	if _phase != Phase.LIVE or _holder != _user or _ball_mode != "held" or _charging or auto_play:
		return
	var target: Actor = _pick_pass_target()
	if target != null:
		_throw_pass(_user, target)


func _on_pick() -> void:
	if _phase == Phase.LIVE and _holder == _user and _ball_mode == "held" and not auto_play:
		_call_pick()


func _pick_pass_target() -> Actor:
	var aim: Vector3
	var v: Vector2 = _input_vector()
	aim = Vector3(v.x, 0, v.y).normalized() if v.length() > 0.2 else _user.facing()
	var best: Actor = null
	var best_score: float = -INF
	for m: Actor in _mates:
		var to: Vector3 = m.flat() - _user.flat()
		var dist: float = to.length()
		if dist < 0.5:
			continue
		var score: float = aim.dot(to / dist) * 2.0 - dist * 0.05 + _openness(m) * 0.3
		if m.role == "roll" and _openness(m) > 1.6:
			score += 0.6
		if score > best_score:
			best_score = score
			best = m
	return best


# =============================================================================
# Pick-and-roll
# =============================================================================

func _call_pick() -> void:
	if _pick_used or _possession_kind != "half":
		return
	_pick_used = true
	var screener: Actor = _big
	if _big.flat().distance_to(_user.flat()) > 9.0 or _big == _holder:
		var best: float = INF
		for m: Actor in _mates:
			var dd: float = m.flat().distance_to(_user.flat())
			if dd < best and m != _holder:
				best = dd
				screener = m
	var fwd: Vector3 = (HOOP_FLAT - _user.flat()).normalized()
	_pick_lat = Vector3(-fwd.z, 0, fwd.x)
	var v: Vector2 = _input_vector()
	if absf(v.x) > 0.3:
		_pick_sign = signf(Vector3(v.x, 0, v.y).dot(_pick_lat))
	elif absf(_user.position.x) > 1.0:
		_pick_sign = signf(Vector3(-_user.position.x, 0, 0).dot(_pick_lat))  # toward the middle
	else:
		_pick_sign = 1.0 if _rng.randf() < 0.5 else -1.0
	screener.role = "screen_come"
	screener.role_time = 0.0
	_pick_passed_t = -1.0
	_show_toast("Pick coming")


func _screener() -> Actor:
	for m: Actor in _mates:
		if m.role in ["screen_come", "screen_set", "roll", "pop"]:
			return m
	return null


func _end_pick() -> void:
	for m: Actor in _mates:
		if m.role in ["screen_come", "screen_set", "roll", "pop"]:
			m.role = "space"


## Where the screen goes: beside the user's defender, on the side the user
## will drive to.
func _screen_point() -> Vector3:
	var ud: Actor = _defender_of(_user)
	var base: Vector3 = ud.flat() if ud != null else _user.flat() + (HOOP_FLAT - _user.flat()).normalized()
	return base + _pick_lat * _pick_sign * 0.75


func _tick_screener(m: Actor, delta: float) -> void:
	m.role_time += delta
	match m.role:
		"screen_come":
			var p: Vector3 = _screen_point()
			m.step_toward(p, 4.2, delta)
			if m.flat().distance_to(p) < 0.35 or m.role_time > 3.0:
				m.role = "screen_set"
				m.role_time = 0.0
		"screen_set":
			m.move_with(Vector3.ZERO, delta, 30.0)
			m.face_point(m.position + _pick_lat * _pick_sign * -1.0 + (HOOP_FLAT - m.flat()).normalized() * 0.3)
			# The handler has used the screen once he's past it on the screen side.
			var past: float = (_user.flat() - m.flat()).dot(_pick_lat * _pick_sign)
			if past > 0.4 and _pick_passed_t < 0.0:
				_pick_passed_t = _time
				_on_screen_used(m)
			if (_pick_passed_t >= 0.0 and _time - _pick_passed_t > 0.25) or m.role_time > 2.2 or _holder != _user:
				var cover: String = str(_opp.get("pnr", "drop"))
				if cover == "drop" and not m.is_big:
					cover = "hedge"
				if cover == "drop":
					m.role = "pop"
					var best: Vector3 = SPOTS[3]
					var far: float = -1.0
					for s: Vector3 in SPOTS:
						var dd: float = s.distance_to(_user.flat())
						if dd > far and s.distance_to(m.flat()) < 6.0:
							far = dd
							best = s
					m.role_target = best
				else:
					m.role = "roll"
					m.role_target = HOOP_FLAT + Vector3(-_pick_sign * _pick_lat.x * 0.8, 0, 1.3)
				m.role_time = 0.0
		"roll", "pop":
			m.step_toward(m.role_target, 4.3 if m.role == "roll" else 3.9, delta)
			if m.role_time > 2.6:
				m.role = "space"


func _on_screen_used(screener: Actor) -> void:
	if str(_opp.get("pnr", "")) == "switch" and not _switched:
		var ud: Actor = _defender_of(_user)
		var sd: Actor = _defender_of(screener)
		if ud != null and sd != null:
			ud.man = screener
			sd.man = _user
			_switched = true
			_show_toast("Switch! Their big is on you")


# =============================================================================
# Shooting
# =============================================================================

func _begin_shot() -> void:
	_gather_from = _ball.position
	_charging = true
	_charge_t = 0.0
	_meter_pos = 0.0
	_reach.clear()
	var tuning: Dictionary = Game.meter_tuning()
	_meter_speed = float(tuning["speed"]) * 0.95
	var window_scale: float = {"Easy": 1.25, "Medium": 1.0, "Hard": 0.85, "Ultimate": 0.70}[GameState.court_difficulty]
	var open_mult: float = CONTEST_WINDOW[_contest_level(_nearest_defender_dist(_user))] * float(scenario.get("shot_bonus", 1.0))  # Hot Hand from the season week
	var kind: String = _shot_type(_user.flat())
	var type_mult: float = {"rim": 1.35, "mid": 1.0, "three": 0.85}[kind]
	_zone_w = clampf(float(tuning["zone"]) * 1.5 * open_mult * type_mult, 0.08, 0.42) * window_scale
	_meter.visible = true
	# The clip's release point (top of the jump, 1.0 s in) is lined up with
	# the middle of the meter, so a well-timed release is the real release.
	_user.action("JumpShot", 1.0, clampf(SHOT_RELEASE_AT - METER_CENTER / _meter_speed, 0.1, 0.6))
	if auto_play:
		var target: float = METER_CENTER
		match auto_quality:
			"good":
				target = METER_CENTER + _zone_w * 0.4
			"miss":
				target = METER_CENTER - _zone_w * 2.0
		get_tree().create_timer(maxf(0.05, target / _meter_speed), true, true).timeout.connect(func() -> void:
			if _charging:
				_release_shot())


func _release_shot() -> void:
	if not _charging:
		return
	_charging = false
	_meter.visible = false
	var quality: String = _grade(_meter_pos)
	var level: int = _contest_level(_nearest_defender_dist(_user))
	var kind: String = _shot_type(_user.flat())
	# 2K's rule: release inside the window and it goes in. Just outside it
	# ("white") falls back to real-life percentages for that look; a bad
	# release misses. The contest already narrowed the window.
	var p: float = 0.0
	if quality in ["perfect", "good"]:
		p = 1.0
	elif quality == "near":
		p = (REAL_3P if kind == "three" else REAL_2P)[level]
	if auto_play:
		p = 1.0 if quality in ["perfect", "good"] else 0.0
	_take_shot(_user, _rng.randf() < p, kind, false, maxf(0.0, METER_CENTER / _meter_speed - _charge_t))
	var grade_text: String = {"perfect": "Perfect release", "good": "Good release", "near": "Slightly off", "miss": "Bad timing"}[quality]
	_sub_banner.text = grade_text + "  ·  " + CONTEST_NAMES[level]
	_sub_banner.modulate.a = 1.0


## NBA tracking buckets by closest defender: very tight under 2 ft, tight
## 2-4 ft, open 4-6 ft, wide open 6 ft and beyond.
func _contest_level(dist: float) -> int:
	if dist < 0.61:
		return 0
	if dist < 1.22:
		return 1
	if dist < 1.83:
		return 2
	return 3


func _grade(p: float) -> String:
	var half: float = _zone_w / 2.0
	var d: float = absf(p - METER_CENTER)
	if d <= half * PERFECT_FRACTION:
		return "perfect"
	if d <= half:
		return "good"
	if d <= half * 1.6:
		return "near"
	return "miss"


func _in_layup_range() -> bool:
	var dist: float = _user.flat().distance_to(HOOP_FLAT)
	if dist < LAYUP_RANGE:
		return true
	var to_hoop: Vector3 = (HOOP_FLAT - _user.flat()).normalized()
	return dist < DRIVE_RANGE and _user.vel.dot(to_hoop) > 2.4


## A layup carries the momentum he has. He keeps running at the rim until
## he is one jump away, then takes off; how far that jump travels depends on
## how fast he was going (a standing layup goes almost straight up, a full
## drive covers close to two metres). He finishes on the side he came from,
## and the stick can shade the finish to either side.
func _begin_layup() -> void:
	_layup = true
	_layup_t = 0.0
	_layup_air = false
	_layup_drive_t = 0.0
	_reach.clear()
	var away: Vector3 = _user.flat() - HOOP_FLAT
	if away.length() < 0.3:
		away = Vector3(0, 0, 1)
	away = away.normalized()
	var finish: Vector3 = HOOP_FLAT + away * 0.75
	var stick: Vector2 = Vector2.ZERO if auto_play else _input_vector()
	var lateral: Vector3 = Vector3(-away.z, 0, away.x)
	finish += lateral * clampf(Vector3(stick.x, 0, stick.y).dot(lateral), -1.0, 1.0) * 0.45
	_layup_to = finish
	_layup_speed = maxf(Vector2(_user.vel.x, _user.vel.z).length(), 2.0)
	_layup_dunk = _nearest_defender_dist(_user) > 1.83 and (_sprinting() or auto_play)


## Distance the jump itself covers, from the speed he arrives with.
func _layup_jump_length() -> float:
	return clampf(_layup_speed * LAYUP_TIME * 0.8, 0.45, 1.9)


func _tick_layup(delta: float) -> void:
	var to_finish: Vector3 = _layup_to - _user.flat()
	if not _layup_air:
		# Still on the floor: drive at the rim until one jump away.
		_layup_drive_t += delta
		if to_finish.length() > _layup_jump_length() and _layup_drive_t < 1.2:
			var speed: float = maxf(_layup_speed, 4.0)
			_user.move_with(to_finish.normalized() * speed, delta, 22.0)
			_layup_speed = maxf(_layup_speed, Vector2(_user.vel.x, _user.vel.z).length())
			return
		_layup_air = true
		_layup_t = 0.0
		_layup_from = _user.flat()
		_gather_from = _ball.position
		_user.action("Layup", 1.0, 0.5)  # the clip's takeoff; its peak lands on the release
	_layup_t += delta
	var k: float = clampf(_layup_t / LAYUP_TIME, 0.0, 1.0)
	var p: Vector3 = _layup_from.lerp(_layup_to, k)  # in the air he travels at a steady speed
	_user.vel = (_layup_to - _layup_from) / LAYUP_TIME
	_user.position.x = p.x
	_user.position.z = p.z
	if _user.flat().distance_to(HOOP_FLAT) > 0.3:
		_user.face_point(HOOP_FLAT)
	if _layup_t >= LAYUP_TIME:
		_user.vel = Vector3.ZERO
		_finish_layup()


func _finish_layup() -> void:
	_layup = false
	var near: Actor = _nearest_defender(_user)
	var dist: float = near.flat().distance_to(_user.flat()) if near != null else 9.0
	var skill: float = GameState.get_stat("basketball_skill") / 100.0
	var level: int = _contest_level(dist)
	var base: float = REAL_LAYUP[level]
	var tag: String = CONTEST_NAMES[level]
	if _layup_dunk:
		base = 0.96
	base = clampf(base + (skill - 0.5) * 0.2, 0.1, 0.97)
	# A body right on you, especially their big, can send it back.
	var block_p: float = (0.3 if near.is_big else 0.16) * float(_opp.get("aggr", 1.0)) if near != null and level == 0 else 0.0
	if not auto_play and _rng.randf() < block_p:
		_stats["fga"] = int(_stats["fga"]) + 1
		near.face_point(_user.position)
		_defender_jump(near, 0.62)
		var back: Vector3 = (_user.flat() - HOOP_FLAT).normalized()
		_ball.position = _user.position + Vector3(0, 2.7, 0)
		_make_loose(back * 4.0 + Vector3(_rng.randf_range(-1.5, 1.5), 2.0, 0), 1)
		_last_handler_user = true
		_show_toast("Blocked! Loose ball")
		return
	var made: bool = _rng.randf() < base
	if auto_play:
		made = auto_quality != "miss"
	_shot_line = ("Slam! +2" if _layup_dunk else "Layup! +2") if made else ""
	_take_shot(_user, made, "rim", true)
	_sub_banner.text = ("Dunk" if _layup_dunk else "Layup") + "  ·  " + tag
	_sub_banner.modulate.a = 1.0


## Get your hip past his and he's beaten: he can only chase. A hard cut
## against the grain (stick pulled back across your momentum) can shake him.
func _check_blowby(_delta: float) -> void:
	var d: Actor = _defender_of(_user)
	if d == null:
		return
	var u: Vector3 = _user.flat()
	var to_hoop: Vector3 = (HOOP_FLAT - u).normalized()
	var lat_axis: Vector3 = Vector3(-to_hoop.z, 0, to_hoop.x)
	var rel: Vector3 = d.flat() - u
	var ahead: float = rel.dot(to_hoop)
	var lat: float = absf(rel.dot(lat_axis))
	var drive: float = _user.vel.dot(to_hoop)
	if d.beaten <= 0.0 and drive > 2.4 and ahead < 0.3 and lat > 0.4 and rel.length() < 2.4 \
			and u.distance_to(HOOP_FLAT) < 10.5:
		d.beaten = 1.2
		_audio.play("squeak", -12.0, 0.12)
		_show_toast("Blew by him. Get to the rim!")
	elif d.beaten > 0.0 and ahead < 0.0:
		d.beaten = maxf(d.beaten, 0.3)  # stays beaten while he's behind you
	if auto_play or _shake_cd > 0.0 or d.stagger > 0.0 or rel.length() > 1.9:
		return
	var v: Vector3 = Vector3(_user.vel.x, 0, _user.vel.z)
	var iv: Vector2 = _input_vector()
	if v.length() < 2.8 or iv.length() < 0.6:
		return
	if Vector3(iv.x, 0, iv.y).normalized().dot(v.normalized()) < -0.2:
		_shake_cd = 1.4
		_audio.play("squeak", -10.0, 0.12)  # hard cut on the hardwood
		_cross_from = _ball_side
		_ball_side = -_ball_side
		_cross_t = 0.0
		var skill: float = GameState.get_stat("basketball_skill") / 100.0
		if _rng.randf() < (0.35 + skill * 0.3) / float(_opp.get("aggr", 1.0)):
			d.stagger = 0.45
			d.stop()
			_show_toast("Shook him!")


func _shot_type(p: Vector3) -> String:
	var dist: float = p.distance_to(HOOP_FLAT)
	if dist < 2.4:
		return "rim"
	if absf(p.x) >= CORNER_X and p.z < HOOP.z + 1.41:
		return "three"
	return "three" if dist >= ARC_R else "mid"


## A defender's two-foot jump (contest, block, pick-off) uses the legs and hips
## of the recorded CMU jump shot. The library "Jump" (Jump_Start) expects the
## engine to lift the body; the court never does, so its legs tucked up under
## hips that stayed at standing height and the defender looked like he sank to
## the floor (tests/leg_trace: knees 130 deg, feet 0.49 m up, hips unchanged).
## JumpShot dips at 0.60 s, leaves the floor at ~0.70 s, peaks at 1.00 s and
## lands at ~1.35 s. Arms stay with the contest IK (docs/animation/OWNERSHIP.md).
const DEFENDER_JUMP_START: float = 0.55
## Height of the ball at a jump shot's release (the contest palms face it).
const CONTEST_PALM_AT_Y: float = 2.4
const DEFENDER_JUMP_SPEED: float = 1.2


func _defender_jump(d: Actor, start: float = DEFENDER_JUMP_START) -> void:
	d.action("JumpShot", DEFENDER_JUMP_SPEED, start)


func _take_shot(shooter: Actor, made: bool, kind: String, layup: bool = false, delay: float = 0.0) -> void:
	_shooter = shooter
	_shot_assisted = shooter == _last_pass_to and _time - _last_pass_by_user_t < 3.5
	_last_pass_to = null
	_shot_made = made
	_shot_points = 3 if kind == "three" else 2
	_follow_t = 0.55
	if shooter == _user:
		_stats["fga"] = int(_stats["fga"]) + 1
		if kind == "three":
			_stats["tpa"] = int(_stats["tpa"]) + 1
	shooter.face_point(HOOP_FLAT)
	if not shooter.busy():
		shooter.action("JumpShot", 1.0, 0.75)
		delay = maxf(delay, SHOT_RELEASE_AT - 0.75)
	# The closest defender leaps to contest.
	var nd: Actor = _nearest_defender(shooter)
	if nd != null and nd.flat().distance_to(shooter.flat()) < 1.7:
		nd.face_point(shooter.position)
		_defender_jump(nd)
	# The ball stays in his hand until the clip reaches its release point.
	_shot_layup = layup
	_holder = null
	if delay > 0.0:
		_ball_mode = "windup"
		_shot_wait = delay
		_set_phase(Phase.SHOT, 0.0)
		return
	_launch_shot()


func _launch_shot() -> void:
	var shooter: Actor = _shooter
	var made: bool = _shot_made
	var layup: bool = _shot_layup
	_ball_mode = "shot"
	_flight_from = shooter.hand_position("R") + Vector3(0, 0.12, 0)
	_flight_to = HOOP
	if not made:
		var side: Vector3 = (HOOP_FLAT - shooter.flat()).normalized().cross(Vector3.UP)
		_flight_to = HOOP + side * (0.3 if _rng.randf() < 0.5 else -0.3) + Vector3(0, 0.08, 0)
	if layup:
		_flight_from = _ball.position
		if not made:
			_flight_to = HOOP + (shooter.flat() - HOOP_FLAT).normalized() * 0.25 + Vector3(0, 0.1, 0)
	# The shot is a real projectile. Players launch at roughly 52 degrees
	# close in and 46 from deep (a layup goes up softer and steeper); that
	# angle and gravity fix how long the ball is in the air and how high it goes.
	var reach: float = Vector2(_flight_to.x - _flight_from.x, _flight_to.z - _flight_from.z).length()
	var rise: float = _flight_to.y - _flight_from.y
	var angle: float = deg_to_rad(62.0 if layup else lerpf(54.0, 46.0, clampf(reach / 8.0, 0.0, 1.0)))
	_flight_dur = sqrt(maxf(0.04, 2.0 * (reach * tan(angle) - rise) / SHOT_GRAVITY))
	_flight_vy = (rise + 0.5 * SHOT_GRAVITY * _flight_dur * _flight_dur) / _flight_dur
	_flight_t = 0.0
	_set_phase(Phase.SHOT, 0.0)


func _tick_shot(delta: float) -> void:
	if _ball_mode == "windup":
		_shot_wait -= delta
		if _shot_wait <= 0.0:
			_launch_shot()
		return
	_flight_t += delta / _flight_dur
	if _flight_t < 1.0:
		return
	_ball_mode = "dead"
	var shot_line: String = _shot_line
	_shot_line = ""
	_audio.play("swish" if _shot_made else "rim", -3.0)
	if _shot_made:
		_audio.play("cheer", -3.0 if _shooter == _user else -10.0, 0.03)
	var by_user: bool = _shooter == _user
	if _shot_made:
		_team_score += _shot_points
		var assisted: bool = _shot_assisted
		if by_user:
			_stats["fgm"] = int(_stats["fgm"]) + 1
			_stats["pts"] = int(_stats["pts"]) + _shot_points
			if _shot_points == 3:
				_stats["tpm"] = int(_stats["tpm"]) + 1
		elif assisted:
			_stats["ast"] = int(_stats["ast"]) + 1
		_refresh_scoreboard()
		var line: String
		if by_user and shot_line != "":
			line = shot_line
		elif by_user:
			line = "Splash! +3" if _shot_points == 3 else "Bucket! +2"
		elif assisted:
			line = "Assist! +%d" % _shot_points
		else:
			line = "Teammate scores +%d" % _shot_points
		_show_banner(line, _sub_banner.text if by_user else "", 1.2)
		_end_pick()
		_set_phase(Phase.DEAD, 1.3)
		if by_user:
			_user.action("Clap", 1.6)
		return
	if _clock <= 0.0:
		_end_possession("Buzzer", "")
		return
	_begin_rebound()


func _begin_rebound() -> void:
	_holder = null
	_end_pick()
	_reach.clear()
	_board_jumps.clear()
	_ball.position = _flight_to
	var direction := Vector3(_flight_to.x - HOOP.x, 0, absf(_flight_to.z - HOOP.z) + 0.18).normalized()
	_loose_vel = direction * _rng.randf_range(1.9, 3.1) + Vector3.UP * 1.65
	_ball_mode = "rebound"
	_shoot_button.text = "BOARD"
	_set_phase(Phase.REBOUND, 0.0)


func _board_jump(a: Actor) -> void:
	if not _board_jumps.has(a):
		_board_jumps[a] = 0.0


func _tick_rebound(delta: float) -> void:
	_clock = maxf(0.0, _clock - delta * CLOCK_FACTOR)
	_refresh_scoreboard()
	if _holder == null:
		_loose_vel.y -= SHOT_GRAVITY * delta
		_ball.position += _loose_vel * delta
		if _ball.position.y <= BALL_FLOOR:
			_ball.position.y = BALL_FLOOR
			_loose_vel.y = absf(_loose_vel.y) * 0.55
			_loose_vel.x *= 0.74
			_loose_vel.z *= 0.74
	var ball_flat := Vector3(_ball.position.x, 0.0, _ball.position.z)
	var target := ball_flat + Vector3(_loose_vel.x, 0, _loose_vel.z) * 0.18
	var pursuers := _chasers(_offense, 2) + _chasers(_defense, 2)
	for a: Actor in _all:
		if _holder != null or _board_jumps.has(a):
			a.move_with(Vector3.ZERO, delta)
		elif a == _user and not auto_play:
			_move_user(delta)
		elif a in pursuers or a == _user:
			a.step_toward(target, MATE_SPEED, delta)
			if a.flat().distance_to(target) < 0.85 and _ball.position.y < 2.95 and _ball.position.y > 1.5 and _loose_vel.y < 0:
				_board_jump(a)
		else:
			a.move_with(Vector3.ZERO, delta)
		if _holder == null:
			a.turn_toward(ball_flat, delta)
	_separate()
	_clamp_all()
	for a: Actor in _board_jumps.keys():
		var progress := minf(1.0, (float(_board_jumps[a]) + delta) / BOARD_JUMP_TIME)
		a.position.y = 0.54 * 4.0 * progress * (1.0 - progress)
		_board_jumps[a] = progress * BOARD_JUMP_TIME
		if progress >= 1.0:
			_board_jumps.erase(a)
	if _holder == null:
		var winner: Actor = null
		var nearest := INF
		for a: Actor in _all:
			var shoulder := a.shoulder_position("R").lerp(a.shoulder_position("L"), 0.5)
			var distance := shoulder.distance_to(_ball.position)
			var ground_pickup := _ball.position.y < 0.85 and a.flat().distance_to(ball_flat) < 0.52
			if ground_pickup:
				distance = a.flat().distance_to(ball_flat)
			if distance < nearest and (ground_pickup or (_board_jumps.has(a) and distance <= a.arm_length("R") + BALL_FLOOR)):
				nearest = distance
				winner = a
		if winner != null:
			_holder = winner
			_start_secure(winner)
			if winner == _user:
				_stats["reb"] += 1
			_audio.play("catch", -8.0)
	if _holder != null and _board_jumps.is_empty() and _recovery_t >= 0.24:
		_shoot_button.text = "SHOOT"
		if _clock <= 0:
			_end_possession("Buzzer", "")
		elif _holder.team == 0:
			_give_ball(_holder)
			_shot_clock = 10.0
			_catch_grace = 0.6
			_last_pass_to = null
			_set_phase(Phase.LIVE, 0.0)
			_show_toast("Offensive rebound")
		else:
			_end_possession("Defensive rebound", str(_opp.get("name", "Opponents")) + " ball")
			_ball_mode = "secured"


# =============================================================================
# Passing and the AI ball handler
# =============================================================================

func _throw_pass(from: Actor, to: Actor) -> void:
	_ball_mode = "pass"
	_pass_from = from
	_pass_target = to
	_holder = null
	_reach.clear()
	_pass_checked.clear()
	_pass_pose_t = 0.22
	_flight_from = _ball.position
	_flight_dur = 0.16 + from.flat().distance_to(to.flat()) / 17.0
	_flight_t = 0.0
	from.face_point(to.position)
	from.action("Pass", 1.8)


func _tick_pass(delta: float) -> void:
	_flight_t += delta / _flight_dur
	var catch_pt: Vector3 = _pass_target.body_point(0.35, 0.0, 1.2)
	var p: Vector3 = _flight_from.lerp(catch_pt, clampf(_flight_t, 0.0, 1.0))
	p.y += sin(clampf(_flight_t, 0.0, 1.0) * PI) * 0.25
	_ball.position = p
	for d: Actor in _defense:
		if d in _pass_checked:
			continue
		if Vector2(d.position.x - p.x, d.position.z - p.z).length() < 0.6:
			_pass_checked.append(d)
			if _rng.randf() < 0.3 * float(_opp.get("aggr", 1.0)):
				_defender_jump(d, 0.62)
				_turnover("Picked off!", _pass_from == _user, true)
				return
	if _flight_t >= 1.0:
		_give_ball(_pass_target)
		if _pass_from == _user:
			_last_pass_to = _pass_target
			_last_pass_by_user_t = _time
		_catch_grace = 0.5
		_audio.play("catch", -9.0)


func _ai_holder(delta: float) -> void:
	var h: Actor = _holder
	_ai_decide -= delta
	if _ai_decide > 0.0:
		return
	_ai_decide = 0.4
	var open: float = _nearest_defender_dist(h)
	var dist: float = h.flat().distance_to(HOOP_FLAT)
	var user_open: float = _nearest_defender_dist(_user)
	if dist < 2.6 and open > 1.0:
		_ai_shoot(h)  # roller with a lane finishes
	elif minf(_clock, _shot_clock) < 3.0 or (open >= 1.83 and dist <= 8.2):
		_ai_shoot(h)
	elif user_open > 1.3 or _hold_time > 1.5:
		_throw_pass(h, _user)
	elif _rng.randf() < 0.4:
		var best: Actor = null
		var best_open: float = 0.0
		for m: Actor in _mates:
			if m == h:
				continue
			var o: float = _nearest_defender_dist(m)
			if o > best_open:
				best_open = o
				best = m
		if best != null:
			_throw_pass(h, best)


func _ai_shoot(h: Actor) -> void:
	var kind: String = _shot_type(h.flat())
	var d: float = _nearest_defender_dist(h)
	var contest: float = 0.62 if d < 0.9 else (0.82 if d < 1.7 else 1.05)
	var type_mult: float = {"rim": 1.25, "mid": 1.0, "three": 0.8}[kind]
	var p: float = clampf((0.3 + float(_team.get("off", 55)) / 250.0) * contest * type_mult, 0.1, 0.8)
	_take_shot(h, _rng.randf() < p, kind)


# =============================================================================
# Ball security: crossovers, swipes, loose balls
# =============================================================================

func _update_crossover(delta: float) -> void:
	if _cross_t >= 0.0:
		_cross_t += delta / 0.24
		if _cross_t >= 1.0:
			_cross_t = -1.0
		return
	var d: Actor = _on_ball_defender()
	if d == null or _cross_cd > 0.0 or _charging:
		return
	var lateral: float = (d.flat() - _holder.flat()).dot(_holder.right())
	if signf(lateral) == _ball_side and absf(lateral) > 0.15 and d.flat().distance_to(_holder.flat()) < 2.0:
		_cross_from = _ball_side
		_ball_side = -_ball_side
		_cross_t = 0.0
		_cross_cd = 0.8


func _tick_reach(delta: float) -> void:
	if _reach.is_empty():
		if _ball_mode != "held" or _holder == null or _catch_grace > 0.0:
			return
		var d: Actor = _on_ball_defender()
		if d == null or d.reach_cd > 0.0 or d.stagger > 0.0:
			return
		if d.flat().distance_to(_holder.flat()) > 1.35:
			return
		if _rng.randf() < 0.55 * float(_opp.get("aggr", 1.0)) * delta:
			_start_reach(d)
		return
	var r: Dictionary = _reach
	var rd: Actor = r["d"]
	r["t"] = float(r["t"]) + delta
	if float(r["t"]) >= SWIPE_HIT_T - 0.05 and not r.has("odds") and _ball_mode == "held":
		r["odds"] = _poke_odds(rd)  # frozen as the hand arrives: animation and resolve agree
	if not bool(r["resolved"]) and float(r["t"]) >= SWIPE_HIT_T:
		r["resolved"] = true
		_resolve_reach(rd)
	if float(r["t"]) >= REACH_TIME:
		rd.reach_cd = _rng.randf_range(1.4, 2.6)
		_reach.clear()


## Start a swipe by `d` at the ball. The outcome's dice are rolled now, not
## when the hand arrives, so the animation can show it honestly: a swipe that
## will knock the ball loose meets it with the palm; one that won't is short
## (the handler kept it away) and pulls back, so no hand touches the ball
## without an effect. Used by the game, tests/swipe_pose_checks.gd and the lab.
func _start_reach(d: Actor) -> void:
	var side: String = "R" if (_ball.position - d.position).dot(d.right()) > 0.0 else "L"
	_reach = {"d": d, "t": 0.0, "side": side, "resolved": false, "roll": _rng.randf(),
		"b_pred": _holder.predict_ball(SWIPE_HIT_T, BALL_FLOOR) if _holder != null else _ball.position}
	d.action("SwipeCMU_R" if side == "R" else "SwipeCMU_L", 1.0)


## Can `d`'s palm get to the ball, and the chance a swipe that does knocks it
## loose. Shared by the resolve and the animation so they always agree.
func _poke_odds(d: Actor) -> Dictionary:
	var h: Actor = _holder
	if h == null:
		return {"reach_ok": false, "p": 0.0}
	var to_d: Vector3 = d.flat() - h.flat()
	var ball_off: Vector3 = Vector3(_ball.position.x, 0, _ball.position.z) - h.flat()
	# The hand has to get to the ball: shoulder to ball, in 3D, against the
	# arm's measured length. A palm at the edge of its reach rarely dislodges
	# it; a hand that gets well onto the ball does.
	var margin: float = d.reach_margin(_ball.position, BALL_FLOOR)
	# Full strength once the palm is 8 cm inside its reach (a whole hand on the
	# ball). The old 25 cm scale belonged to the old, fingertip-and-lean reach.
	var contact: float = clampf(margin / 0.08, 0.0, 1.0)
	var exposed: float = 1.0 if ball_off.dot(to_d) > 0.05 else 0.28
	if _cross_t >= 0.0:
		exposed = 0.7  # caught mid-crossover
	var skill: float = GameState.get_stat("basketball_skill") / 100.0 if h == _user else 0.45
	return {"reach_ok": margin > 0.0,
		"p": 0.42 * exposed * float(_opp.get("aggr", 1.0)) * (1.1 - skill * 0.6) * contact}


## Before the swipe resolves: will this one knock it loose? (After, the ball
## being loose says.) Without dice (a staged test) it is assumed to connect.
func _swipe_connects(d: Actor) -> bool:
	if bool(_reach.get("resolved", false)):
		return _ball_mode == "loose"
	if not _reach.has("roll"):
		return true
	var o: Dictionary = _reach.get("odds", _poke_odds(d))
	return bool(o["reach_ok"]) and float(_reach["roll"]) < float(o["p"])


func _resolve_reach(d: Actor) -> void:
	if _ball_mode != "held" or _holder == null:
		return
	if not _reach.is_empty():
		_reach["ball_at"] = _ball.position  # where the palm meets it
	var h: Actor = _holder
	var to_d: Vector3 = d.flat() - h.flat()
	var o: Dictionary = _reach.get("odds", _poke_odds(d))
	var reach_ok: bool = o["reach_ok"]
	var p: float = o["p"]
	var roll: float = float(_reach.get("roll", _rng.randf()))
	if reach_ok and roll < p:
		var away: Vector3 = to_d.normalized() if _rng.randf() < 0.6 else \
			Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
		_make_loose(away * _rng.randf_range(2.5, 4.0) + Vector3(0, 2.2, 0), 1)
		_audio.play("catch", -5.0)  # hand on the ball
		_show_toast("Poked loose!")
	elif _rng.randf() < 0.12:
		d.reach_cd = 3.0
		_shot_clock = maxf(_shot_clock, 14.0)
		_show_toast("Reach-in foul on %s" % str(_opp.get("short", "them")))
		_audio.play("whistle", -6.0, 0.0)
		_catch_grace = 1.0
	else:
		d.stagger = 0.65  # bit on it; go by him
		if h == _user:
			_show_toast("He bit. Go!")


func _make_loose(v: Vector3, touched_by: int) -> void:
	_ball_mode = "loose"
	_holder = null
	_loose_vel = v
	_loose_t = 0.0
	_last_touch_team = touched_by
	_charging = false
	_layup = false
	_meter.visible = false


func _tick_loose_pickup(delta: float) -> void:
	_loose_t += delta
	var bp: Vector3 = Vector3(_ball.position.x, 0, _ball.position.z)
	if absf(bp.x) > HALF_W or bp.z < -BASELINE or bp.z > BASELINE:
		if _last_touch_team == 1:
			_show_banner("Out off %s" % str(_opp.get("short", "them")), "NVS ball", 1.0)
			_ball_mode = "dead"
			_set_phase(Phase.OPP, 1.1)  # quick inbound, our ball again
		else:
			_audio.play("whistle", -6.0, 0.0)
			_turnover("Out of bounds", _last_handler_user)
		return
	if _loose_t < 0.15 or _ball.position.y > 1.5:
		return
	var best: Actor = null
	var best_d: float = 0.65
	for a: Actor in _all:
		var dd: float = a.flat().distance_to(bp)
		if dd < best_d:
			best_d = dd
			best = a
	if best == null and _loose_t > 4.0:
		best = _nearest_to(bp, _all)
	if best == null:
		return
	if best.team == 0:
		_give_ball(best)
		_catch_grace = 0.7
		_show_toast("Recovered!")
	else:
		_turnover("Stolen!", _last_handler_user, true)
		_holder = best
		_last_touch_team = best.team
		_start_secure(best)
		best.release_swipe()


# =============================================================================
# Teammates: spacing, cuts, screens
# =============================================================================

func _move_mates(delta: float) -> void:
	_spacing_t -= delta
	if _spacing_t <= 0.0:
		_spacing_t = 0.5
		_assign_spacing()
	var loose_chasers: Array = _chasers(_mates + [_user], 2) if _ball_mode == "loose" else []
	for m: Actor in _mates:
		if m == _holder:
			m.move_with(Vector3.ZERO, delta)
			continue
		if m in loose_chasers:
			m.step_toward(_ball.position, 4.6, delta)
			continue
		if m.role in ["screen_come", "screen_set", "roll", "pop"]:
			_tick_screener(m, delta)
			continue
		if m.role == "cut":
			m.role_time += delta
			m.step_toward(m.role_target, 4.3, delta)
			if m.role_time > 1.5:
				m.role = "space"
			continue
		# Spacing: hold the spot with a little life; cut backdoor if denied.
		m.wander_timer -= delta
		if m.wander_timer <= 0.0:
			m.wander_timer = _rng.randf_range(1.0, 1.8)
			m.wander_target = m.spot + Vector3(_rng.randf_range(-0.5, 0.5), 0, _rng.randf_range(-0.4, 0.4))
			var d: Actor = _defender_of(m)
			var ball_flat: Vector3 = Vector3(_ball.position.x, 0, _ball.position.z)
			if d != null and _phase == Phase.LIVE and d.flat().distance_to(m.flat()) < 1.6 \
					and d.flat().distance_to(ball_flat) < m.flat().distance_to(ball_flat) - 0.3 \
					and _rng.randf() < 0.3:
				m.role = "cut"
				m.role_time = 0.0
				m.role_target = Vector3(signf(m.spot.x) * 0.9 if m.spot.x != 0.0 else 0.9, 0, -11.3)
		m.step_toward(m.wander_target, MATE_SPEED, delta)


## Fill perimeter spots away from the ball. Recomputed twice a second, so
## when you drive at a teammate he drifts to the corner or lifts.
func _assign_spacing() -> void:
	var handler: Actor = _holder if _holder != null else _user
	var free: Array[Vector3] = []
	for s: Vector3 in SPOTS:
		if s.distance_to(handler.flat()) > 3.2:
			free.append(s)
	for m: Actor in _mates:
		if m == _holder or m.role != "space" or free.is_empty():
			continue
		var best_i: int = 0
		var best: float = INF
		for i in free.size():
			var dd: float = free[i].distance_to(m.flat())
			if dd < best:
				best = dd
				best_i = i
		m.spot = free[best_i]
		free.remove_at(best_i)


# =============================================================================
# Defense
# =============================================================================

func _move_defense(delta: float) -> void:
	var coverage_scale: float = {"Easy": 0.85, "Medium": 1.0, "Hard": 1.10, "Ultimate": 1.20}[GameState.court_difficulty]
	var spd: float = float(_opp.get("speed", 1.0)) * coverage_scale
	var ball_flat: Vector3 = Vector3(_ball.position.x, 0, _ball.position.z)
	var holder: Actor = _holder
	var screener: Actor = _screener()
	var cover: String = str(_opp.get("pnr", "drop"))
	var loose_chasers: Array = _chasers(_defense, 2) if _ball_mode == "loose" else []
	# One helper steps in when the ball gets to the paint (or the roller rolls).
	var helper: Actor = null
	var threat: Actor = null
	if holder != null and holder.flat().distance_to(HOOP_FLAT) < 4.4:
		threat = holder
	elif screener != null and screener.role == "roll" and screener.flat().distance_to(HOOP_FLAT) < 4.5:
		threat = screener
	if threat != null:
		var best: float = INF
		for d: Actor in _defense:
			if d.man == threat or d.man == holder:
				continue
			var dd: float = d.flat().distance_to(HOOP_FLAT)
			if dd < best:
				best = dd
				helper = d
	for d: Actor in _defense:
		var m: Actor = d.man
		d.track = d.track.lerp(m.flat(), 1.0 - exp(-(7.0 if m == holder else 5.0) * spd * delta))
		var target: Vector3
		var speed: float = 3.45 * spd
		if d in loose_chasers:
			target = ball_flat
			speed = 4.5 * spd
		elif d.protect_rim and _possession_kind == "break" and _break_timer < 4.0:
			target = HOOP_FLAT + (ball_flat - HOOP_FLAT).normalized() * 2.2
			speed = 3.8 * spd
		elif d == helper:
			target = HOOP_FLAT + (threat.flat() - HOOP_FLAT).normalized() * 1.5
			speed = 4.0 * spd
		elif screener != null and m == screener and not _switched and screener.role in ["screen_come", "screen_set"]:
			if cover == "hedge" and screener.role == "screen_set":
				# Step out in front of the ball handler.
				target = _user.flat() + _pick_lat * _pick_sign * 1.0 + (HOOP_FLAT - _user.flat()).normalized() * 0.9
				speed = 4.2 * spd
			elif cover == "drop":
				target = HOOP_FLAT + (_user.flat() - HOOP_FLAT).normalized() * 3.4
			else:
				target = m.flat() + (HOOP_FLAT - m.flat()).normalized() * 1.0
		elif m == holder and d.beaten > 0.0:
			# Beaten: trail on the hip and try to recover, can't cut him off.
			var drive_dir: Vector3 = (HOOP_FLAT - m.flat()).normalized()
			var lat_axis: Vector3 = Vector3(-drive_dir.z, 0, drive_dir.x)
			var side: float = 1.0 if (d.flat() - m.flat()).dot(lat_axis) >= 0.0 else -1.0
			target = m.flat() - drive_dir * 0.7 + lat_axis * side * 0.55
			speed = 3.9 * spd
		elif m == holder and _reach.get("d", null) == d and float(_reach["t"]) < SWIPE_STEP_T:
			# The swipe is a jab step: he steps at the ball, then recovers.
			var from_ball: Vector3 = d.flat() - ball_flat
			from_ball = from_ball.normalized() if from_ball.length() > 0.01 else -d.facing()
			target = ball_flat + from_ball * SWIPE_STEP_TO_M
			speed = 5.0 * spd
		elif m == holder:
			var gap: float = 1.35 - 0.25 * float(_opp.get("aggr", 1.0))
			speed = 3.8 * spd
			if _charging and m == _user and _charge_t > 0.16:
				gap = 0.55  # close out on the shooter
				speed = 4.5 * spd
			target = d.track + (HOOP_FLAT - d.track).normalized() * gap
		else:
			var sag: Vector3 = (HOOP_FLAT - d.track).normalized() * 1.7
			var lean: Vector3 = (ball_flat - d.track).normalized() * 0.8
			target = d.track + sag + lean
			if cover == "drop" and screener != null and m == screener and screener.role == "pop":
				speed = 3.0 * spd  # late recovering to the popper
		if d.flat().distance_to(target) > 4.0:
			speed *= 1.15
		_screen_check(d, target)
		d.step_toward(target, speed, delta, 18.0)


## A defender trying to go through a set screen runs into it: slowed and
## knocked off line, which is the window a pick creates.
func _screen_check(d: Actor, target: Vector3) -> void:
	for m: Actor in _mates:
		if m.role != "screen_set" or d.man == m:
			continue
		var to_s: Vector3 = m.flat() - d.flat()
		var to_t: Vector3 = target - d.flat()
		if to_s.length() < 0.95 and to_t.length() > 0.3 and to_s.normalized().dot(to_t.normalized()) > 0.2:
			var last: float = float(_screen_hits.get(d, -10.0))
			if _time - last > 1.2:
				_screen_hits[d] = _time
				d.stagger = 0.55
				_audio.play("squeak", -12.0, 0.12)
				d.stop()
				if d.man == _user:
					_show_toast("Screen! You've got a step")


func _idle_actors(delta: float) -> void:
	for a: Actor in _all:
		a.move_with(Vector3.ZERO, delta, 20.0)


## Bodies don't overlap. Running into a defender is a bump: you lose speed
## and slide off his chest; he holds his ground. A set screener doesn't move.
func _separate() -> void:
	for i in _all.size():
		for j in range(i + 1, _all.size()):
			var a: Actor = _all[i]
			var b: Actor = _all[j]
			var off: Vector3 = Vector3(b.position.x - a.position.x, 0, b.position.z - a.position.z)
			var d: float = off.length()
			if d >= 0.72 or d < 0.001:
				continue
			var n: Vector3 = off / d
			var push: Vector3 = n * (0.72 - d)
			var wa: float = 0.5
			if _layup and a == _user:
				wa = 0.1  # he's in the air going up; bodies give way
			elif _layup and b == _user:
				wa = 0.9
			elif a.role == "screen_set":
				wa = 0.05
			elif b.role == "screen_set":
				wa = 0.95
			elif a.team == 0 and b.team == 1 and a == _holder:
				wa = 0.85
			elif b.team == 0 and a.team == 1 and b == _holder:
				wa = 0.15
			a.position -= push * wa
			b.position += push * (1.0 - wa)
			# Take away the velocity that drives into the other body.
			var into_a: float = a.vel.dot(n)
			if into_a > 0.0:
				a.vel -= n * into_a * 0.9
			var into_b: float = b.vel.dot(-n)
			if into_b > 0.0:
				b.vel += n * into_b * 0.9


func _clamp_all() -> void:
	for a: Actor in _all:
		a.position.x = clampf(a.position.x, -HALF_W + 0.3, HALF_W - 0.3)
		a.position.z = clampf(a.position.z, -BASELINE + 0.4, BASELINE - 0.4)


func _defender_of(o: Actor) -> Actor:
	for d: Actor in _defense:
		if d.man == o:
			return d
	return null


func _on_ball_defender() -> Actor:
	return _defender_of(_holder) if _holder != null else null


func _nearest_defender(o: Actor) -> Actor:
	return _nearest_to(o.flat(), _defense)


func _nearest_to(p: Vector3, group: Array) -> Actor:
	var best: Actor = null
	var best_d: float = INF
	for a: Actor in group:
		var dd: float = a.flat().distance_to(p)
		if dd < best_d:
			best_d = dd
			best = a
	return best


func _nearest_defender_dist(o: Actor) -> float:
	var nd: Actor = _nearest_defender(o)
	return nd.flat().distance_to(o.flat()) if nd != null else INF


func _openness(o: Actor) -> float:
	return clampf(_nearest_defender_dist(o), 0.0, 4.0)


func _chasers(group: Array, count: int) -> Array:
	var bp: Vector3 = Vector3(_ball.position.x, 0, _ball.position.z)
	var sorted: Array = group.duplicate()
	sorted.sort_custom(func(a: Actor, b: Actor) -> bool:
		return a.flat().distance_to(bp) < b.flat().distance_to(bp))
	var out: Array = []
	for a: Actor in sorted:
		if a.is_user:
			continue
		out.append(a)
		if out.size() >= count:
			break
	return out


# =============================================================================
# Poses: what every body is doing with its arms this frame
# =============================================================================

func _grip_ball(actor: Actor, side: String, center: Vector3, weight: float) -> void:
	# Wrap the palms around the far half of the ball as it comes into the chest.
	var outward := actor.right() if side == "R" else -actor.right()
	var radial := (outward + actor.facing() * 0.55 + Vector3.UP * 0.35).normalized()
	actor.palm_on(side, center + radial * BALL_FLOOR, center, weight)


func _pose_all(delta: float = 1.0 / 60.0) -> void:
	for a: Actor in _all:
		a.pose_reset()
		a.has_ball = a == _holder and _ball_mode == "held"
	var bp: Vector3 = _ball.position
	if _phase == Phase.REBOUND:
		for a: Actor in _all:
			a.pressure_stance = false
			var jumping := _board_jumps.has(a)
			if a == _holder or (_holder == null and (jumping or a.flat().distance_to(Vector3(bp.x, 0, bp.z)) < 1.5)):
				a.rebound_hands = true
				var chest := a.shoulder_position("R").lerp(a.shoulder_position("L"), 0.5)
				var from_chest := bp - chest
				var target := chest + a.facing() * maxf(0.18, from_chest.dot(a.facing()))
				target += a.right() * clampf(from_chest.dot(a.right()), -0.20, 0.20)
				target.y = bp.y
				var lift := smoothstep(0.0, 0.19, float(_board_jumps.get(a, 0.0)))
				if a == _holder:
					a.rebound_fold = smoothstep(0.0, 0.24, _recovery_t)
					target = bp
					lift = 1.0
				for side: String in ["R", "L"]:
					var sign_side := 1.0 if side == "R" else -1.0
					var ready := chest + a.facing() * 0.32 + a.right() * (sign_side * 0.21) + Vector3.DOWN * 0.16
					a.hand(side, ready.lerp(target + a.right() * (sign_side * 0.10), lift), 1.0)
					if a == _holder:
						_grip_ball(a, side, bp, smoothstep(0.0, 0.065, _recovery_t))
		return
	# Offense
	if _holder != null and _ball_mode == "held":
		var h: Actor = _holder
		if h == _user and (_charging or (_layup and _layup_air)):
			pass  # mocap owns the arms on a shot
		else:
			var ball_hand: String = "R" if _ball_side > 0.0 else "L"
			if _cross_t >= 0.0 and _cross_t < 0.5:
				ball_hand = "R" if _cross_from > 0.0 else "L"
			var rise: float = clampf((bp.y - 0.14) / 0.8, 0.0, 1.0)  # 0 on the floor, 1 at the hand
			h.hand(ball_hand, Vector3(bp.x, bp.y + 0.13, bp.z), smoothstep(0.45, 0.85, rise) * 0.85)
	if _pass_pose_t > 0.0 and _pass_from != null:
		_pass_from.hand("R", _pass_from.body_point(0.6, 0.15, 1.3), 1.0)
		_pass_from.hand("L", _pass_from.body_point(0.6, -0.15, 1.3), 1.0)
	if _ball_mode == "pass" and _pass_target != null:
		var t: Actor = _pass_target
		var aim: Vector3 = bp if bp.distance_to(t.position) < 3.0 else t.body_point(0.45, 0.0, 1.25)
		t.hand("R", aim + t.right() * 0.12, 1.0)
		t.hand("L", aim - t.right() * 0.12, 1.0)
		t.face_point(bp)
	for m: Actor in _mates:
		if m.role == "screen_set":
			m.hand("R", m.body_point(0.25, 0.05, 1.2), 1.0)
			m.hand("L", m.body_point(0.25, -0.05, 1.25), 1.0)
			m.lean_goal = 0.12
		elif _holder == _user and m != _pass_target and _openness(m) > 2.4 and _phase == Phase.LIVE:
			m.elbow_up = true
			m.hand("R", m.body_point(0.4, 0.3, 2.0), 0.9)  # calling for it: hand up, out in front
	_pose_release()
	# Defense
	var reach_d: Actor = _reach.get("d", null)
	for d: Actor in _defense:
		# Enter the low stance at guarding distance. Use a wider exit radius so
		# small changes in spacing cannot repeatedly raise and lower the hips.
		var ball_gap := d.flat().distance_to(Vector3(bp.x, 0.0, bp.z))
		if _ball_mode == "secured" and d == _holder:
			d.rebound_hands = true
			d.rebound_fold = 1.0
			d.pressure_stance = false
			d.contest_lift = 0.0
			d.hand("R", bp + d.right() * 0.10, 1.0)
			d.hand("L", bp - d.right() * 0.10, 1.0)
			for side: String in ["R", "L"]:
				_grip_ball(d, side, bp, 1.0)
			continue
		d.pressure_stance = ball_gap < (3.2 if d.pressure_stance else 2.6)
		d.lock_face(bp if _holder != d.man else (d.man as Actor).position)
		var near_shooter: bool = (_charging or _phase == Phase.SHOT) and _shooter != null \
			and d.flat().distance_to((_user if _charging else _shooter).flat()) < 2.2
		if (_charging or _layup) and d.flat().distance_to(_user.flat()) < 2.2:
			near_shooter = true
		d.contest_lift = move_toward(d.contest_lift, 1.0 if near_shooter else 0.0, delta * 3.8)
		if d.contest_lift > 0.0 and d != reach_d:
			d.elbow_up = true
			var lift := smoothstep(0.0, 1.0, d.contest_lift)
			var shooter: Actor = _user if _charging else _shooter
			var toward_shooter := d.facing()
			if shooter != null:
				# Face the shooter for the whole contest. Facing the ball in flight
				# turned the body away while the hands still aimed at the shooter.
				d.lock_face(shooter.position)
				var to_shooter := shooter.flat() - d.flat()
				if to_shooter.length_squared() > 0.01:
					toward_shooter = to_shooter.normalized()
			var high_side := 1.0 if d.right().dot(toward_shooter) >= 0.0 else -1.0
			for side: String in ["L", "R"]:
				var side_sign := 1.0 if side == "R" else -1.0
				var reach := d.arm_length(side)
				var high_hand := side_sign == high_side
				# Arms straight up over the shoulders, tipped slightly toward the
				# shooter (Arizona #35, Springfield #11). 0.82 rise / 0.32 forward
				# left the hands 36-40 cm over the shoulder with the elbows bent 71-86 deg.
				# Past arm_length on purpose: the hand clamp lets a contest arm reach
				# 112% of the bone chain (court_actor._clamp_hand_target); the IK
				# straightens the arm toward it and stops at full length.
				var forward_reach := reach * (0.16 if high_hand else 0.12)
				var rise := reach * 1.19
				var lateral := reach * 0.06 * side_sign
				var wrist_goal := d.shoulder_position(side) + toward_shooter * forward_reach 					+ Vector3.UP * rise + d.right() * lateral
				# Raise the target, not the IK weight: start where the stance hand hangs
				# (shoulder + 0.85 reach down, 0.27 out) and lift it to the goal. Blending
				# the solver weight instead drew half-solved arms (elbows flat, wrists
				# bent back) while the hands came up.
				var hang := d.shoulder_position(side) + Vector3.DOWN * reach * 0.85 					+ d.right() * reach * 0.27 * side_sign + toward_shooter * reach * 0.05
				d.hand(side, hang.lerp(wrist_goal, lift), clampf(d.contest_lift * 6.0, 0.0, 1.0))
				# A contest has no contact point. Turn the palms toward the ball at
				# the shooter's release point (CONTEST_PALM_AT_Y over his feet)
				# without a second palm-position solve moving the arm.
				var palm_at: Vector3 = wrist_goal + toward_shooter
				if shooter != null:
					palm_at = shooter.flat() + Vector3.UP * CONTEST_PALM_AT_Y
				d.palm_to(side, palm_at, lift)
			continue
		if d == reach_d:
			_pose_swipe(d, bp)
			continue
		# Ordinary coverage keeps the arms from the current movement clip.


## The shooting wrist after the ball leaves the hand. The CMU jump shot has no
## hand motion at all (its hand stays in line with the forearm the whole clip),
## so the release snap and follow-through are a short procedural motion that
## owns only the shooting wrist; the clip keeps everything else. From the
## launch: the palm turns from under the ball to facing down at the rim over
## RELEASE_SNAP (the fingers end pointing at the rim: the "gooseneck"), holds,
## and hands back to the clip over the last RELEASE_RELAX of the clip. Driven
## through palm_to (hand_aim); elbow_hinge keeps the twist in the forearm and
## the bend within its limit.
const RELEASE_SNAP: float = 0.08
const RELEASE_RELAX: float = 0.3


func _pose_release() -> void:
	if _ball_mode != "shot" or _shooter == null or _shot_layup:
		return
	var a: Actor = _shooter
	var left: float = float(a.get("_action_time"))
	if left <= 0.0:
		return
	var since: float = _flight_t * _flight_dur
	var w: float = smoothstep(0.0, RELEASE_SNAP, since) * clampf(left / RELEASE_RELAX, 0.0, 1.0)
	var to_rim: Vector3 = Vector3(HOOP_FLAT.x - a.position.x, 0.0, HOOP_FLAT.z - a.position.z).normalized()
	var wrist: Vector3 = a.hand_position("R")
	# Palm faces down and toward the rim: fingers over the top, pointing at it.
	a.palm_to("R", wrist + to_rim * 0.5 + Vector3.DOWN * 1.0, w)


## The baked full-body clip owns the entire swipe chain. Game timing and contact
## resolution stay independent from the visual hand trajectory.
const SWIPE_HIT_T: float = 0.26     # palm meets the ball (the swipe resolves here)
## The jab step: for the first part of the swipe he steps until his body is
## this far from the ball (across the floor), then the normal guard resumes.
const SWIPE_STEP_T: float = 0.30
const SWIPE_STEP_TO_M: float = 0.55


func _pose_swipe(d: Actor, _bp: Vector3) -> void:
	d.mocap_swipe_active = true
	# The selected right/left clip already includes torso, both shoulders, both
	# elbows, wrists, and recovery. No wrist target, pole solve, or palm modifier
	# may rewrite that chain during the action.
	d.hand("R", Vector3.ZERO, 0.0)
	d.hand("L", Vector3.ZERO, 0.0)
	d.palm_on("R", Vector3.ZERO, Vector3.ZERO, 0.0)
	d.palm_on("L", Vector3.ZERO, Vector3.ZERO, 0.0)
	d.lean_at = Vector3.ZERO
	d.lean_amount_goal = 0.0
	d.lean_twist_goal = 0.0
	d.crouch_goal = -1.0


# =============================================================================
# Test driver
# =============================================================================

func _auto_user(delta: float) -> void:
	var fwd: Vector3 = (HOOP_FLAT - _user.flat()).normalized()
	var screener: Actor = _screener()
	var target: Vector3
	if _possession_kind == "half" and not _pick_used and _hold_time > 0.8:
		_call_pick()
	if screener != null and screener.role in ["screen_come", "screen_set"]:
		target = screener.flat() + _pick_lat * _pick_sign * 1.4 + fwd * 0.6 if screener.role == "screen_set" \
			else _user.flat()
	else:
		target = Vector3(_user.spot.x * 0.5, 0, -7.0) if _possession_kind == "half" else HOOP_FLAT + Vector3(0, 0, 1.2)
	_user.step_toward(target, SPRINT_SPEED, delta)
	var open: float = _nearest_defender_dist(_user)
	var dist: float = _user.flat().distance_to(HOOP_FLAT)
	if dist < 3.0:
		_begin_layup()
	elif (open > 1.6 and dist < 7.5 and _hold_time > 1.2) or _hold_time > 5.0:
		_begin_shot()
	elif _hold_time > 2.0 and _rng.randf() < 0.01:
		var t: Actor = _pick_pass_target()
		if t != null:
			_throw_pass(_user, t)


# =============================================================================
# Actors, ball, markers, camera
# =============================================================================

func _build_actors() -> void:
	var actors: Node3D = Node3D.new()
	actors.name = "Actors"
	add_child(actors)
	var look: Dictionary = ContentDB.get_look(GameState.look_id)
	var gold: Color = Color(0.92, 0.72, 0.3)
	var navy: Color = Color(0.12, 0.2, 0.42)
	_user = _make_actor(actors, str(look.get("model", "male_casual")), {
		"Shirt": gold, "Pants": navy,
		"Skin": CharacterAppearance.SKIN_TONES[str(look.get("skin", "brown"))],
		"Hair": Color(str(look.get("hair", "#1a1412"))), "Socks": Color(0.95, 0.95, 0.95),
	}, 0)
	_user.is_user = true
	var mate_models: Array[String] = ["male_shirt", "male_longsleeve", "male_casual", "male_shirt"]
	var skins: Array[String] = ["deep", "light", "brown", "tan", "deep"]
	for i in 4:
		_mates.append(_make_actor(actors, mate_models[i], {
			"Shirt": gold, "Pants": navy, "Skin": CharacterAppearance.SKIN_TONES[skins[i]],
			"Hair": Color(0.08, 0.07, 0.06), "Socks": Color(0.95, 0.95, 0.95),
		}, 0))
	_big = _mates[3]
	_big.is_big = true
	_big.set_height(1.08)
	_offense = [_user] + _mates
	var opp_color: Color = Color(str(_opp.get("color", "#a3282e")))
	var opp_models: Array[String] = ["male_longsleeve", "male_casual", "male_shirt", "male_longsleeve", "male_casual"]
	for i in 5:
		var d: Actor = _make_actor(actors, opp_models[i], {
			"Shirt": opp_color, "Pants": Color(0.95, 0.95, 0.95), "Skin": CharacterAppearance.SKIN_TONES[skins[(i + 2) % 5]],
			"Hair": Color(0.08, 0.07, 0.06), "Socks": Color(0.95, 0.95, 0.95),
		}, 1)
		d.man = _offense[i]
		_defense.append(d)
	(_defense[4] as Actor).is_big = true
	(_defense[4] as Actor).set_height(1.08)
	_all = _offense + _defense


## Muscle for the user's player: the gym raises athleticism, athleticism
## bulks you up (0 = lean freshman, 1 = fully built).
static func user_bulk() -> float:
	return clampf((GameState.get_stat("athleticism") - 40.0) / 60.0, 0.0, 1.0)


func _make_actor(parent: Node3D, model_key: String, colors: Dictionary, team: int) -> Actor:
	var a: Actor = SpriteActor.new() if use_sprites else Actor.new()
	a.team = team
	parent.add_child(a)
	a.setup(model_key, colors, _made % 3 - 1 if _made > 0 else 0, user_bulk() if _made == 0 else BUILDS[_made % BUILDS.size()])
	_made += 1
	return a


func _build_ball() -> void:
	_ball = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	_ball.mesh = sphere
	_ball.material_override = Arena.mat(Color(0.88, 0.42, 0.14), 0.7)
	if use_sprites:
		_ball.mesh = QuadMesh.new()
		_ball.extra_cull_margin = 1.0
		_ball.material_override = SpriteActor.ball_material()
		_ball_shadow = CharacterAppearance.blob_shadow(0.17)
		add_child(_ball_shadow)
	_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ball)
	_target_ring = _ring(Color(0.92, 0.72, 0.3, 0.9), 0.55)
	_user_ring = _ring(Color(1, 1, 1, 0.7), 0.5)


func _ring(c: Color, radius: float) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var t: TorusMesh = TorusMesh.new()
	t.inner_radius = radius - 0.06
	t.outer_radius = radius
	t.rings = 24
	mi.mesh = t
	var m: StandardMaterial3D = Arena.mat(c)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.scale = Vector3(1, 0.15, 1)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _start_secure(actor: Actor) -> void:
	var offset := _ball.position - actor.position
	_secure_offset = Vector3(offset.dot(actor.right()), offset.y, offset.dot(actor.facing()))
	_recovery_t = 0.0
	_ball_mode = "secured"


func _update_ball(delta: float) -> void:
	match _ball_mode:
		"held":
			if _holder == null:
				return
			var h: Actor = _holder
			if h == _user and (_charging or (_layup and _layup_air)):
				# The shot and layup are mocap: the ball rides in the shooting hand.
				# He gathers it off the dribble over the first moment, never a snap.
				var into: float = smoothstep(0.0, 1.0, (_charge_t if _charging else _layup_t) / GATHER_TIME)
				_ball.position = _gather_from.lerp(h.hand_position("R") + Vector3(0, 0.12, 0), into)
				return
			_ball.position = h.dribble_ball(delta, BALL_FLOOR)
			if h.ball_hit_floor:
				_audio.play("bounce", -7.0)
		"windup":
			_ball.position = _shooter.hand_position("R") + Vector3(0, 0.12, 0)
		"pass":
			_tick_pass(delta)
		"shot":
			var t: float = clampf(_flight_t, 0.0, 1.0)
			var p: Vector3 = _flight_from.lerp(_flight_to, t)
			var air: float = t * _flight_dur
			p.y = _flight_from.y + _flight_vy * air - 0.5 * SHOT_GRAVITY * air * air
			_ball.position = p
		"loose":
			_loose_vel.y -= 9.8 * delta
			_ball.position += _loose_vel * delta
			if _ball.position.y < 0.12:
				_ball.position.y = 0.12
				if absf(_loose_vel.y) > 1.2:
					_audio.play("bounce", -9.0)
				_loose_vel.y = absf(_loose_vel.y) * 0.55
				_loose_vel.x *= 0.82
				_loose_vel.z *= 0.82
		"secured":
			_recovery_t += delta
			var pocket := _holder.body_point(0.28, 0.0, _holder.shoulder_position("R").y - _holder.position.y - 0.28)
			_ball.position = _holder.body_point(_secure_offset.z, _secure_offset.x, _secure_offset.y).lerp(pocket, smoothstep(0.0, 0.24, _recovery_t))
		"dead":
			_ball.position.y = maxf(BALL_FLOOR, _ball.position.y - delta * 6.0)


func _update_markers() -> void:
	if _ball_shadow != null:
		_ball_shadow.position = Vector3(_ball.position.x, 0.025, _ball.position.z)
	_user_ring.position = _user.position + Vector3(0, 0.03, 0)
	var show_target: bool = _phase == Phase.LIVE and _holder == _user and _ball_mode == "held" and not _charging
	var target: Actor = _pick_pass_target() if show_target else null
	_target_ring.visible = target != null
	if target != null:
		_target_ring.position = target.position + Vector3(0, 0.03, 0)
	for m: Actor in _mates:
		m.show_open(show_target and _openness(m) > 2.4)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 50.0

	add_child(_camera)
	_camera.make_current()
	_cam_focus = _desired_focus()
	_place_camera()


func _desired_focus() -> Vector3:
	var u: Vector3 = _user.flat()
	if _phase == Phase.REBOUND:
		var board := Vector3(_ball.position.x, 0, _ball.position.z)
		return board.lerp(u, 0.16)
	var f: Vector3 = u.lerp(HOOP_FLAT, 0.32)
	f.x *= 0.65
	return f


func _update_camera(delta: float) -> void:
	_cam_focus = _cam_focus.lerp(_desired_focus(), minf(1.0, 3.5 * delta))
	_place_camera()


func _place_camera() -> void:
	if debug_close_cam:  # animation QA: tight on the ball handler, from the front quarter
		var who: Actor = _holder if _holder != null else _user
		_camera.position = who.position + Vector3(2.2, 1.9, -3.2)
		_camera.look_at(who.position + Vector3(0, 1.0, 0), Vector3.UP)
		return
	_camera.position = _cam_focus + Vector3(_cam_focus.x * 0.12, 8.6, 10.0)
	_camera.look_at(_cam_focus + Vector3(0, 0.6, -1.0), Vector3.UP)


# =============================================================================
# UI
# =============================================================================

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)

	var board: PanelContainer = UIKit.panel(0.92)
	board.offset_left = 16
	board.offset_right = 380
	board.offset_top = 14
	_layer.add_child(board)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	board.add_child(col)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	col.add_child(row)
	_home_label = UIKit.label("", 26, UIKit.GOLD)
	row.add_child(_home_label)
	_clock_label = UIKit.label("", 22)
	_clock_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_clock_label)
	_away_label = UIKit.label("", 26, UIKit.TEXT)
	row.add_child(_away_label)
	_shot_clock_label = UIKit.label("", 16, UIKit.MUTED)
	_shot_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_shot_clock_label)

	_banner = _outlined_label(44, UIKit.GOLD)
	_banner.anchor_top = 0.22
	_banner.anchor_bottom = 0.22
	_layer.add_child(_banner)
	_sub_banner = _outlined_label(20, UIKit.TEXT)
	_sub_banner.anchor_top = 0.22
	_sub_banner.anchor_bottom = 0.22
	_sub_banner.offset_top = 56
	_sub_banner.offset_bottom = 110
	_layer.add_child(_sub_banner)

	_meter = Control.new()
	_meter.anchor_left = 0.5
	_meter.anchor_right = 0.5
	_meter.anchor_top = 0.5
	_meter.anchor_bottom = 0.5
	_meter.offset_left = 90
	_meter.offset_right = 130
	_meter.offset_top = -150
	_meter.offset_bottom = 90
	_meter.draw.connect(_draw_meter)
	_meter.visible = false
	_layer.add_child(_meter)

	_joystick = Control.new()
	_joystick.set_script(JoystickScript)
	_joystick.anchor_top = 1.0
	_joystick.anchor_bottom = 1.0
	_joystick.offset_left = 40
	_joystick.offset_right = 200
	_joystick.offset_top = -200
	_joystick.offset_bottom = -40
	_layer.add_child(_joystick)

	_shoot_button = UIKit.button("SHOOT", true, 120)
	_shoot_button.name = "ShootButton"
	_anchor_br(_shoot_button, -180, -40, -170, -50)
	_shoot_button.add_theme_font_size_override("font_size", 24)
	_layer.add_child(_shoot_button)
	_pass_button = UIKit.button("PASS", false, 90)
	_pass_button.name = "PassButton"
	_anchor_br(_pass_button, -330, -200, -140, -50)
	_pass_button.add_theme_font_size_override("font_size", 20)
	_pass_button.pressed.connect(_on_pass)
	_layer.add_child(_pass_button)
	_pick_button = UIKit.button("PICK", false, 80)
	_pick_button.name = "PickButton"
	_anchor_br(_pick_button, -170, -50, -290, -195)
	_pick_button.add_theme_font_size_override("font_size", 18)
	_pick_button.pressed.connect(_on_pick)
	_layer.add_child(_pick_button)

	# Controls live where sports games keep them: the pause menu.
	var pause_menu: Node = PauseMenuScene.instantiate()
	add_child(pause_menu)


func _anchor_br(c: Control, left: float, right: float, top: float, bottom: float) -> void:
	c.anchor_left = 1.0
	c.anchor_right = 1.0
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = left
	c.offset_right = right
	c.offset_top = top
	c.offset_bottom = bottom


func _outlined_label(size: int, color: Color) -> Label:
	var l: Label = UIKit.label("", size, color)
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.offset_top = 0
	l.offset_bottom = 56
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.1))
	l.add_theme_constant_override("outline_size", 9)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _show_banner(text: String, sub: String, seconds: float) -> void:
	_banner.text = text
	_sub_banner.text = sub
	_banner.modulate.a = 1.0
	_sub_banner.modulate.a = 1.0
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_interval(seconds)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.3)
	_banner_tween.parallel().tween_property(_sub_banner, "modulate:a", 0.0, 0.3)


## Small callout during live play (doesn't cover the action).
func _show_toast(text: String) -> void:
	_show_banner("", text, 0.9)


func _refresh_scoreboard() -> void:
	_home_label.text = "%s  %d" % [str(_team.get("short", "NVS")), _team_score]
	_away_label.text = "%d  %s" % [_opp_score, str(_opp.get("short", "OPP"))]
	var secs: int = int(ceil(_clock))
	_clock_label.text = "Q%d  %d:%02d" % [_quarter, secs / 60, secs % 60]
	var sc: int = int(ceil(_shot_clock))
	_shot_clock_label.text = "Shot clock %d" % sc
	_shot_clock_label.add_theme_color_override("font_color", UIKit.BAD if sc <= 5 else UIKit.MUTED)


func _situation_line() -> String:
	var diff: int = _team_score - _opp_score
	var secs: int = int(_clock)
	var state: String = "Tied" if diff == 0 else ("Up %d" % diff if diff > 0 else "Down %d" % -diff)
	return "Q%d · %d:%02d · %s" % [_quarter, secs / 60, secs % 60, state]


func _draw_meter() -> void:
	var size: Vector2 = _meter.size
	var rect: Rect2 = Rect2(Vector2(8, 0), Vector2(size.x - 16, size.y))
	_meter.draw_rect(rect.grow(5), Color(UIKit.NAVY_DEEP, 0.9))
	_meter.draw_rect(rect, Color(1, 1, 1, 0.12))
	var zone_top: float = rect.end.y - (METER_CENTER + _zone_w / 2.0) * rect.size.y
	var zone_h: float = _zone_w * rect.size.y
	_meter.draw_rect(Rect2(rect.position.x, zone_top, rect.size.x, zone_h), Color(UIKit.GOLD, 0.6))
	var perfect_h: float = zone_h * PERFECT_FRACTION
	_meter.draw_rect(Rect2(rect.position.x, zone_top + (zone_h - perfect_h) / 2.0, rect.size.x, perfect_h),
		Color(1.0, 0.95, 0.7, 0.95))
	var fill_h: float = _meter_pos * rect.size.y
	_meter.draw_rect(Rect2(rect.position.x, rect.end.y - fill_h, rect.size.x, fill_h), Color(1, 1, 1, 0.35))
	_meter.draw_rect(Rect2(0, rect.end.y - fill_h - 3, size.x, 6), Color.WHITE)


func _show_final(result: Dictionary) -> void:
	_final_panel = UIKit.panel(0.95)
	_final_panel.anchor_left = 0.5
	_final_panel.anchor_right = 0.5
	_final_panel.anchor_top = 0.5
	_final_panel.anchor_bottom = 0.5
	_final_panel.offset_left = -300
	_final_panel.offset_right = 300
	_final_panel.offset_top = -150
	_final_panel.offset_bottom = 150
	_layer.add_child(_final_panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_final_panel.add_child(col)
	var won: bool = int(result["margin"]) > 0
	col.add_child(UIKit.label("End of stretch", 28, UIKit.GOLD))
	col.add_child(UIKit.label("%s %d  –  %d %s" % [str(_team.get("short", "NVS")), _team_score, _opp_score,
		str(_opp.get("short", "OPP"))], 24, UIKit.GOOD if won else UIKit.TEXT))
	var fg: String = "%d-%d FG" % [int(result["fgm"]), int(result["fga"])]
	if int(result["tpa"]) > 0:
		fg += ", %d-%d 3PT" % [int(result["tpm"]), int(result["tpa"])]
	col.add_child(UIKit.label("You: %d pts  ·  %s  ·  %d ast  ·  %d TO" % [int(result["pts"]), fg,
		int(result["ast"]), int(result["to"])], 19))
	var swing: int = int(result["margin"]) - int(result["start_margin"])
	col.add_child(UIKit.label("Stretch: %s%d" % ["+" if swing >= 0 else "", swing], 17, UIKit.MUTED))
	var standalone: bool = get_tree().current_scene == self
	var b: Button = UIKit.button("Play again" if standalone else "Continue", true, 54)
	b.name = "FinalContinue"
	col.add_child(b)
	b.pressed.connect(func() -> void:
		if get_tree().current_scene == self:
			get_tree().reload_current_scene()
		else:
			finished.emit(result))
	if auto_play:
		finished.emit(result)
