extends Node
## Gate 4: poles and limits (docs/animation/RIG_CERTIFICATION.md).
## The arm IK alone (as gate 3), the game's pole rule (court_actor.elbow_hint).
##   turn: the whole character through 360 deg (15 deg steps), body-relative
##     targets: in the body's frame the arm must come out the same at every
##     heading, and the same again while the character turns and moves each
##     frame (no frame of lag, no world-space pole).
##   straight: the target from 85% to 110% of the chain in 0.5% steps: no
##     jump, no flip, no backward bend as the arm straightens; past full
##     length the arm points at the target.
##   through the pole: a target swept across the pole's direction (where the
##     bend plane is undefined): how far the elbow jumps.
##   reach policy: what court_actor._clamp_hand_target lets a hand reach.
## Legs: the test-only leg IK of gate 3, turned through 360 deg.
##   godot --headless --fixed-fps 60 --path . res://tests/rig/pole_rotation_checks.tscn [-- fault=world_pole]
const F = preload("res://tests/rig/rig_fixture.gd")

const TURN_CM: float = 0.5
const TURN_DEG: float = 1.0
const STRAIGHT_JUMP_CM: float = 1.5
const STRAIGHT_JUMP_DEG: float = 5.0
const POLE_JUMP_CM: float = 6.0

var f: F
var world_pole: bool = false
var _pole0: Dictionary = {}


func _ready() -> void:
	f = F.new()
	f.build(self)
	world_pole = F.fault() == "world_pole"
	var base := f.clip_pose("Idle", 0.0)
	f.use(base)
	await f.settle()
	print("GATE 4 poles and limits: arm IK alone, the game's pole rule; base pose Idle frame 0")
	for side: String in ["R", "L"]:
		await _turn(side)
		await _straight(side)
		await _through_pole(side)
		_reach_policy(side)
	for side: String in ["R", "L"]:
		await _leg_turn(side)
	print("FAILED_CHECKS: " + ",".join(f.failures))
	f.finish(get_tree(), "GATE 4")


func _model() -> Node3D:
	return f.actor.get("_model")


func _set_heading(yaw_deg: float, pos: Vector3 = Vector3.ZERO) -> void:
	f.actor.position = pos
	_model().rotation.y = deg_to_rad(yaw_deg)


func _to_body(p: Vector3) -> Vector3:
	return _model().global_transform.affine_inverse() * p


## Body-frame target (x right, y up, z front, metres from the shoulder) -> world.
func _target(side: String, body: Vector3) -> Vector3:
	var shoulder: Vector3 = f.world(f.gin(F.ARM[side][1]).origin)
	var a: Node3D = f.actor
	return shoulder + a.right() * body.x + Vector3.UP * body.y + a.facing() * body.z


func _aim(side: String, target: Vector3, key: String = "") -> void:
	var arm: Dictionary = (f.actor.get("_ik") as Dictionary)[side]
	var shoulder: Vector3 = f.world(f.gin(F.ARM[side][1]).origin)
	f.actor.set("elbow_up", target.y > shoulder.y + 0.05)
	var pole: Vector3 = shoulder + (f.actor.call("elbow_hint", side) as Vector3).normalized() * 0.6
	if world_pole and key != "":
		# Fault: the pole worked out once at the first heading and left in the world.
		if not _pole0.has(key):
			_pole0[key] = pole
		pole = _pole0[key]
	(arm["target"] as Node3D).global_position = target
	(arm["pole"] as Node3D).global_position = pole
	(arm["ik"] as SkeletonModifier3D).influence = 1.0


func _arm_body(side: String) -> Dictionary:
	var r := f.limb_rest("arm", side)
	var m := f.limb(f.last.g, r)
	return {"e": _to_body(f.world(m["e"])), "w": _to_body(f.world(m["w"])), "flex": m["flex"], "roll": m["roll"], "twist": m["twist"]}


