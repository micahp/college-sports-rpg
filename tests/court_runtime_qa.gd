extends Node3D
## Runtime animation QA: drives one court player through every movement and
## transition the game uses, the way the game drives it (velocity in,
## AnimationTree out), and measures what stills can't show:
##   slide   planted-foot travel in world space, as a share of ground speed
##   sink    how far a foot goes below the floor
##   pop     fastest joint movement in body space (a spike = a pose jump)
## Record it with Godot's movie writer so the same run is the video:
##   godot --write-movie out.avi --fixed-fps 60 tests/court_runtime_qa.tscn -- out <dir>

const Actor = preload("res://scripts/court/court_actor.gd")
const JOINTS: Array[String] = ["Hips", "Head", "LeftHand", "RightHand", "LeftFoot", "RightFoot"]
const TOES: Array[String] = ["LeftToes", "RightToes"]
const FLOOR: float = 0.012  # where Idle's toes rest
const SLIDE_FAIL: float = 0.25  # planted foot moving at over 25% of ground speed
const SLIDE_WARN: float = 0.12
const POP_FAIL: float = 14.0  # m/s in body space; sprinting hands peak near 8

## [label, mode, velocity (x, z) in m/s, seconds]. Facing: -Z is "upcourt".
const PLAN: Array = [
	["calib: walk at its own 0.97", "loco", Vector2(0, -0.97), 3.0],
	["calib: jog at its own 2.68", "loco", Vector2(0, -2.68), 2.5],
	["calib: run at its own 3.60", "loco", Vector2(0, -3.60), 2.5],
	["calib: slide at its own 2.63", "defense", Vector2(2.63, 0), 2.5],
	["loco: idle", "loco", Vector2(0, 0), 1.5],
	["loco: walk 1.6", "loco", Vector2(0, -1.6), 2.5],
	["loco: jog 3.4", "loco", Vector2(0, -3.4), 2.5],
	["loco: sprint 5.0", "loco", Vector2(0, -5.0), 2.5],
	["loco: stop from sprint", "loco", Vector2(0, 0), 1.5],
	["loco: jog, cut 90", "loco", Vector2(3.4, 0), 2.0],
	["loco: jog, reverse 180", "loco", Vector2(-3.4, 0), 2.0],
	["dribble: standing", "dribble", Vector2(0, 0), 2.0],
	["dribble: walk 1.5", "dribble", Vector2(0, -1.5), 3.0],
	["dribble: run 3.9", "dribble", Vector2(0, -3.9), 2.5],
	["dribble: sprint 4.7", "dribble", Vector2(0, -4.7), 2.0],
	["dribble: stop", "dribble", Vector2(0, 0), 1.5],
	["defense: stance", "defense", Vector2(0, 0), 1.5],
	["defense: slide left 2.5", "defense", Vector2(-2.5, 0), 2.5],
	["defense: slide right 2.5", "defense", Vector2(2.5, 0), 2.5],
	["defense: slide left slow 1.2", "defense", Vector2(-1.2, 0), 2.0],
	["defense: backpedal 2.0", "defense", Vector2(0, 2.0), 2.0],
	["defense: close out 3.5", "defense", Vector2(0, -3.5), 1.5],
	["switch: jog to dribble", "dribble", Vector2(0, -3.4), 1.5],
	["switch: dribble to defense", "defense", Vector2(-2.0, 0), 1.5],
	["switch: defense to jog", "loco", Vector2(0, -3.4), 1.5],
]

