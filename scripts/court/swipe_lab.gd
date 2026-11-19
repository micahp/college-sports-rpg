extends Node
## Swipe Lab: watch the on-ball defender's swipe in any validator scenario,
## the basketball counterpart of gridiron-physics' tacklelab.html. Same code
## path as the game (court_game.tscn runs underneath, untouched); this only
## picks the scenario, starts a swipe every SWIPE_EVERY seconds, gives the
## ball back after a poke, and shows what tests/swipe_pose_checks.gd measures:
## where the palm is against the ball, which way it faces, and the elbows.
##
##   web:      index.html?swipelab            (&sc=lateral,1.0,1.06  &speed=0.25)
##   desktop:  godot -- swipelab [sc=stand,1.0,1.0] [speed=0.5]
## Drag to orbit, wheel to zoom.

const CourtScene: PackedScene = preload("res://scenes/court/court_game.tscn")
const CourtGame = preload("res://scripts/court/court_game.gd")
const Actor = preload("res://scripts/court/court_actor.gd")
const BodyMetrics = preload("res://tests/body_metrics.gd")

## The validator's sweep (tests/swipe_pose_checks.gd), in the same order.
const MOVES: Array = ["stand", "lateral", "drive_back", "diagonal"]
const AGGR: Array = [0.6, 1.0, 1.4]
const SIZES: Array = [0.95, 1.0, 1.06]
const MOVE_NAMES: Dictionary = {"stand": "Handler standing", "lateral": "Handler side to side",
	"drive_back": "Handler driving and backing up", "diagonal": "Handler on a diagonal"}
const SWIPES_EACH: int = 3
const SWIPE_EVERY: float = 1.5
const PALM_GAP_M: float = 0.04
const PALM_FACING: float = 0.5
const BALL_R: float = 0.12

var _court: Node3D
var _bm: BodyMetrics = BodyMetrics.new()
var _cases: Array = []
var _ci: int = 0
var _t: float = 0.0
var _move_t: float = 0.0
var _swipes: int = 0
var _final: Dictionary = {}
var _tapped: bool = false
var _started: bool = false
var _resolved_seen: bool = false
var _last: String = ""
var _prev_ball: Vector3 = Vector3.ZERO

var _cam: Camera3D
var _yaw: float = 1.2
var _pitch: float = 0.22
var _dist: float = 4.2
var _drag: bool = false
var _pick: OptionButton
var _cycle: CheckBox
var _speed: OptionButton
var _act: Label
var _palm_dot: MeshInstance3D
var _palm_line: MeshInstance3D
var _line_mesh: ImmediateMesh


func _ready() -> void:
	GameState.reset()
	var looks: Array = ContentDB.get_looks()
	if not looks.is_empty():
		GameState.look_id = str(looks[0]["id"])
	CourtGame.auto_play = false
	for mv: String in MOVES:
		for ag: float in AGGR:
			for sz: float in SIZES:
				_cases.append({"move": mv, "aggr": ag, "size": sz,
					"name": "%s, guard %s, defender x%.2f" % [MOVE_NAMES[mv], {0.6: "loose", 1.0: "normal", 1.4: "tight"}[ag], sz]})
	for preview in [["Guard stance", "stand"], ["Lateral containment", "lateral"], ["Hands-up contest", "contest"]]:
		_cases.append({"name": preview[0], "move": preview[1], "aggr": 0.0, "size": 1.0, "preview": true})
	_court = CourtScene.instantiate()
	_court.scenario = CourtGame.demo_scenario()
	add_child(_court)
	process_physics_priority = -100  # inputs before the game reads them
	_build_ui()
	_build_markers()
	_cam = Camera3D.new()
	_cam.fov = 40.0
	add_child(_cam)
	var probe: Node = Node.new()
	probe.process_priority = 1000
	var s: GDScript = GDScript.new()
	s.source_code = "extends Node\nvar qa: Node\nfunc _process(delta: float) -> void:\n\tqa.measure(delta)\n"
	s.reload()
	probe.set_script(s)
	probe.set("qa", self)
	add_child(probe)
	_apply_args()


