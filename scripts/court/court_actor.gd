extends Node3D
## One player on the game court: the standard-skeleton court model
## (CourtPlayerModel) with steering. Animation is an AnimationTree with
## three movement modes (off the ball, dribbling, defending) built from
## library locomotion and basketball mocap (dribble, defensive slides), and
## a one-shot on top for the jump shot, layup and jumps. Hands reach world
## targets (the ball, a passing lane, a contest) through the engine's
## TwoBoneIK3D, one per arm, with the weight as the modifier's influence.
## The court game sets pose goals each frame; this script blends to them.

var team: int = 0  # 0 = North Valley State, 1 = opponent
var is_user: bool = false
var is_big: bool = false
var spot: Vector3 = Vector3.ZERO
var man: Node3D = null  # defenders: the offensive player they guard
var track: Vector3 = Vector3.ZERO  # defenders: lagged read of their man
var vel: Vector3 = Vector3.ZERO
var wander_target: Vector3 = Vector3.ZERO
var wander_timer: float = 0.0
var protect_rim: bool = false
## Off balance (whiffed a swipe, ran into a screen): slow and leaning.
var stagger: float = 0.0
## Defenders: the handler got past him; he chases from behind, can't cut off.
var beaten: float = 0.0
## Teammates: "space", "screen_come", "screen_set", "roll", "pop", "cut"
var role: String = "space"
var role_time: float = 0.0
var role_target: Vector3 = Vector3.ZERO
var reach_cd: float = 1.0

# Pose goals set by the game each frame (world space), and blended values.
var hand_r: Vector3 = Vector3.ZERO
var hand_l: Vector3 = Vector3.ZERO
var w_r: float = 0.0
var w_l: float = 0.0
var goal_w_r: float = 0.0
var goal_w_l: float = 0.0
var lean_now: float = 0.0
var lean_goal: float = 0.0
var elbow_up: bool = false
## Gameplay palm aim (world point the palm should face) per hand, 0 = off.
var palm_at_r: Vector3 = Vector3.ZERO
var palm_at_l: Vector3 = Vector3.ZERO
var palm_w_r: float = 0.0
var palm_w_l: float = 0.0
## A swipe bends the trunk toward this point (reach_lean.gd) and sinks the
## hips; -1 crouch leaves the stance logic in charge.
var lean_at: Vector3 = Vector3.ZERO
var lean_amount_goal: float = 0.0
var crouch_goal: float = -1.0
var _lean_amount: float = 0.0
## Trunk rotation goal for a swipe (radians, + turns the left side forward).
var lean_twist_goal: float = 0.0
var _lean_twist: float = 0.0
var _reach_lean: SkeletonModifier3D
var face_lock: bool = false
var face_target: Vector3 = Vector3.ZERO

## Which local axis of the forearm bone the elbow bends toward on this rig.
const POLE_AXIS: int = SkeletonModifier3D.SECONDARY_DIRECTION_PLUS_Z
const FootFloor = preload("res://scripts/court/foot_floor.gd")
const ArmClearance = preload("res://scripts/court/arm_clearance.gd")
const HandAim = preload("res://scripts/court/hand_aim.gd")
const ElbowHinge = preload("res://scripts/court/elbow_hinge.gd")
const ReachLean = preload("res://scripts/court/reach_lean.gd")
const PoseTap = preload("res://scripts/court/pose_tap.gd")
var _pose_tap: SkeletonModifier3D
const TorsoPosture = preload("res://scripts/court/torso_posture.gd")
const Crouch = preload("res://scripts/court/crouch.gd")
const StudentFeet = preload("res://scripts/court/student_feet.gd")
const ARM_TRACKS: Array[String] = ["LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand"]
const UPPER_ACTIONS: Array[String] = ["Reach", "Pass", "Clap"]
const GRAVITY: float = 9.81
const STATURE: float = 1.81  # the court model's standing height
const BOUNCE: float = 0.78  # share of its speed the ball keeps off the floor
const GAITS: Array[String] = ["Idle", "Walk", "JogM", "Run", "Jog", "DribbleRun", "SlideL", "SlideR", "Backpedal"]
const ARM_BONES: Dictionary = {"R": ["RightUpperArm", "RightLowerArm", "RightHand"],
	"L": ["LeftUpperArm", "LeftLowerArm", "LeftHand"]}

## Set by the game each frame: this player is dribbling the ball.
var has_ball: bool = false

var _model: Node3D
var _anim: AnimationPlayer
var _tree: AnimationTree
var _act_node: AnimationNodeAnimation
var _uact_node: AnimationNodeAnimation
var _carry: float = 0.0
var _drib_t: float = 0.0  # seconds into the dribble clip the arms are at
var _drib_rate: float = 1.0
var _drib_w: float = 0.0
static var dribble_log: bool = false
## Keep the dribbling hand at the mocap's actual height. The pole follows the
## animated elbow so IK corrects the hand without inventing a new bend plane.
static var arm_fix_enabled: bool = true
var _log_t: float = 0.0
var _sim_t: float = 0.0
var _fly_t: float = -1.0  # seconds into the current flight, or -1 while the ball is in his hand
var _fly: Dictionary = {}
var _released: Dictionary = {}
static var _dribble: Dictionary = {}
static var _hands: Dictionary = {}
## Set by dribble_ball(): the ball met the floor this frame.
var ball_hit_floor: bool = false
var _hand_lo: Dictionary = {"R": 1.0, "L": 1.0}
var _hand_hi: Dictionary = {"R": 1.0, "L": 1.0}
var _hand_prev: float = 0.0
var _hand_rising: bool = false
var _drib_side: String = "R"  # the hand that has the ball
var _drib_pending: String = "R"  # the hand he wants it in; applied at the next bounce
var _role: Dictionary = {"R": 1.0, "L": 0.0}  # 1 = dribbling hand, 0 = free hand
var _ball_x: float = -1.0  # -1 = ball on his right, +1 = on his left (smoothed)
var _free_t: float = 0.0
var _hand_still: float = 0.0
var _ball_y: float = 0.0
var _ball_was_up: bool = true
var _skeleton: Skeleton3D
var _gait: String = ""
var _feet: SkeletonModifier3D
var _crouch: SkeletonModifier3D
var _crouch_now: float = 0.0
var _body_floor: SkeletonModifier3D
var _stride: float = 0.0  # 0..1 through the stride, 0 = left foot lands
var _switch_wait: float = 0.0
var _action_time: float = 0.0
var _ik: Dictionary = {}  # side -> {ik, target, pole}
var _arm_reach: Dictionary = {}  # measured upper-arm + forearm length, in world units
var _openness_label: Label3D


