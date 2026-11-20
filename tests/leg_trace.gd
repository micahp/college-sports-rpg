extends Node
## Traces the contesting defender's legs through every skeleton modifier, per
## frame: a tap after each stage records hip height and knee flexion, so you can
## see which layer folds the legs. Same setup as tests/contest_views.gd.
##   godot --headless --path . res://tests/leg_trace.tscn -- [from=26] [to=60] [stages]
## Without `stages` it prints one line per frame (animation-only vs drawn).
const CourtScene: PackedScene = preload("res://scenes/court/court_game.tscn")
const CourtGame = preload("res://scripts/court/court_game.gd")
const RELEASE_AT: int = 30


class LegTap extends SkeletonModifier3D:
	var ids: Dictionary = {}
	var hip_y := 0.0
	var knee := {"L": 0.0, "R": 0.0}
	var foot_y := {"L": 0.0, "R": 0.0}

	func _process_modification_with_delta(_delta: float) -> void:
		var sk: Skeleton3D = get_skeleton()
		if sk == null:
			return
		if ids.is_empty():
			for b in ["Hips", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"]:
				ids[b] = sk.find_bone(b)
		sk.force_update_all_bone_transforms()
		var g := sk.global_transform
		hip_y = (g * sk.get_bone_global_pose(ids["Hips"]).origin).y
		for side in ["L", "R"]:
			var p: String = "Left" if side == "L" else "Right"
			var a: Vector3 = g * sk.get_bone_global_pose(ids[p + "UpperLeg"]).origin
			var k: Vector3 = g * sk.get_bone_global_pose(ids[p + "LowerLeg"]).origin
			var f: Vector3 = g * sk.get_bone_global_pose(ids[p + "Foot"]).origin
			knee[side] = 180.0 - rad_to_deg((a - k).normalized().angle_to((f - k).normalized()))
			foot_y[side] = f.y

	func line() -> String:
		return "hip_y=%.2f kneeL=%3.0f kneeR=%3.0f footL_y=%.2f footR_y=%.2f" % [hip_y, knee["L"], knee["R"], foot_y["L"], foot_y["R"]]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var from := 26
	var to := 60
	for a in args:
		if a.begins_with("from="):
			from = int(a.substr(5))
		elif a.begins_with("to="):
			to = int(a.substr(3))
	var stages: bool = args.has("stages")
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
	var sk: Skeleton3D = CourtPlayerModel.find_skeleton(d.get("_model"))
	var taps: Array = []
	var mods: Array = sk.get_children().filter(func(c): return c is SkeletonModifier3D)
	var t0 := LegTap.new()
	sk.add_child(t0)
	sk.move_child(t0, mods[0].get_index())
	taps.append(["(animation only)", t0])
	for m in mods:
		var label: String = m.get_class()
		if m.get_script() != null:
			label = (m.get_script() as Script).resource_path.get_file().get_basename()
		var t := LegTap.new()
		sk.add_child(t)
		sk.move_child(t, m.get_index() + 1)
		taps.append([label, t])
	for i in 40:
		await get_tree().physics_frame
	court._begin_shot()
	for frame in range(1, to + 1):
		await get_tree().physics_frame
		if frame == RELEASE_AT:
			court._release_shot()
		if frame < from:
			continue
		await get_tree().process_frame
		print("F%02d phase=%s ball=%s gait=%s lift=%.2f crouch=%.2f stance=%s y=%.2f vel=%.2f | anim %s | drawn %s" % [frame, court._phase, court._ball_mode, d.get("_gait"), d.contest_lift, d.get("_crouch_now"), d.pressure_stance, d.position.y, (d.vel as Vector3).length(), taps[0][1].line(), taps.back()[1].line()])
		if stages:
			for t in taps:
				print("    %-22s %s" % [t[0], t[1].line()])
	get_tree().quit(0)