func _args() -> Dictionary:
	var out: Dictionary = {}
	var parts: Array = []
	if OS.has_feature("web"):
		var q: Variant = JavaScriptBridge.eval("window.location.search", true)
		if q is String:
			parts = Array((q as String).trim_prefix("?").split("&"))
	else:
		parts = Array(OS.get_cmdline_user_args())
	for p: String in parts:
		var kv: PackedStringArray = p.split("=")
		if kv.size() == 2:
			out[kv[0]] = kv[1].uri_decode()
	return out


func _apply_args() -> void:
	var a: Dictionary = _args()
	if a.has("sc"):
		var f: PackedStringArray = str(a["sc"]).split(",")
		if f.size() == 3:
			var want: Dictionary = {"move": f[0], "aggr": float(f[1]), "size": float(f[2])}
			for i in _cases.size():
				var c: Dictionary = _cases[i]
				if c["move"] == want["move"] and is_equal_approx(c["aggr"], want["aggr"]) and is_equal_approx(c["size"], want["size"]):
					_ci = i
			_cycle.button_pressed = false
	if a.has("speed"):
		for i in _speed.item_count:
			if is_equal_approx(float(_speed.get_item_metadata(i)), float(a["speed"])):
				_speed.select(i)
	_court._charging = false
	_pick.select(_ci)
	Engine.time_scale = float(_speed.get_item_metadata(_speed.selected))


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(10, 10)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.1, 0.85)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(360, 0)
	panel.add_child(box)
	var title: Label = Label.new()
	title.text = "SWIPE LAB"
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)
	_pick = OptionButton.new()
	for i in _cases.size():
		_pick.add_item("%d. %s" % [i + 1, _cases[i]["name"]], i)
	_pick.item_selected.connect(func(i: int) -> void:
		_ci = i
		_cycle.button_pressed = false
		_restart())
	box.add_child(_pick)
	var row: HBoxContainer = HBoxContainer.new()
	box.add_child(row)
	_cycle = CheckBox.new()
	_cycle.text = "Cycle"
	_cycle.button_pressed = true
	row.add_child(_cycle)
	var sl: Label = Label.new()
	sl.text = "   Speed"
	row.add_child(sl)
	_speed = OptionButton.new()
	for v: float in [1.0, 0.5, 0.25]:
		_speed.add_item("%sx" % str(v))
		_speed.set_item_metadata(_speed.item_count - 1, v)
	_speed.item_selected.connect(func(i: int) -> void: Engine.time_scale = float(_speed.get_item_metadata(i)))
	row.add_child(_speed)
	var note: Label = Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	note.modulate = Color(0.75, 0.8, 0.85)
	note.text = "Same code as the game: the defender jab-steps, leans and swipes with an open palm; elbows are solved as hinges and the palm is placed last, on the final body. Green dot: palm on the ball and facing it (what the validator checks). Red: off. Drag to orbit, wheel to zoom."
	box.add_child(note)
	_act = Label.new()
	_act.add_theme_font_size_override("font_size", 17)
	_act.add_theme_color_override("font_outline_color", Color.BLACK)
	_act.add_theme_constant_override("outline_size", 6)
	_act.anchor_left = 0.5
	_act.anchor_right = 0.5
	_act.anchor_top = 1.0
	_act.anchor_bottom = 1.0
	_act.offset_left = -420
	_act.offset_right = 420
	_act.offset_top = -78
	_act.offset_bottom = -14
	_act.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_act)