var _actor: Node3D
var _sk: Skeleton3D
var _cam: Camera3D
var _label: Label
var _step: int = -1
var _left: float = 0.0
var _rows: Array = []
var _cur: Dictionary = {}
var _prev_toe: Dictionary = {}
var _prev_joint: Dictionary = {}
var _out: String = ""
var _ankle_floor: float = 0.09
var _final_toe: Dictionary = {}


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[args.find("out") + 1] if args.find("out") >= 0 else ""
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.18, 0.24)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.75
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	add_child(sun)
	# A gridded floor: a sliding foot shows against the lines.
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(400, 400)
	floor_mesh.mesh = plane
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = """
shader_type spatial;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 g = abs(fract(wp.xz * 2.0) - 0.5);
	float line = step(0.47, max(g.x, g.y));
	vec2 big = abs(fract(wp.xz * 0.5) - 0.5);
	float thick = step(0.485, max(big.x, big.y));
	ALBEDO = mix(vec3(0.74, 0.55, 0.33), vec3(0.3, 0.2, 0.1), max(line * 0.6, thick));
	ROUGHNESS = 0.7;
}
"""
	floor_mesh.material_override = mat
	add_child(floor_mesh)
	_actor = Actor.new()
	add_child(_actor)
	_actor.setup("", {"Shirt": Color(0.92, 0.72, 0.3), "Pants": Color(0.12, 0.2, 0.42),
		"Skin": Color(0.48, 0.34, 0.24), "Socks": Color(0.95, 0.95, 0.95)}, 0, 0.15)
	_sk = _actor.get("_skeleton")
	_ankle_floor = _sk.get_bone_global_rest(_sk.find_bone("LeftFoot")).origin.y
	_cam = Camera3D.new()
	_cam.fov = 40.0
	add_child(_cam)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(24, 18)
	_label.add_theme_font_size_override("font_size", 28)
	layer.add_child(_label)
	var tap: SkeletonModifier3D = SkeletonModifier3D.new()  # last modifier: sees the final pose
	var tap_script: GDScript = GDScript.new()
	tap_script.source_code = "extends SkeletonModifier3D
var qa: Node
func _process_modification_with_delta(_d: float) -> void:
	qa.final_pose(get_skeleton())
"
	tap_script.reload()
	tap.set_script(tap_script)
	tap.set("qa", self)
	_sk.add_child(tap)
	var probe: Node = Node.new()  # measures after the AnimationTree has posed this frame
	probe.process_priority = 1000
	probe.set_script(_probe_script())
	probe.set("qa", self)
	add_child(probe)
	_advance()


func _probe_script() -> GDScript:
	var s: GDScript = GDScript.new()
	s.source_code = "extends Node\nvar qa: Node\nfunc _process(delta: float) -> void:\n\tqa.measure(delta)\n"
	s.reload()
	return s


func _advance() -> void:
	if not _cur.is_empty():
		_rows.append(_cur)
	_step += 1
	if _step >= PLAN.size():
		_finish()
		return
	var p: Array = PLAN[_step]
	_left = p[3]
	_cur = {"label": p[0], "time": 0.0, "dist": 0.0, "planted_t": 0.0, "slide": 0.0, "sink": 0.0, "pop": 0.0,
		"pop_joint": ""}
	_label.text = "%s" % p[0]


func _physics_process(delta: float) -> void:
	if _step < 0 or _step >= PLAN.size():
		return
	var p: Array = PLAN[_step]
	var mode: String = p[1]
	var v: Vector2 = p[2]
	_actor.pose_reset()
	_actor.team = 1 if mode == "defense" else 0
	_actor.has_ball = mode == "dribble"
	if mode == "defense":
		_actor.lock_face(_actor.position + Vector3(0, 0, -8.0))
	var before: Vector3 = _actor.position
	_actor.move_with(Vector3(v.x, 0, v.y), delta, 16.0)
	_cur["dist"] = float(_cur["dist"]) + _actor.position.distance_to(before)
	_actor.animate(delta)
	_left -= delta
	if _left <= 0.0:
		_advance()


## Final bone poses, with every modifier applied (what is actually drawn).
func final_pose(sk: Skeleton3D) -> void:
	for toe: String in TOES:
		_final_toe[toe] = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(toe)).origin


