extends Node3D
## The 3D campus courtyard visual slice: composed environment, warm lighting,
## fixed three-quarter camera that follows the player, and one conversation
## with Jordan. Presentation milestone — no day loop, stats, or save data.

const PlayerScene: PackedScene = preload("res://scenes/world3d/player3d.tscn")
const NpcScene: PackedScene = preload("res://scenes/world3d/npc3d.tscn")
const JoystickScript: GDScript = preload("res://scripts/ui/virtual_joystick.gd")
const DialogueScript: GDScript = preload("res://scripts/ui/dialogue3d.gd")
const HudScript: GDScript = preload("res://scripts/ui/hud3d.gd")

const BuildingLarge: PackedScene = preload("res://assets/city/Building_Large_2.gltf")
const BuildingMedium: PackedScene = preload("res://assets/city/Building_Medium_2_001.gltf")
const BuildingSmall: PackedScene = preload("res://assets/city/Building_Small_1.gltf")
const DoorModel: PackedScene = preload("res://assets/city/Door_1.gltf")
const BenchModel: PackedScene = preload("res://assets/props/Bench.glb")
const TrashcanModel: PackedScene = preload("res://assets/props/Trashcan.glb")
const StreetLightModel: PackedScene = preload("res://assets/props/StreetLight.glb")
const FlagModel: PackedScene = preload("res://assets/props/Flag.glb")

const TREE_SCENES: Array[String] = [
	"res://assets/nature/CommonTree_1.gltf",
	"res://assets/nature/CommonTree_2.gltf",
	"res://assets/nature/CommonTree_3.gltf",
	"res://assets/nature/CommonTree_4.gltf",
	"res://assets/nature/CommonTree_5.gltf",
]
const BUSH_SCENES: Array[String] = [
	"res://assets/nature/Bush_Common.gltf",
	"res://assets/nature/Bush_Common_Flowers.gltf",
]
const FLOWER_SCENES: Array[String] = [
	"res://assets/nature/Flower_3_Group.gltf",
	"res://assets/nature/Flower_4_Group.gltf",
]

## Playable extent; invisible walls sit on these edges.
const BOUNDS: Rect2 = Rect2(-24, -18, 48, 38)

## Camera framing: fixed three-quarter view, no rotation.
const CAM_PITCH: float = -46.0
const CAM_YAW: float = 22.0
const CAM_DISTANCE: float = 21.5
const CAM_FOV: float = 31.0

const NAVY: Color = Color(0.12, 0.2, 0.36)
const GOLD: Color = Color(0.92, 0.72, 0.3)

var player: CharacterBody3D
var jordan: Node3D
var current_npc: Node = null

var _rig: Node3D
var _joystick: Control
var _interact_button: Button
var _dialogue: PanelContainer


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_buildings()
	_build_greenery()
	_build_props()
	_build_actors()
	_build_camera()
	_build_ui()


func _process(delta: float) -> void:
	player.external_input = _joystick.output
	var talking: bool = _dialogue.visible
	_joystick.visible = not talking
	_interact_button.visible = current_npc != null and not talking
	_rig.global_position = _rig.global_position.lerp(
		player.global_position, minf(1.0, 7.0 * delta)
	)
	if Input.is_action_just_pressed("interact"):
		_do_interact()


func _do_interact() -> void:
	if _dialogue.visible:
		_dialogue.close()
	elif current_npc != null:
		player.control_locked = true
		current_npc.face_toward(player.global_position)
		player.face_toward(current_npc.global_position)
		_dialogue.open(
			current_npc.npc_name,
			"First day too? I'm trying to figure out whether this place is a campus or a whole city."
		)


func _on_dialogue_closed() -> void:
	player.control_locked = false


# --- Environment -------------------------------------------------------------