func _build_markers() -> void:
	_palm_dot = MeshInstance3D.new()
	var sph: SphereMesh = SphereMesh.new()
	sph.radius = 0.025
	sph.height = 0.05
	_palm_dot.mesh = sph
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.albedo_color = Color.RED
	_palm_dot.material_override = mat
	add_child(_palm_dot)
	_line_mesh = ImmediateMesh.new()
	_palm_line = MeshInstance3D.new()
	_palm_line.mesh = _line_mesh
	var lm: StandardMaterial3D = StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.no_depth_test = true
	lm.vertex_color_use_as_albedo = true
	_palm_line.material_override = lm
	add_child(_palm_line)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb: InputEventMouseButton = e
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(1.6, _dist * 0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(12.0, _dist * 1.1)
	elif e is InputEventMouseMotion and _drag:
		var mm: InputEventMouseMotion = e
		_yaw -= mm.relative.x * 0.008
		_pitch = clampf(_pitch + mm.relative.y * 0.006, -0.1, 1.3)
	elif e is InputEventScreenDrag:
		var sd: InputEventScreenDrag = e
		_yaw -= sd.relative.x * 0.008
		_pitch = clampf(_pitch + sd.relative.y * 0.006, -0.1, 1.3)


# ---------------------------------------------------------------- driver

func _restart() -> void:
	var c: Dictionary = _cases[_ci]
	_court._charging = false
	_pick.select(_ci)
	for act: String in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(act)
	_court._opp["aggr"] = float(c["aggr"])
	for dd: Actor in _court._defense:
		dd.set_height(1.0)
	var d: Actor = _court._on_ball_defender()
	if d != null:
		d.set_height(float(c["size"]))
	_court._reach.clear()
	_court._give_ball(_court._user)
	_court._user.position = Vector3(0, 0, -6.5)
	_court._user.vel = Vector3.ZERO
	_t = -0.8
	_move_t = 0.0
	_swipes = 0


func _tap_all() -> void:
	_tapped = true
	for a: Actor in _court._all:
		var sk: Skeleton3D = a.get("_skeleton")
		if sk == null:
			continue
		var tap: SkeletonModifier3D = SkeletonModifier3D.new()
		var ts: GDScript = GDScript.new()
		ts.source_code = "extends SkeletonModifier3D\nvar qa: Node\nvar who: Node\nfunc _process_modification_with_delta(_d: float) -> void:\n\tqa.final_pose(who, get_skeleton())\n"
		ts.reload()
		tap.set_script(ts)
		tap.set("qa", self)
		tap.set("who", a)
		sk.add_child(tap)


func final_pose(a: Actor, sk: Skeleton3D) -> void:
	_final[a] = {"R": _bm.arm(sk, "R"), "L": _bm.arm(sk, "L")}


func _physics_process(delta: float) -> void:
	if _court._phase != CourtGame.Phase.LIVE:
		return
	if not _started:
		_started = true
		_tap_all()
		_restart()
		return
	_court._shot_clock = 20.0
	_court._clock = maxf(_court._clock, 60.0)
	var u: Actor = _court._user
	if (_court._ball_mode == "loose" and _court._loose_t > 0.9) or _court._ball_mode == "dead" or _court._holder != u:
		_court._give_ball(u)
	_drive_input(delta)
	_t += delta
	if _cases[_ci].get("preview", false):
		for defender: Actor in _court._defense:
			defender.reach_cd = 2.0
		_court._charging = _cases[_ci]["move"] == "contest" and fmod(_move_t, 3.0) > 1.5
		_court._meter_pos = 0.0
		if _cycle.button_pressed and _move_t > 8.0:
			_ci = (_ci + 1) % _cases.size()
			_restart()
		return
	if _t >= SWIPE_EVERY and _court._reach.is_empty() and _court._ball_mode == "held":
		if _swipes >= SWIPES_EACH and _cycle.button_pressed:
			_ci = (_ci + 1) % _cases.size()
			_restart()
			return
		var d: Actor = _court._on_ball_defender()
		if d == null:
			return
		_t = 0.0
		_swipes += 1
		d.reach_cd = 0.0
		d.stagger = 0.0
		_court._start_reach(d)  # the game's own swipe start (rolls its outcome)
		_resolved_seen = false


func _drive_input(delta: float) -> void:
	_move_t += delta
	for act: String in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(act)
	var flip: bool = int(_move_t / 1.1) % 2 == 1
	match str(_cases[_ci]["move"]):
		"lateral":
			Input.action_press("move_right" if flip else "move_left")
		"drive_back":
			Input.action_press("move_down" if flip else "move_up")
		"diagonal":
			Input.action_press("move_up")
			Input.action_press("move_left" if flip else "move_right")


# ---------------------------------------------------------------- readouts

func measure(_delta: float) -> void:
	if not _started:
		return
	var d: Actor = _court._on_ball_defender()
	var u: Actor = _court._user
	if d == null or u == null:
		return
	# Orbit camera on the pair.
	var mid: Vector3 = (u.position + d.position) * 0.5 + Vector3(0, 0.85, 0)
	_cam.current = true
	_cam.position = mid + Vector3(cos(_pitch) * sin(_yaw), sin(_pitch), cos(_pitch) * cos(_yaw)) * _dist
	_cam.look_at(mid, Vector3.UP)
	var r: Dictionary = _court._reach
	var ball: Vector3 = _court._ball.position
	var fm: Dictionary = _final.get(d, {})
	var side: String = str(r.get("side", "R"))
	var m: Dictionary = fm.get(side, {})
	var lines: Array[String] = []
	var c: Dictionary = _cases[_ci]
	lines.append("%d/%d  %s   ·   swipe %d/%d" % [_ci + 1, _cases.size(), c["name"], _swipes, SWIPES_EACH])
	var faults: Array[String] = []
	for s2: String in ["R", "L"]:
		var f: String = BodyMetrics.arm_faults(fm.get(s2, {}))
		if f != "":
			faults.append("%s arm: %s" % [s2, f])
	_line_mesh.clear_surfaces()
	if not m.is_empty() and not r.is_empty():
		var pb: Dictionary = BodyMetrics.palm_on_ball(m, ball, BALL_R)
		var on: bool = float(pb["gap"]) <= PALM_GAP_M and float(pb["gap"]) >= -0.02 and float(pb["facing"]) >= PALM_FACING
		(_palm_dot.material_override as StandardMaterial3D).albedo_color = Color(0.2, 1.0, 0.35) if on else Color(1.0, 0.25, 0.2)
		_palm_dot.visible = true
		_palm_dot.global_position = m["palm"]
		_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		_line_mesh.surface_set_color(Color(0.3, 0.8, 1.0))
		_line_mesh.surface_add_vertex(m["palm"])
		_line_mesh.surface_add_vertex((m["palm"] as Vector3) + (m["palm_n"] as Vector3) * 0.15)
		_line_mesh.surface_end()
		if bool(r["resolved"]) and not _resolved_seen:
			_resolved_seen = true
			var poked: bool = _court._ball_mode == "loose"
			_last = "%s at contact: palm %.0f cm %s the ball, turned %.0f° from it, reach margin %+.0f cm" % [
				"POKED" if poked else ("FOUL" if d.reach_cd >= 3.0 else "missed"),
				absf(float(pb["gap"])) * 100.0, "off" if float(pb["gap"]) >= 0.0 else "into",
				rad_to_deg(acos(clampf(float(pb["facing"]), -1.0, 1.0))), d.reach_margin(_prev_ball, BALL_R) * 100.0]
		lines.append("swiping %s hand: elbow %.0f°, wrist bend %.0f°, forearm twist %.0f°   palm %.0f cm from ball" % [
			side, m["flex"], m["bend"], m["twist"], float(pb["gap"]) * 100.0])
	else:
		_palm_dot.visible = false
		lines.append("guarding: elbows R %.0f° L %.0f°" % [float((fm.get("R", {}) as Dictionary).get("flex", 0.0)),
			float((fm.get("L", {}) as Dictionary).get("flex", 0.0))])
	if _last != "":
		lines.append(_last)
	if not faults.is_empty():
		lines.append("OUTSIDE HUMAN LIMITS: " + "; ".join(faults))
	_act.text = "\n".join(lines)
	_act.modulate = Color(1.0, 0.55, 0.5) if not faults.is_empty() else Color.WHITE
	_prev_ball = ball
