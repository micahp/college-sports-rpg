extends SceneTree
## Draws the court player's sprite sheets from nothing: no 3D model, no
## mocap, no skinning. A player is a set of round 2D shapes (head, torso,
## limbs) placed from a pose, and every pose is written by hand below as
## where the feet, hands and hips are at each moment of a move.
##
##   godot --headless -s tools/court_sprites/draw.gd                 (all clips)
##   godot --headless -s tools/court_sprites/draw.gd -- preview <dir> [clips...]
##
## Output: assets/court/sprites/<Clip>.res (Image, RG8: R = shade, G = part
## code) and meta.json, read by scripts/court/court_sprite_actor.gd.

const Dribble = preload("res://scripts/court/court_dribble.gd")
const OUT: String = "res://assets/court/sprites"
const FPS: float = 15.0
const DIRS: int = 8
const CW: int = 200
const CH: int = 260
const AX: int = 100
const AY: int = 226
const PX_PER_M: float = 104.0 / 1.81
const PITCH_DEG: float = 36.0

# Part codes (the sprite shader paints them).
const OUTLINE: int = 1
const JERSEY: int = 2
const SHORTS: int = 3
const HAIR: int = 4
const SKIN: int = 5
const SHOES: int = 6

# Body, metres.
const HIP_W: float = 0.095
const SHOULDER_W: float = 0.2
const THIGH: float = 0.45
const SHIN: float = 0.45
const UPPER_ARM: float = 0.3
const FOREARM: float = 0.27
const TORSO: float = 0.5
const ANKLE: float = 0.09
const STAND: float = 0.96

var _code: PackedByteArray
var _shade: PackedByteArray
var _sin_p: float
var _cos_p: float
var _meta: Dictionary = {}
var _preview_dir: String = ""


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var only: PackedStringArray = PackedStringArray()
	var i: int = args.find("preview")
	if i >= 0 and i + 1 < args.size():
		_preview_dir = args[i + 1]
		DirAccess.make_dir_recursive_absolute(_preview_dir)
		for j in range(i + 2, args.size()):
			only.append(args[j])
	DirAccess.make_dir_recursive_absolute(OUT)
	_sin_p = sin(deg_to_rad(PITCH_DEG))
	_cos_p = cos(deg_to_rad(PITCH_DEG))
	var meta_path: String = OUT + "/meta.json"
	if not only.is_empty() and FileAccess.file_exists(meta_path):
		var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
		if old is Dictionary:
			_meta = old
	_meta["px_per_m"] = PX_PER_M
	_meta["pitch_deg"] = PITCH_DEG
	_meta["dirs"] = DIRS
	if not _meta.has("clips"):
		_meta["clips"] = {}
	for clip: Dictionary in _clips():
		if only.is_empty() or only.has(str(clip["name"])):
			_bake(clip)
	var f: FileAccess = FileAccess.open(meta_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(_meta))
	f.close()
	print("DRAW DONE")
	quit(0)


# =============================================================================
# The moves. Each returns a pose for u in 0..1: where things are, in metres,
# x = to his right, y = up, z = the way he faces.
# =============================================================================

func _clips() -> Array:
	return [
		{"name": "Idle", "length": 1.6, "loop": true},
		{"name": "Walk", "length": 1.0, "loop": true, "speed": 1.3},
		{"name": "JogM", "length": 0.76, "loop": true, "speed": 2.7},
		{"name": "Run", "length": 0.64, "loop": true, "speed": 4.0},
		{"name": "Jog", "length": 0.54, "loop": true, "speed": 5.4},
		{"name": "SlideL", "length": 0.5, "loop": true, "speed": 2.3},
		{"name": "SlideR", "length": 0.5, "loop": true, "speed": 2.3},
		{"name": "Backpedal", "length": 0.7, "loop": true, "speed": 1.6},
		{"name": "Dribble", "length": 1.0, "loop": true, "speed": 1.3, "dribbles": 2},
		{"name": "DribIdle", "length": 0.56, "loop": true, "dribbles": 1},
		{"name": "DribJogM", "length": 0.76, "loop": true, "speed": 2.7, "dribbles": 2},
		{"name": "DribRun", "length": 0.64, "loop": true, "speed": 4.0, "dribbles": 1},
		{"name": "DribJog", "length": 0.54, "loop": true, "speed": 5.4, "dribbles": 1},
		{"name": "JumpShot", "length": 1.5, "loop": false},
		{"name": "Layup", "length": 1.5, "loop": false},
		{"name": "Jump", "length": 1.2, "loop": false},
		{"name": "Clap", "length": 1.2, "loop": false},
		{"name": "Reach", "length": 0.75, "loop": false},
		{"name": "Pass", "length": 0.72, "loop": false},
		{"name": "HandsUp", "length": 0.07, "loop": false},
		{"name": "CallBall", "length": 0.07, "loop": false},
		{"name": "Screen", "length": 0.07, "loop": false},
	]


