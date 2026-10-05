extends SceneTree
## Scaffold generator for the three interiors. Run with:
##   godot --headless -s tools/build_interiors.gd
##
## Writes scenes/interiors/{dorm,classroom,gym}.tscn. Each is a cutaway room
## (no wall on the camera side) with furniture, lighting, colliders and the
## markers location.gd reads (arrive_*, spot_*, door_campus, and for the gym
## hoop + shot_*). After generation the .tscn files are the source of truth.

const NAVY: Color = Color(0.12, 0.2, 0.36)
const GOLD: Color = Color(0.92, 0.72, 0.3)
const WALL_HEIGHT: float = 3.0

var _root: Node3D


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/interiors"))
	_save(_build_dorm(), "res://scenes/interiors/dorm.tscn")
	_save(_build_classroom(), "res://scenes/interiors/classroom.tscn")
	_save(_build_gym(), "res://scenes/interiors/gym.tscn")
	print("interiors written")
	quit(0)


# =============================================================================
# Room 214, Hargrove Hall
# =============================================================================

func _build_dorm() -> Node3D:
	_start("Dorm", "dorm", {
		"cam_pitch": -46.0, "cam_yaw": 14.0, "cam_distance": 10.5, "cam_fov": 40.0,
		"cam_bounds": Rect2(-0.6, -0.4, 1.2, 1.4), "talk_distance": 6.5,
		"look_ahead": Vector3(0, 0, -0.6),
	})
	_lighting(Color(0.1, 0.11, 0.16), Color(0.95, 0.88, 0.8), 0.55)
	_room(Vector2(7.6, 6.4), _textured("res://assets/interiors/wood_dorm.png", Vector3(3, 3, 1)),
		Color(0.86, 0.82, 0.74), Color(0.36, 0.3, 0.26))
	_omni("CeilingLight", Vector3(0, 2.7, 0), Color(1.0, 0.88, 0.7), 1.6, 8.0)
	_omni("DeskLamp", Vector3(-1.4, 1.3, -2.6), Color(1.0, 0.8, 0.5), 0.9, 3.0)

	var f: Node3D = _group("Furniture")
	# Your half (left): bed along the west wall, desk under the window.
	_bed(f, "YourBed", Vector3(-3.15, 0, -1.6), NAVY, Color(0.92, 0.9, 0.85))
	_desk(f, "YourDesk", Vector3(-1.25, 0, -2.75), Color(0.55, 0.42, 0.3))
	_box_in(f, "Textbook", Vector3(0.32, 0.06, 0.24), Vector3(-1.0, 0.8, -2.7), Color(0.2, 0.45, 0.4))
	_box_in(f, "Planner", Vector3(0.22, 0.03, 0.3), Vector3(-1.5, 0.79, -2.6), GOLD)
	var backpack: Node3D = _inst("res://assets/props/Backpack.glb", f, "Backpack",
		Vector3(-2.5, 0, -0.35), 0.4)
	backpack.rotation_degrees.y = 30
	# Jordan's half (right): already fully moved in.
	_bed(f, "JordanBed", Vector3(3.15, 0, -1.6), Color(0.5, 0.16, 0.2), Color(0.92, 0.9, 0.85))
	_desk(f, "JordanDesk", Vector3(1.25, 0, -2.75), Color(0.55, 0.42, 0.3))
	_box_in(f, "Speaker", Vector3(0.2, 0.32, 0.2), Vector3(1.75, 0.92, -2.8), Color(0.15, 0.15, 0.17))
	_box_in(f, "Laptop", Vector3(0.42, 0.03, 0.3), Vector3(1.1, 0.79, -2.65), Color(0.7, 0.72, 0.75))
	# The famous mini-fridge.
	_box_in(f, "MiniFridge", Vector3(0.56, 0.86, 0.56), Vector3(3.3, 0.43, -0.05), Color(0.88, 0.88, 0.9))
	_box_in(f, "FridgeHandle", Vector3(0.04, 0.4, 0.04), Vector3(3.05, 0.55, 0.23), Color(0.4, 0.4, 0.42))
	_box_body_in(f, "FridgeBody", Vector3(3.3, 0.43, -0.05), Vector3(0.6, 0.9, 0.6))
	# Window between the desks: late light from outside.
	_window(f, "Window", Vector3(0, 1.75, -3.17), Vector2(1.3, 1.2), 0.0)
	# Rug and posters.
	_box_in(f, "Rug", Vector3(2.6, 0.02, 1.8), Vector3(0, 0.012, -0.2), Color(0.2, 0.28, 0.44))
	_box_in(f, "RugStripe", Vector3(2.6, 0.022, 0.18), Vector3(0, 0.014, -0.2), GOLD)
	_poster(f, "PosterHawks", "res://assets/branding/banner_hawks.png", Vector3(-3.77, 1.8, 0.6), Vector2(0.62, 1.24), 90.0)
	_poster(f, "PosterWalkOn", "res://assets/branding/poster_walkon.png", Vector3(3.77, 1.75, -1.6), Vector2(0.75, 1.0), -90.0)
	_poster(f, "Pennant", "res://assets/branding/banner_theu.png", Vector3(2.2, 2.05, -3.17), Vector2(0.45, 0.9), 0.0)

	_door(Vector3(3.8, 0, 1.45), -90.0, "HALLWAY")
	_markers([
		["arrive_door", Vector3(2.7, 0, 1.45), 90.0],
		["arrive_bed", Vector3(-2.2, 0, -0.7), -60.0],
		["door_campus", Vector3(3.3, 0, 1.45), 0.0],
		["spot_bed", Vector3(-2.35, 0, -1.6), 90.0],
		["spot_desk", Vector3(-1.25, 0, -1.75), 0.0],
		["spot_jordan", Vector3(1.4, 0, -1.6), 150.0],
	])
	return _root


