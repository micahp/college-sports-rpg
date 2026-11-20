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
var pressure_stance := true
var contest_lift := 0.0
var goal_w_r: float = 0.0
var goal_w_l: float = 0.0
var lean_now: float = 0.0
var lean_goal: float = 0.0
var elbow_up: bool = false
var rebound_fold := 0.0
var rebound_hands := false
var guard_elbow: bool = false  # set by the game for a defender holding ball pressure: elbows down, in, bent
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
var mocap_swipe_active: bool = false
var _reach_lean: SkeletonModifier3D
var face_lock: bool = false
var face_target: Vector3 = Vector3.ZERO

## Which local axis of the forearm bone the elbow bends toward on this rig.
const POLE_AXIS: int = SkeletonModifier3D.SECONDARY_DIRECTION_PLUS_Z
## Defender stance, from the CMU defenders (assets/court/defense_102_*.glb, slide_*.glb, measured by
## tools/mocap/def_arms.gd): the hands hang low and wide beside the body and keep moving. Wrist offset from
## the shoulder midpoint in arm lengths (out, up, forward); sway amplitude on each axis; the elbow pole
## (out, up, back) that gives that pose the recording's arm roll (see elbow_hint).
const STANCE_WRIST: Vector3 = Vector3(0.7, -0.6, -0.1)
const STANCE_SWAY: Vector3 = Vector3(0.2, 0.2, 0.25)
const STANCE_ELBOW: Vector3 = Vector3(0.4, -0.35, 0.25)
## Standing stance uses a held frame of the defensive shuffle.
const STANCE_ARMS_FROM_HANDS: bool = false
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
## Action clips whose trunk matches their recording on the drawn player without
## torso_posture (tests/jumpshot_fidelity: JumpShot within 1 deg of the CMU
## trunk pitch and roll at every moment; with torso_posture the gather lean was
## cut from 19 to 6 deg). Only clips measured this way belong here.
const TRUNK_VERIFIED: Array[StringName] = [&"JumpShot"]
## Blend times of the full-body action one-shot (JumpShot, Layup, ...).
const SHOT_FADE_IN: float = 0.12
const SHOT_FADE_OUT: float = 0.2
const UPPER_ACTIONS: Array[String] = ["Reach", "Pass", "Clap", "SwipeCMU", "SwipeCMU_R", "SwipeCMU_L"]
const GRAVITY: float = 9.81
const STATURE: float = 1.81  # the court model's standing height (top of the head)
## Thigh + shin + hips-to-head, the sum the football segments add up to (0.45 + 0.43
## + 0.70). The court player is scaled so its own sum equals this.
const LEG_TORSO: float = 1.58
const JOINT_HEIGHT: float = 1.61  # ankle-to-head joint, for the dribble scale
const BOUNCE: float = 0.78  # share of its speed the ball keeps off the floor
const SWIPE_BLEND_OUT: float = 0.22
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
var _swipe_node: AnimationNodeAnimation
var _swipe_oneshot: AnimationNodeOneShot
var _swipe_time: float = 0.0
var _swipe_elapsed: float = 0.0
var _swipe_duration: float = 0.0
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
var _stride_arms := preload("res://scripts/court/defender_stride_arms.gd").new()
var _torso_posture: SkeletonModifier3D
var _gait: String = ""
var _braking := false
var _student_feet: StudentFeet
var _feet: SkeletonModifier3D
var _crouch: SkeletonModifier3D
var _crouch_now: float = 0.0
var _body_floor: SkeletonModifier3D
var _stride: float = 0.0  # 0..1 through the stride, 0 = left foot lands
var _switch_wait: float = 0.0
var _action_time: float = 0.0
var _stance_hands: bool = false  # this frame the default stance placed the hands (see elbow_hint)
var _sway_t: float = 0.0
var _guard_amt: float = 0.0
var _stance_arms_amt: float = 0.0  # 1 while the standing stance plays the recorded defender arms
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
		_normalise_height(sk)  # before anything measures the limbs (reach, feet, arms)
		CourtPlayerModel.balance_idle_once(sk)  # the Idle clip, solved on this rest pose
		_crouch = Crouch.new()
		sk.add_child(_crouch)
		# Feet first: lift any foot the animation leaves under the floor.
		var feet: SkeletonModifier3D = FootFloor.new()
		feet.set("toe_rest", 0.012)
		feet.set("ankle_rest", sk.get_bone_global_rest(sk.find_bone("LeftFoot")).origin.y - 0.02)
		sk.add_child(feet)
		_feet = feet
		if sk.find_bone("Foot.L") >= 0:
			_student_feet = StudentFeet.new()
			sk.add_child(_student_feet)
			var body: SkeletonModifier3D = FootFloor.new()
			body.set("body_mode", true)
			body.set("_hips", -1)
			sk.add_child(body)
			_body_floor = body
		_torso_posture = TorsoPosture.new()
		sk.add_child(_torso_posture)  # before arm IK
		_reach_lean = ReachLean.new()  # after the posture fix (it would undo it), before the arms
		sk.add_child(_reach_lean)
		_stride_arms.influence = 0.0
		sk.add_child(_stride_arms)
		for side: String in ["R", "L"]:
			_build_arm_ik(sk, side)  # used only to put dribbling hands where the performer's were
		_arm_clearance = ArmClearance.new()  # after the IK, so it has the last word on the elbows
		sk.add_child(_arm_clearance)
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
	_braking = desired.is_zero_approx()
	vel = vel.move_toward(desired, accel * delta)
	position += vel * delta