func _pose(clip: Dictionary, u: float) -> Dictionary:
	var name: String = clip["name"]
	var length: float = clip["length"]
	var t: float = u * length
	match name:
		"Idle":
			var p: Dictionary = _stand()
			var breath: float = sin(u * TAU) * 0.008
			p["py"] = STAND - 0.02 + breath
			p["hl"] = Vector3(-0.27, 0.86 + breath, 0.06)
			p["hr"] = Vector3(0.27, 0.86 + breath, 0.06)
			return p
		"Walk":
			return _gait(u, 1.3, length, 0.62, 0.1, 0.02, 0.05, 0.55)
		"JogM":
			return _gait(u, 2.7, length, 0.42, 0.22, 0.04, 0.14, 0.9)
		"Run":
			return _gait(u, 4.0, length, 0.36, 0.34, 0.05, 0.22, 1.15)
		"Jog":
			return _gait(u, 5.4, length, 0.3, 0.42, 0.06, 0.3, 1.3)
		"Dribble":
			return _with_dribble(_gait(u, 1.3, length, 0.62, 0.1, 0.05, 0.12, 0.5), clip, u)
		"DribJogM":
			return _with_dribble(_gait(u, 2.7, length, 0.42, 0.22, 0.06, 0.2, 0.8), clip, u)
		"DribRun":
			return _with_dribble(_gait(u, 4.0, length, 0.36, 0.34, 0.06, 0.26, 1.0), clip, u)
		"DribJog":
			return _with_dribble(_gait(u, 5.4, length, 0.3, 0.42, 0.07, 0.32, 1.15), clip, u)
		"DribIdle":
			var p: Dictionary = _stand()
			p["py"] = 0.88
			p["lean"] = 0.2
			p["fl"] = Vector3(-0.2, ANKLE, 0.1)
			p["fr"] = Vector3(0.2, ANKLE, -0.08)
			p["hl"] = Vector3(-0.34, 0.95, 0.22)
			return _with_dribble(p, clip, u)
		"SlideR":
			return _slide(u, 2.3, length)
		"SlideL":
			return _mirror(_slide(u, 2.3, length))
		"Backpedal":
			var p: Dictionary = _gait(1.0 - u, 1.6, length, 0.55, 0.08, 0.1, -0.02, 0.0)
			p["py"] = float(p["py"]) - 0.08
			p["hl"] = Vector3(-0.42, 1.05, 0.22)
			p["hr"] = Vector3(0.42, 1.05, 0.22)
			return p
		"JumpShot":
			return _jump_shot(t)
		"Layup":
			return _layup(t)
		"Jump":
			return _jump(t)
		"Clap":
			var p: Dictionary = _stand()
			var open: float = 0.5 + 0.5 * cos(t / length * TAU * 3.0)
			open *= smoothstep(0.0, 0.15, u) * (1.0 - smoothstep(0.85, 1.0, u)) + (1.0 - smoothstep(0.0, 0.15, u)) + smoothstep(0.85, 1.0, u)
			var raise: float = smoothstep(0.0, 0.15, u) * (1.0 - smoothstep(0.85, 1.0, u))
			p["hl"] = Vector3(-0.27, 0.86, 0.06).lerp(Vector3(-0.03 - 0.16 * open, 1.3, 0.34), raise)
			p["hr"] = Vector3(0.27, 0.86, 0.06).lerp(Vector3(0.03 + 0.16 * open, 1.3, 0.34), raise)
			return p
		"Reach":
			# A swipe at the ball: load to the side, cut across low, recover.
			var p: Dictionary = _defend()
			var wind: Vector3 = Vector3(0.55, 1.0, 0.1)
			var through: Vector3 = Vector3(-0.12, 0.72, 0.62)
			var k: float = smoothstep(0.1, 0.32, t) * (1.0 - smoothstep(0.45, 0.75, t))
			p["hr"] = (p["hr"] as Vector3).lerp(wind, smoothstep(0.0, 0.1, t) * (1.0 - smoothstep(0.5, 0.75, t))).lerp(through, k)
			p["lean"] = 0.3 + 0.22 * k
			p["twist"] = 0.45 * k
			p["pz"] = 0.1 * k
			p["fr"] = Vector3(0.3, ANKLE, 0.12 + 0.2 * k)
			return p
		"Pass":
			# Chest pass: ball at the chest, step and push through, recover.
			var p: Dictionary = _stand()
			var push: float = smoothstep(0.12, 0.32, t) * (1.0 - smoothstep(0.45, 0.72, t))
			var set: float = smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.5, 0.72, t))
			p["py"] = STAND - 0.06 * set
			p["lean"] = 0.08 + 0.2 * push
			p["hl"] = Vector3(-0.27, 0.86, 0.06).lerp(Vector3(-0.12, 1.22, 0.22), set).lerp(Vector3(-0.13, 1.28, 0.68), push)
			p["hr"] = Vector3(0.27, 0.86, 0.06).lerp(Vector3(0.12, 1.22, 0.22), set).lerp(Vector3(0.13, 1.28, 0.68), push)
			p["fr"] = Vector3(0.1, ANKLE, 0.28 * push)
			p["el"] = Vector3(-1.0, -0.4, -0.3)
			p["er"] = Vector3(1.0, -0.4, -0.3)
			return p
		"HandsUp":
			var p: Dictionary = _defend()
			p["py"] = 0.92
			p["lean"] = 0.06
			p["hl"] = Vector3(-0.24, 2.12, 0.2)
			p["hr"] = Vector3(0.24, 2.12, 0.2)
			p["el"] = Vector3(-1.0, 0.1, 0.5)
			p["er"] = Vector3(1.0, 0.1, 0.5)
			return p
		"CallBall":
			var p: Dictionary = _stand()
			p["hr"] = Vector3(0.3, 2.05, 0.18)
			p["er"] = Vector3(1.0, 0.1, 0.4)
			return p
		"Screen":
			var p: Dictionary = _stand()
			p["py"] = 0.9
			p["fl"] = Vector3(-0.26, ANKLE, 0.0)
			p["fr"] = Vector3(0.26, ANKLE, 0.0)
			p["hl"] = Vector3(0.06, 1.14, 0.22)
			p["hr"] = Vector3(-0.06, 1.2, 0.24)
			p["el"] = Vector3(-1.0, -0.6, 0.2)
			p["er"] = Vector3(1.0, -0.6, 0.2)
			return p
	return _stand()