# =============================================================================
# Moreno Hall 104 — Intro to Kinesiology
# =============================================================================

func _build_classroom() -> Node3D:
	_start("Classroom", "classroom", {
		"cam_pitch": -44.0, "cam_yaw": 12.0, "cam_distance": 13.5, "cam_fov": 40.0,
		"cam_bounds": Rect2(-2.0, -1.5, 4.0, 3.0), "talk_distance": 7.5,
		"look_ahead": Vector3(0, 0, -1.0),
	})
	_lighting(Color(0.12, 0.13, 0.17), Color(0.92, 0.94, 1.0), 0.7)
	_room(Vector2(13.0, 11.0), _textured("res://assets/interiors/carpet.png", Vector3(6, 6, 1)),
		Color(0.8, 0.82, 0.8), NAVY)
	for i in 3:
		_omni("Panel%d" % i, Vector3(-4 + i * 4, 2.8, -1), Color(0.95, 0.97, 1.0), 1.2, 9.0)

	var f: Node3D = _group("Furniture")
	_box_in(f, "Whiteboard", Vector3(5.0, 1.4, 0.06), Vector3(0, 1.75, -5.42), Color(0.97, 0.97, 0.96))
	_box_in(f, "BoardFrame", Vector3(5.2, 0.08, 0.1), Vector3(0, 1.0, -5.4), Color(0.6, 0.62, 0.65))
	var title: Label3D = _label("KIN 101 · ENERGY SYSTEMS", 40, NAVY)
	title.outline_size = 0
	title.position = Vector3(0, 2.15, -5.37)
	_root.add_child(title)
	var scrawl: Label3D = _label("ATP-PC  →  GLYCOLYTIC  →  AEROBIC\nQuiz Friday — no curve", 30, Color(0.2, 0.3, 0.55))
	scrawl.outline_size = 0
	scrawl.position = Vector3(0, 1.6, -5.37)
	_root.add_child(scrawl)
	_box_in(f, "Lectern", Vector3(0.8, 1.1, 0.55), Vector3(0, 0.55, -3.8), Color(0.38, 0.28, 0.2))
	_box_in(f, "LecternTop", Vector3(0.9, 0.05, 0.6), Vector3(0, 1.12, -3.8), Color(0.3, 0.22, 0.16))
	_box_body_in(f, "LecternBody", Vector3(0, 0.55, -3.8), Vector3(0.85, 1.1, 0.6))
	var seat_index: int = 0
	for row in 3:
		for col: float in [-4.4, -1.7, 1.7, 4.4]:
			_student_desk(f, "Desk%d" % seat_index, Vector3(col, 0, -1.2 + row * 2.3))
			seat_index += 1
	for i in 3:
		_window(f, "Window%d" % i, Vector3(-6.47, 1.7, -3.2 + i * 3.0), Vector2(1.6, 1.3), 90.0)
	_poster(f, "Emblem", "res://assets/branding/emblem.png", Vector3(4.4, 1.9, -5.42), Vector2(1.0, 1.0), 0.0)
	_poster(f, "MapPoster", "res://assets/branding/poster_map.png", Vector3(6.47, 1.7, -2.0), Vector2(0.9, 1.2), -90.0)

	var students: Node3D = _group("Students")
	_sitter(students, "SitterA", "female_casual", Vector3(-4.4, 0, 1.35), Color(0.6, 0.3, 0.45), "light")
	_sitter(students, "SitterB", "male_shirt", Vector3(4.4, 0, -0.95), Color(0.3, 0.5, 0.4), "brown")
	_sitter(students, "SitterC", "female_alternative", Vector3(1.7, 0, 3.65), Color(0.85, 0.8, 0.7), "tan")

	_door(Vector3(6.5, 0, 3.6), -90.0, "EXIT")
	_markers([
		["arrive_door", Vector3(5.4, 0, 3.6), 90.0],
		["door_campus", Vector3(6.0, 0, 3.6), 0.0],
		["spot_seat", Vector3(-1.7, 0, -0.35), 0.0],
		["spot_lectern", Vector3(1.1, 0, -3.9), 180.0],
		["spot_back_row", Vector3(-2.6, 0, -4.4), 160.0],
	])
	return _root