func stop() -> void:
	vel = Vector3.ZERO


## Called once per frame by the game after movement and pose goals.
func animate(delta: float) -> void:
	_swipe_time = maxf(0.0, _swipe_time - delta)
	var swipe_chain_active: bool = mocap_swipe_active or _swipe_time > 0.0
	var swipe_pose_weight: float = 0.0
	if _swipe_duration > 0.0 and _swipe_elapsed < _swipe_duration + SWIPE_BLEND_OUT:
		_swipe_elapsed = minf(_swipe_duration + SWIPE_BLEND_OUT, _swipe_elapsed + delta)
		var fade_out: float = 1.0 - smoothstep(_swipe_duration, _swipe_duration + SWIPE_BLEND_OUT, _swipe_elapsed)
		swipe_pose_weight = fade_out
	stagger = maxf(0.0, stagger - delta)
	beaten = maxf(0.0, beaten - delta)
	reach_cd = maxf(0.0, reach_cd - delta)
	# Defenders play in a stance: knees bent, hands up and out, unless the
	# game has given them something to do with their hands.
	var stance: bool = pressure_stance and face_lock and team == 1 and not has_ball and _action_time <= 0.0 and _clap_t <= 0.0
	_stance_hands = false
	# Use the held guard pose only while stationary. Walking, recovery runs
	# and lateral footwork keep the shoulder and arm motion of their gait.
	var idle_hands: bool = stance and goal_w_r <= 0.0 and goal_w_l <= 0.0
	var recorded_arms: bool = idle_hands and _gait != "Idle" and _gait != ""
	_guard_amt = move_toward(_guard_amt, 0.0 if recorded_arms else (1.0 if pressure_stance and team == 1 and face_lock else 0.0), delta * 6.0)
	_tree.set("parameters/guard/blend_amount", _guard_amt)
	_stance_arms_amt = move_toward(_stance_arms_amt, 1.0 if idle_hands else 0.0, delta * 6.0)
	_tree.set("parameters/stance_arms/blend_amount", _stance_arms_amt)
	if STANCE_ARMS_FROM_HANDS and idle_hands and not recorded_arms:
		# Standing stance: hands low and wide beside the body as the recorded defenders hold them,
		# swaying a little (the recordings' hands are never still).
		var mid: Vector3 = (shoulder_position("R") + shoulder_position("L")) * 0.5
		var arm_len: float = arm_length("R") / 0.94  # shoulder to wrist (the measured reach is 94% of it)
		_sway_t += delta
		var phase: float = float(get_instance_id() % 628) * 0.01
		for side: String in ["R", "L"]:
			var sgn: float = 1.0 if side == "R" else -1.0
			var ph: float = phase + (0.0 if side == "R" else 2.1)
			var out: float = STANCE_WRIST.x + STANCE_SWAY.x * sin(1.9 * _sway_t + ph)
			var up: float = STANCE_WRIST.y + STANCE_SWAY.y * sin(2.6 * _sway_t + ph * 1.3)
			var fwd: float = STANCE_WRIST.z + STANCE_SWAY.z * sin(1.4 * _sway_t + ph * 2.1)
			var p: Vector3 = mid + (right() * sgn * out + Vector3.UP * up + facing() * fwd) * arm_len
			if side == "R":
				hand_r = p
			else:
				hand_l = p
		goal_w_r = 0.9
		goal_w_l = 0.9
		_stance_hands = true
	# The side slide is already a low shuffle; the crouch is for standing and backing up.
	var crouch_want: float = 0.55 if stance and (_gait == "Idle" or _gait == "Backpedal") else 0.0
	if crouch_goal >= 0.0:
		crouch_want = crouch_goal
	_crouch_now = move_toward(_crouch_now, crouch_want, delta * (6.0 if crouch_goal >= 0.0 else 4.0))
	_lean_amount = move_toward(_lean_amount, lean_amount_goal, delta * 7.0)
	_lean_twist = move_toward(_lean_twist, lean_twist_goal, delta * 9.0)
	if _reach_lean != null:
		_reach_lean.set("target", lean_at)
		_reach_lean.set("disabled", swipe_chain_active)
		_reach_lean.influence = 0.0 if swipe_chain_active else 1.0
		_reach_lean.set("amount", 0.0 if swipe_chain_active else _lean_amount)
		_reach_lean.set("twist", 0.0 if swipe_chain_active else _lean_twist)
	if _elbow_hinge != null:
		_elbow_hinge.active = not swipe_chain_active and (not idle_hands or not _palm_goals.is_empty())
		_elbow_hinge.influence = 0.0 if swipe_chain_active else 1.0
		_elbow_hinge.set("rebound_grip", rebound_hands)
		_elbow_hinge.set("clap_forward", facing() if _clap_t > 0.0 else Vector3.ZERO)
		_elbow_hinge.set("palm_goal", {} if swipe_chain_active else _palm_goals.duplicate())
		# Contest: the arm IK is the one owner of the elbow (docs/animation/OWNERSHIP.md).
		_elbow_hinge.set("keep_swivel", contest_lift > 0.001)
	# Contest palms twist about the forearm first (hand_aim.gd).
	for aim: SkeletonModifier3D in [_hand_aim, _hand_aim_l]:
		if aim != null:
			aim.set("twist_first", contest_lift > 0.001)
	if _arm_clearance != null:
		_arm_clearance.active = not swipe_chain_active
		_arm_clearance.influence = 0.0 if swipe_chain_active else 1.0
		_arm_clearance.set("skip_arms", contest_lift > 0.001)
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
		if swipe_chain_active:
			(arm["ik"] as SkeletonModifier3D).influence = 0.0
			var swipe_aim: SkeletonModifier3D = _hand_aim if side == "R" else _hand_aim_l
			if swipe_aim != null:
				swipe_aim.set("weight", 0.0)
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
	if _student_feet != null:
		var forward_stride := _gait in ["Walk", "JogM", "Jog", "Run", "DribbleRun"] and _action_time <= 0.0 and not swipe_chain_active
		_student_feet.stride_amount = move_toward(_student_feet.stride_amount, float(forward_stride), delta * 5.0)
	var forward_guard := idle_hands and _gait in ["Walk", "JogM", "Run", "Jog"]
	# Keep the trunk correction active over locomotion too; the bound is applied
	# in both pitch and side-bend, so it does not pull the shoulders across the chest.
	if _torso_posture != null:
		# While a clip whose trunk was verified against its recording plays, the
		# clip owns the trunk (TRUNK_VERIFIED). torso_posture stays on elsewhere.
		var trunk_owned: bool = _action_time > 0.0 and _act_node != null and _act_node.animation in TRUNK_VERIFIED
		# Fade with the clip's own blend in and out (the "shot" one-shot), so the
		# trunk hands over continuously instead of keeping part of the correction.
		_torso_posture.influence = move_toward(_torso_posture.influence, 0.0 if trunk_owned else 1.0,
			delta / (SHOT_FADE_IN if trunk_owned else SHOT_FADE_OUT))
	_stride_arms.forward = facing()
	_stride_arms.influence = 0.0 if swipe_chain_active else move_toward(_stride_arms.influence, float(forward_guard), delta * 8.0)
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
var _arm_clearance: SkeletonModifier3D
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
	var k: float = JOINT_HEIGHT * _model.scale.x / float(table.get("stature", 1.45))
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
	if _braking and _gait in ["Idle", "Walk", "JogM", "Run", "Jog", "DribbleRun"]:
		# Finish the moving stride, then blend to the standing pose through
		# the last braking step. Cycling through slower clips resets the feet.
		return "Idle" if s < 1.8 else _gait
	if pressure_stance and face_lock and team == 1:
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
	rebound_fold = 0.0
	rebound_hands = false
	guard_elbow = false
	face_lock = false
	palm_w_r = 0.0
	palm_w_l = 0.0
	_palm_goals = {}
	lean_twist_goal = 0.0
	lean_amount_goal = 0.0
	crouch_goal = -1.0
	mocap_swipe_active = false