func _build_environment() -> void:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-38, -58, 0)
	sun.light_color = Color(1.0, 0.9, 0.76)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)

	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.35, 0.55, 0.8)
	sky_material.sky_horizon_color = Color(0.9, 0.8, 0.65)
	sky_material.ground_bottom_color = Color(0.3, 0.35, 0.3)
	sky_material.ground_horizon_color = Color(0.85, 0.78, 0.64)
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _build_ground() -> void:
	var grass: MeshInstance3D = MeshInstance3D.new()
	var grass_mesh: PlaneMesh = PlaneMesh.new()
	grass_mesh.size = Vector2(120, 100)
	var grass_material: StandardMaterial3D = StandardMaterial3D.new()
	grass_material.albedo_color = Color(0.28, 0.41, 0.22)
	grass_material.roughness = 1.0
	grass_mesh.material = grass_material
	grass.mesh = grass_mesh
	add_child(grass)

	# The ground itself must be solid or the player falls out of the world.
	_add_box_collider(Vector3(0, -0.5, 0), Vector3(120, 1, 100))

	# Paved paths: a north-south approach to the Rec Center and an east-west walk.
	var path_material: StandardMaterial3D = StandardMaterial3D.new()
	path_material.albedo_texture = load("res://assets/city/T_Concrete_BaseColor.png")
	path_material.albedo_color = Color(0.76, 0.74, 0.7)
	path_material.roughness = 0.9
	path_material.uv1_scale = Vector3(6, 6, 1)
	_add_path(Vector3(0, 0, 0), Vector2(5.0, 36), path_material)
	_add_path(Vector3(0, 0, 3.4), Vector2(46, 4.2), path_material)
	_add_path(Vector3(-14, 0, -3), Vector2(4.0, 14), path_material)
	_add_path(Vector3(14, 0, -3), Vector2(4.0, 14), path_material)

	# Plaza in front of the Rec Center entrance.
	var plaza_material: StandardMaterial3D = StandardMaterial3D.new()
	plaza_material.albedo_texture = load("res://assets/city/T_MarbleFloor_BaseColor.png")
	plaza_material.albedo_color = Color(0.92, 0.9, 0.85)
	plaza_material.roughness = 0.85
	plaza_material.uv1_scale = Vector3(8, 8, 1)
	_add_path(Vector3(0, 0.005, -12.5), Vector2(16, 8), plaza_material)

	# Invisible boundary walls.
	for wall: Array in [
		[Vector3(BOUNDS.position.x, 1.5, 1), Vector3(0.5, 3, BOUNDS.size.y + 4)],
		[Vector3(BOUNDS.end.x, 1.5, 1), Vector3(0.5, 3, BOUNDS.size.y + 4)],
		[Vector3(0, 1.5, BOUNDS.position.y), Vector3(BOUNDS.size.x + 4, 3, 0.5)],
		[Vector3(0, 1.5, BOUNDS.end.y), Vector3(BOUNDS.size.x + 4, 3, 0.5)],
	]:
		_add_box_collider(wall[0], wall[1])


func _add_path(at: Vector3, size: Vector2, material: StandardMaterial3D) -> void:
	var path: MeshInstance3D = MeshInstance3D.new()
	var mesh: PlaneMesh = PlaneMesh.new()
	mesh.size = size
	mesh.material = material
	path.mesh = mesh
	path.position = at + Vector3(0, 0.02, 0)
	add_child(path)


# --- Buildings ---------------------------------------------------------------

func _build_buildings() -> void:
	# Rec Center: the hero building, north, entrance facing the courtyard.
	var rec: Node3D = _place_model(BuildingLarge, Vector3(-1, 0, -16.6), 0.0)
	_collider_from_aabb(rec)

	var door: Node3D = _place_model(DoorModel, Vector3(0, 0, -16.05), 0.0)
	door.scale = Vector3(1.5, 1.5, 1.5)

	var rec_sign: Label3D = _make_label3d("· REC CENTER ·", 96)
	rec_sign.modulate = GOLD
	rec_sign.position = Vector3(0, 2.72, -15.5)
	add_child(rec_sign)

	var banner_left: Node3D = _place_model(FlagModel, Vector3(-5.6, 0, -14.9), 30.0)
	var banner_right: Node3D = _place_model(FlagModel, Vector3(5.6, 0, -14.9), -30.0)
	banner_left.scale = Vector3(1.1, 1.1, 1.1)
	banner_right.scale = Vector3(1.1, 1.1, 1.1)

	# Flanking facades to close the composition.
	var west: Node3D = _place_model(BuildingMedium, Vector3(-25.5, 0, -4), 90.0)
	_collider_from_aabb(west)
	var east: Node3D = _place_model(BuildingSmall, Vector3(25.5, 0, -2), -90.0)
	_collider_from_aabb(east)

	# Campus sign at the courtyard crossing.
	var sign_base: MeshInstance3D = MeshInstance3D.new()
	var base_mesh: BoxMesh = BoxMesh.new()
	base_mesh.size = Vector3(3.4, 1.5, 0.5)
	var base_material: StandardMaterial3D = StandardMaterial3D.new()
	base_material.albedo_color = NAVY
	base_material.roughness = 0.6
	base_mesh.material = base_material
	sign_base.mesh = base_mesh
	sign_base.position = Vector3(-8.2, 0.75, 7.6)
	sign_base.rotation_degrees.y = -18
	add_child(sign_base)
	_add_box_collider(Vector3(-8.2, 0.75, 7.6), Vector3(3.4, 1.5, 0.6))

	var sign_text: Label3D = _make_label3d("NORTH VALLEY STATE", 64)
	sign_text.modulate = GOLD
	sign_text.position = Vector3(-8.2, 1.05, 7.9)
	sign_text.rotation_degrees.y = -18
	add_child(sign_text)
	var sign_sub: Label3D = _make_label3d("EST. 1962  ·  HOME OF THE RIDGEHAWKS", 30)
	sign_sub.modulate = Color(1, 1, 1, 0.85)
	sign_sub.position = Vector3(-8.2, 0.62, 7.9)
	sign_sub.rotation_degrees.y = -18
	add_child(sign_sub)