# =============================================================================
# Rec Center — Court 1
# =============================================================================

func _build_gym() -> Node3D:
	_start("Gym", "gym", {
		"cam_pitch": -38.0, "cam_yaw": 12.0, "cam_distance": 14.5, "cam_fov": 40.0,
		"cam_bounds": Rect2(-3.5, -5.5, 7.0, 7.5), "talk_distance": 8.0,
		"look_ahead": Vector3(0, 0, -1.4),
	})
	_lighting(Color(0.1, 0.11, 0.15), Color(0.95, 0.96, 1.0), 0.75)
	_room(Vector2(22.0, 18.0), _textured("res://assets/interiors/wood_court.png", Vector3(8, 8, 1)),
		Color(0.9, 0.88, 0.82), NAVY)
	for i in 3:
		for j in 2:
			_omni("Highbay%d%d" % [i, j], Vector3(-6 + i * 6, 5.0, -5 + j * 7), Color(1.0, 0.98, 0.94), 1.6, 11.0)

	var court: Node3D = _group("Court")
	var line: Color = Color(0.97, 0.97, 0.95)
	# Baseline, sidelines, half-court, key, free-throw line and circle.
	_box_in(court, "Baseline", Vector3(15.0, 0.012, 0.08), Vector3(0, 0.006, -8.4), line)
	_box_in(court, "SidelineL", Vector3(0.08, 0.012, 15.0), Vector3(-7.5, 0.006, -0.9), line)
	_box_in(court, "SidelineR", Vector3(0.08, 0.012, 15.0), Vector3(7.5, 0.006, -0.9), line)
	_box_in(court, "Midcourt", Vector3(15.0, 0.012, 0.08), Vector3(0, 0.006, 6.6), line)
	_box_in(court, "KeyPaint", Vector3(4.9, 0.01, 5.8), Vector3(0, 0.004, -5.5), NAVY)
	_box_in(court, "KeyL", Vector3(0.08, 0.012, 5.8), Vector3(-2.45, 0.006, -5.5), line)
	_box_in(court, "KeyR", Vector3(0.08, 0.012, 5.8), Vector3(2.45, 0.006, -5.5), line)
	_box_in(court, "FreeThrow", Vector3(4.9, 0.012, 0.08), Vector3(0, 0.006, -2.6), line)
	_arc(court, "FTCircle", Vector3(0, 0.006, -2.6), 1.8, -90.0, 90.0, line, 12)
	_arc(court, "ThreeArc", Vector3(0, 0.006, -7.6), 6.75, -78.0, 78.0, line, 28)
	_arc(court, "CenterCircle", Vector3(0, 0.006, 6.6), 1.8, -90.0, 90.0, GOLD, 12)
	var center_logo: MeshInstance3D = _quad("res://assets/branding/decal_emblem.png", Vector2(3.0, 3.0))
	(center_logo.mesh as QuadMesh).orientation = PlaneMesh.FACE_Y
	center_logo.position = Vector3(0, 0.014, 7.6)
	court.add_child(center_logo)

	_hoop(court, Vector3(0, 0, -8.9))

	var f: Node3D = _group("Furniture")
	# Bleachers along the west wall, three tiers.
	for tier in 3:
		_box_in(f, "Bleacher%d" % tier, Vector3(1.0, 0.45 + tier * 0.45, 9.0),
			Vector3(-10.3 + tier * 0.95, (0.45 + tier * 0.45) / 2.0, 0), Color(0.62, 0.48, 0.32))
		_box_in(f, "BleacherEdge%d" % tier, Vector3(0.06, 0.04, 9.0),
			Vector3(-9.8 + tier * 0.95, 0.47 + tier * 0.45, 0), NAVY)
	_box_body_in(f, "BleacherBody", Vector3(-9.4, 0.7, 0), Vector3(3.2, 1.4, 9.0))
	# Ball rack by the court spot.
	_box_in(f, "RackFrame", Vector3(1.2, 0.08, 0.45), Vector3(3.6, 0.75, -1.0), Color(0.25, 0.25, 0.28))
	_box_in(f, "RackLegs", Vector3(1.2, 0.75, 0.04), Vector3(3.6, 0.37, -1.0), Color(0.25, 0.25, 0.28))
	for i in 4:
		_ball(f, "Ball%d" % i, Vector3(3.15 + i * 0.3, 0.92, -1.0))
	_box_body_in(f, "RackBody", Vector3(3.6, 0.5, -1.0), Vector3(1.3, 1.0, 0.5))
	# Coach's corner: desk, clipboard, film monitor.
	_desk(f, "CoachDesk", Vector3(9.4, 0, -4.6), Color(0.3, 0.32, 0.36))
	_box_in(f, "Monitor", Vector3(0.7, 0.45, 0.06), Vector3(9.4, 1.05, -4.85), Color(0.08, 0.08, 0.1))
	_box_in(f, "Clipboard", Vector3(0.24, 0.02, 0.32), Vector3(9.0, 0.79, -4.5), Color(0.75, 0.6, 0.4))
	# Conditioning corner: racks, plates, plyo boxes.
	for i in 3:
		_box_in(f, "PlyoBox%d" % i, Vector3(0.6, 0.3 + i * 0.15, 0.6), Vector3(9.6, (0.3 + i * 0.15) / 2.0, 0.2 + i * 0.85),
			Color(0.16, 0.16, 0.18))
	_box_body_in(f, "PlyoBody", Vector3(9.6, 0.4, 1.05), Vector3(0.7, 0.8, 2.6))
	_box_in(f, "DumbbellRack", Vector3(0.5, 0.8, 2.0), Vector3(10.6, 0.4, 3.4), Color(0.22, 0.22, 0.25))
	_box_body_in(f, "DumbbellBody", Vector3(10.6, 0.4, 3.4), Vector3(0.6, 0.8, 2.0))
	var circuit: Label3D = _label("TODAY'S CIRCUIT\nrow 500m · box jump x10\nsled x2 · REPEAT x4", 30, Color(0.85, 0.15, 0.15))
	circuit.outline_size = 0
	circuit.position = Vector3(10.95, 1.9, 1.6)
	circuit.rotation_degrees.y = -90
	_root.add_child(circuit)
	_box_in(f, "CircuitBoard", Vector3(0.04, 1.1, 1.8), Vector3(10.97, 1.85, 1.6), Color(0.96, 0.96, 0.95))

	# Back-wall branding.
	var wordmark: Label3D = _label("RIDGEHAWKS BASKETBALL", 96, GOLD)
	wordmark.position = Vector3(0, 4.7, -8.95)
	_root.add_child(wordmark)
	_poster(f, "BannerL", "res://assets/branding/banner_hawks.png", Vector3(-6.5, 3.6, -8.95), Vector2(1.2, 2.4), 0.0)
	_poster(f, "BannerR", "res://assets/branding/banner_rec.png", Vector3(6.5, 3.6, -8.95), Vector2(1.2, 2.4), 0.0)

	# Background regulars running the far court.
	var students: Node3D = _group("Students")
	_runner(students, "Runner", "male_shirt", PackedVector3Array([
		Vector3(-6.5, 0, 5.2), Vector3(6.5, 0, 5.2)]), Color(0.9, 0.9, 0.9), "deep", 1)
	_runner(students, "Stretcher", "female_tanktop", PackedVector3Array(), NAVY, "light", 3,
		Vector3(-6.0, 0, -6.6), 40.0)

	_door(Vector3(11.0, 0, 5.6), -90.0, "EXIT")
	_markers([
		["arrive_door", Vector3(9.8, 0, 5.6), 90.0],
		["door_campus", Vector3(10.4, 0, 5.6), 0.0],
		["spot_court", Vector3(2.6, 0, -1.1), 0.0],
		["spot_weights", Vector3(8.6, 0, 1.4), -90.0],
		["spot_office", Vector3(8.6, 0, -3.8), 90.0],
		["spot_sideline", Vector3(-7.6, 0, 1.0), -90.0],
		["hoop", Vector3(0, 3.05, -7.65), 0.0],
		["shot_1", Vector3(-3.4, 0, -3.6), 0.0],
		["shot_2", Vector3(0, 0, -1.9), 0.0],
		["shot_3", Vector3(3.6, 0, -3.8), 0.0],
		["shot_ft", Vector3(0, 0, -3.0), 0.0],
	])
	return _root


