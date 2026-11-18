extends Node3D
## Dumps the game's final joint positions (after every modifier) for each
## mocap gait, with and without the hand-placement fix, in the same body
## frame and scale as tools/court_assets/dump_source_joints.py.
##   godot --headless --fixed-fps 60 tests/court_joint_dump.tscn -- <out.json>

const Actor = preload("res://scripts/court/court_actor.gd")
const Tap = preload("res://tests/court_joint_tap.gd")
const JOINTS: Dictionary = {"hips": "Hips", "chest": "UpperChest", "neck": "Neck", "head": "Head",
	"l_shoulder": "LeftUpperArm", "l_elbow": "LeftLowerArm", "l_wrist": "LeftHand",
	"r_shoulder": "RightUpperArm", "r_elbow": "RightLowerArm", "r_wrist": "RightHand",
	"l_hip": "LeftUpperLeg", "l_knee": "LeftLowerLeg", "l_ankle": "LeftFoot", "l_toe": "LeftToes",
	"r_hip": "RightUpperLeg", "r_knee": "RightLowerLeg", "r_ankle": "RightFoot", "r_toe": "RightToes"}
## clip -> [velocity x, z (m/s), has ball, defending]
const PLAN: Dictionary = {"JogM": [0.0, -2.68, false, false], "DribbleRun": [0.0, -1.43, true, false],
	"Run": [0.0, -3.6, false, false], "SlideR": [2.63, 0.0, false, true], "SlideL": [-2.24, 0.0, false, true],
	"Backpedal": [0.0, 1.22, false, true]}

var _out: Dictionary = {}
var _actor: Node3D
var _sk: Skeleton3D
var _latest: Dictionary = {}


func _ready() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	for variant: String in ["raw", "fixed"]:
		Actor.arm_fix_enabled = variant == "fixed"
		for clip: String in PLAN:
			await _record(clip, variant)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(_out))
	f.close()
	get_tree().quit(0)


## Called by the tap modifier with the pose that will actually be drawn.
func final_pose(sk: Skeleton3D) -> void:
	var model: Node3D = _actor.get("_model")
	var inv: Transform3D = Transform3D(Basis(Vector3.UP, model.rotation.y), _actor.global_position).affine_inverse()
	var row: Dictionary = {}
	for joint: String in JOINTS:
		var p: Vector3 = inv * (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(JOINTS[joint])).origin)
		row[joint] = [snappedf(p.x / 1.81, 0.0001), snappedf(p.y / 1.81, 0.0001), snappedf(p.z / 1.81, 0.0001)]
	_latest = row


func _record(clip: String, variant: String) -> void:
	_actor = Actor.new()
	add_child(_actor)
	_actor.setup("", {}, 0, 0.0)
	_sk = _actor.get("_skeleton")
	var tap: SkeletonModifier3D = Tap.new()
	tap.qa = self
	_sk.add_child(tap)
	var plan: Array = PLAN[clip]
	var samples: Array = []
	var anim_len: float = (_actor.get("_anim") as AnimationPlayer).get_animation(clip).length
	for i in 60 * 5:
		_actor.pose_reset()
		_actor.team = 1 if plan[3] else 0
		_actor.has_ball = plan[2]
		if plan[3]:
			_actor.lock_face(_actor.position + Vector3(0, 0, -8.0))
		_actor.move_with(Vector3(plan[0], 0, plan[1]), 1.0 / 60.0, 16.0)
		_actor.animate(1.0 / 60.0)
		await get_tree().process_frame
		if i < 60 * 3 or _latest.is_empty() or str(_actor.get("_gait")) != clip:
			continue
		var t: float = float(_actor.get("_drib_t"))
		if clip != "DribbleRun":
			t = fposmod(float(CourtPlayerModel.CLIP_STRIKE[clip]) + float(_actor.get("_stride")) * anim_len, anim_len)
		samples.append({"t": t, "j": _latest})
	print("GAME ", variant, " ", clip, " ", samples.size(), " samples")
	if not _out.has(clip):
		_out[clip] = {"length": anim_len}
	(_out[clip] as Dictionary)[variant] = samples
	_actor.queue_free()
	await get_tree().process_frame