func setup(_model_key: String, colors: Dictionary, hair: int = 0, bulk: float = 0.0) -> void:
	_model = CourtPlayerModel.build_student(colors) if CourtPlayerModel.students else CourtPlayerModel.build(colors, hair, bulk)
	add_child(_model)
	add_child(CharacterAppearance.blob_shadow())
	_anim = _model.get_node("AnimationPlayer")
	_build_tree()
	var sk: Skeleton3D = CourtPlayerModel.find_skeleton(_model)
	_skeleton = sk
	if sk != null:
		_fit_proportions(sk)  # before anything measures the limbs (reach, feet, arms)
		_crouch = Crouch.new()
		sk.add_child(_crouch)
		# Feet first: lift any foot the animation leaves under the floor.
		var feet: SkeletonModifier3D = FootFloor.new()
		feet.set("toe_rest", 0.012)
		feet.set("ankle_rest", sk.get_bone_global_rest(sk.find_bone("LeftFoot")).origin.y - 0.02)
		sk.add_child(feet)
		_feet = feet
		if sk.find_bone("Foot.L") >= 0:
			sk.add_child(StudentFeet.new())
			var body: SkeletonModifier3D = FootFloor.new()
			body.set("body_mode", true)
			body.set("_hips", -1)
			sk.add_child(body)
			_body_floor = body
		sk.add_child(TorsoPosture.new())  # before the arm IK, so the hands see the corrected torso
		_reach_lean = ReachLean.new()  # after the posture fix (it would undo it), before the arms
		sk.add_child(_reach_lean)
		for side: String in ["R", "L"]:
			_build_arm_ik(sk, side)  # used only to put dribbling hands where the performer's were
		sk.add_child(ArmClearance.new())  # after the IK, so it has the last word on the elbows
		_hand_aim = HandAim.new()
		sk.add_child(_hand_aim)
		_hand_aim_l = HandAim.new()
		_hand_aim_l.set("bone_name", "LeftHand")
		sk.add_child(_hand_aim_l)
		_elbow_hinge = ElbowHinge.new()  # real hinge elbows, forearm twist, palm contact
		sk.add_child(_elbow_hinge)
		_pose_tap = PoseTap.new()  # last: records where the arms really ended up, for game-code reads
		_pose_tap.set("model", _model)
		sk.add_child(_pose_tap)
	_openness_label = Label3D.new()
	_openness_label.text = "OPEN"
	_openness_label.font_size = 40
	_openness_label.outline_size = 10
	_openness_label.modulate = Color(0.92, 0.72, 0.3)
	_openness_label.outline_modulate = Color(0.03, 0.05, 0.1)
	_openness_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_openness_label.no_depth_test = true
	_openness_label.position = Vector3(0, 2.35, 0)
	_openness_label.visible = false
	add_child(_openness_label)


func show_open(on: bool) -> void:
	_openness_label.visible = on


func flat() -> Vector3:
	return Vector3(position.x, 0, position.z)


func step_toward(target: Vector3, max_speed: float, delta: float, accel: float = 16.0) -> void:
	var to: Vector3 = Vector3(target.x - position.x, 0, target.z - position.z)
	var d: float = to.length()
	var desired: Vector3 = Vector3.ZERO
	if d > 0.08:
		desired = to / d * minf(max_speed, d * 4.0)
	move_with(desired, delta, accel)


func move_with(desired: Vector3, delta: float, accel: float = 16.0) -> void:
	if stagger > 0.0:
		desired *= 0.3
	vel = vel.move_toward(desired, accel * delta)
	position += vel * delta


func stop() -> void:
	vel = Vector3.ZERO