func _stand() -> Dictionary:
	return {"px": 0.0, "py": STAND, "pz": 0.0, "lean": 0.05, "side": 0.0, "twist": 0.0, "root": 0.0,
		"fl": Vector3(-0.11, ANKLE, 0.0), "fr": Vector3(0.11, ANKLE, 0.0), "lift_l": 0.0, "lift_r": 0.0,
		"hl": Vector3(-0.27, 0.86, 0.06), "hr": Vector3(0.27, 0.86, 0.06),
		"el": Vector3(-0.3, -0.3, -1.0), "er": Vector3(0.3, -0.3, -1.0)}


## Defensive stance: low, wide, hands out.
func _defend() -> Dictionary:
	var p: Dictionary = _stand()
	p["py"] = 0.8
	p["lean"] = 0.3
	p["fl"] = Vector3(-0.36, ANKLE, 0.02)
	p["fr"] = Vector3(0.36, ANKLE, 0.02)
	p["hl"] = Vector3(-0.56, 1.0, 0.3)
	p["hr"] = Vector3(0.56, 1.0, 0.3)
	p["el"] = Vector3(-0.8, -0.6, -0.2)
	p["er"] = Vector3(0.8, -0.6, -0.2)
	return p


## One leg through a stride: on the floor moving back under him for `stance`
## of the cycle, then lifted and swung forward. Returns [ankle, lift 0..1].
func _leg(phase: float, side: float, speed: float, length: float, stance: float, lift: float) -> Array:
	var half: float = speed * stance * length * 0.5
	phase = fposmod(phase, 1.0)
	if phase < stance:
		return [Vector3(side * 0.1, ANKLE, 0.06 + half - 2.0 * half * phase / stance), 0.0]
	var s: float = (phase - stance) / (1.0 - stance)
	var z: float = 0.06 - half + 2.0 * half * smoothstep(0.0, 1.0, s)
	var up: float = sin(PI * pow(s, 0.75))
	return [Vector3(side * 0.1, ANKLE + lift * up, z), up]


