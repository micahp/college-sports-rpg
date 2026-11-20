extends Node
## Does the clip keep the bones it owns? (docs/animation/OWNERSHIP.md)
## Contested jump shot (the tests/contest_views fixture). A tap after every
## skeleton modifier records each bone's local rotation and world position and
## rotation. While a clip owns a bone, every change a modifier makes to it must
## be a PERMITTED correction (named modifier, named bones, bounded); anything
## else is unauthorized and fails. The final drawn pose is also compared with
## the AnimationTree output, position (cm) and rotation (deg), so a hand that
## ends in the right place with the forearm twisted wrong still fails.
##   godot --headless --path . res://tests/clip_fidelity.tscn  [-- verbose]
## Exit 1 on any unauthorized change.
const CourtScene: PackedScene = preload("res://scenes/court/court_game.tscn")
const CourtGame = preload("res://scripts/court/court_game.gd")

const TRUNK: Array = ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head"]
const LEGS: Array = ["LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"]
const ARMS: Array = ["LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand"]
const FEET: Array = ["LeftFoot", "RightFoot", "LeftToes", "RightToes"]
## Where the hand really points: the finger and thumb joints (children of the
## hand bone, not driven by the clip). A hand rotation that moves these moved
## the visible hand; one that does not is only a change in how a bone stores
## its twist. Reported, and the drawn fingers must stay within FINAL_CM.
const DIGITS: Array = ["Fingers.L", "Thumb2.L", "Fingers.R", "Thumb2.R"]

## Who owns what during the jump-shot clip (OWNERSHIP.md):
##   shooter: the JumpShot clip owns the whole body ("mocap owns the arms on a shot")
##   contesting defender: the clip owns trunk and legs; the contest controller
##   owns the arms (checked by tests/contest_pose_check, not here)
const OWNED: Dictionary = {"shooter": TRUNK + LEGS + ARMS, "defender": TRUNK + LEGS}