## Called once per frame by the game after movement and pose goals.
func animate(delta: float) -> void:
	stagger = maxf(0.0, stagger - delta)
	beaten = maxf(0.0, beaten - delta)
	reach_cd = maxf(0.0, reach_cd - delta)
	# Defenders play in a stance: knees bent, hands up and out, unless the
	# game has given them something to do with their hands.
	var stance: bool = face_lock and team == 1 and not has_ball and _action_time <= 0.0 and _clap_t <= 0.0
	if stance and goal_w_r <= 0.0 and goal_w_l <= 0.0:
		hand_r = body_point(0.4, 0.55, 1.15)
		hand_l = body_point(0.4, -0.55, 1.15)
		goal_w_r = 0.9
		goal_w_l = 0.9
	# The side slide is already a low shuffle; the crouch is for standing and backing up.
	var crouch_want: float = 0.55 if stance and (_gait == "Idle" or _gait == "Backpedal") else 0.0
	if crouch_goal >= 0.0:
		crouch_want = crouch_goal
	_crouch_now = move_toward(_crouch_now, crouch_want, delta * (6.0 if crouch_goal >= 0.0 else 4.0))
	_lean_amount = move_toward(_lean_amount, lean_amount_goal, delta * 7.0)
	_lean_twist = move_toward(_lean_twist, lean_twist_goal, delta * 9.0)
	if _reach_lean != null:
		_reach_lean.set("target", lean_at)
		_reach_lean.set("amount", _lean_amount)
		_reach_lean.set("twist", _lean_twist)
	if _elbow_hinge != null:
		_elbow_hinge.set("palm_goal", _palm_goals.duplicate())
	if _crouch != null:
		_crouch.set("amount", _crouch_now)
	var k: float = minf(1.0, 20.0 * delta)
	w_r = lerpf(w_r, goal_w_r, k)
	w_l = lerpf(w_l, goal_w_l, k)
	if _clap_t > 0.0:
		# Applause: the hands meet at the chest about three times a second.
		_clap_t = maxf(0.0, _clap_t - delta)
		var apart: float = 0.5 + 0.5 * cos(TAU * 3.0 * (CLAP_TIME - _clap_t))
		var half: float = lerpf(0.03, 0.2, apart)
		hand_r = body_point(0.36, half, 1.25)
		hand_l = body_point(0.36, -half, 1.25)
		w_r = 1.0
		w_l = 1.0
		goal_w_r = 1.0
		goal_w_l = 1.0
	lean_now = lerpf(lean_now, lean_goal + (0.35 if stagger > 0.0 else 0.0), minf(1.0, 9.0 * delta))
	if _feet != null:
		_feet.set("floor_y", global_position.y)
		if _body_floor != null:
			_body_floor.set("floor_y", global_position.y)
	# Dribbling: copying joint angles onto a longer torso leaves the hands at
	# the chest. Put each hand back where the performer's really was relative
	# to his hips (assets/court/dribble_ball.json, from the original mocap).
	var fix_clip: String = _hands_clip()
	_drib_w = move_toward(_drib_w, 1.0 if fix_clip != "" and _action_time <= 0.0 else 0.0, delta * 6.0)
	_update_dribble_side(delta)
	if _drib_w > 0.0 and fix_clip != "":
		hand_r = _dribble_hand("R")
		w_r = _drib_w
		if fix_clip == "DribbleRun":
			hand_l = _dribble_hand("L")
			w_l = _drib_w
	for side: String in ["R", "L"]:
		var arm: Dictionary = _ik.get(side, {})
		if arm.is_empty():
			continue
		var w: float = w_r if side == "R" else w_l
		var target: Vector3 = hand_r if side == "R" else hand_l
		if _drib_w > 0.0 and fix_clip != "" and (side == "R" or fix_clip == "DribbleRun"):
			w = maxf(w, _drib_w)
			# For a ball handler, match the dribble curve. Generic gameplay
			# goals (pass catch, screen, contest, reach) remain available to others.
			target = _dribble_hand(side)
		if w > 0.001:
			target = _clamp_hand_target(side, target)
		(arm["ik"] as SkeletonModifier3D).influence = clampf(w, 0.0, 1.0)
		(arm["target"] as Node3D).global_position = target
		var elbow_bone: int = _skeleton.find_bone(ARM_BONES[side][1])
		var elbow_world: Vector3 = _skeleton.global_transform * _skeleton.get_bone_global_pose(elbow_bone).origin
		if _drib_w > 0.3 and fix_clip == "DribbleRun":
			# A dribbler's elbow stays by the ribs: down, a little back and out.
			var out_dir: Vector3 = right() * (0.25 if side == "R" else -0.25)
			var shoulder: Vector3 = _skeleton.global_transform * _skeleton.get_bone_global_pose(_skeleton.find_bone(ARM_BONES[side][0])).origin
			elbow_world = shoulder + (Vector3.DOWN * 0.8 - facing() * 0.5 + out_dir).normalized() * 0.5
		elif w > 0.001:
			# A gameplay hand (stance, swipe, catch, contest): the elbow points
			# where a real one does for that reach, never along the arm, which
			# leaves the IK plane undefined and lets the elbow flip.
			elbow_world = shoulder_position(side) + elbow_hint(side).normalized() * 0.6
		(arm["pole"] as Node3D).global_position = elbow_world
		var aim: SkeletonModifier3D = _hand_aim if side == "R" else _hand_aim_l
		if aim != null:
			var aim_on: bool = _drib_w > 0.3 and fix_clip == "DribbleRun"
			var pw: float = palm_w_r if side == "R" else palm_w_l
			if aim_on:
				var curve: Dictionary = _dribble_curve()
				var ball: Vector3 = _dribble_spot()
				ball.y = global_position.y + maxf(CourtDribble.RADIUS, CourtDribble.sample(curve["ball"], _dribble_phase(curve)) * _model.scale.x)
				aim.set("target", ball)
				aim.set("weight", _drib_w * float(_role[side]))
			elif pw > 0.0:
				aim.set("target", palm_at_r if side == "R" else palm_at_l)
				aim.set("weight", pw)
			else:
				aim.set("weight", 0.0)
	_action_time = maxf(0.0, _action_time - delta)
	var s: float = Vector2(vel.x, vel.z).length()
	if face_lock:
		turn_toward(face_target, delta)
	elif s > 0.35 and _action_time <= 0.0:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(vel.x, vel.z), minf(1.0, 12.0 * delta))
	# Pick the gait for how he is moving, and play it at the rate that
	# matches his ground speed. A switch waits for the last cross-fade to
	# finish and starts the new clip at the same point in the stride.
	_switch_wait = maxf(0.0, _switch_wait - delta)
	var gait: String = _pick_gait(s)
	if gait != _gait and (_switch_wait <= 0.0 or _gait == ""):
		_gait = gait
		_switch_wait = 0.22
		_tree.set("parameters/gait/transition_request", gait)
		if CourtPlayerModel.CLIP_STRIKE.has(gait):
			var length: float = _anim.get_animation(gait).length
			var at: float = fposmod(float(CourtPlayerModel.CLIP_STRIKE[gait]) + _stride * length, length)
			if gait == "DribbleRun":
				at = _drib_t  # the dribble keeps its own beat; the legs join it
			_tree.set("parameters/seek_%s/seek_request" % gait, at)
	var rate: float = 1.0
	if CourtPlayerModel.CLIP_SPEED.has(_gait):
		rate = clampf(s / float(CourtPlayerModel.CLIP_SPEED[_gait]), 0.8 if _gait == "DribbleRun" else 0.5, 1.9)
		_stride = fposmod(_stride + delta * rate / _anim.get_animation(_gait).length, 1.0)
	_tree.set("parameters/speed/scale", rate)
	# Dribbling arms over the legs (not needed when the legs are already the dribble clip).
	# The arm layer is the dribble clip kept in step with the legs: one
	# dribble per stride, started at the matching point of the stride.
	var drib_len: float = _anim.get_animation("DribbleRun").length
	var drib_rate: float = 1.0
	if _gait == "DribbleRun":
		# Legs and arms are the same clip here: one continuous clock for both.
		drib_rate = rate
		_drib_t = fposmod(_drib_t + delta * drib_rate, drib_len)
		_stride = fposmod((_drib_t - float(CourtPlayerModel.CLIP_STRIKE["DribbleRun"])) / drib_len, 1.0)
	else:
		if CourtPlayerModel.CLIP_SPEED.has(_gait):
			drib_rate = clampf(rate * drib_len / _anim.get_animation(_gait).length, 0.85, 1.5)
		_drib_t = fposmod(_drib_t + delta * drib_rate, drib_len)
	var want: float = 1.0 if has_ball and _gait != "DribbleRun" and _action_time <= 0.0 else 0.0
	if want > 0.0 and _carry <= 0.0:
		_tree.set("parameters/d_seek/seek_request", _drib_t)
	_carry = move_toward(_carry, want, delta * 5.0)
	_tree.set("parameters/carry/blend_amount", _carry)
	_tree.set("parameters/d_speed/scale", drib_rate)
	_drib_rate = drib_rate