## Walking and running. u = 0 is the left foot landing.
func _gait(u: float, speed: float, length: float, stance: float, lift: float, crouch: float, lean: float, arms: float) -> Dictionary:
	var p: Dictionary = _stand()
	var l: Array = _leg(u, -1.0, speed, length, stance, lift)
	var r: Array = _leg(u + 0.5, 1.0, speed, length, stance, lift)
	p["fl"] = l[0]
	p["fr"] = r[0]
	p["lift_l"] = l[1]
	p["lift_r"] = r[1]
	# Lowest as each foot takes the weight, highest between steps.
	p["py"] = STAND - 0.03 - crouch - 0.025 * cos(u * 2.0 * TAU) * minf(1.0, speed / 2.5)
	p["lean"] = lean
	var swing: float = cos(u * TAU)  # +1: left leg forward, so right arm forward
	p["twist"] = 0.16 * swing * minf(arms, 1.0)
	var sh: float = float(p["py"]) + TORSO - 0.03
	var fwd: Vector3 = Vector3(0.12, -0.3, 0.27)
	var back: Vector3 = Vector3(0.21, -0.4, -0.2)
	var rest: Vector3 = Vector3(0.25, -0.52, 0.04)
	var kr: float = 0.5 + 0.5 * swing
	var kl: float = 0.5 - 0.5 * swing
	var hr: Vector3 = rest.lerp(back.lerp(fwd, kr), clampf(arms, 0.0, 1.0)) * Vector3(1, 1, maxf(1.0, arms))
	var hl: Vector3 = rest.lerp(back.lerp(fwd, kl), clampf(arms, 0.0, 1.0)) * Vector3(1, 1, maxf(1.0, arms))
	p["hr"] = Vector3(hr.x, sh + hr.y, hr.z + lean * 0.3)
	p["hl"] = Vector3(-hl.x, sh + hl.y, hl.z + lean * 0.3)
	return p


## Defensive slide to his right: the lead foot reaches, the trail foot follows.
func _slide(u: float, speed: float, length: float) -> Dictionary:
	var p: Dictionary = _defend()
	var stance: float = 0.58
	var half: float = speed * stance * length * 0.5
	var feet: Array = []
	for k in 2:
		var phase: float = fposmod(u + 0.5 * k, 1.0)
		var base: float = 0.36 if k == 0 else -0.36
		var x: float
		var y: float = ANKLE
		if phase < stance:
			x = base + half - 2.0 * half * phase / stance
		else:
			var s: float = (phase - stance) / (1.0 - stance)
			x = base - half + 2.0 * half * smoothstep(0.0, 1.0, s)
			y += 0.07 * sin(PI * s)
		feet.append(Vector3(x, y, 0.02))
	p["fr"] = feet[0]
	p["fl"] = feet[1]
	p["py"] = 0.8 + 0.015 * cos(u * 2.0 * TAU)
	p["side"] = 0.05
	return p


## The right hand rides the ball (CourtDribble's curve); the left arm guards.
func _with_dribble(p: Dictionary, clip: Dictionary, u: float) -> Dictionary:
	var table: Dictionary = clip["table"]
	var hand_y: float = Dribble.sample(table["hand"], u * int(clip["dribbles"]))
	p["hr"] = Vector3(-Dribble.LOCAL.x, hand_y, Dribble.LOCAL.z)
	p["er"] = Vector3(0.9, -0.2, -0.6)
	p["lean"] = float(p["lean"]) + 0.08
	p["py"] = float(p["py"]) - 0.03
	return p


func _jump_arc(t: float, takeoff: float, land: float, height: float) -> float:
	if t <= takeoff or t >= land:
		return 0.0
	var s: float = (t - takeoff) / (land - takeoff)
	return height * 4.0 * s * (1.0 - s)


## Jump shot. The ball leaves the hand 1.0 s in (the game times its release to that).
func _jump_shot(t: float) -> Dictionary:
	var p: Dictionary = _stand()
	var dip: float = smoothstep(0.0, 0.5, t) * (1.0 - smoothstep(0.62, 0.86, t))
	var rise: float = smoothstep(0.5, 0.88, t)
	var extend: float = smoothstep(0.84, 1.0, t)
	var down: float = smoothstep(1.2, 1.5, t)
	var air: float = _jump_arc(t, 0.86, 1.24, 0.2)
	var land: float = smoothstep(1.24, 1.32, t) * (1.0 - smoothstep(1.32, 1.5, t))
	p["root"] = air
	p["py"] = STAND - 0.17 * dip - 0.08 * land
	p["lean"] = 0.1 + 0.14 * dip - 0.06 * extend
	p["fl"] = Vector3(-0.15, ANKLE, 0.0)
	p["fr"] = Vector3(0.15, ANKLE, 0.06)
	if air > 0.0:
		p["lift_l"] = 0.6
		p["lift_r"] = 0.6
	# Ball: off the dribble at his right hip, to the pocket, up past the face, out.
	var ball: Vector3 = Vector3(0.28, 0.92, 0.3).lerp(Vector3(0.1, 1.02, 0.26), smoothstep(0.0, 0.4, t))
	ball = ball.lerp(Vector3(0.1, 1.74, 0.2), rise).lerp(Vector3(0.12, 2.28, 0.4), extend)
	var hr: Vector3 = ball + Vector3(0.02, -0.1, -0.03)
	var hl: Vector3 = (ball + Vector3(-0.15, -0.02, 0.02)).lerp(Vector3(-0.1, 1.86, 0.24), extend)
	p["hr"] = hr.lerp(Vector3(0.27, 0.9, 0.08), down)
	p["hl"] = hl.lerp(Vector3(-0.27, 0.9, 0.08), down)
	p["er"] = Vector3(0.5, -0.3, 0.9).lerp(Vector3(0.5, -0.4, -0.8), down)
	p["el"] = Vector3(-0.9, -0.3, 0.6).lerp(Vector3(-0.5, -0.4, -0.8), down)
	return p