## Called after the pose is final for this rendered frame.
func measure(delta: float) -> void:
	if _cur.is_empty() or delta <= 0.0 or _step >= PLAN.size():
		return
	_cam.position = _actor.position + Vector3(3.6, 1.5, 3.4)
	_cam.look_at(_actor.position + Vector3(0, 0.95, 0))
	_cur["time"] = float(_cur["time"]) + delta
	var to_world: Transform3D = _sk.global_transform
	var toes: Array[Vector3] = []
	for toe: String in TOES:
		var w: Vector3 = _final_toe.get(toe, to_world * _sk.get_bone_global_pose(_sk.find_bone(toe)).origin)
		_cur["sink"] = minf(float(_cur["sink"]), w.y - FLOOR)
		toes.append(w)
	# Measured slide: in single support (one toe on the floor, the other
	# clearly off it) the grounded toe should not travel.
	var low: int = 0 if toes[0].y < toes[1].y else 1
	if toes[low].y < FLOOR + 0.02 and toes[1 - low].y > toes[low].y + 0.04 and _prev_toe.has(low) and int(_prev_toe.get("who", -1)) == low:
		_cur["m_slide"] = float(_cur.get("m_slide", 0.0)) + Vector2(toes[low].x - (_prev_toe[low] as Vector3).x, toes[low].z - (_prev_toe[low] as Vector3).z).length()
		_cur["m_time"] = float(_cur.get("m_time", 0.0)) + delta
	_prev_toe[low] = toes[low]
	_prev_toe["who"] = low
	var lift_node: Variant = _actor.get("_feet")
	if lift_node != null:
		_cur["lift"] = maxf(float(_cur.get("lift", 0.0)), float((lift_node as Node).get("last_lift")))
	# Skate: the clip carries the body at (rate x its recorded speed) in its
	# own direction; anything the body does beyond that drags a planted foot.
	var gait: String = _actor.get("_gait")
	var body_v: Vector3 = _actor.get("vel")
	var carried: Vector3 = Vector3.ZERO
	if CourtPlayerModel.CLIP_SPEED.has(gait):
		var rate: float = clampf(body_v.length() / float(CourtPlayerModel.CLIP_SPEED[gait]), 0.5, 1.9)
		var dir: Vector2 = CourtPlayerModel.CLIP_DIR[gait]
		var f: Vector3 = _actor.call("facing")
		var r: Vector3 = _actor.call("right")
		carried = (r * dir.x + f * dir.y) * rate * float(CourtPlayerModel.CLIP_SPEED[gait])
	_cur["slide"] = float(_cur["slide"]) + (body_v - carried).length() * delta
	_cur["planted_t"] = float(_cur["planted_t"]) + delta
	for j: String in JOINTS:
		var m: Vector3 = _sk.get_bone_global_pose(_sk.find_bone(j)).origin
		if _prev_joint.has(j):
			var speed: float = m.distance_to(_prev_joint[j]) / delta
			if speed > float(_cur["pop"]):
				_cur["pop"] = speed
				_cur["pop_joint"] = j
			if speed > POP_FAIL and OS.get_cmdline_user_args().has("debug"):
				print("POP %.1f m/s %s at %.2fs of '%s' gait=%s" % [speed, j, float(_cur["time"]), _cur["label"], _actor.get("_gait")])
		_prev_joint[j] = m


func _finish() -> void:
	var fps: int = Engine.get_frames_per_second() if Engine.get_write_movie_path() == "" else 0
	var lines: PackedStringArray = []
	lines.append("segment | ground m/s | skate m/s (from clip speed) | skate % | measured single-support slide m/s | sink cm | foot lift cm | fastest joint m/s | verdict")
	var fails: int = 0
	for r: Dictionary in _rows:
		var t: float = maxf(float(r["time"]), 0.001)
		var speed: float = float(r["dist"]) / t
		var planted: float = float(r["planted_t"])
		var rate: float = float(r["slide"]) / planted if planted > 0.05 else 0.0
		var pct: float = rate / speed if speed > 0.5 else 0.0
		var verdict: String = "pass"
		var why: PackedStringArray = []
		if speed > 0.5 and pct > SLIDE_FAIL:
			why.append("feet slide")
		elif speed <= 0.5 and rate > 0.25:
			why.append("feet drift while standing")
		if float(r["sink"]) < -0.03:
			why.append("foot through floor")
		if float(r["pop"]) > POP_FAIL:
			why.append("pose pop (%s)" % str(r["pop_joint"]))
		if not why.is_empty():
			verdict = "FAIL: " + ", ".join(why)
			fails += 1
		elif speed > 0.5 and pct > SLIDE_WARN:
			verdict = "warn: some slide"
		var m_time: float = float(r.get("m_time", 0.0))
		var measured: String = "%.2f" % (float(r.get("m_slide", 0.0)) / m_time) if m_time > 0.15 else "n/a"
		lines.append("%s | %.2f | %.2f | %d | %s | %.1f | %.1f | %.1f | %s" % [r["label"], speed, rate, int(round(pct * 100.0)),
			measured, float(r["sink"]) * 100.0, float(r.get("lift", 0.0)) * 100.0, float(r["pop"]), verdict])
	var text: String = "\n".join(lines)
	print(text)
	print("RUNTIME QA: %d of %d segments fail (fps arg %d)" % [fails, _rows.size(), fps])
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
		var f: FileAccess = FileAccess.open(_out + "/runtime_qa.txt", FileAccess.WRITE)
		f.store_string(text + "\n")
		f.close()
	get_tree().quit(0)