# =============================================================================
# Room kit
# =============================================================================

func _start(node_name: String, location_id: String, settings: Dictionary) -> void:
	_root = Node3D.new()
	_root.name = node_name
	_root.set_script(load("res://scripts/world3d/location.gd"))
	_root.set("location_id", location_id)
	for key: String in settings.keys():
		_root.set(key, settings[key])
	var actors: Node3D = Node3D.new()
	actors.name = "Actors"
	_root.add_child(actors)
	var ui_sound: AudioStreamPlayer = AudioStreamPlayer.new()
	ui_sound.name = "UISound"
	ui_sound.volume_db = -6.0
	_root.add_child(ui_sound)


func _lighting(background: Color, key_color: Color, ambient: float) -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.8, 0.86)
	env.ambient_light_energy = ambient * 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world: WorldEnvironment = WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = env
	_root.add_child(world)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.name = "KeyLight"
	key.rotation_degrees = Vector3(-58, -24, 0)
	key.light_color = key_color
	key.light_energy = 0.5
	key.shadow_enabled = true
	key.shadow_opacity = 0.55
	key.shadow_blur = 1.5
	key.directional_shadow_max_distance = 40.0
	_root.add_child(key)


## Floor plus back/left/right walls; the camera (south) side stays open.
func _room(size: Vector2, floor_material: StandardMaterial3D, wall_color: Color,
		trim_color: Color) -> void:
	var room: Node3D = _group("Room")
	var floor: MeshInstance3D = MeshInstance3D.new()
	floor.name = "Floor"
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = size
	plane.material = floor_material
	floor.mesh = plane
	room.add_child(floor)
	_box_body_in(room, "FloorBody", Vector3(0, -0.5, 0), Vector3(size.x + 4, 1, size.y + 4))
	var hx: float = size.x / 2.0
	var hz: float = size.y / 2.0
	var walls: Array = [
		["WallBack", Vector3(size.x + 0.3, WALL_HEIGHT, 0.3), Vector3(0, WALL_HEIGHT / 2.0, -hz - 0.15)],
		["WallLeft", Vector3(0.3, WALL_HEIGHT, size.y), Vector3(-hx - 0.15, WALL_HEIGHT / 2.0, 0)],
		["WallRight", Vector3(0.3, WALL_HEIGHT, size.y), Vector3(hx + 0.15, WALL_HEIGHT / 2.0, 0)],
	]
	if size.x > 15.0:
		# The gym's walls are taller; the extra height carries the branding.
		for w: Array in walls:
			w[1].y = 6.0
			w[2].y = 3.0
	for w: Array in walls:
		_box_in(room, w[0], w[1], w[2], wall_color, 0.95)
		_box_body_in(room, w[0] + "Body", w[2], w[1])
		# Wainscot band in campus navy along the bottom of each wall.
		var band_size: Vector3 = Vector3(w[1].x + 0.02, 0.9, w[1].z + 0.02)
		_box_in(room, w[0] + "Wainscot", band_size, Vector3(w[2].x, 0.45, w[2].z), trim_color, 0.8)
	# Low invisible lip on the open side so nobody walks off the set.
	_box_body_in(room, "FrontLip", Vector3(0, 0.5, hz + 0.3), Vector3(size.x, 1.0, 0.3))