## Layup: two steps, up off the left foot at 0.5 s, right hand lays it in at 1.0 s.
func _layup(t: float) -> Dictionary:
	var p: Dictionary
	if t < 0.5:
		p = _gait(0.5 + t / 0.5 * 0.5, 4.0, 0.64, 0.36, 0.3, 0.07, 0.22, 0.0)
	else:
		p = _stand()
		p["lean"] = lerpf(0.22, 0.02, smoothstep(0.5, 1.0, t))
	var air: float = _jump_arc(t, 0.5, 1.26, 0.52)
	var up: float = smoothstep(0.42, 0.95, t)
	var down: float = smoothstep(1.12, 1.45, t)
	var land: float = smoothstep(1.26, 1.34, t) * (1.0 - smoothstep(1.34, 1.5, t))
	p["root"] = air
	if t >= 0.5:
		p["py"] = STAND - 0.1 * land
		# Left leg pushes off and trails; right knee drives up, then both come down.
		var knee: float = smoothstep(0.5, 0.72, t) * (1.0 - smoothstep(0.95, 1.26, t))
		p["fl"] = Vector3(-0.1, ANKLE + 0.02, -0.16 * knee)
		p["fr"] = Vector3(0.1, ANKLE + 0.42 * knee, 0.3 * knee)
		p["lift_l"] = 0.7 if air > 0.0 else 0.0
		p["lift_r"] = 0.5 if air > 0.0 else 0.0
	var carry: Vector3 = Vector3(0.14, 1.12, 0.26)
	var hr: Vector3 = carry.lerp(Vector3(0.16, 2.3, 0.34), up)
	var hl: Vector3 = (carry + Vector3(-0.2, 0.02, 0.02)).lerp(Vector3(-0.22, 1.28, 0.24), up)
	p["hr"] = hr.lerp(Vector3(0.27, 0.9, 0.08), down)
	p["hl"] = hl.lerp(Vector3(-0.27, 0.9, 0.08), down)
	p["er"] = Vector3(0.6, -0.2, 0.7).lerp(Vector3(0.5, -0.4, -0.8), down)
	return p


## A contest: load, go straight up with both hands, land.
func _jump(t: float) -> Dictionary:
	var p: Dictionary = _stand()
	var load: float = smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(0.24, 0.36, t))
	var up: float = smoothstep(0.12, 0.42, t) * (1.0 - smoothstep(0.85, 1.15, t))
	var air: float = _jump_arc(t, 0.3, 0.82, 0.34)
	var land: float = smoothstep(0.82, 0.9, t) * (1.0 - smoothstep(0.9, 1.15, t))
	p["root"] = air
	p["py"] = STAND - 0.2 * load - 0.1 * land
	p["lean"] = 0.08 + 0.18 * load
	p["fl"] = Vector3(-0.17, ANKLE, 0.0)
	p["fr"] = Vector3(0.17, ANKLE, 0.0)
	if air > 0.0:
		p["lift_l"] = 0.7
		p["lift_r"] = 0.7
	p["hl"] = Vector3(-0.3, 0.92, 0.1).lerp(Vector3(-0.2, 2.26, 0.2), up)
	p["hr"] = Vector3(0.3, 0.92, 0.1).lerp(Vector3(0.2, 2.3, 0.2), up)
	p["el"] = Vector3(-0.5, -0.4, -0.8).lerp(Vector3(-1.0, 0.1, 0.5), up)
	p["er"] = Vector3(0.5, -0.4, -0.8).lerp(Vector3(1.0, 0.1, 0.5), up)
	return p