## Middle of the palm minus the wrist joint, from the pose as last drawn: lets
## a caller aim the wrist (what the IK places) so the palm lands on a point.
## Same palm definition as tests/body_metrics.gd: 8 cm along the hand from
## the wrist, 2 cm out of the palm side (palm down at rest).
## Proportions come from the character import (tools/character_rig_fit.gd).
## Here the court player is scaled so its ankle-to-head joint height reads
## JOINT_HEIGHT, the measure the football segments add up to.
func _normalise_height(sk: Skeleton3D) -> void:
	var hips: int = sk.find_bone("Hips")
	var head: int = sk.find_bone("Head")
	var thigh_b: int = sk.find_bone("LeftLowerLeg")
	var shin_end: int = sk.find_bone("LeftFoot")
	if shin_end < 0:
		shin_end = sk.find_bone("LowerLeg.L_end")
	if hips < 0 or head < 0 or thigh_b < 0 or shin_end < 0:
		return
	var g := func(a: int, b: int) -> float:
		return (sk.get_bone_global_rest(b).origin - sk.get_bone_global_rest(a).origin).length()
	var legs_torso: float = g.call(sk.find_bone("LeftUpperLeg") if sk.find_bone("LeftUpperLeg") >= 0 else sk.find_bone("UpperLeg.L"), thigh_b) 		+ g.call(thigh_b, shin_end) + g.call(hips, head)
	var world: float = legs_torso * sk.global_transform.basis.get_scale().x
	if world > 0.1:
		_base_scale = _model.scale.x * LEG_TORSO / world
		_model.scale = Vector3.ONE * _base_scale


