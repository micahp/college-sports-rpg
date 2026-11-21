extends Node
## Gate 3: the limb IK on its own (docs/animation/RIG_CERTIFICATION.md).
## Arms: the game's TwoBoneIK3D per arm, with the game's own pole rule
## (court_actor.elbow_hint, the pole placed as animate() places it), and every
## other modifier off: elbow_hinge, hand_aim, arm_clearance and the rest do
## not get to repair the solution. Legs: the game has no leg IK; a test-only
## TwoBoneIK3D per leg with the knee pole axis gate 1 measured, to show the leg
## chain is IK-ready (or not).
## For each target: hand / foot error, and the joint as an anatomist reads it
## (rig_fixture.limb): elbow / knee flex inside its range and in its hinge
## plane, forearm / shin twist, humeral / femoral roll, the elbow on the pole's
## side, the hand untouched. Then a continuous loop through the targets (no
## jumps), release (back to the animation exactly) and re-engage (same answer).
##   godot --headless --fixed-fps 60 --path . res://tests/rig/arm_ik_sweep.tscn [-- fault=pole_plus_z|hinge_on]
## Video of the right arm's loop (IK alone, the game's pole rule), with Movie Maker:
##   godot --fixed-fps 60 --write-movie build/rig/ik_loop.png --path . res://tests/rig/arm_ik_sweep.tscn -- movie
const F = preload("res://tests/rig/rig_fixture.gd")

const HAND_CM: float = 2.0       # target error for a reachable target (<= 95% of the chain)
const OFF_HINGE_DEG: float = 5.0
const FLEX_MIN: float = -5.0     # a few degrees past straight: no hyperextension
const ELBOW_MAX: float = 150.0
const KNEE_MAX: float = 150.0
const TWIST_MAX: float = 90.0    # forearm pronation / supination either way
const ROLL_MAX: float = 95.0     # humeral rotation either way (court_actor's limit is 85)
const LEG_ROLL_MAX: float = 45.0
const POLE_SIDE_DEG: float = 35.0
const STEP_CM: float = 2.0
const JUMP_CM: float = 4.0       # an elbow / knee may not move more than this for one STEP_CM target step
const JUMP_DEG: float = 10.0

var f: F


func _ready() -> void:
	f = F.new()
	f.build(self)
	var flt := F.fault()
	if flt == "pole_plus_z":
		for side: String in ["R", "L"]:
			(f.mod("arm_ik_" + side) as TwoBoneIK3D).set_pole_direction(0, SkeletonModifier3D.SECONDARY_DIRECTION_PLUS_Z)
	var base := f.clip_pose("Idle", 0.0)
	f.use(base)
	await f.settle()
	if OS.get_cmdline_user_args().has("movie"):
		await _movie()
		get_tree().quit(0)
		return
	print("GATE 3 limb IK in isolation: base pose Idle frame 0, actor at the origin facing +Z")
	await _self_test()
	f.use(base)
	await f.settle()
	for side: String in ["R", "L"]:
		await _arm(side, base, flt)
	for side: String in ["R", "L"]:
		await _leg(side, base)
	print("FAILED_CHECKS: " + ",".join(f.failures))
	f.finish(get_tree(), "GATE 3")


# ------------------------------------------------------------------ video