## Corrections a modifier may make to clip-owned bones: bones, and the most it
## may turn one (deg, local rotation) or move the hips (m, local position).
const PERMITTED: Dictionary = {
	"foot_floor": {"bones": FEET + ["Hips"], "deg": 25.0, "hips_m": 0.12, "why": "grounding: lift a foot or the body out of the floor"},
	"student_feet": {"bones": FEET, "deg": 25.0, "hips_m": 0.0, "why": "student rig foot controls follow the feet"},
}
## Handoff: while the clip's one-shot blends in (court_actor.SHOT_FADE_IN), the
## tree is still mixing the previous pose, and the modifiers that corrected that
## pose fade out with it. Only these, only on these bones, only in that window.
const HANDOFF: Dictionary = {"torso_posture": ["Spine"], "crouch": ["Hips", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"]}
const HANDOFF_FRAMES: int = 8  # 0.12 s at 60 fps, plus the frame the request lands
const EPS_DEG: float = 0.5
const EPS_M: float = 0.003
const FINAL_CM: float = 3.0
const FINAL_DEG: float = 5.0


class Tap extends SkeletonModifier3D:
	var local: Dictionary = {}   # bone -> basis relative to its parent (with the rig's bone scale)
	var lpos: Dictionary = {}    # Hips -> world position (the only bone a modifier may move)
	var gpos: Dictionary = {}    # bone -> world position
	var grot: Dictionary = {}    # bone -> world basis
	var bones: Array = []
	func _process_modification_with_delta(_delta: float) -> void:
		var sk := get_skeleton()
		sk.force_update_all_bone_transforms()
		for b: String in bones:
			var i := sk.find_bone(b)
			if i < 0:
				continue
			var gt: Transform3D = sk.global_transform * sk.get_bone_global_pose(i)
			# Rotation relative to the parent, from world transforms. The bone's
			# stored local rotation is not usable: these bones carry scale, and a
			# modifier that writes a whole pose can change how the engine splits a
			# transform into rotation and scale without the bone moving.
			var par := sk.get_bone_parent(i)
			var pb: Basis = (sk.global_transform * sk.get_bone_global_pose(par)).basis if par >= 0 else Basis.IDENTITY
			local[b] = pb.inverse() * gt.basis
			lpos[b] = gt.origin if b == "Hips" else Vector3.ZERO
			gpos[b] = gt.origin
			grot[b] = gt.basis


func _label(m: Node) -> String:
	return (m.get_script() as Script).resource_path.get_file().get_basename() if m.get_script() != null else m.get_class()


func _stages(actor: Node3D) -> Array:
	var sk: Skeleton3D = CourtPlayerModel.find_skeleton(actor.get("_model"))
	var mods: Array = sk.get_children().filter(func(c): return c is SkeletonModifier3D)
	var all_bones: Array = TRUNK + LEGS + ARMS + FEET + DIGITS
	var out: Array = []
	var t0 := Tap.new()
	t0.bones = all_bones
	sk.add_child(t0)
	sk.move_child(t0, mods[0].get_index())
	out.append(["(animation)", t0])
	for m in mods:
		var t := Tap.new()
		t.bones = all_bones
		sk.add_child(t)
		sk.move_child(t, m.get_index() + 1)
		out.append([_label(m), t])
	return out


## How far basis b is turned from basis a, in degrees: the rotation in
## a^-1 * b. Whole matrices, not quaternions: these bones carry scale, some
## mirrored, and splitting such a basis into one rotation is ambiguous (two
## readings 180 deg apart for the same transform). 999 = handedness flipped.
func _angle(a: Basis, b: Basis) -> float:
	var m: Basis = a.inverse() * b
	if m.determinant() < 0.0:
		return 999.0
	var deg := rad_to_deg(m.orthonormalized().get_rotation_quaternion().get_angle())
	return minf(deg, 360.0 - deg)


## One frame for one actor: every modifier's change to every owned bone.
func _check_frame(who: String, stages: Array, frame: int, bad: Dictionary, final_worst: Dictionary, clip_frame: int = 99) -> void:
	var owned: Array = OWNED[who]
	for si in range(1, stages.size()):
		var label: String = stages[si][0]
		var before: Tap = stages[si - 1][1]
		var after: Tap = stages[si][1]
		for b: String in owned + FEET:
			if not after.local.has(b) or not (b in owned or b in FEET):
				continue
			if not b in owned and b in FEET and not ("LeftFoot" in owned):
				continue
			var deg := _angle(before.local[b], after.local[b])
			var moved: float = (before.lpos[b] as Vector3).distance_to(after.lpos[b])
			if deg < EPS_DEG and moved < EPS_M * 1000.0 * 0.0 + EPS_M:
				continue
			var rule: Dictionary = PERMITTED.get(label, {})
			var ok: bool = not rule.is_empty() and b in rule["bones"] and deg <= float(rule["deg"]) + 0.01
			if clip_frame < HANDOFF_FRAMES and HANDOFF.has(label) and b in HANDOFF[label]:
				ok = true
			if b == "Hips" and moved >= EPS_M:
				ok = ok and moved <= float(rule.get("hips_m", 0.0))
			if not ok:
				var key := "%s | %s | %s" % [who, label, b]
				var cur: Array = bad.get(key, [0.0, 0.0, 999, -1, 0])
				bad[key] = [maxf(cur[0], deg), maxf(cur[1], moved), mini(cur[2], frame), maxi(cur[3], frame), int(cur[4]) + 1]
	if clip_frame < HANDOFF_FRAMES:
		return  # the drawn pose is still handing over: compare from the end of the blend
	# Final: drawn vs AnimationTree output, per owned bone.
	var first: Tap = stages[0][1]
	var last: Tap = stages.back()[1]
	for b: String in owned + (DIGITS if "LeftHand" in owned else []):
		if not last.gpos.has(b):
			continue
		var cm: float = (first.gpos[b] as Vector3).distance_to(last.gpos[b]) * 100.0
		var deg := _angle(first.grot[b], last.grot[b])
		var key := "%s | %s" % [who, b]
		var cur: Array = final_worst.get(key, [0.0, 0.0, 0, 0])
		final_worst[key] = [maxf(cur[0], cm), maxf(cur[1], deg), frame if cm > cur[0] else cur[2], frame if deg > cur[1] else cur[3]]


func _ready() -> void:
	var verbose: bool = OS.get_cmdline_user_args().has("verbose")
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
	var actors := {"shooter": [user, _stages(user)], "defender": [d, _stages(d)]}
	for i in 40:
		await get_tree().physics_frame
	court._begin_shot()
	var bad: Dictionary = {}
	var final_worst: Dictionary = {}
	var frames := {"shooter": 0, "defender": 0}
	for frame in range(1, 121):
		await get_tree().physics_frame
		if frame == 30:
			court._release_shot()
		await get_tree().process_frame
		for who: String in actors:
			var a: Node3D = actors[who][0]
			var act: AnimationNodeAnimation = a.get("_act_node")
			# The clip owns the body while its one-shot plays.
			if float(a.get("_action_time")) > 0.0 and act != null and act.animation == &"JumpShot":
				_check_frame(who, actors[who][1], frame, bad, final_worst, int(frames[who]))
				frames[who] = int(frames[who]) + 1
	print("CLIP FIDELITY: jump-shot clip frames checked: shooter %d, defender %d" % [frames["shooter"], frames["defender"]])
	print("Final drawn vs AnimationTree, worst per owned bone (cm, deg):")
	for who: String in ["shooter", "defender"]:
		var line := "  %s:" % who
		for b: String in OWNED[who] + (DIGITS if "LeftHand" in OWNED[who] else []):
			var key := "%s | %s" % [who, b]
			if final_worst.has(key):
				var v: Array = final_worst[key]
				if verbose or v[0] > FINAL_CM or v[1] > FINAL_DEG:
					line += " %s %.1fcm/%.0fdeg" % [b, v[0], v[1]]
		print(line)
	var final_over: int = 0
	for key: String in final_worst:
		var v: Array = final_worst[key]
		if v[0] > FINAL_CM or v[1] > FINAL_DEG:
			final_over += 1
	print("Owned bones past %.0f cm / %.0f deg from the clip: %d" % [FINAL_CM, FINAL_DEG, final_over])
	if bad.is_empty() and final_over == 0:
		print("No unauthorized modifier changes to clip-owned bones -> ok")
		get_tree().quit(0)
		return
	print("UNAUTHORIZED changes to clip-owned bones (who | modifier | bone: max deg, max m, frames, count):")
	var keys: Array = bad.keys()
	keys.sort()
	for k: String in keys:
		var v: Array = bad[k]
		print("  FAIL %s: %.1f deg, %.3f m, frames %d-%d (%d)" % [k, v[0], v[1], v[2], v[3], v[4]])
	print("CLIP FIDELITY FAILED: %d unauthorized modifier/bone pairs, %d owned bones past the final limit" % [bad.size(), final_over])
	get_tree().quit(1)