var _base_scale: float = 1.0  # model scale that makes the player JOINT_HEIGHT tall


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
	# arm_length is 94% of the bone chain, which keeps every arm bent at least
	# ~40 deg. A shot contest is arms straight up: aim past the chain so the arm
	# stays straight even while the jump lifts the shoulder ahead of the goal
	# (the goal is built from last frame's drawn shoulder).
	if contest_lift > 0.001:
		reach *= lerpf(1.0, 1.12 / 0.94, clampf(contest_lift, 0.0, 1.0))
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
	if rebound_hands:
		var reach := right() * sgn * 0.55 + facing() * 0.80 + Vector3.DOWN * 0.30
		var cradle := right() * sgn * 0.50 + Vector3.DOWN * 0.85
		return reach.lerp(cradle, rebound_fold)
	if contest_lift > 0.001:
		# A shot contest is arms straight up. The arm is nearly extended, so the
		# pole only picks which way the slight elbow bend points: forward and a
		# little out, as in the reference photos. The old pole (out and DOWN)
		# pulled the elbows out to the side at shoulder height (flex 71-86 deg).
		return right() * sgn * 0.30 + facing() * 0.40 + Vector3.UP * 0.25
	if elbow_up:
		# Hand raised (calling for it, contesting): the elbow points out to the
		# side and a little back and up, not straight back, which would pull
		# the upper arm back past vertical (outside the shoulder's range).
		return right() * sgn * 0.9 - facing() * 0.25 + Vector3.UP * 0.2
	# The defender's default stance (STANCE_WRIST). The pole decides how the IK swivels the arm, and with it
	# where the thumbs point: an elbow hanging straight down had both thumbs at the floor in the slide.
	# Only for that stance, so swipes and catches keep their pole.
	if _stance_hands:
		return right() * sgn * STANCE_ELBOW.x + Vector3.UP * STANCE_ELBOW.y - facing() * STANCE_ELBOW.z
	if guard_elbow:
		# Ball pressure: elbow down by the ribs and a little back, so the forearm reaches out and the arm bends.
		return right() * sgn * 0.2 + Vector3.DOWN * 0.9 - facing() * 0.3
	# Hands held in front (swipe, catch): the elbow hangs down and a
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
		if anim_name in ["SwipeCMU_R", "SwipeCMU_L"]:
			_swipe_node.animation = _capture_swipe_entry_pose(anim_name)
			_swipe_oneshot.fadein_time = 0.0
			_tree.set("parameters/swipe_speed/scale", speed)
			_tree.set("parameters/swipe/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			_swipe_duration = _anim.get_animation(anim_name).length / maxf(speed, 0.01)
			_swipe_elapsed = 0.0
			_swipe_time = _swipe_duration + SWIPE_BLEND_OUT
			for side: String in ["R", "L"]:
				var arm: Dictionary = _ik.get(side, {})
				if not arm.is_empty():
					(arm["ik"] as SkeletonModifier3D).influence = 0.0
				var aim: SkeletonModifier3D = _hand_aim if side == "R" else _hand_aim_l
				if aim != null:
					aim.set("weight", 0.0)
		else:
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


## A recovered loose ball takes both hands, even when the recovering
## defender initiated the poke and still has a swipe follow-through.
func release_swipe() -> void:
	if _tree != null and _swipe_time > 0.0:
		_tree.set("parameters/swipe/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	_swipe_time = 0.0
	_swipe_duration = 0.0
	mocap_swipe_active = false


## Give the swipe's first animation keys the rotations currently visible on this
## actor, then blend into the authored joint chain. The transition is pose-to-
## pose; no IK target or pole is allowed to steer the swipe itself.
func _capture_swipe_entry_pose(anim_name: String) -> StringName:
	const ENTRY_BLEND: float = 0.18
	if _skeleton == null or _anim == null:
		return StringName(anim_name)
	_skeleton.force_update_all_bone_transforms()
	var clip: Animation = _anim.get_animation(anim_name).duplicate()
	var entry_end: float = minf(ENTRY_BLEND, clip.length)
	for track in clip.get_track_count():
		if clip.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var bone: String = str(clip.track_get_path(track).get_concatenated_subnames())
		var index: int = _skeleton.find_bone(bone)
		if index < 0:
			continue
		var start_q: Quaternion = _skeleton.get_bone_pose_rotation(index)
		var first_q: Quaternion = clip.rotation_track_interpolate(track, 0.0)
		var correction := start_q * first_q.inverse()
		for key in clip.track_get_key_count(track):
			var t := clip.track_get_key_time(track, key)
			if t >= entry_end:
				break
			var recorded: Quaternion = clip.track_get_key_value(track, key)
			var offset := correction.slerp(Quaternion.IDENTITY, smoothstep(0.0, entry_end, t))
			clip.track_set_key_value(track, key, (offset * recorded).normalized())
	var runtime_library := AnimationLibrary.new()
	runtime_library.add_animation("Swipe", clip)
	if _anim.has_animation_library("SwipeRuntime"):
		_anim.remove_animation_library("SwipeRuntime")
	_anim.add_animation_library("SwipeRuntime", runtime_library)
	return StringName("SwipeRuntime/Swipe")


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


## Scale relative to the normal player: 1.0 is the football proportions, 1.08 is 8% taller.
func set_height(factor: float) -> void:
	_model.scale = Vector3.ONE * _base_scale * factor


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
	shot.fadein_time = SHOT_FADE_IN
	shot.fadeout_time = SHOT_FADE_OUT
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
	# Generic reach/pass/clap actions stay on the arms so they cannot bend the
	# idle back. Swipe has a separate full upper-body lane below.
	var upper: AnimationNodeOneShot = AnimationNodeOneShot.new()
	upper.fadein_time = 0.1
	upper.fadeout_time = 0.2
	upper.filter_enabled = true
	for bone: String in ARM_TRACKS:
		upper.set_filter_path(NodePath("%GeneralSkeleton:" + bone), true)
	_uact_node = AnimationNodeAnimation.new()
	_uact_node.animation = "Reach"
	root.add_node("upper", upper)
	root.add_node("uact", _uact_node)
	root.add_node("uact_speed", AnimationNodeTimeScale.new())
	# Swipe owns the pelvis-to-hand chain as one action. The ordinary one-shot
	# stays arm-only, so a pass or reach cannot bend the idle back.
	_swipe_oneshot = AnimationNodeOneShot.new()
	_swipe_oneshot.fadein_time = 0.0
	_swipe_oneshot.fadeout_time = SWIPE_BLEND_OUT
	_swipe_oneshot.filter_enabled = true
	for bone: String in ARM_TRACKS + ["LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot", "Hips", "Spine", "Chest", "UpperChest", "Neck", "Head"]:
		_swipe_oneshot.set_filter_path(NodePath("%GeneralSkeleton:" + bone), true)
	_swipe_node = AnimationNodeAnimation.new()
	_swipe_node.animation = "SwipeCMU_R"
	root.add_node("swipe", _swipe_oneshot)
	root.add_node("swipe_action", _swipe_node)
	root.add_node("swipe_speed", AnimationNodeTimeScale.new())
	root.connect_node("speed", 0, "gait")
	# Anchor the shoulders and arms before defensive IK. Otherwise the swing
	# from each locomotion clip changes the pose under the same hand target.
	var guard := AnimationNodeBlend2.new()
	guard.filter_enabled = true
	for bone: String in ARM_TRACKS:
		guard.set_filter_path(NodePath("%GeneralSkeleton:" + bone), true)
	var neutral := AnimationNodeAnimation.new()
	neutral.animation = "Idle"
	var stance_bp := AnimationNodeAnimation.new()
	stance_bp.animation = "GuardHold"
	var stance_arms := AnimationNodeBlend2.new()
	stance_arms.filter_enabled = true
	for bone: String in ARM_TRACKS:
		stance_arms.set_filter_path(NodePath("%GeneralSkeleton:" + bone), true)
	root.add_node("guard", guard)
	root.add_node("neutral", neutral)
	root.add_node("stance_bp", stance_bp)
	root.add_node("stance_arms", stance_arms)
	root.connect_node("guard", 0, "speed")
	root.connect_node("guard", 1, "stance_arms")
	root.connect_node("stance_arms", 0, "neutral")
	root.connect_node("stance_arms", 1, "stance_bp")
	root.connect_node("carry", 0, "guard")
	root.connect_node("carry", 1, "d_speed")
	root.connect_node("uact_speed", 0, "uact")
	root.connect_node("upper", 0, "carry")
	root.connect_node("upper", 1, "uact_speed")
	root.connect_node("swipe_speed", 0, "swipe_action")
	root.connect_node("swipe", 0, "upper")
	root.connect_node("swipe", 1, "swipe_speed")
	root.connect_node("act_speed", 0, "act")
	root.connect_node("shot", 0, "swipe")
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