func _movie() -> void:
	get_window().size = Vector2i(960, 720)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.66, 0.72)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.global_position = Vector3(-1.25, 1.45, 1.35)
	cam.look_at(Vector3(-0.2, 1.2, 0.1), Vector3.UP)
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.position = Vector2(12, 8)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color.BLACK)
	layer.add_child(label)
	var pole_ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.03
	sm.height = 0.06
	pole_ball.mesh = sm
	add_child(pole_ball)
	var target_ball := MeshInstance3D.new()
	target_ball.mesh = sm
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.9, 0.2, 0.2)
	target_ball.material_override = tm
	add_child(target_ball)
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.2, 0.4, 0.95)
	pole_ball.material_override = pm
	f.only(["arm_ik_R"])
	var side := "R"
	var r := f.limb_rest("arm", side)
	var chain: float = float(r["len"]) * f.metres_per_unit()
	var shoulder: Vector3 = f.world(f.gin(F.ARM[side][1]).origin)
	var loop: Array = []
	var names: Array = []
	for d: Array in _arm_targets(side):
		loop.append(shoulder + (d[1] as Vector3).normalized() * chain * 0.7)
		names.append(d[0])
	loop.append(loop[0])
	names.append(names[0])
	for i in range(loop.size() - 1):
		var n: int = 40
		for k in n:
			var t: Vector3 = (loop[i] as Vector3).lerp(loop[i + 1], float(k) / n)
			t = shoulder + (t - shoulder).normalized() * chain * 0.7
			_aim_arm(side, t)
			target_ball.global_position = t
			pole_ball.global_position = ((f.actor.get("_ik") as Dictionary)[side]["pole"] as Node3D).global_position
			await get_tree().process_frame
			var m := f.limb(f.last.g, r)
			label.text = "Right arm IK alone (no elbow_hinge), the game's pole rule. Red: hand target, blue: pole.
%s -> %s   elbow flex %.0f  off-hinge %.0f deg  humeral roll %.0f  elbow_up %s" % [names[i], names[i + 1], m["flex"], m["off"], m["roll"], f.actor.get("elbow_up")]


# ------------------------------------------------------------------ the measure itself

## rig_fixture.limb must read back poses built with known joint angles, or
## nothing below means anything. Built from the rest pose, no modifier on.
func _self_test() -> void:
	f.only([])
	var worst := 0.0
	var what := ""
	for side: String in ["R", "L"]:
		var up: String = F.ARM[side][1]
		var lo: String = F.ARM[side][2]
		var thigh: String = F.LEG[side][0]
		var shin: String = F.LEG[side][1]
		# The real hinge axis and forearm line at rest (skeleton space): local
		# axes only approximate them (the forearm's +Y is the shoulder-elbow line;
		# the wrist sits ~7 deg off it).
		var e0: Vector3 = f.sk.get_bone_global_rest(f.bone(lo)).origin
		var a0: Vector3 = (e0 - f.sk.get_bone_global_rest(f.bone(up)).origin).normalized()
		var f0: Vector3 = (f.sk.get_bone_global_rest(f.bone(F.ARM[side][3])).origin - e0).normalized()
		var h: Vector3 = a0.cross((Vector3.BACK - a0 * a0.dot(Vector3.BACK)).normalized()).normalized()
		var f60: Vector3 = Basis(h, deg_to_rad(60.0)) * f0
		var cases: Array = [
			["elbow flex 90", "arm", [[lo, "x", 90.0]], {"flex": 90.0, "off": 0.0, "twist": 0.0, "roll": 0.0}],
			["forearm twist 40", "arm", [[lo, f0, 40.0]], {"flex": 0.0, "off": 0.0, "twist": 40.0, "roll": 0.0}],
			["flex 60 then pronate -50", "arm", [[lo, h, 60.0], [lo, f60, -50.0]], {"flex": 60.0, "off": 0.0, "twist": -50.0}],
			["humeral roll 30 + flex 70", "arm", [[up, "y", 30.0], [lo, "x", 70.0]], {"flex": 70.0, "off": 0.0, "twist": 0.0, "roll": 30.0}],
			["sideways elbow 25", "arm", [[lo, "z", 25.0]], {"off": 25.0}],
			["knee flex 80", "leg", [[shin, "x", 80.0]], {"flex": 80.0, "off": 0.0, "twist": 0.0, "roll": 0.0}],
			["thigh roll 20 + knee 60", "leg", [[thigh, "y", 20.0], [shin, "x", 60.0]], {"flex": 60.0, "off": 0.0, "roll": 20.0}],
		]
		for c: Array in cases:
			f.use(f.posed(c[2]))
			await f.settle(2)
			var m := f.limb(f.first.g, f.limb_rest(c[1], side))
			for k: String in c[3]:
				# Read without sign for the cases where the side flips it (gate 1:
				# right = left mirrored, local Y and Z mirrored only).
				var err: float = absf(absf(float(m[k])) - absf(float(c[3][k])))
				if err > worst:
					worst = err
					what = "%s %s: %s read %.1f, built %.1f" % [side, c[0], k, m[k], c[3][k]]
	f.check(worst <= 1.5, "measure self-test", "known joint angles read back within %.1f deg (worst: %s)" % [worst, what if what != "" else "-"])