# --- Greenery and props --------------------------------------------------------

func _build_greenery() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var tree_spots: Array = [
		Vector3(-9, 0, -8), Vector3(9.5, 0, -9), Vector3(-17, 0, 6), Vector3(-20, 0, 13),
		Vector3(18, 0, 12), Vector3(21, 0, 5), Vector3(-8, 0, 12), Vector3(12, 0, 15),
		Vector3(-13.5, 0, 16), Vector3(16, 0, -10), Vector3(-21, 0, -10), Vector3(6, 0, 13.5),
	]
	for i in tree_spots.size():
		var tree: Node3D = _place_model(
			load(TREE_SCENES[i % TREE_SCENES.size()]), tree_spots[i], rng.randf_range(0, 360)
		)
		var s: float = rng.randf_range(1.15, 1.6)
		tree.scale = Vector3(s, s, s)
		_add_cylinder_collider(tree_spots[i], 0.4)

	for i in 14:
		var bush_pos: Vector3 = Vector3(
			rng.randf_range(BOUNDS.position.x + 1, BOUNDS.end.x - 1), 0,
			BOUNDS.end.y - rng.randf_range(0.5, 1.5)
		)
		_place_model(load(BUSH_SCENES[i % BUSH_SCENES.size()]), bush_pos, rng.randf_range(0, 360))
	for i in 10:
		var flower_pos: Vector3 = Vector3(rng.randf_range(-11, -4.2), 0, rng.randf_range(5.8, 7.6))
		if i >= 5:
			flower_pos = Vector3(rng.randf_range(4.2, 11), 0, rng.randf_range(-0.5, 1.2))
		var flowers: Node3D = _place_model(load(FLOWER_SCENES[i % FLOWER_SCENES.size()]), flower_pos, rng.randf_range(0, 360))
		flowers.scale = Vector3(0.35, 0.35, 0.35)


func _build_props() -> void:
	for bench_data: Array in [
		[Vector3(-3.6, 0, 5.6), 0.0], [Vector3(3.6, 0, 5.6), 0.0],
		[Vector3(-3.6, 0, 1.2), 180.0], [Vector3(3.6, 0, 1.2), 180.0],
		[Vector3(-11.5, 0, -5), 90.0],
	]:
		var bench: Node3D = _place_model(BenchModel, bench_data[0], bench_data[1])
		bench.scale = Vector3(2.4, 2.4, 2.4)
		_add_box_collider(bench_data[0] + Vector3(0, 0.4, 0), Vector3(2.0, 0.8, 0.9))

	for light_pos: Vector3 in [
		Vector3(-3.2, 0, -8.5), Vector3(3.2, 0, -8.5),
		Vector3(-3.2, 0, 10.5), Vector3(3.2, 0, 10.5), Vector3(14, 0, 5.6),
	]:
		_place_model(StreetLightModel, light_pos, 0.0)
		_add_cylinder_collider(light_pos, 0.2)

	for trash_pos: Vector3 in [Vector3(-5.4, 0, 6.1), Vector3(5.2, 0, 0.8)]:
		var trashcan: Node3D = _place_model(TrashcanModel, trash_pos, 0.0)
		trashcan.scale = Vector3(0.65, 0.65, 0.65)
		_add_cylinder_collider(trash_pos, 0.3)


# --- Actors and camera ---------------------------------------------------------

