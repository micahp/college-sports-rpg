extends Node3D
## Court actor (every game modifier on) playing the retargeted clips: saves
## front and side frames and prints the drawn ankle height through the action.
##   godot --fixed-fps 60 --rendering-driver opengl3 tools/mocap/shots.tscn -- <out dir>

const Actor = preload("res://scripts/court/court_actor.gd")
const Tap = preload("res://tests/court_joint_tap.gd")
const SHOTS: Dictionary = {"JumpShot": [0.3, 0.7, 1.0, 1.2, 1.4], "Layup": [0.3, 0.6, 0.9, 1.1, 1.4], "DribbleRun": [0.1, 0.3, 0.5, 0.7, 0.9]}

var _actor: Node3D
var _ankle: float = 0.0
var _hips: float = 0.0
var _dist: float = 4.6
var _feet_cam: bool = false
var _gap: float = 0.0
var _foot_rows: PackedStringArray = []


func final_pose(sk: Skeleton3D) -> void:
	var a: float = INF
	for b: String in ["LeftFoot", "RightFoot"]:
		a = minf(a, (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(b)).origin).y)
	_ankle = a
	_hips = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Hips")).origin).y
	# drawn distance between each ankle (shin end) and the foot control bone the shoe is skinned to, and the shoe pitch
	var g: float = 0.0
	var info: PackedStringArray = []
	for pr: Array in [["LeftFoot", "Foot.L", "Foot.L_end"], ["RightFoot", "Foot.R", "Foot.R_end"]]:
		var ank: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(pr[0])).origin
		var ctl: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(pr[1])).origin
		var toe: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(pr[2])).origin
		g = maxf(g, ank.distance_to(ctl))
		info.append("%s gap %.3f ctl_y %.3f toe_y %.3f pitch %.0f" % [pr[1], ank.distance_to(ctl), ctl.y, toe.y, rad_to_deg(atan2(toe.y - ctl.y, Vector2(toe.x - ctl.x, toe.z - ctl.z).length()))])
	_gap = g
	_foot_rows = info


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://mocap_shots"
	CourtPlayerModel.mocap_retarget = not args.has("old")
	var close: bool = args.has("close")
	_dist = 2.4 if close else 4.6
	_feet_cam = args.has("feet")
	if _feet_cam:
		_dist = 1.5
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(420, 520))
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.72, 0.82)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	(floor_mesh.mesh as PlaneMesh).size = Vector2(40, 40)
	var fm: StandardMaterial3D = StandardMaterial3D.new()
	fm.albedo_color = Color(0.79, 0.6, 0.36)
	floor_mesh.material_override = fm
	add_child(floor_mesh)
	var cam: Camera3D = Camera3D.new()
	add_child(cam)
	for clip: String in SHOTS:
		for view: String in ["front", "side"]:
			await _run(clip, view, cam, out)
	get_tree().quit(0)


func _run(clip: String, view: String, cam: Camera3D, out: String) -> void:
	_actor = Actor.new()
	add_child(_actor)
	_actor.setup("", {"Shirt": Color(0.92, 0.72, 0.3), "Pants": Color(0.12, 0.2, 0.42), "Skin": Color(0.48, 0.34, 0.24), "Socks": Color(0.95, 0.95, 0.95)}, 0, 0.0)
	var sk: Skeleton3D = _actor.get("_skeleton")
	var tap: SkeletonModifier3D = Tap.new()
	tap.qa = self
	sk.add_child(tap)
	var dribble: bool = clip == "DribbleRun"
	var times: Array = SHOTS[clip]
	var start: int = 40
	var shot: int = 0
	var lo: float = INF
	var hi: float = -INF
	var rows: PackedStringArray = []
	for i in 60 * 3:
		_actor.pose_reset()
		_actor.has_ball = dribble
		if dribble:
			_actor.move_with(Vector3(0, 0, 1.43), 1.0 / 60.0, 16.0)
		else:
			_actor.lock_face(_actor.position + Vector3(0, 0, 8.0))
		if i == start and not dribble:
			_actor.action(clip)
		_actor.animate(1.0 / 60.0)
		var p: Vector3 = _actor.position
		if view == "front":
			cam.position = p + Vector3(0, 1.1, _dist)
		else:
			cam.position = p + Vector3(_dist, 1.1, 0)
		if _feet_cam:
			cam.position.y = 0.35
		cam.look_at(p + Vector3(0, 0.15 if _feet_cam else (0.95 if _dist < 3.0 else 1.0), 0))
		await get_tree().process_frame
		var at: float = (i - start) / 60.0
		if i >= start and at <= 1.6:
			lo = minf(lo, _ankle)
			hi = maxf(hi, _ankle)
			if view == "side" and (i - start) % 12 == 0:
				print("FOOT %s t=%.1f %s" % [clip, at, " | ".join(_foot_rows)])
			if view == "front" and (i - start) % 6 == 0:
				rows.append("%.1f:%.2f/%.2f" % [at, _ankle, _hips])
		if shot < times.size() and i >= start and at >= float(times[shot]):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s_%s_%.2f.png" % [out, clip, view, float(times[shot])])
			shot += 1
	if view == "front":
		print("DRAWN %s ankle range %.3f m (low %.3f high %.3f) | t:ankle/hips %s" % [clip, hi - lo, lo, hi, " ".join(rows)])
	_actor.queue_free()
	await get_tree().process_frame