# ------------------------------------------------------------------ arms

func _arm_targets(side: String) -> Array:
	var a: Node3D = f.actor
	var fwd: Vector3 = a.facing()
	var out: Vector3 = a.right() * (1.0 if side == "R" else -1.0)
	var dirs: Array = [["forward", fwd], ["forward_low", fwd * 0.7 + Vector3.DOWN * 0.7], ["front_high", fwd * 0.6 + Vector3.UP * 0.8],
		["overhead", Vector3.UP + fwd * 0.15], ["side", out], ["side_high", out * 0.7 + Vector3.UP * 0.7],
		["across", -out * 0.6 + fwd * 0.8], ["side_low", out * 0.6 + Vector3.DOWN * 0.8]]
	return dirs


## Places the arm IK the way court_actor.animate() does: target, and the pole at
## shoulder + elbow_hint * 0.6 m. elbow_up (the raised-hand rule) when the hand
## is above the shoulder.
func _aim_arm(side: String, target: Vector3, weight: float = 1.0) -> void:
	var arm: Dictionary = (f.actor.get("_ik") as Dictionary)[side]
	var shoulder: Vector3 = f.world(f.gin(F.ARM[side][1]).origin)
	f.actor.set("elbow_up", target.y > shoulder.y + 0.05)
	(arm["target"] as Node3D).global_position = target
	(arm["pole"] as Node3D).global_position = shoulder + (f.actor.call("elbow_hint", side) as Vector3).normalized() * 0.6
	(arm["ik"] as SkeletonModifier3D).influence = weight