func _door(at: Vector3, yaw: float, sign_text: String) -> void:
	var door: Node3D = _inst("res://assets/city/Door_1.gltf", _root, "Door", at, 1.25)
	door.rotation_degrees.y = yaw
	# Door_1's mesh spans x -1..0 at scale 1; nudge it so it centers on `at`.
	door.position += door.transform.basis.x * 0.62
	var sign: Label3D = _label(sign_text, 28, GOLD)
	sign.rotation_degrees.y = yaw
	sign.position = at + Vector3(0, 3.05, 0) + door.transform.basis.z * 0.05
	_root.add_child(sign)


func _markers(specs: Array) -> void:
	var markers: Node3D = _group("Markers")
	for spec: Array in specs:
		var m: Marker3D = Marker3D.new()
		m.name = spec[0]
		m.position = spec[1]
		m.rotation_degrees.y = float(spec[2])
		markers.add_child(m)


func _bed(parent: Node3D, node_name: String, at: Vector3, blanket: Color, sheet: Color) -> void:
	var g: Node3D = Node3D.new()
	g.name = node_name
	g.position = at
	parent.add_child(g)
	_box_in(g, "Frame", Vector3(1.05, 0.35, 2.05), Vector3(0, 0.18, 0), Color(0.42, 0.32, 0.24))
	_box_in(g, "Mattress", Vector3(0.95, 0.2, 1.95), Vector3(0, 0.45, 0), sheet)
	_box_in(g, "Blanket", Vector3(0.99, 0.08, 1.3), Vector3(0, 0.56, 0.32), blanket)
	_box_in(g, "Pillow", Vector3(0.7, 0.14, 0.38), Vector3(0, 0.62, -0.72), Color(0.96, 0.95, 0.92))
	_box_in(g, "Headboard", Vector3(1.05, 0.9, 0.08), Vector3(0, 0.45, -1.0), Color(0.42, 0.32, 0.24))
	_box_body_in(g, "Body", Vector3(0, 0.35, 0), Vector3(1.05, 0.7, 2.05))