func _mirror(p: Dictionary) -> Dictionary:
	var m: Dictionary = p.duplicate()
	var flip: Vector3 = Vector3(-1, 1, 1)
	m["fl"] = (p["fr"] as Vector3) * flip
	m["fr"] = (p["fl"] as Vector3) * flip
	m["hl"] = (p["hr"] as Vector3) * flip
	m["hr"] = (p["hl"] as Vector3) * flip
	m["el"] = (p["er"] as Vector3) * flip
	m["er"] = (p["el"] as Vector3) * flip
	m["lift_l"] = p["lift_r"]
	m["lift_r"] = p["lift_l"]
	m["px"] = -float(p["px"])
	m["side"] = -float(p["side"])
	m["twist"] = -float(p["twist"])
	return m


# =============================================================================
# Pose -> joints -> shapes -> pixels
# =============================================================================

## Middle joint of a two-part limb that reaches from `a` to `t`, bending toward `pole`.
func _bend(a: Vector3, t: Vector3, l1: float, l2: float, pole: Vector3) -> Array:
	var to: Vector3 = t - a
	var d: float = clampf(to.length(), 0.05, (l1 + l2) * 0.995)
	var along: Vector3 = to.normalized()
	var end: Vector3 = a + along * d
	var x: float = (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h: float = sqrt(maxf(0.0, l1 * l1 - x * x))
	var side: Vector3 = pole - along * pole.dot(along)
	side = side.normalized() if side.length() > 0.001 else Vector3(0, 0, 1)
	return [a + along * x + side * h, end]


## Every shape of the body for this pose, in body space:
## [from, to, radius_from, radius_to, part, sort_bias]
func _shapes(p: Dictionary) -> Array:
	var root: Vector3 = Vector3(0, float(p["root"]), 0)
	var pelvis: Vector3 = Vector3(float(p["px"]), float(p["py"]), float(p["pz"])) + root
	var lean: float = p["lean"]
	var side: float = p["side"]
	var up: Vector3 = Vector3(sin(side), cos(lean) * cos(side), sin(lean)).normalized()
	var tw: float = p["twist"]
	var across: Vector3 = Vector3(cos(tw), 0.0, sin(tw))
	var neck: Vector3 = pelvis + up * TORSO
	var head_up: Vector3 = (up + Vector3.UP).normalized()
	var head: Vector3 = neck + head_up * 0.17
	var fwd: Vector3 = Vector3(-sin(tw), 0.0, cos(tw))
	var out: Array = []
	# Legs.
	for k in 2:
		var s: float = -1.0 if k == 0 else 1.0
		var hip: Vector3 = pelvis + Vector3(s * HIP_W, 0, 0)
		var ankle: Vector3 = (p["fl"] if k == 0 else p["fr"]) + root
		var lift: float = p["lift_l"] if k == 0 else p["lift_r"]
		var leg: Array = _bend(hip, ankle, THIGH, SHIN, Vector3(s * 0.12, 0.0, 1.0))
		var knee: Vector3 = leg[0]
		ankle = leg[1]
		var mid: Vector3 = hip.lerp(knee, 0.62)
		out.append([hip, mid, 0.1, 0.09, SHORTS, 0.01])
		out.append([mid, knee, 0.07, 0.062, SKIN, 0.0])
		out.append([knee, ankle, 0.066, 0.046, SKIN, 0.0])
		var toe: Vector3 = ankle + Vector3(s * 0.02, -0.05 - 0.1 * lift, 0.17 - 0.05 * lift)
		toe.y = maxf(toe.y, 0.04 + root.y * 0.0)
		out.append([ankle + Vector3(0, -0.035, -0.03), toe, 0.056, 0.046, SHOES, 0.0])
	out.append([pelvis + Vector3(-HIP_W, 0.02, 0), pelvis + Vector3(HIP_W, 0.02, 0), 0.125, 0.125, SHORTS, 0.0])
	# Trunk, shoulders, neck, head.
	out.append([pelvis + up * 0.13, neck - up * 0.1, 0.132, 0.15, JERSEY, 0.0])
	var sh_l: Vector3 = neck - up * 0.035 - across * SHOULDER_W
	var sh_r: Vector3 = neck - up * 0.035 + across * SHOULDER_W
	out.append([sh_l.lerp(sh_r, 0.12), sh_r.lerp(sh_l, 0.12), 0.082, 0.082, JERSEY, 0.0])
	out.append([neck - up * 0.02, head - head_up * 0.04, 0.05, 0.05, SKIN, -0.02])
	out.append([head, head, 0.118, 0.118, SKIN, 0.0])
	var hair: Vector3 = head + head_up * 0.04 - fwd * 0.05
	out.append([hair, hair, 0.104, 0.104, HAIR, 0.0])
	for s: float in [-1.0, 1.0]:
		var eye: Vector3 = head + fwd * 0.105 + across * s * 0.042 + head_up * 0.012
		out.append([eye, eye, 0.014, 0.014, HAIR, 0.06])
	# Arms.
	for k in 2:
		var sh: Vector3 = sh_l if k == 0 else sh_r
		var hand: Vector3 = (p["hl"] if k == 0 else p["hr"]) + root
		var arm: Array = _bend(sh, hand, UPPER_ARM, FOREARM, p["el"] if k == 0 else p["er"])
		out.append([sh, arm[0], 0.06, 0.051, SKIN, 0.0])
		out.append([arm[0], arm[1], 0.049, 0.04, SKIN, 0.0])
		out.append([arm[1], arm[1], 0.046, 0.046, SKIN, 0.005])
	return out


func _hands(p: Dictionary) -> Array:
	var shapes: Array = _shapes(p)
	var n: int = shapes.size()
	return [shapes[n - 4][0], shapes[n - 1][0]]  # left hand, right hand


func _render(p: Dictionary, dir: int) -> Image:
	_code.fill(0)
	_shade.fill(0)
	var yaw: float = dir * TAU / DIRS
	var face: Vector3 = Vector3(sin(yaw), 0, cos(yaw))
	var right: Vector3 = Vector3(-cos(yaw), 0, sin(yaw))
	var shapes: Array = _shapes(p)
	var order: Array = []
	for s: Array in shapes:
		var a: Vector3 = right * (s[0] as Vector3).x + Vector3.UP * (s[0] as Vector3).y + face * (s[0] as Vector3).z
		var b: Vector3 = right * (s[1] as Vector3).x + Vector3.UP * (s[1] as Vector3).y + face * (s[1] as Vector3).z
		var depth: float = ((a.y + b.y) * 0.5 * _sin_p + (a.z + b.z) * 0.5 * _cos_p) + float(s[5])
		order.append([depth, _screen(a), _screen(b), float(s[2]) * PX_PER_M, float(s[3]) * PX_PER_M, int(s[4])])
	order.sort_custom(func(m: Array, n: Array) -> bool: return m[0] < n[0])
	for s: Array in order:
		_capsule(s[1], s[2], s[3], s[4], s[5])
	# Outline around the whole figure.
	var img_data: PackedByteArray = PackedByteArray()
	img_data.resize(CW * CH * 4)
	for y in range(1, CH - 1):
		for x in range(1, CW - 1):
			var i: int = y * CW + x
			var c: int = _code[i]
			var o: int = i * 4
			if c == 0:
				if _code[i - 1] > 0 or _code[i + 1] > 0 or _code[i - CW] > 0 or _code[i + CW] > 0:
					img_data[o + 1] = OUTLINE * 28
					img_data[o + 3] = 255
			else:
				img_data[o] = _shade[i]
				img_data[o + 1] = c * 28
				img_data[o + 3] = 255
	return Image.create_from_data(CW, CH, false, Image.FORMAT_RGBA8, img_data)


func _screen(w: Vector3) -> Vector2:
	return Vector2(AX + w.x * PX_PER_M, AY - (w.y * _cos_p - w.z * _sin_p) * PX_PER_M)


## A round-ended limb, lit from the upper left in three tones, with a dark
## rim on its shadow side so limbs read against the body.
func _capsule(a: Vector2, b: Vector2, ra: float, rb: float, code: int) -> void:
	var rmax: float = maxf(ra, rb) + 1.0
	var x0: int = maxi(1, int(floor(minf(a.x, b.x) - rmax)))
	var x1: int = mini(CW - 2, int(ceil(maxf(a.x, b.x) + rmax)))
	var y0: int = maxi(1, int(floor(minf(a.y, b.y) - rmax)))
	var y1: int = mini(CH - 2, int(ceil(maxf(a.y, b.y) + rmax)))
	var ab: Vector2 = b - a
	var len2: float = ab.length_squared()
	var tiny: bool = maxf(ra, rb) < 1.5
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var px: float = x + 0.5
			var py: float = y + 0.5
			var t: float = 0.0
			if len2 > 0.0001:
				t = clampf(((px - a.x) * ab.x + (py - a.y) * ab.y) / len2, 0.0, 1.0)
			var dx: float = px - (a.x + ab.x * t)
			var dy: float = py - (a.y + ab.y * t)
			var r: float = ra + (rb - ra) * t
			var d2: float = dx * dx + dy * dy
			if d2 > r * r:
				continue
			var i: int = y * CW + x
			var tone: int = 255
			if tiny:
				tone = 110
			else:
				var k: float = (dx * -0.62 + dy * -0.78) / r
				if k < -0.5:
					tone = 150
				elif k < 0.12:
					tone = 205
				if k < -0.15 and d2 > (r - 1.0) * (r - 1.0):
					tone = 118
			_code[i] = code
			_shade[i] = tone


func _bake(clip: Dictionary) -> void:
	var name: String = clip["name"]
	var length: float = clip["length"]
	var loops: bool = clip["loop"]
	var n: int = maxi(1, roundi(length * FPS))
	if clip.has("dribbles"):
		clip["table"] = Dribble.table(length / int(clip["dribbles"]))
	_code.resize(CW * CH)
	_shade.resize(CW * CH)
	var cells: Array = []
	var hands_r: Array = []
	var hands_l: Array = []
	var used: Rect2i = Rect2i()
	for f in n:
		var u: float = float(f) / float(n) if loops else float(f) / float(maxi(1, n - 1)) * (float(n - 1) / float(n))
		var p: Dictionary = _pose(clip, u)
		var hands: Array = _hands(p)
		hands_l.append(_model_space(hands[0]))
		hands_r.append(_model_space(hands[1]))
		var row: Array = []
		for d in DIRS:
			var img: Image = _render(p, d)
			var r: Rect2i = img.get_used_rect()
			if r.size.x > 0:
				used = r if used.size.x == 0 else used.merge(r)
			row.append(img)
		cells.append(row)
	if used.position.x <= 1 or used.position.y <= 1 or used.end.x >= CW - 1 or used.end.y >= CH - 1:
		print("WARNING ", name, " touches the cell edge: ", used)
	var sheet: Image = Image.create(used.size.x * n, used.size.y * DIRS, false, Image.FORMAT_RGBA8)
	for f in n:
		for d in DIRS:
			sheet.blit_rect(cells[f][d] as Image, used, Vector2i(f * used.size.x, d * used.size.y))
	if _preview_dir != "":
		_preview(sheet).save_png("%s/%s.png" % [_preview_dir, name])
	sheet.convert(Image.FORMAT_RG8)
	var err: int = ResourceSaver.save(sheet, "%s/%s.res" % [OUT, name], ResourceSaver.FLAG_COMPRESS)
	var entry: Dictionary = {"frames": n, "length": length, "loop": loops, "cw": used.size.x, "ch": used.size.y,
		"ax": AX - used.position.x, "ay": AY - used.position.y, "hand_r": hands_r, "hand_l": hands_l}
	if clip.has("speed"):
		entry["speed"] = clip["speed"]
	if clip.has("dribbles"):
		entry["dribbles"] = clip["dribbles"]
		entry["ball"] = (clip["table"] as Dictionary)["ball"]
		entry["bounce"] = (clip["table"] as Dictionary)["bounce"]
	(_meta["clips"] as Dictionary)[name] = entry
	print("drew %-9s %2d frames  %.2fs  cell %dx%d  save %d" % [name, n, length, used.size.x, used.size.y, err])


## Body space (x = his right) to the game's model space at yaw 0 (-x = his right).
func _model_space(v: Vector3) -> Array:
	return [snappedf(-v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


## The sheet with sample team colours, for looking at.
func _preview(sheet: Image) -> Image:
	var out: Image = Image.create(sheet.get_width(), sheet.get_height(), false, Image.FORMAT_RGBA8)
	out.fill(Color(0.78, 0.62, 0.4))
	var part: Array[Color] = [Color.BLACK, Color(0.07, 0.06, 0.1), Color(0.92, 0.72, 0.3), Color(0.12, 0.2, 0.42),
		Color(0.08, 0.07, 0.06), Color(0.48, 0.34, 0.24), Color(0.95, 0.95, 0.95)]
	var src: PackedByteArray = sheet.get_data()
	var w: int = sheet.get_width()
	for i in range(0, src.size(), 4):
		if src[i + 3] < 128:
			continue
		var code: int = clampi(int(round(src[i + 1] / 28.0)), 0, 6)
		var c: Color = part[code]
		if code > 1:
			var s: float = pow(src[i] / 255.0, 2.2)
			c = Color(pow(c.r, 2.2) * s, pow(c.g, 2.2) * s, pow(c.b, 2.2) * s)
			c = Color(pow(c.r, 1.0 / 2.2), pow(c.g, 1.0 / 2.2), pow(c.b, 1.0 / 2.2))
		@warning_ignore("integer_division")
		out.set_pixel((i / 4) % w, (i / 4) / w, Color(c.r, c.g, c.b, 1.0))
	return out