## Where the ball is while he dribbles. The dribble mocap was recorded with
## a real ball, so its hand pumps at a real rhythm; tests/court_dribble_bake
## records when in the clip the hand lets go and when it meets the ball
## again. At each release the flight is solved here, in real time, from
## where the hand actually is to where it will be: constant speed across the
## floor, gravity in the air, one bounce. Between flights the ball is in the
## hand. Nothing moves the arm to the ball.
func dribble_ball(_delta: float, floor_y: float) -> Vector3:
	var t: Dictionary = _dribble_curve()
	var phase: float = _dribble_phase(t)
	var bounce: float = float(t["bounce"])
	ball_hit_floor = _dphase_prev < bounce and phase >= bounce
	_dphase_prev = phase
	var k: float = _model.scale.x
	var p: Vector3 = _dribble_spot()
	var y: float = CourtDribble.sample(t["ball"], phase)
	p.y = floor_y - CourtDribble.RADIUS + maxf(CourtDribble.RADIUS, y * k)
	return p


## Where the dribbled ball will be `ahead` seconds from now if he keeps going
## as he is: the dribble curve a little later in the beat, carried by his own
## motion. Reads only: his dribble state is put back exactly. A swipe aims at
## this, so the hand goes to where the ball will be, not where it was.
func predict_ball(ahead: float, floor_y: float) -> Vector3:
	var keep_t: float = _drib_t
	var keep_prev: float = _dphase_prev
	var keep_hit: bool = ball_hit_floor
	var span: float = _anim.get_animation("DribbleRun").length
	_drib_t = fposmod(_drib_t + ahead * _drib_rate, span)
	var p: Vector3 = dribble_ball(0.0, floor_y)
	_drib_t = keep_t
	_dphase_prev = keep_prev
	ball_hit_floor = keep_hit
	return p + Vector3(vel.x, 0.0, vel.z) * ahead


var _dphase_prev: float = 0.0
var _hand_aim: SkeletonModifier3D
var _hand_aim_l: SkeletonModifier3D
var _clap_t: float = 0.0
const CLAP_TIME: float = 1.2
static var _dcurves: Dictionary = {}


## The dribble curve (ball and hand heights over one dribble) for the beat
## the legs are currently at; cached per tenth of a second of period.
func _dribble_curve() -> Dictionary:
	var length: float = float(_dribble_table().get("length", 1.0))
	var period: float = clampf(length / maxf(_drib_rate, 0.5), 0.35, 1.4)
	var key: int = int(roundf(period * 25.0))
	if not _dcurves.has(key):
		_dcurves[key] = CourtDribble.table(key / 25.0)
	return _dcurves[key]


## Phase 0 is the hand meeting the ball. The clip's release lands at the end
## of the hand's contact, so the legs and the dribble keep one beat.
func _dribble_phase(t: Dictionary) -> float:
	var table: Dictionary = _dribble_table()
	var length: float = float(table.get("length", 1.0))
	var flights: Array = table.get("flights", [])
	var release: float = float(flights[0]["t0"]) if not flights.is_empty() else 0.0
	return fposmod((_drib_t - release) / length + float(t["contact"]), 1.0)


## Beside him and a little ahead, where the ball bounces. Floor-level point;
## the caller sets the height.
## Where the free hand rests while he dribbles: relaxed beside the hip.
func _free_hand(side: String = "L") -> Vector3:
	var k: float = _model.scale.x
	var sway: float = 0.02 * sin(TAU * _drib_t)
	var s: float = 1.0 if side == "R" else -1.0
	var local: Vector3 = right() * s * (0.27 + sway) * k + facing() * 0.07 * k
	return global_position + local + Vector3(0, 0.78 * k, 0)