func _arm(side: String, base: Dictionary, flt: String) -> void:
	var label := "arm_ik_" + side
	f.only([label, "elbow_hinge"] if flt == "hinge_on" else [label])
	var r := f.limb_rest("arm", side)
	var chain: float = float(r["len"]) * f.metres_per_unit()
	var shoulder: Vector3 = f.world(f.gin(F.ARM[side][1]).origin)
	print("Arm %s: chain %.1f cm, shoulder at %s" % [side, chain * 100, shoulder.snapped(Vector3.ONE * 0.001)])
	var worst := {"err": 0.0, "off": 0.0, "flex_lo": 999.0, "flex_hi": -999.0, "twist": 0.0, "roll": 0.0, "pole": 0.0, "hand": 0.0, "after": 0.0}
	var where := {}
	var lines: Array = []
	for d: Array in _arm_targets(side):
		for frac: float in [0.45, 0.7, 0.95]:
			var target: Vector3 = shoulder + (d[1] as Vector3).normalized() * chain * frac
			_aim_arm(side, target)
			await f.settle(2)
			var m := _arm_measure(side, r, target)
			var key := "%s@%.0f%%" % [d[0], frac * 100]
			lines.append("    %-18s err %4.1f cm  flex %6.1f  off %5.1f  twist %6.1f  roll %6.1f  pole %5.1f  hand %4.1f" % [key, m["err"], m["flex"], m["off"], m["twist"], m["roll"], m["pole"], m["hand"]])
			for k: String in ["err", "off", "twist", "roll", "pole", "hand", "after"]:
				var v: float = absf(float(m[k]))
				if v > float(worst[k]):
					worst[k] = v
					where[k] = key
			if float(m["flex"]) < float(worst["flex_lo"]):
				worst["flex_lo"] = m["flex"]
				where["flex_lo"] = key
			if float(m["flex"]) > float(worst["flex_hi"]):
				worst["flex_hi"] = m["flex"]
				where["flex_hi"] = key
	for l: String in lines:
		print(l)
	f.check(float(worst["err"]) <= HAND_CM, "arm %s reaches" % side, "worst hand error %.1f cm (%s), limit %.0f cm" % [worst["err"], where.get("err", "-"), HAND_CM])
	f.check(float(worst["flex_lo"]) >= FLEX_MIN, "arm %s elbow never bends backward" % side, "least flex %.0f deg (%s), limit %.0f" % [worst["flex_lo"], where.get("flex_lo", "-"), FLEX_MIN])
	f.check(float(worst["flex_hi"]) <= ELBOW_MAX, "arm %s elbow within its fold" % side, "most flex %.0f deg (%s), limit %.0f" % [worst["flex_hi"], where.get("flex_hi", "-"), ELBOW_MAX])
	f.check(float(worst["off"]) <= OFF_HINGE_DEG, "arm %s elbow is a hinge" % side, "worst bend out of the hinge plane %.1f deg (%s)" % [worst["off"], where.get("off", "-")])
	f.check(float(worst["twist"]) <= TWIST_MAX, "arm %s forearm twist" % side, "worst %.0f deg (%s), limit %.0f" % [worst["twist"], where.get("twist", "-"), TWIST_MAX])
	f.check(float(worst["roll"]) <= ROLL_MAX, "arm %s humeral roll" % side, "worst %.0f deg (%s), limit %.0f" % [worst["roll"], where.get("roll", "-"), ROLL_MAX])
	f.check(float(worst["pole"]) <= POLE_SIDE_DEG, "arm %s elbow follows its pole" % side, "worst %.0f deg between the elbow and the pole about the shoulder-wrist line (%s)" % [worst["pole"], where.get("pole", "-")])
	f.check(float(worst["hand"]) <= 1.0, "arm %s hand untouched" % side, "the IK turned the hand off its forearm by up to %.1f deg (%s)" % [worst["hand"], where.get("hand", "-")])
	f.check(float(worst["after"]) <= 0.05, "arm %s nothing after the IK" % side, "modifiers after the IK moved the arm by up to %.2f cm" % worst["after"])

	# Continuous loop through the 70% targets and back, STEP_CM at a time.
	var loop: Array = []
	for d: Array in _arm_targets(side):
		loop.append(shoulder + (d[1] as Vector3).normalized() * chain * 0.7)
	loop.append(loop[0])
	var prev: Dictionary = {}
	var jump := 0.0
	var jump_at := ""
	var turn := 0.0
	var turn_at := ""
	for i in range(loop.size() - 1):
		var a: Vector3 = loop[i]
		var b: Vector3 = loop[i + 1]
		var n: int = maxi(1, ceili(a.distance_to(b) * 100.0 / STEP_CM))
		for k in n + 1:
			var t: Vector3 = a.lerp(b, float(k) / n)
			t = shoulder + (t - shoulder).normalized() * chain * 0.7  # stay on the 70% sphere
			_aim_arm(side, t)
			await f.settle(1)
			var m := _arm_measure(side, r, t)
			if not prev.is_empty():
				var de: float = f.world(m["e"]).distance_to(f.world(prev["e"])) * 100.0
				var dr: float = maxf(absf(wrapf(float(m["roll"]) - float(prev["roll"]), -180, 180)), absf(float(m["flex"]) - float(prev["flex"])))
				if de > jump:
					jump = de
					jump_at = "between target %d and %d" % [i, i + 1]
				if dr > turn:
					turn = dr
					turn_at = "between target %d and %d" % [i, i + 1]
			prev = m
	f.check(jump <= JUMP_CM and turn <= JUMP_DEG, "arm %s continuous" % side, "loop at 70%% reach in %.0f cm steps: elbow moved at most %.1f cm (%s), roll/flex %.1f deg (%s) in one step" % [STEP_CM, jump, jump_at, turn, turn_at])

	# Release: back to the animation exactly. Re-engage: the same solution.
	var probe: Vector3 = shoulder + (f.actor.facing() + Vector3.UP * 0.3).normalized() * chain * 0.7
	_aim_arm(side, probe)
	await f.settle(2)
	var engaged := _arm_measure(side, r, probe)
	_aim_arm(side, probe, 0.0)
	await f.settle(2)
	var rel: Array = f.change([F.ARM[side][1], F.ARM[side][2], F.ARM[side][3]])
	f.check(float(rel[0]) <= 0.5 and float(rel[2]) <= 0.2, "arm %s release" % side, "influence 0: drawn arm differs from the animation by %.2f deg / %.2f cm" % [rel[0], rel[2]])
	_aim_arm(side, probe)
	await f.settle(2)
	var again := _arm_measure(side, r, probe)
	var hyst: float = f.world(again["e"]).distance_to(f.world(engaged["e"])) * 100.0
	f.check(hyst <= 0.2, "arm %s re-engage" % side, "the same target after a release puts the elbow %.2f cm from before" % hyst)
	(((f.actor.get("_ik") as Dictionary)[side])["ik"] as SkeletonModifier3D).influence = 0.0