func _build_actors() -> void:
	player = PlayerScene.instantiate()
	player.name = "Player"
	player.position = Vector3(0, 0.1, 11)
	add_child(player)

	jordan = NpcScene.instantiate()
	jordan.name = "Jordan"
	jordan.position = Vector3(2.6, 0, 3.2)
	jordan.rotation_degrees.y = 30
	add_child(jordan)
	jordan.range_changed.connect(_on_npc_range_changed)


func _on_npc_range_changed(npc: Node, in_range: bool) -> void:
	if in_range:
		current_npc = npc
	elif current_npc == npc:
		current_npc = null


func _build_camera() -> void:
	_rig = Node3D.new()
	_rig.name = "CameraRig"
	_rig.position = player.position
	add_child(_rig)
	var arm: Node3D = Node3D.new()
	arm.rotation_degrees = Vector3(CAM_PITCH, CAM_YAW, 0)
	_rig.add_child(arm)
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0, 0, CAM_DISTANCE)
	camera.fov = CAM_FOV
	arm.add_child(camera)
	camera.make_current()


# --- UI ------------------------------------------------------------------------

func _build_ui() -> void:
	var ui: CanvasLayer = CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)

	var hud: PanelContainer = PanelContainer.new()
	hud.name = "HUD"
	hud.set_script(HudScript)
	ui.add_child(hud)

	_joystick = Control.new()
	_joystick.name = "Joystick"
	_joystick.set_script(JoystickScript)
	_joystick.position = Vector2(48, 452)
	_joystick.size = Vector2(220, 220)
	ui.add_child(_joystick)

	_interact_button = Button.new()
	_interact_button.name = "InteractButton"
	_interact_button.text = "TALK"
	_interact_button.position = Vector2(1090, 545)
	_interact_button.size = Vector2(130, 130)
	_interact_button.focus_mode = Control.FOCUS_NONE
	_interact_button.add_theme_font_size_override("font_size", 26)
	var talk_style: StyleBoxFlat = StyleBoxFlat.new()
	talk_style.bg_color = Color(0.1, 0.14, 0.22, 0.85)
	talk_style.set_corner_radius_all(65)
	talk_style.border_color = Color(GOLD, 0.8)
	talk_style.set_border_width_all(3)
	_interact_button.add_theme_stylebox_override("normal", talk_style)
	var talk_hover: StyleBoxFlat = talk_style.duplicate()
	talk_hover.bg_color = Color(0.16, 0.22, 0.34, 0.9)
	_interact_button.add_theme_stylebox_override("hover", talk_hover)
	_interact_button.add_theme_stylebox_override("pressed", talk_hover)
	_interact_button.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_interact_button.pressed.connect(_do_interact)
	ui.add_child(_interact_button)

	_dialogue = PanelContainer.new()
	_dialogue.name = "Dialogue"
	_dialogue.set_script(DialogueScript)
	ui.add_child(_dialogue)
	_dialogue.closed.connect(_on_dialogue_closed)


# --- Helpers -------------------------------------------------------------------

func _place_model(scene: PackedScene, at: Vector3, yaw_degrees: float) -> Node3D:
	var node: Node3D = scene.instantiate()
	node.position = at
	node.rotation_degrees.y = yaw_degrees
	add_child(node)
	return node


func _make_label3d(text: String, size: int) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text
	label.font_size = size
	label.outline_size = int(size / 8.0)
	label.modulate = Color(0.98, 0.96, 0.9)
	label.outline_modulate = Color(0.1, 0.12, 0.2)
	return label


func _add_box_collider(at: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = at
	var collider: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	collider.shape = box
	body.add_child(collider)
	add_child(body)


func _add_cylinder_collider(at: Vector3, radius: float) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = at + Vector3(0, 1.5, 0)
	var collider: CollisionShape3D = CollisionShape3D.new()
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = 3.0
	collider.shape = cylinder
	body.add_child(collider)
	add_child(body)


## Adds a static box collider matching a placed model's world-space footprint.
func _collider_from_aabb(model: Node3D) -> void:
	var mesh_instance: MeshInstance3D = _find_mesh(model)
	if mesh_instance == null:
		return
	var aabb: AABB = mesh_instance.mesh.get_aabb()
	var body: StaticBody3D = StaticBody3D.new()
	var collider: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = aabb.size
	collider.shape = box
	collider.position = aabb.get_center()
	body.add_child(collider)
	body.transform = model.transform
	add_child(body)


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found: MeshInstance3D = _find_mesh(child)
		if found != null:
			return found
	return null