## Which hand dribbles: the one on the side he is moving toward. The change is
## made at a bounce, while the ball is off the hand, and the arms then trade
## roles over a quarter of a second.
func _update_dribble_side(delta: float) -> void:
	var lat: float = vel.dot(right())
	var fwd: float = vel.dot(facing())
	if absf(lat) > 0.9 and absf(lat) > absf(fwd) * 0.35:
		_drib_pending = "R" if lat > 0.0 else "L"
	if _drib_pending != _drib_side and (ball_hit_floor or _drib_w < 0.5):
		_drib_side = _drib_pending
	for side: String in ["R", "L"]:
		_role[side] = move_toward(float(_role[side]), 1.0 if side == _drib_side else 0.0, delta * 5.0)
	_ball_x = move_toward(_ball_x, -1.0 if _drib_side == "R" else 1.0, delta * 9.0)


## Where a hand goes while he has the ball: on the dribble curve if it is the
## dribbling hand, relaxed at his side if not, and a blend while they trade.
func _dribble_hand(side: String) -> Vector3:
	var free: Vector3 = _free_hand(side)
	var role: float = float(_role[side])
	if role <= 0.001:
		return free
	var spot: Vector3 = _source_hand(side)
	return free.lerp(spot, role) if role < 0.999 else spot


func _dribble_spot() -> Vector3:
	var k: float = _model.scale.x
	var ahead: float = CourtDribble.LOCAL.z + 0.045 * Vector2(vel.x, vel.z).length()
	var local: Vector3 = Vector3(CourtDribble.LOCAL.x * -_ball_x * k, 0.0, ahead * k)
	return global_position + Basis(Vector3.UP, _model.rotation.y) * local


## Time to the floor and downward launch speed so a ball leaving at height
## y0 (above the floor) bounces once and is at y1 after `span` seconds.
static func _solve_bounce(y0: float, y1: float, span: float, radius: float) -> Array:
	if span < 0.15 or span > 0.9 or y0 <= radius:
		return []
	var prev_err: float = 0.0
	var have_prev: bool = false
	for k in range(1, 200):
		var tb: float = span * k / 200.0
		var v0: float = (y0 - radius - 0.5 * GRAVITY * tb * tb) / tb
		if v0 < 0.0:
			continue
		var up: float = span - tb
		var err: float = radius + BOUNCE * (v0 + GRAVITY * tb) * up - 0.5 * GRAVITY * up * up - y1
		if have_prev and (err > 0.0) != (prev_err > 0.0):
			return [tb, v0]
		prev_err = err
		have_prev = true
	return []


## Which recording the hands should follow right now: the dribble whenever
## he has the ball, otherwise the gait his legs are in (if it is mocap).
func _hands_clip() -> String:
	if not arm_fix_enabled:
		return ""
	return "DribbleRun" if has_ball else ""


## Where the performer's hand was at this point of the clip, placed relative
## to this player's hips and at the performer's height above the floor.
func _source_hand(side: String) -> Vector3:
	if _hands_clip() == "DribbleRun":
		var t: Dictionary = _dribble_curve()
		var spot: Vector3 = _dribble_spot()
		var mine: float = -1.0 if side == "R" else 1.0
		spot = spot - Basis(Vector3.UP, _model.rotation.y) * Vector3(CourtDribble.LOCAL.x * -_ball_x * _model.scale.x, 0.0, 0.0) 			+ Basis(Vector3.UP, _model.rotation.y) * Vector3(CourtDribble.LOCAL.x * -mine * _model.scale.x, 0.0, 0.0)
		spot.y = global_position.y + CourtDribble.sample(t["hand"], _dribble_phase(t)) * _model.scale.x
		return spot
	var clip: String = _hands_clip()
	var table: Dictionary = _hands_table().get(clip, {})
	var pts: Array = table.get("hand_r" if side == "R" else "hand_l", [])
	if pts.is_empty() or _skeleton == null:
		return hand_position(side)
	var length: float = float(table.get("length", 1.0))
	var at: float = _drib_t
	if clip != "DribbleRun":
		at = fposmod(float(CourtPlayerModel.CLIP_STRIKE.get(clip, 0.0)) + _stride * length, length)
	var n: int = pts.size()
	var x: float = fposmod(at / length, 1.0) * n
	var i: int = int(x) % n
	var a: Array = pts[i]
	var b: Array = pts[(i + 1) % n]
	var rel: Vector3 = Vector3(a[0], a[1], a[2]).lerp(Vector3(b[0], b[1], b[2]), x - floorf(x))
	var hips: Vector3 = _skeleton.global_transform * _skeleton.get_bone_global_pose(_skeleton.find_bone("Hips")).origin
	# Everything is in proportion to body height: the performer is shorter
	# than this player, so his offsets and heights are scaled up to match.
	var k: float = STATURE * _model.scale.x / float(table.get("stature", 1.45))
	var goal: Vector3 = hips + Basis(Vector3.UP, _model.rotation.y) * (rel * k)
	goal.y = global_position.y + (float(table.get("hips_height", 0.96)) + rel.y) * k
	return goal