func _arm_measure(side: String, r: Dictionary, target: Vector3) -> Dictionary:
	var m := f.limb(f.last.g, r)
	m["err"] = f.world(m["w"]).distance_to(target) * 100.0
	# Elbow on the pole's side of the shoulder-wrist line.
	var s: Vector3 = f.world(m["s"])
	var w: Vector3 = f.world(m["w"])
	var e: Vector3 = f.world(m["e"])
	var axis := (w - s).normalized()
	var pole: Vector3 = (((f.actor.get("_ik") as Dictionary)[side])["pole"] as Node3D).global_position
	var ve := (e - s).slide(axis)
	var vp := (pole - s).slide(axis)
	m["pole"] = rad_to_deg(ve.angle_to(vp)) if ve.length() > 0.01 and vp.length() > 0.01 and float(m["flex"]) > 20.0 else 0.0
	# The hand relative to its forearm, against the animation's.
	var hi: int = f.bone(F.ARM[side][3])
	var li: int = f.bone(F.ARM[side][2])
	var rin: Basis = (f.first.g[li] as Transform3D).basis.orthonormalized().inverse() * (f.first.g[hi] as Transform3D).basis.orthonormalized()
	var rout: Basis = (f.last.g[li] as Transform3D).basis.orthonormalized().inverse() * (f.last.g[hi] as Transform3D).basis.orthonormalized()
	m["hand"] = F.angle(rin, rout)
	# Anything after the IK.
	var after: F.Tap = f.taps["arm_ik_" + side]
	m["after"] = f.change([F.ARM[side][1], F.ARM[side][2], F.ARM[side][3]], after, f.last)[2]
	return m


# ------------------------------------------------------------------ legs

