extends Node
## Does the recorded clip own what it is supposed to own? For a clip-owned
## action, compares every joint as the AnimationTree posed it (before the first
## skeleton modifier) with the joint as drawn (after the last), per frame, in
## centimetres, grouped by body part. Anything the modifiers move is something
## the clip does not own. Same contested jump shot as tests/contest_views.
##   godot --headless --path . res://tests/clip_fidelity.tscn
## Shooter: JumpShot owns the whole body. Defender: JumpShot owns legs, hips,
## spine (the contest IK owns the arms, so arms are reported, not expected).
const CourtScene: PackedScene = preload("res://scenes/court/court_game.tscn")
const CourtGame = preload("res://scripts/court/court_game.gd")
const GROUPS: Dictionary = {
	"hips+spine": ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head"],
	"legs": ["LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"],
	"arms": ["LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand"],
}


class AllTap extends SkeletonModifier3D:
	var pos: Dictionary = {}  # bone name -> world position
	func _process_modification_with_delta(_delta: float) -> void:
		var sk: Skeleton3D = get_skeleton()
		sk.force_update_all_bone_transforms()
		for g in GROUPS.values():
			for b: String in g:
				var i := sk.find_bone(b)
				if i >= 0:
					pos[b] = sk.global_transform * sk.get_bone_global_pose(i).origin


func _taps(actor: Node3D) -> Array:
	var sk: Skeleton3D = CourtPlayerModel.find_skeleton(actor.get("_model"))
	var mods: Array = sk.get_children().filter(func(c): return c is SkeletonModifier3D)
	var first := AllTap.new()
	sk.add_child(first)
	sk.move_child(first, mods[0].get_index())
	var last := AllTap.new()
	sk.add_child(last)  # after pose_tap, the last modifier
	return [first, last]


func _report(label: String, rows: Array) -> void:
	print("== %s: max joint shift from the clip, cm (frame of the max)" % label)
	for g: String in GROUPS:
		var worst := 0.0
		var worst_f := 0
		var worst_b := ""
		var sum := 0.0
		for r in rows:
			var m: float = r[g][0]
			sum += m
			if m > worst:
				worst = m
				worst_f = r["frame"]
				worst_b = r[g][1]
		print("   %-11s max %5.1f cm (F%02d, %s)   mean of per-frame max %4.1f cm" % [g, worst, worst_f, worst_b, sum / maxf(1.0, rows.size())])


func _measure(taps: Array, frame: int) -> Dictionary:
	var out := {"frame": frame}
	for g: String in GROUPS:
		var m := 0.0
		var mb := ""
		for b: String in GROUPS[g]:
			if not taps[0].pos.has(b):
				continue
			var dcm: float = (taps[0].pos[b] as Vector3).distance_to(taps[1].pos[b]) * 100.0
			if dcm > m:
				m = dcm
				mb = b
		out[g] = [m, mb]
	return out


## Per-stage: which modifier moves the head / hands away from the clip.
func _stage_taps(actor: Node3D) -> Array:
	var sk: Skeleton3D = CourtPlayerModel.find_skeleton(actor.get("_model"))
	var mods: Array = sk.get_children().filter(func(c): return c is SkeletonModifier3D)
	var out: Array = []
	for m in mods:
		var t := AllTap.new()
		sk.add_child(t)
		sk.move_child(t, m.get_index() + 1)
		var label: String = (m.get_script() as Script).resource_path.get_file().get_basename() if m.get_script() != null else m.get_class()
		out.append([label, t])
	return out


func _ready() -> void:
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
	var ut := _taps(user)
	var stages: bool = OS.get_cmdline_user_args().has("stages")
	var us: Array = _stage_taps(user) if stages else []
	var dt := _taps(d)
	for i in 40:
		await get_tree().physics_frame
	court._begin_shot()
	var urows: Array = []
	var drows: Array = []
	for frame in range(1, 81):
		await get_tree().physics_frame
		if frame == 30:
			court._release_shot()
		await get_tree().process_frame
		urows.append(_measure(ut, frame))
		if stages and frame in [4, 20, 45, 60]:
			var prev: AllTap = ut[0]
			var line := "F%02d" % frame
			for st in us:
				var t: AllTap = st[1]
				var mv := 0.0
				for b in ["Head", "LeftHand", "RightHand", "Hips"]:
					if prev.pos.has(b):
						mv = maxf(mv, (prev.pos[b] as Vector3).distance_to(t.pos[b]) * 100.0)
				if mv > 0.5:
					line += "  %s %.1f" % [st[0], mv]
				prev = t
			print(line)
		if frame >= 32:  # the defender's jump clip starts at the release
			drows.append(_measure(dt, frame))
	_report("SHOOTER jump shot (clip should own everything), frames 1-80", urows)
	_report("DEFENDER jump (clip should own legs, hips, spine), frames 32-80", drows)
	get_tree().quit(0)