func _desk(parent: Node3D, node_name: String, at: Vector3, wood: Color) -> void:
	var g: Node3D = Node3D.new()
	g.name = node_name
	g.position = at
	parent.add_child(g)
	_box_in(g, "Top", Vector3(1.4, 0.05, 0.62), Vector3(0, 0.76, 0), wood)
	_box_in(g, "Drawers", Vector3(0.42, 0.72, 0.58), Vector3(0.46, 0.37, 0), wood.darkened(0.15))
	_box_in(g, "Leg", Vector3(0.05, 0.74, 0.58), Vector3(-0.66, 0.37, 0), wood.darkened(0.15))
	_box_in(g, "ChairSeat", Vector3(0.46, 0.06, 0.46), Vector3(-0.1, 0.46, 0.55), Color(0.2, 0.22, 0.26))
	_box_in(g, "ChairBack", Vector3(0.46, 0.5, 0.05), Vector3(-0.1, 0.72, 0.78), Color(0.2, 0.22, 0.26))
	_box_in(g, "ChairPost", Vector3(0.06, 0.44, 0.06), Vector3(-0.1, 0.22, 0.55), Color(0.3, 0.3, 0.32))
	_box_body_in(g, "Body", Vector3(0, 0.4, 0), Vector3(1.4, 0.8, 0.62))


func _student_desk(parent: Node3D, node_name: String, at: Vector3) -> void:
	var g: Node3D = Node3D.new()
	g.name = node_name
	g.position = at
	parent.add_child(g)
	_box_in(g, "Top", Vector3(1.1, 0.04, 0.5), Vector3(0, 0.74, -0.3), Color(0.72, 0.6, 0.44))
	_box_in(g, "Frame", Vector3(0.05, 0.72, 0.45), Vector3(-0.5, 0.36, -0.3), Color(0.3, 0.3, 0.33))
	_box_in(g, "Frame2", Vector3(0.05, 0.72, 0.45), Vector3(0.5, 0.36, -0.3), Color(0.3, 0.3, 0.33))
	_box_in(g, "Seat", Vector3(0.48, 0.05, 0.44), Vector3(0, 0.45, 0.25), NAVY)
	_box_in(g, "Back", Vector3(0.48, 0.42, 0.05), Vector3(0, 0.7, 0.48), NAVY)
	_box_in(g, "Post", Vector3(0.05, 0.43, 0.05), Vector3(0, 0.22, 0.25), Color(0.3, 0.3, 0.33))
	_box_body_in(g, "Body", Vector3(0, 0.4, -0.3), Vector3(1.1, 0.8, 0.5))


