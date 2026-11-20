extends Node
## Traces a contest arm through every skeleton modifier: a PoseTap after each
## stage records shoulder, elbow and hand, so you can see which layer moved what.
##   godot --headless --path . res://tests/chain_trace.tscn -- at=26 [costs] [notaps]
## at=N: physics frames after the shot starts (release is at 30). costs: print
## the elbow hinge swivel search. notaps: final pose only (checks the taps change nothing).
const CourtScene: PackedScene = preload("res://scenes/court/court_game.tscn")
const CourtGame = preload("res://scripts/court/court_game.gd")
const PoseTap = preload("res://scripts/court/pose_tap.gd")

var taps: Array = []  # [label, tap]


func _rel(d: Node3D, tap, side: String) -> String:
	var s: Vector3 = tap.call("world", side, "shoulder")
	var e: Vector3 = tap.call("world", side, "elbow")
	var h: Vector3 = tap.call("world", side, "hand")
	var sg: float = 1.0 if side == "R" else -1.0
	var r: Vector3 = e - s
	var hr: Vector3 = h - s
	var flex: float = 180.0 - rad_to_deg((s - e).normalized().angle_to((h - e).normalized()))
	return "%s elbow out=%+.2f fwd=%+.2f up=%+.2f | hand out=%+.2f fwd=%+.2f up=%+.2f | flex=%3.0f" % [side, r.dot(d.right()) * sg, r.dot(d.facing()), r.y, hr.dot(d.right()) * sg, hr.dot(d.facing()), hr.y, flex]


func _ready() -> void:
	var with_taps: bool = not OS.get_cmdline_user_args().has("notaps")
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
		o.position = Vector3(o.position.x, 0, 4.0)
		o.track = o.position
	d.position = user.flat() + toward * 1.0
	d.track = d.position
	var sk: Skeleton3D = CourtPlayerModel.find_skeleton(d.get("_model"))
	if with_taps:
		var mods: Array = []
		for c in sk.get_children():
			if c is SkeletonModifier3D:
				mods.append(c)
		var t0 = PoseTap.new()
		t0.set("model", d.get("_model"))
		sk.add_child(t0)
		sk.move_child(t0, mods[0].get_index())
		taps.append(["(animation only)", t0])
		for m in mods:
			var label: String = m.get_class()
			if m.get_script() != null:
				label = (m.get_script() as Script).resource_path.get_file().get_basename()
			if m == d.get("_ik")["R"]["ik"]:
				label = "TwoBoneIK3D R"
			elif m == d.get("_ik")["L"]["ik"]:
				label = "TwoBoneIK3D L"
			elif m == d.get("_hand_aim_l"):
				label = "hand_aim L"
			elif m == d.get("_hand_aim"):
				label = "hand_aim R"
			var t = PoseTap.new()
			t.set("model", d.get("_model"))
			sk.add_child(t)
			sk.move_child(t, m.get_index() + 1)
			taps.append([label, t])
	print("ORDER: ", ", ".join(sk.get_children().filter(func(c): return c is SkeletonModifier3D).map(func(c): return (c.get_script() as Script).resource_path.get_file().get_basename() if c.get_script() != null else c.get_class())))
	for i in 40:
		await get_tree().physics_frame
	court._begin_shot()
	var at: int = 48
	for a in OS.get_cmdline_user_args():
		if a.begins_with("at="):
			at = int(a.substr(3))
	for frame in range(1, at + 1):
		await get_tree().physics_frame
		if frame == 30:
			court._release_shot()
	var hinge = d.get("_elbow_hinge")
	var to_sh: Vector3 = (user.flat() - d.flat()).normalized()
	print("FACING man_is_user=%s  angle(facing, to_shooter)=%.0f deg  face_lock=%s" % [d.man == user, rad_to_deg(d.facing().angle_to(to_sh)), d.face_lock])
	if OS.get_cmdline_user_args().has("costs"):
		hinge.set("debug_print", true)
		await get_tree().physics_frame
		await get_tree().process_frame
		hinge.set("debug_print", false)
	print("STATE lift=%.2f w_r=%.2f w_l=%.2f goal_w_r=%.2f goal_w_l=%.2f hinge.active=%s clearance.active=%s palm_w_r=%.2f palm_w_l=%.2f gait=%s guard=%.2f stance_arms=%.2f" % [d.contest_lift, d.w_r, d.w_l, d.goal_w_r, d.goal_w_l, hinge.active, d.get("_arm_clearance").active, d.palm_w_r, d.palm_w_l, d.get("_gait"), d.get("_guard_amt"), d.get("_stance_arms_amt")])
	for side in ["R", "L"]:
		var s: Vector3 = d.shoulder_position(side)
		var g: Vector3 = d.hand_r if side == "R" else d.hand_l
		var pole: Vector3 = (d.get("_ik")[side]["pole"] as Node3D).global_position
		var sg: float = 1.0 if side == "R" else -1.0
		print("GOAL %s hand goal out=%+.2f fwd=%+.2f up=%+.2f | pole out=%+.2f fwd=%+.2f up=%+.2f" % [side, (g - s).dot(d.right()) * sg, (g - s).dot(d.facing()), (g - s).y, (pole - s).dot(d.right()) * sg, (pole - s).dot(d.facing()), (pole - s).y])
	if with_taps:
		for t in taps:
			print("STAGE %-22s %s   ||   %s" % [t[0], _rel(d, t[1], "R"), _rel(d, t[1], "L")])
	print("FINAL %-22s %s   ||   %s" % ["pose_tap (drawn)", _rel(d, d.get("_pose_tap"), "R"), _rel(d, d.get("_pose_tap"), "L")])
	get_tree().quit(0)