func _turn(side: String) -> void:
	f.only(["arm_ik_" + side])
	var chain: float = float(f.limb_rest("arm", side)["len"]) * f.metres_per_unit()
	var s: float = 1.0 if side == "R" else -1.0
	var bodies: Array = [["forward", Vector3(0, 0, 0.7)], ["side", Vector3(0.7 * s, 0, 0)], ["overhead", Vector3(0, 0.7, 0.1)],
		["across", Vector3(-0.4 * s, -0.1, 0.55)], ["low_front", Vector3(0.15 * s, -0.5, 0.45)]]
	var ref: Dictionary = {}
	var worst_cm := 0.0
	var worst_deg := 0.0
	var at := ""
	for yaw in range(0, 360, 15):
		_set_heading(float(yaw), Vector3(0.3, 0, -0.2) * float(yaw) / 90.0)
		await f.settle(1)
		for b: Array in bodies:
			_aim(side, _target(side, (b[1] as Vector3) * chain), b[0])
			await f.settle(2)
			var m := _arm_body(side)
			if yaw == 0:
				ref[b[0]] = m
				continue
			var r0: Dictionary = ref[b[0]]
			var cm: float = maxf((m["e"] as Vector3).distance_to(r0["e"]), (m["w"] as Vector3).distance_to(r0["w"])) * 100.0
			var deg: float = maxf(absf(float(m["flex"]) - float(r0["flex"])), maxf(absf(wrapf(float(m["roll"]) - float(r0["roll"]), -180, 180)), absf(wrapf(float(m["twist"]) - float(r0["twist"]), -180, 180))))
			if cm > worst_cm:
				worst_cm = cm
				at = "%s at %d deg" % [b[0], yaw]
			worst_deg = maxf(worst_deg, deg)
	f.check(worst_cm <= TURN_CM and worst_deg <= TURN_DEG, "arm %s same at every heading" % side, "turned 0-345 deg and moved: body-frame elbow/wrist differ by up to %.2f cm (%s), joint angles by %.2f deg" % [worst_cm, at, worst_deg])
	# Turning and moving every frame: the arm must not trail the body.
	_set_heading(0.0)
	await f.settle(1)
	_aim(side, _target(side, (bodies[0][1] as Vector3) * chain))
	await f.settle(2)
	var still := _arm_body(side)
	var lag := 0.0
	for i in 90:
		_set_heading(float(i) * 4.0, Vector3(0.02, 0, 0.03) * float(i))
		_aim(side, _target(side, (bodies[0][1] as Vector3) * chain))
		await f.settle(1)
		var m := _arm_body(side)
		lag = maxf(lag, (m["w"] as Vector3).distance_to(still["w"]) * 100.0)
	f.check(lag <= TURN_CM, "arm %s keeps up while turning" % side, "turning 4 deg and moving 3.6 cm a frame, the hand stays within %.2f cm of the standing solution (body frame)" % lag)
	_set_heading(0.0)


func _straight(side: String) -> void:
	f.only(["arm_ik_" + side])
	var chain: float = float(f.limb_rest("arm", side)["len"]) * f.metres_per_unit()
	var s: float = 1.0 if side == "R" else -1.0
	var worst := {"jump": 0.0, "turn": 0.0, "flex": 999.0, "err": 0.0, "dir": 0.0}
	var at := {}
	for b: Array in [["forward", Vector3(0, 0, 1)], ["side", Vector3(s, 0, 0)], ["overhead", Vector3(0, 1, 0.1)], ["forward_down", Vector3(0, -0.6, 0.8)]]:
		var prev: Dictionary = {}
		var k := 0.85
		while k <= 1.1001:
			var t := _target(side, (b[1] as Vector3).normalized() * chain * k)
			_aim(side, t)
			await f.settle(1)
			var m := _arm_body(side)
			var r := f.limb(f.last.g, f.limb_rest("arm", side))
			if not prev.is_empty():
				var j: float = (m["e"] as Vector3).distance_to(prev["e"]) * 100.0
				var tr: float = maxf(absf(wrapf(float(m["roll"]) - float(prev["roll"]), -180, 180)), absf(wrapf(float(m["twist"]) - float(prev["twist"]), -180, 180)))
				if j > float(worst["jump"]):
					worst["jump"] = j
					at["jump"] = "%s %.1f%%" % [b[0], k * 100]
				if tr > float(worst["turn"]):
					worst["turn"] = tr
					at["turn"] = "%s %.1f%%" % [b[0], k * 100]
			if float(m["flex"]) < float(worst["flex"]):
				worst["flex"] = m["flex"]
				at["flex"] = "%s %.1f%%" % [b[0], k * 100]
			var hand: Vector3 = f.world(r["w"])
			var sh: Vector3 = f.world(r["s"])
			if k <= 0.995:
				var e: float = hand.distance_to(t) * 100.0
				if e > float(worst["err"]):
					worst["err"] = e
					at["err"] = "%s %.1f%%" % [b[0], k * 100]
			elif k > 1.005:
				var d: float = rad_to_deg((hand - sh).angle_to(t - sh))
				if d > float(worst["dir"]):
					worst["dir"] = d
					at["dir"] = "%s %.1f%%" % [b[0], k * 100]
			prev = m
			k += 0.005
	f.check(float(worst["jump"]) <= STRAIGHT_JUMP_CM and float(worst["turn"]) <= STRAIGHT_JUMP_DEG, "arm %s straightens smoothly" % side, "85-110%% of the chain in 0.5%% steps: elbow moves at most %.2f cm (%s), roll/twist %.1f deg (%s) per step" % [worst["jump"], at.get("jump", "-"), worst["turn"], at.get("turn", "-")])
	f.check(float(worst["flex"]) >= -5.0, "arm %s no backward bend at full stretch" % side, "least flex %.1f deg (%s)" % [worst["flex"], at.get("flex", "-")])
	f.check(float(worst["err"]) <= 0.5, "arm %s reaches up to full stretch" % side, "worst hand error %.2f cm up to 99.5%% (%s)" % [worst["err"], at.get("err", "-")])
	f.check(float(worst["dir"]) <= 1.0, "arm %s points at an unreachable target" % side, "past full length the arm points %.2f deg off the target (%s)" % [worst["dir"], at.get("dir", "-")])