func _window(parent: Node3D, node_name: String, at: Vector3, size: Vector2, yaw: float) -> void:
	var g: Node3D = Node3D.new()
	g.name = node_name
	g.position = at
	g.rotation_degrees.y = yaw
	parent.add_child(g)
	var glass: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = size
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.84, 0.96)
	mat.emission_enabled = true
	mat.emission = Color(0.75, 0.85, 1.0)
	mat.emission_energy_multiplier = 0.7
	quad.material = mat
	glass.mesh = quad
	glass.position = Vector3(0, 0, 0.17)
	g.add_child(glass)
	var frame: Color = Color(0.95, 0.94, 0.9)
	_box_in(g, "Top", Vector3(size.x + 0.12, 0.08, 0.08), Vector3(0, size.y / 2.0, 0.18), frame)
	_box_in(g, "Bottom", Vector3(size.x + 0.2, 0.08, 0.16), Vector3(0, -size.y / 2.0, 0.2), frame)
	_box_in(g, "Mullion", Vector3(0.05, size.y, 0.06), Vector3(0, 0, 0.18), frame)
	_box_in(g, "SideL", Vector3(0.08, size.y, 0.08), Vector3(-size.x / 2.0, 0, 0.18), frame)
	_box_in(g, "SideR", Vector3(0.08, size.y, 0.08), Vector3(size.x / 2.0, 0, 0.18), frame)


func _poster(parent: Node3D, node_name: String, texture: String, at: Vector3, size: Vector2, yaw: float) -> void:
	var q: MeshInstance3D = _quad(texture, size)
	q.name = node_name
	q.position = at
	q.rotation_degrees.y = yaw
	# Pull off the wall toward the room so it never z-fights.
	q.position += q.transform.basis.z * 0.02
	parent.add_child(q)


func _hoop(parent: Node3D, base: Vector3) -> void:
	var g: Node3D = Node3D.new()
	g.name = "Hoop"
	g.position = base
	parent.add_child(g)
	var steel: Color = Color(0.32, 0.34, 0.38)
	_box_in(g, "Mount", Vector3(0.2, 3.6, 0.2), Vector3(0, 4.2, -0.05), steel)
	_box_in(g, "Arm", Vector3(0.12, 0.12, 0.85), Vector3(0, 3.55, 0.4), steel)
	_box_in(g, "Backboard", Vector3(1.8, 1.05, 0.05), Vector3(0, 3.45, 0.85), Color(0.97, 0.97, 0.97))
	var orange: Color = Color(0.92, 0.38, 0.12)
	_box_in(g, "BoxTop", Vector3(0.6, 0.04, 0.02), Vector3(0, 3.5, 0.88), orange)
	_box_in(g, "BoxL", Vector3(0.04, 0.45, 0.02), Vector3(-0.29, 3.3, 0.88), orange)
	_box_in(g, "BoxR", Vector3(0.04, 0.45, 0.02), Vector3(0.29, 3.3, 0.88), orange)
	_box_in(g, "Padding", Vector3(1.8, 0.12, 0.12), Vector3(0, 2.92, 0.86), NAVY)
	var rim: MeshInstance3D = MeshInstance3D.new()
	rim.name = "Rim"
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.215
	torus.outer_radius = 0.245
	var rim_mat: StandardMaterial3D = StandardMaterial3D.new()
	rim_mat.albedo_color = orange
	rim_mat.metallic = 0.3
	torus.material = rim_mat
	rim.mesh = torus
	rim.position = Vector3(0, 3.05, 1.25)
	g.add_child(rim)
	var net: MeshInstance3D = MeshInstance3D.new()
	net.name = "Net"
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.22
	cone.bottom_radius = 0.14
	cone.height = 0.42
	cone.cap_top = false
	cone.cap_bottom = false
	var net_mat: StandardMaterial3D = StandardMaterial3D.new()
	net_mat.albedo_color = Color(1, 1, 1, 0.55)
	net_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	net_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cone.material = net_mat
	net.mesh = cone
	net.position = Vector3(0, 2.83, 1.25)
	g.add_child(net)