func _leg(side: String, base: Dictionary) -> void:
	f.only([])
	var names: Array = F.LEG[side]
	var target := Marker3D.new()
	var pole := Marker3D.new()
	target.top_level = true
	pole.top_level = true
	f.actor.add_child(target)
	f.actor.add_child(pole)
	var ik := TwoBoneIK3D.new()
	f.sk.add_child(ik)
	f.sk.move_child(ik, f.last.get_index())  # just before the last tap
	ik.setting_count = 1
	ik.set_root_bone_name(0, names[0])
	ik.set_middle_bone_name(0, names[1])
	ik.set_end_bone_name(0, names[2])
	ik.set_pole_direction(0, SkeletonModifier3D.SECONDARY_DIRECTION_MINUS_Z)  # gate 1: the knee tip is the shin's -Z
	ik.set_target_node(0, ik.get_path_to(target))
	ik.set_pole_node(0, ik.get_path_to(pole))
	var r := f.limb_rest("leg", side)
	var chain: float = float(r["len"]) * f.metres_per_unit()
	var hip: Vector3 = f.world(f.gin(names[0]).origin)
	var fwd: Vector3 = f.actor.facing()
	var out: Vector3 = f.actor.right() * (1.0 if side == "R" else -1.0)
	print("Leg %s (test-only IK, the game has none): chain %.1f cm, hip at %s" % [side, chain * 100, hip.snapped(Vector3.ONE * 0.001)])
	var targets: Array = [["stand", Vector3.DOWN * 0.97], ["knee_lift", Vector3.DOWN * 0.45 + fwd * 0.3], ["squat", Vector3.DOWN * 0.6 + fwd * 0.08],
		["step_forward", Vector3.DOWN * 0.85 + fwd * 0.35], ["step_back", Vector3.DOWN * 0.85 - fwd * 0.35], ["step_out", Vector3.DOWN * 0.88 + out * 0.3],
		["kick_back", Vector3.DOWN * 0.55 - fwd * 0.45], ["cross_over", Vector3.DOWN * 0.88 - out * 0.2 + fwd * 0.15]]
	var worst := {"err": 0.0, "off": 0.0, "flex_lo": 999.0, "flex_hi": -999.0, "twist": 0.0, "roll": 0.0, "pole": 0.0}
	var where := {}
	for t: Array in targets:
		var goal: Vector3 = hip + (t[1] as Vector3) * chain
		target.global_position = goal
		# Knee forward and a little out, below the hip (where a knee points).
		pole.global_position = hip + fwd * 0.6 + out * 0.1 + Vector3.DOWN * 0.25
		ik.influence = 1.0
		await f.settle(2)
		var m := f.limb(f.last.g, r)
		m["err"] = f.world(m["w"]).distance_to(goal) * 100.0
		var s: Vector3 = f.world(m["s"])
		var axis: Vector3 = (f.world(m["w"]) - s).normalized()
		var ve: Vector3 = (f.world(m["e"]) - s).slide(axis)
		var vp: Vector3 = (pole.global_position - s).slide(axis)
		m["pole"] = rad_to_deg(ve.angle_to(vp)) if float(m["flex"]) > 20.0 and ve.length() > 0.01 else 0.0
		print("    %-13s err %4.1f cm  knee %6.1f  off %5.1f  shin twist %6.1f  thigh roll %6.1f  pole %5.1f" % [t[0], m["err"], m["flex"], m["off"], m["twist"], m["roll"], m["pole"]])
		for k: String in ["err", "off", "twist", "roll", "pole"]:
			if absf(float(m[k])) > float(worst[k]):
				worst[k] = absf(float(m[k]))
				where[k] = t[0]
		if float(m["flex"]) < float(worst["flex_lo"]):
			worst["flex_lo"] = m["flex"]
			where["flex_lo"] = t[0]
		if float(m["flex"]) > float(worst["flex_hi"]):
			worst["flex_hi"] = m["flex"]
			where["flex_hi"] = t[0]
	f.check(float(worst["err"]) <= HAND_CM, "leg %s reaches" % side, "worst foot error %.1f cm (%s)" % [worst["err"], where.get("err", "-")])
	f.check(float(worst["flex_lo"]) >= FLEX_MIN, "leg %s knee never bends backward" % side, "least knee %.0f deg (%s)" % [worst["flex_lo"], where.get("flex_lo", "-")])
	f.check(float(worst["flex_hi"]) <= KNEE_MAX, "leg %s knee within its fold" % side, "most knee %.0f deg (%s)" % [worst["flex_hi"], where.get("flex_hi", "-")])
	f.check(float(worst["off"]) <= OFF_HINGE_DEG, "leg %s knee is a hinge" % side, "worst bend out of the hinge plane %.1f deg (%s)" % [worst["off"], where.get("off", "-")])
	f.check(float(worst["roll"]) <= LEG_ROLL_MAX and float(worst["twist"]) <= LEG_ROLL_MAX, "leg %s no leg twist" % side, "thigh roll %.0f deg (%s), shin twist %.0f deg (%s)" % [worst["roll"], where.get("roll", "-"), worst["twist"], where.get("twist", "-")])
	f.check(float(worst["pole"]) <= POLE_SIDE_DEG, "leg %s knee follows its pole" % side, "worst %.0f deg (%s)" % [worst["pole"], where.get("pole", "-")])
	ik.influence = 0.0
	await f.settle(2)
	var rel: Array = f.change(names)
	f.check(float(rel[0]) <= 0.5 and float(rel[2]) <= 0.2, "leg %s release" % side, "influence 0: drawn leg differs from the animation by %.2f deg / %.2f cm" % [rel[0], rel[2]])
	ik.queue_free()
	target.queue_free()
	pole.queue_free()