static func _hands_table() -> Dictionary:
	if _hands.is_empty():
		var f: FileAccess = FileAccess.open("res://assets/court/source_hands.json", FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_hands = parsed
		if _hands.is_empty():
			_hands = {"none": {}}
	return _hands


static func _dribble_table() -> Dictionary:
	if _dribble.is_empty():
		var f: FileAccess = FileAccess.open("res://assets/court/dribble_ball.json", FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_dribble = parsed
		if _dribble.is_empty():
			_dribble = {"length": 1.0, "flights": []}
	return _dribble


func _pick_gait(s: float) -> String:
	if s < (0.25 if _gait == "Idle" else 0.15):
		return "Idle"
	if face_lock and team == 1:
		# Defending: he faces his man, so pick by which way he is moving.
		var lat: float = vel.dot(right())
		var fwd: float = vel.dot(facing())
		if absf(lat) >= absf(fwd) * 0.7:
			return "SlideR" if lat > 0.0 else "SlideL"
		if fwd < 0.0:
			return "Backpedal"
		return _run_gait(s)
	if has_ball and s < (2.5 if _gait == "DribbleRun" else 2.1):
		return "DribbleRun"
	return _run_gait(s)


## Forward gaits by speed, with a margin so he doesn't flicker between two.
func _run_gait(s: float) -> String:
	var order: Array[String] = ["Walk", "JogM", "Run", "Jog"]
	var up: Array[float] = [1.75, 3.15, 4.45]  # speed to step up from each gait
	var at: int = order.find(_gait)
	var pick: int = 0
	for i in up.size():
		var edge: float = up[i] + (0.2 if at <= i else -0.2)
		if s > edge:
			pick = i + 1
	return order[pick]


## Clears pose goals; the game re-applies what it wants this frame.
func pose_reset() -> void:
	goal_w_r = 0.0
	goal_w_l = 0.0
	lean_goal = 0.0
	elbow_up = false
	face_lock = false
	palm_w_r = 0.0
	palm_w_l = 0.0
	_palm_goals = {}
	lean_twist_goal = 0.0
	lean_amount_goal = 0.0
	crouch_goal = -1.0


## Middle of the palm minus the wrist joint, from the pose as last drawn: lets
## a caller aim the wrist (what the IK places) so the palm lands on a point.
## Same palm definition as tests/body_metrics.gd: 8 cm along the hand from
## the wrist, 2 cm out of the palm side (palm down at rest).
## Limb lengths to the football body's measured proportions (web/stack/skeleton.js,
## for a 1.81 m body): parent bone, child bone, target metres. The mocap rig's
## thighs were 26% short, shins 20% long, forearms 27% long, and the hips sat
## 17% low. Each child's rest offset from its parent is scaled, so the clips'
## rotations still apply and every bone below moves with its segment.
const PROPORTIONS: Array = [
	["LeftUpperLeg", "LeftLowerLeg", 0.45], ["LeftLowerLeg", "LeftFoot", 0.43],
	["RightUpperLeg", "RightLowerLeg", 0.45], ["RightLowerLeg", "RightFoot", 0.43],
	["LeftUpperArm", "LeftLowerArm", 0.29], ["LeftLowerArm", "LeftHand", 0.26],
	["RightUpperArm", "RightLowerArm", 0.29], ["RightLowerArm", "RightHand", 0.26],
]


func _fit_proportions(sk: Skeleton3D) -> void:
	for seg: Array in PROPORTIONS:
		var a: int = sk.find_bone(seg[0])
		var b: int = sk.find_bone(seg[1])
		if a < 0 or b < 0:
			continue
		var gap: Vector3 = sk.get_bone_global_rest(b).origin - sk.get_bone_global_rest(a).origin
		var measured: float = gap.length() * sk.global_transform.basis.get_scale().x
		if measured < 0.01:
			continue
		var rest: Transform3D = sk.get_bone_rest(b)
		rest.origin *= float(seg[2]) / measured
		sk.set_bone_rest(b, rest)


func palm_offset(side: String) -> Vector3:
	if _skeleton == null:
		return Vector3.ZERO
	var lower: int = _skeleton.find_bone(ARM_BONES[side][1])
	var hand_b: int = _skeleton.find_bone(ARM_BONES[side][2])
	if lower < 0 or hand_b < 0:
		return Vector3.ZERO
	var l0: Transform3D = _skeleton.get_bone_global_rest(lower)
	var w0: Transform3D = _skeleton.get_bone_global_rest(hand_b)
	var wb0: Basis = w0.basis.orthonormalized().inverse()
	var axis_l: Vector3 = wb0 * (w0.origin - l0.origin).normalized()
	var palm_l: Vector3 = wb0 * Vector3.DOWN
	var wb: Basis = _skeleton.global_transform.basis * _skeleton.get_bone_global_pose(hand_b).basis.orthonormalized()
	if _pose_tap != null and _pose_tap.call("has_pose"):
		wb = _pose_tap.call("hand_basis", side)  # the hand as drawn, not as animated
	return (wb * axis_l).normalized() * 0.08 + (wb * palm_l).normalized() * 0.02


## Put the middle of a palm on `point`, open toward `face`: solved last, on
## the final body (elbow_hinge.gd), within elbow and wrist limits.
func palm_on(side: String, point: Vector3, face: Vector3, weight: float = 1.0) -> void:
	_palm_goals[side] = {"point": point, "face": face, "weight": weight}


var _palm_goals: Dictionary = {}
var _elbow_hinge: SkeletonModifier3D


## Turn a hand so its palm faces `point` (an open palm toward the ball).
func palm_to(side: String, point: Vector3, weight: float = 1.0) -> void:
	if side == "R":
		palm_at_r = point
		palm_w_r = weight
	else:
		palm_at_l = point
		palm_w_l = weight


## Gameplay hand target in world space. Animation remains the base pose; the
## engine's TwoBoneIK3D reaches only as far as the current action requires.
func hand(side: String, world: Vector3, weight: float = 1.0) -> void:
	if side == "R":
		hand_r = world
		goal_w_r = clampf(weight, 0.0, 1.0)
	else:
		hand_l = world
		goal_w_l = clampf(weight, 0.0, 1.0)


## TwoBoneIK3D rotates the arm chain toward its target; it does not know the
## mesh's comfortable reach. Keep targets inside the measured bone lengths so
## a high contest or an out-of-position catch cannot pull the shoulder long.
func _clamp_hand_target(side: String, world: Vector3) -> Vector3:
	var arm: Dictionary = _ik.get(side, {})
	if arm.is_empty():
		return world
	var root: Vector3 = shoulder_position(side)
	var offset: Vector3 = world - root
	var reach: float = arm_length(side)
	if reach <= 0.0 or offset.length() <= reach:
		return world
	return root + offset.normalized() * reach


func lock_face(point: Vector3) -> void:
	face_lock = true
	face_target = point


## Elbow direction for the IK plane: out and down normally, back when the
## hands go over the head.
func elbow_hint(side: String) -> Vector3:
	var sgn: float = 1.0 if side == "R" else -1.0
	if elbow_up:
		# Hand raised (calling for it, contesting): the elbow points out to the
		# side and a little back and up, not straight back, which would pull
		# the upper arm back past vertical (outside the shoulder's range).
		return right() * sgn * 0.9 - facing() * 0.25 + Vector3.UP * 0.2
	# Hands held in front (stance, swipe, catch): the elbow hangs down and a
	# little out. Pointing it back drags the upper arm behind the body.
	return right() * sgn * 0.55 + Vector3.DOWN * 0.8 - facing() * 0.1


## Point at body height: forward (+) / right (+) / up, in world space.
func body_point(fwd: float, side: float, up: float) -> Vector3:
	return position + facing() * fwd + right() * side + Vector3(0, up, 0)


func face_point(p: Vector3) -> void:
	var to: Vector3 = Vector3(p.x - position.x, 0, p.z - position.z)
	if to.length() > 0.01:
		_model.rotation.y = atan2(to.x, to.z)


func turn_toward(p: Vector3, delta: float) -> void:
	var to: Vector3 = Vector3(p.x - position.x, 0, p.z - position.z)
	if to.length() > 0.01:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(to.x, to.z), minf(1.0, 10.0 * delta))


func facing() -> Vector3:
	return Vector3(sin(_model.rotation.y), 0, cos(_model.rotation.y))


func right() -> Vector3:
	return facing().cross(Vector3.UP)


## Plays a one-off clip over the movement (JumpShot, Layup, Jump, Clap).
## `start` skips into the clip so its key moment lands when the game needs.
func action(anim_name: String, speed: float = 1.0, start: float = 0.0) -> void:
	if not _anim.has_animation(anim_name):
		return
	if anim_name == "Clap":
		_clap_t = CLAP_TIME
	if anim_name in UPPER_ACTIONS:
		_uact_node.animation = anim_name
		_tree.set("parameters/uact_speed/scale", speed)
		_tree.set("parameters/upper/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		return
	var length: float = _anim.get_animation(anim_name).length
	start = clampf(start, 0.0, length - 0.1)
	_act_node.animation = anim_name
	_act_node.use_custom_timeline = start > 0.0
	_act_node.start_offset = start
	_act_node.timeline_length = length - start
	_act_node.stretch_time_scale = false
	_tree.set("parameters/act_speed/scale", speed)
	_tree.set("parameters/shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_action_time = (length - start) / speed


func busy() -> bool:
	return _action_time > 0.0


## World position of a hand bone ("R" / "L"), for carrying the ball.
func hand_position(side: String) -> Vector3:
	if _skeleton == null:
		return position + Vector3(0, 1.2, 0)
	if _pose_tap != null and _pose_tap.call("has_pose"):
		return _pose_tap.call("world", side, "hand")  # as drawn (get_bone_global_pose is pre-modifier)
	var bone: int = _skeleton.find_bone(ARM_BONES[side][2])
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(bone).origin


## What the hand adds to the arm's reach for an open-palm swipe. The palm
## turned to face the ball sits beside the wrist, not beyond it: measured with
## tests/swipe_pose_checks.gd, the palm surface at full stretch lands ~1 cm
## short of the straight-arm wrist distance (0.64 m shoulder to ball centre
## for the 1.81 m model, arm 0.53 m, ball 0.12 m). Not the fingertips' 18 cm.
const PALM_M: float = -0.01


## World position of a shoulder (the upper-arm bone's head).
func shoulder_position(side: String) -> Vector3:
	if _skeleton == null:
		return body_point(0.0, 0.2 if side == "R" else -0.2, 1.45 * _model.scale.y)
	if _pose_tap != null and _pose_tap.call("has_pose"):
		return _pose_tap.call("world", side, "shoulder")  # as drawn: includes lean, twist and crouch
	var bone: int = _skeleton.find_bone(ARM_BONES[side][0])
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(bone).origin


## Shoulder to wrist in metres. _arm_reach is in skeleton space, and the
## skeleton is scaled inside the model (0.375 for the court rig), so it takes
## the skeleton's world scale, not the model's.
func arm_length(side: String) -> float:
	var raw: float = float(_arm_reach.get(side, 0.0))
	if raw <= 0.0 or _skeleton == null:
		return 0.0
	return raw * _skeleton.global_transform.basis.get_scale().x


## Shoulder to the middle of the palm in metres, with the arm as straight as
## the IK lets it go (the measured arm, which already allows for that).
func reach_length(side: String) -> float:
	var arm: float = arm_length(side)
	if arm <= 0.0:
		arm = 0.5 * _model.scale.x
	return arm + PALM_M


## How far inside this player's reach the surface of a ball at `point` is,
## using the closer arm, from the shoulder as drawn this frame. When a swipe
## resolves the trunk lean and the crouch are already in that pose, so they
## are not added again. Positive: the palm gets onto the ball. Negative: short.
## (tests/swipe_pose_checks.gd checks this against where the palm really is.)
func reach_margin(point: Vector3, radius: float = 0.0) -> float:
	var best: float = -INF
	for side: String in ["R", "L"]:
		var gap: float = shoulder_position(side).distance_to(point) - radius
		best = maxf(best, reach_length(side) - gap)
	return best


## World position of an elbow ("R" / "L").
func elbow_position(side: String) -> Vector3:
	if _skeleton == null:
		return position + Vector3(0, 1.1, 0)
	if _pose_tap != null and _pose_tap.call("has_pose"):
		return _pose_tap.call("world", side, "elbow")
	var bone: int = _skeleton.find_bone(ARM_BONES[side][1])
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(bone).origin


func set_height(factor: float) -> void:
	_model.scale = Vector3.ONE * factor


## One transition node holds every gait; switching cross-fades over a
## fifth of a second. A time scale sits above it and a one-shot (jump shot,
## layup, jump) is layered on top. Built per actor because the one-shot's
## clip changes.
func _build_tree() -> void:
	var root: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	var gait: AnimationNodeTransition = AnimationNodeTransition.new()
	gait.xfade_time = 0.2
	for i in GAITS.size():
		var node: AnimationNodeAnimation = AnimationNodeAnimation.new()
		node.animation = GAITS[i]
		root.add_node("g_" + GAITS[i], node)
		root.add_node("seek_" + GAITS[i], AnimationNodeTimeSeek.new())
		root.connect_node("seek_" + GAITS[i], 0, "g_" + GAITS[i])
		gait.add_input(GAITS[i])
		gait.set_input_reset(i, false)  # keep each cycle running through a switch
	root.add_node("gait", gait)
	for i in GAITS.size():
		root.connect_node("gait", i, "seek_" + GAITS[i])
	_act_node = AnimationNodeAnimation.new()
	_act_node.animation = "Jump"
	var shot: AnimationNodeOneShot = AnimationNodeOneShot.new()
	shot.fadein_time = 0.12
	shot.fadeout_time = 0.2
	root.add_node("speed", AnimationNodeTimeScale.new())
	root.add_node("act", _act_node)
	root.add_node("act_speed", AnimationNodeTimeScale.new())
	root.add_node("shot", shot)
	# Carrying the ball: the dribble mocap's arms ride on top of whatever
	# the legs are doing, so he dribbles standing, jogging or sprinting.
	var carry: AnimationNodeBlend2 = AnimationNodeBlend2.new()
	carry.filter_enabled = true
	for bone: String in ARM_TRACKS:
		carry.set_filter_path(NodePath("%GeneralSkeleton:" + bone), true)
	var arms: AnimationNodeAnimation = AnimationNodeAnimation.new()
	arms.animation = "DribbleRun"
	root.add_node("carry", carry)
	root.add_node("d_arms", arms)
	root.add_node("d_seek", AnimationNodeTimeSeek.new())
	root.add_node("d_speed", AnimationNodeTimeScale.new())
	root.connect_node("d_seek", 0, "d_arms")
	root.connect_node("d_speed", 0, "d_seek")
	# Reaches and passes play on the upper body only; the legs keep moving.
	var upper: AnimationNodeOneShot = AnimationNodeOneShot.new()
	upper.fadein_time = 0.1
	upper.fadeout_time = 0.2
	upper.filter_enabled = true
	for bone: String in ARM_TRACKS + ["Spine", "Chest", "UpperChest", "Neck", "Head"]:
		upper.set_filter_path(NodePath("%GeneralSkeleton:" + bone), true)
	_uact_node = AnimationNodeAnimation.new()
	_uact_node.animation = "Reach"
	root.add_node("upper", upper)
	root.add_node("uact", _uact_node)
	root.add_node("uact_speed", AnimationNodeTimeScale.new())
	root.connect_node("speed", 0, "gait")
	root.connect_node("carry", 0, "speed")
	root.connect_node("carry", 1, "d_speed")
	root.connect_node("uact_speed", 0, "uact")
	root.connect_node("upper", 0, "carry")
	root.connect_node("upper", 1, "uact_speed")
	root.connect_node("act_speed", 0, "act")
	root.connect_node("shot", 0, "upper")
	root.connect_node("shot", 1, "act_speed")
	root.connect_node("output", 0, "shot")
	_tree = AnimationTree.new()
	_tree.tree_root = root
	_model.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(_anim)
	_tree.active = true


func _build_arm_ik(sk: Skeleton3D, side: String) -> void:
	var bones: Array = ARM_BONES[side]
	if sk.find_bone(bones[0]) < 0 or sk.find_bone(bones[2]) < 0:
		return
	var root_rest: Vector3 = sk.get_bone_global_rest(sk.find_bone(bones[0])).origin
	var middle_rest: Vector3 = sk.get_bone_global_rest(sk.find_bone(bones[1])).origin
	var end_rest: Vector3 = sk.get_bone_global_rest(sk.find_bone(bones[2])).origin
	_arm_reach[side] = (root_rest.distance_to(middle_rest) + middle_rest.distance_to(end_rest)) * 0.94
	var target: Marker3D = Marker3D.new()
	var pole: Marker3D = Marker3D.new()
	target.top_level = true
	pole.top_level = true
	add_child(target)
	add_child(pole)
	var ik: TwoBoneIK3D = TwoBoneIK3D.new()
	sk.add_child(ik)
	ik.setting_count = 1
	ik.set_root_bone_name(0, bones[0])
	ik.set_middle_bone_name(0, bones[1])
	ik.set_end_bone_name(0, bones[2])
	ik.set_pole_direction(0, POLE_AXIS)
	ik.set_target_node(0, ik.get_path_to(target))
	ik.set_pole_node(0, ik.get_path_to(pole))
	ik.influence = 0.0
	_ik[side] = {"ik": ik, "target": target, "pole": pole}