func _arc(parent: Node3D, node_name: String, center: Vector3, radius: float, from_deg: float,
		to_deg: float, color: Color, segments: int) -> void:
	# 0° points toward +Z (toward the camera side of the court).
	for i in segments:
		var a0: float = deg_to_rad(lerpf(from_deg, to_deg, float(i) / segments))
		var a1: float = deg_to_rad(lerpf(from_deg, to_deg, float(i + 1) / segments))
		var p0: Vector3 = center + Vector3(sin(a0), 0, cos(a0)) * radius
		var p1: Vector3 = center + Vector3(sin(a1), 0, cos(a1)) * radius
		var seg: MeshInstance3D = _box(Vector3(0.08, 0.012, p0.distance_to(p1) + 0.02), color, 0.8)
		seg.name = "%s%d" % [node_name, i]
		seg.position = (p0 + p1) / 2.0
		seg.rotation.y = atan2(p1.x - p0.x, p1.z - p0.z)
		parent.add_child(seg)


func _ball(parent: Node3D, node_name: String, at: Vector3) -> void:
	var ball: MeshInstance3D = MeshInstance3D.new()
	ball.name = node_name
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.42, 0.14)
	mat.roughness = 0.75
	sphere.material = mat
	ball.mesh = sphere
	ball.position = at
	parent.add_child(ball)


func _sitter(parent: Node3D, node_name: String, model: String, desk_at: Vector3, shirt: Color, skin: String) -> void:
	var s: Node3D = _inst("res://scenes/world3d/student.tscn", parent, node_name, desk_at + Vector3(0, 0.1, -0.12), 1.0)
	s.rotation_degrees.y = 180
	s.set("model_key", model)
	s.set("activity", 2)
	s.set("shirt_color", shirt)
	s.set("skin_tone", skin)
	s.set("phase_offset", randf())


func _runner(parent: Node3D, node_name: String, model: String, waypoints: PackedVector3Array,
		shirt: Color, skin: String, activity: int, at: Vector3 = Vector3.ZERO, yaw: float = 0.0) -> void:
	var s: Node3D = _inst("res://scenes/world3d/student.tscn", parent, node_name,
		waypoints[0] if waypoints.size() > 0 else at, 1.0)
	s.rotation_degrees.y = yaw
	s.set("model_key", model)
	s.set("activity", activity)
	s.set("waypoints", waypoints)
	s.set("shirt_color", shirt)
	s.set("skin_tone", skin)


func _omni(node_name: String, at: Vector3, color: Color, energy: float, light_range: float) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = node_name
	light.position = at
	light.light_color = color
	light.light_energy = energy * 0.45
	light.omni_range = light_range
	_root.add_child(light)


func _group(node_name: String) -> Node3D:
	var g: Node3D = Node3D.new()
	g.name = node_name
	_root.add_child(g)
	return g


func _textured(path: String, uv: Vector3) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = load(path)
	mat.uv1_scale = uv
	mat.albedo_color = Color(0.78, 0.76, 0.74)
	mat.roughness = 0.7
	return mat


# =============================================================================
# Primitive helpers
# =============================================================================

func _save(root: Node, path: String) -> void:
	_set_owner_recursive(root, root)
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, path) == OK)
	print("wrote ", path)
	root.free()


func _set_owner_recursive(root: Node, node: Node) -> void:
	for child in node.get_children():
		child.owner = root
		if child.scene_file_path == "":
			_set_owner_recursive(root, child)


func _inst(path: String, parent: Node, node_name: String, at: Vector3, scale: float) -> Node3D:
	var node: Node3D = (load(path) as PackedScene).instantiate()
	node.name = node_name
	node.position = at
	node.scale = Vector3.ONE * scale
	parent.add_child(node)
	return node


func _box(size: Vector3, color: Color, roughness: float = 0.85) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	mesh.material = material
	mesh_instance.mesh = mesh
	return mesh_instance


func _box_in(parent: Node, node_name: String, size: Vector3, at: Vector3, color: Color,
		roughness: float = 0.85) -> MeshInstance3D:
	var b: MeshInstance3D = _box(size, color, roughness)
	b.name = node_name
	b.position = at
	parent.add_child(b)
	return b


func _box_body_in(parent: Node, node_name: String, at: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = at
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.name = "Shape"
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	collider.shape = box
	body.add_child(collider)
	parent.add_child(body)


func _quad(texture_path: String, size: Vector2) -> MeshInstance3D:
	var quad: MeshInstance3D = MeshInstance3D.new()
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = load(texture_path)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.9
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mesh.material = material
	quad.mesh = mesh
	return quad


func _label(text: String, font_size: int, color: Color) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text
	label.font_size = font_size
	label.outline_size = int(font_size / 8.0)
	label.modulate = color
	label.outline_modulate = Color(0.08, 0.1, 0.16)
	return label