## A target swept on a circle around the shoulder through the direction the
## pole rule points the elbow: at the pole, the bend plane is undefined.
func _through_pole(side: String) -> void:
	f.only(["arm_ik_" + side])
	var chain: float = float(f.limb_rest("arm", side)["len"]) * f.metres_per_unit()
	var s: float = 1.0 if side == "R" else -1.0
	# The default (hand below the shoulder) elbow hint, body frame: out 0.55, down 0.8, back 0.1.
	var hint := Vector3(0.55 * s, -0.8, -0.1).normalized()
	var across := hint.cross(Vector3(0, 0, 1)).normalized()
	var jump := 0.0
	var at := 0.0
	var prev := Vector3.INF
	for i in range(-30, 31):
		var a := deg_to_rad(float(i))
		var dir := (hint * cos(a) + across * sin(a)).normalized()
		_aim(side, _target(side, dir * chain * 0.75))
		await f.settle(1)
		var e: Vector3 = _arm_body(side)["e"]
		if prev != Vector3.INF:
			var j := e.distance_to(prev) * 100.0
			if j > jump:
				jump = j
				at = float(i)
		prev = e
	f.check(jump <= POLE_JUMP_CM, "arm %s target through the pole" % side, "a target swept 1 deg at a time across the elbow-hint direction moves the elbow at most %.1f cm in one step (at %.0f deg)" % [jump, at])


func _reach_policy(side: String) -> void:
	var chain: float = float(f.limb_rest("arm", side)["len"]) * f.metres_per_unit()
	var t := _target(side, Vector3(0, 0, chain * 0.99))
	var clamped: Vector3 = f.actor.call("_clamp_hand_target", side, t)
	var shoulder: Vector3 = f.world(f.gin(F.ARM[side][1]).origin)
	var share: float = shoulder.distance_to(clamped) / chain
	print("    reach policy %s: asked %.3f m, clamped %.3f m, arm_length %.3f m, shoulder_position %s vs bone %s" % [side, shoulder.distance_to(t), shoulder.distance_to(clamped), f.actor.call("arm_length", side), f.actor.call("shoulder_position", side), shoulder])
	f.check(share >= 0.985, "arm %s full extension available" % side, "court_actor._clamp_hand_target lets a hand reach %.1f%% of the chain (asked 99%%; the IK alone reaches 99.5%%, above): a controller policy, not a rig limit" % (share * 100.0))


func _leg_turn(side: String) -> void:
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
	f.sk.move_child(ik, f.last.get_index())
	ik.setting_count = 1
	ik.set_root_bone_name(0, names[0])
	ik.set_middle_bone_name(0, names[1])
	ik.set_end_bone_name(0, names[2])
	ik.set_pole_direction(0, SkeletonModifier3D.SECONDARY_DIRECTION_MINUS_Z)
	ik.set_target_node(0, ik.get_path_to(target))
	ik.set_pole_node(0, ik.get_path_to(pole))
	ik.influence = 1.0
	var r := f.limb_rest("leg", side)
	var chain: float = float(r["len"]) * f.metres_per_unit()
	var ref: Dictionary = {}
	var worst := 0.0
	var at := ""
	for yaw in range(0, 360, 15):
		_set_heading(float(yaw), Vector3(-0.2, 0, 0.3) * float(yaw) / 90.0)
		await f.settle(1)
		var a: Node3D = f.actor
		var hip: Vector3 = f.world(f.gin(names[0]).origin)
		for b: Array in [["knee_lift", Vector3(0, -0.45, 0.3)], ["step_back", Vector3(0, -0.85, -0.35)]]:
			var v: Vector3 = b[1]
			target.global_position = hip + (a.right() * v.x + Vector3.UP * v.y + a.facing() * v.z) * chain
			pole.global_position = hip + a.facing() * 0.6 + Vector3.DOWN * 0.25
			await f.settle(2)
			var m := f.limb(f.last.g, r)
			var knee := _to_body(f.world(m["e"]))
			if yaw == 0:
				ref[b[0]] = knee
			else:
				var cm: float = knee.distance_to(ref[b[0]]) * 100.0
				if cm > worst:
					worst = cm
					at = "%s at %d deg" % [b[0], yaw]
	f.check(worst <= TURN_CM, "leg %s same at every heading" % side, "test-only leg IK turned 0-345 deg: body-frame knee differs by up to %.2f cm (%s)" % [worst, at])
	_set_heading(0.0)
	ik.queue_free()
	target.queue_free()
	pole.queue_free()
