extends SceneTree
## One-time scaffold generator for the courtyard scene. Run with:
##   godot --headless -s tools/build_campus_scene.gd
##
## Writes editor-authored scenes: scenes/world3d/campus3d.tscn plus the
## compound-prop subscenes it instances (rec_center, campus_sign, info_board,
## club_table, pole_banner). Every placement below is a deliberate
## composition choice, not a random scatter. After generation the .tscn files
## are the source of truth — open them in the Godot editor to iterate.
## campus3d.gd contains only runtime behavior.

const NAVY: Color = Color(0.12, 0.2, 0.36)
const GOLD: Color = Color(0.92, 0.72, 0.3)

## Playable extent; invisible walls sit on these edges.
const BOUNDS: Rect2 = Rect2(-24, -18, 48, 38)

var _root: Node3D


func _initialize() -> void:
	_save(_build_pole_banner(), "res://scenes/world3d/env/pole_banner.tscn")
	_save(_build_campus_sign(), "res://scenes/world3d/env/campus_sign.tscn")
	_save(_build_info_board(), "res://scenes/world3d/env/info_board.tscn")
	_save(_build_club_table(), "res://scenes/world3d/env/club_table.tscn")
	_save(_build_rec_center(), "res://scenes/world3d/env/rec_center.tscn")
	_save(_build_campus(), "res://scenes/world3d/campus3d.tscn")
	print("scenes written")
	quit(0)


func _save(root: Node, path: String) -> void:
	_set_owner_recursive(root, root)
	var packed: PackedScene = PackedScene.new()
	var err: int = packed.pack(root)
	assert(err == OK)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	err = ResourceSaver.save(packed, path)
	assert(err == OK)
	print("wrote ", path)
	root.free()


func _set_owner_recursive(root: Node, node: Node) -> void:
	for child in node.get_children():
		child.owner = root
		# Do not descend into instanced scenes; they save as references.
		if child.scene_file_path == "":
			_set_owner_recursive(root, child)


# =============================================================================
# Subscenes
# =============================================================================

## Streetlight with two hanging campus banners — the classic university
## light-pole dressing. Banner texture chosen per instance via metadata.
func _build_pole_banner() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "PoleBanner"
	root.set_script(load("res://scripts/world3d/pole_banner.gd"))
	var light: Node3D = _instance("res://assets/props/StreetLight.glb")
	light.name = "StreetLight"
	root.add_child(light)
	var banner: MeshInstance3D = _banner_quad(
		"res://assets/branding/banner_theu.png", Vector2(0.62, 1.24)
	)
	banner.name = "Banner"
	banner.position = Vector3(0, 2.55, 0.16)
	root.add_child(banner)
	var body: StaticBody3D = _cylinder_body(0.18)
	root.add_child(body)
	return root


## Monument sign at the courtyard entrance: navy slab, gold cap, emblem.
func _build_campus_sign() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "CampusSign"

	var slab: MeshInstance3D = _box(Vector3(3.9, 1.5, 0.45), NAVY, 0.55)
	slab.name = "Slab"
	slab.position = Vector3(0, 0.75, 0)
	root.add_child(slab)

	var cap: MeshInstance3D = _box(Vector3(4.05, 0.12, 0.55), GOLD, 0.4)
	cap.name = "Cap"
	cap.position = Vector3(0, 1.56, 0)
	root.add_child(cap)

	var base: MeshInstance3D = _box(Vector3(4.2, 0.22, 0.7), Color(0.55, 0.53, 0.5), 0.9)
	base.name = "Base"
	base.position = Vector3(0, 0.11, 0)
	root.add_child(base)

	var emblem: MeshInstance3D = _banner_quad("res://assets/branding/emblem.png", Vector2(1.0, 1.0))
	emblem.name = "Emblem"
	emblem.position = Vector3(-1.28, 0.82, 0.24)
	root.add_child(emblem)

	var title: Label3D = _label("NORTH VALLEY STATE", 56, GOLD)
	title.position = Vector3(0.5, 1.05, 0.24)
	root.add_child(title)
	var subtitle: Label3D = _label("HOME OF THE RIDGEHAWKS", 26, Color(1, 1, 1, 0.9))
	subtitle.position = Vector3(0.5, 0.62, 0.24)
	root.add_child(subtitle)

	var body: StaticBody3D = _box_body(Vector3(0, 0.75, 0), Vector3(4.0, 1.6, 0.6))
	root.add_child(body)
	return root


## Bulletin board with the walk-on tryouts poster and the campus map.
func _build_info_board() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "InfoBoard"

	var frame: MeshInstance3D = _box(Vector3(3.2, 1.75, 0.14), NAVY, 0.6)
	frame.name = "Frame"
	frame.position = Vector3(0, 1.72, 0)
	root.add_child(frame)

	var roof: MeshInstance3D = _box(Vector3(3.45, 0.1, 0.42), GOLD, 0.5)
	roof.name = "Roof"
	roof.position = Vector3(0, 2.66, 0)
	root.add_child(roof)

	for leg_x: float in [-1.35, 1.35]:
		var leg: MeshInstance3D = _box(Vector3(0.16, 0.9, 0.16), Color(0.2, 0.25, 0.35), 0.7)
		leg.name = "LegL" if leg_x < 0 else "LegR"
		leg.position = Vector3(leg_x, 0.45, 0)
		root.add_child(leg)

	var header: Label3D = _label("CAMPUS BULLETIN", 30, GOLD)
	header.position = Vector3(0, 2.44, 0.09)
	root.add_child(header)

	var poster_a: MeshInstance3D = _banner_quad(
		"res://assets/branding/poster_walkon.png", Vector2(1.14, 1.5)
	)
	poster_a.name = "PosterWalkOn"
	poster_a.position = Vector3(-0.72, 1.6, 0.09)
	poster_a.rotation_degrees.z = 1.5
	root.add_child(poster_a)

	var poster_b: MeshInstance3D = _banner_quad(
		"res://assets/branding/poster_map.png", Vector2(1.14, 1.5)
	)
	poster_b.name = "PosterMap"
	poster_b.position = Vector3(0.72, 1.6, 0.09)
	poster_b.rotation_degrees.z = -1.0
	root.add_child(poster_b)

	var body: StaticBody3D = _box_body(Vector3(0, 1.2, 0), Vector3(3.3, 2.4, 0.4))
	root.add_child(body)
	return root


## Student-org table: a cloth-draped fair table with the club banner on the
## skirt and sign-up flyers on top — the classic club-fair setup.
func _build_club_table() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "ClubTable"

	var cloth: MeshInstance3D = _box(Vector3(1.8, 0.78, 0.72), NAVY, 0.85)
	cloth.name = "Cloth"
	cloth.position = Vector3(0, 0.39, 0)
	root.add_child(cloth)

	var top: MeshInstance3D = _box(Vector3(1.88, 0.05, 0.8), Color(0.18, 0.27, 0.44), 0.8)
	top.name = "Top"
	top.position = Vector3(0, 0.8, 0)
	root.add_child(top)

	var banner: MeshInstance3D = _banner_quad(
		"res://assets/branding/banner_club.png", Vector2(1.5, 0.66)
	)
	banner.name = "Banner"
	banner.position = Vector3(0, 0.42, 0.37)
	root.add_child(banner)

	for i in 3:
		var flyer: MeshInstance3D = _box(
			Vector3(0.22, 0.008, 0.3), Color(0.96, 0.94, 0.88), 0.9
		)
		flyer.name = "Flyer%d" % i
		flyer.position = Vector3(-0.42 + i * 0.36, 0.84, 0.03 * i - 0.05)
		flyer.rotation_degrees.y = -14 + i * 16
		root.add_child(flyer)

	var body: StaticBody3D = _box_body(Vector3(0, 0.4, 0), Vector3(1.9, 0.85, 0.85))
	root.add_child(body)
	return root


## The hero building: Rec Center with entrance stairs, facade banners,
## gold lettering, flanking flags and planters.
func _build_rec_center() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "RecCenter"

	var building: Node3D = _instance("res://assets/city/Building_Large_2.gltf")
	building.name = "Building"
	root.add_child(building)

	var door: Node3D = _instance("res://assets/city/Door_1.gltf")
	door.name = "Door"
	door.position = Vector3(1.0, 0, 0.55)
	door.scale = Vector3(1.5, 1.5, 1.5)
	root.add_child(door)

	var stairs: Node3D = _instance("res://assets/city/Stairs_Entrance_Concrete.gltf")
	stairs.name = "Stairs"
	stairs.position = Vector3(1.0, 0, 1.15)
	root.add_child(stairs)

	# Navy fascia band across the facade covers the storefront awning and
	# carries the building's name in gold — this is what makes the asset-kit
	# building read as a campus rec center.
	var fascia: MeshInstance3D = _box(Vector3(14.7, 0.8, 0.14), NAVY, 0.6)
	fascia.name = "Fascia"
	fascia.position = Vector3(0.4, 2.98, 1.02)
	root.add_child(fascia)

	var sign: Label3D = _label("NORTH VALLEY STATE  ·  RECREATION CENTER", 52, GOLD)
	sign.name = "Sign"
	sign.position = Vector3(0.4, 2.98, 1.11)
	sign.outline_size = 0
	root.add_child(sign)

	for side: int in [-1, 1]:
		var banner: MeshInstance3D = _banner_quad(
			"res://assets/branding/banner_rec.png", Vector2(1.15, 2.85)
		)
		banner.name = "FacadeBannerL" if side < 0 else "FacadeBannerR"
		banner.position = Vector3(1.0 + side * 3.1, 3.6, 1.12)
		root.add_child(banner)

		var flag: Node3D = _instance("res://assets/props/Flag.glb")
		flag.name = "FlagL" if side < 0 else "FlagR"
		flag.position = Vector3(1.0 + side * 7.4, 0, 1.9)
		flag.rotation_degrees.y = side * -30
		flag.scale = Vector3(1.1, 1.1, 1.1)
		flag.set_script(load("res://scripts/world3d/recolor.gd"))
		flag.set("recolors", {
			"LightRed": GOLD, "Brown": Color(0.28, 0.3, 0.36),
		})
		root.add_child(flag)

		var planter: Node3D = _instance("res://assets/city/Prop_Planter_Single.gltf")
		planter.name = "PlanterL" if side < 0 else "PlanterR"
		planter.position = Vector3(1.0 + side * 2.4, 0, 1.4)
		root.add_child(planter)

	var body: StaticBody3D = _box_body(Vector3(0.4, 2.5, -1.6), Vector3(14.5, 5.0, 5.4))
	root.add_child(body)
	return root


# =============================================================================
# The courtyard
# =============================================================================

func _build_campus() -> Node3D:
	_root = Node3D.new()
	_root.name = "Campus3D"
	_root.set_script(load("res://scripts/world3d/campus3d.gd"))

	_add_lighting()
	_add_ground()
	_add_buildings()
	_add_landmarks()
	_add_props()
	_add_greenery()
	_add_actors()
	_add_camera()
	_add_audio()
	_add_ui()
	return _root


func _add_lighting() -> void:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.1
	sun.light_angular_distance = 3.0
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.6
	sun.shadow_blur = 2.0
	sun.directional_shadow_max_distance = 55.0
	_root.add_child(sun)

	# Cool low fill opposite the sun: lifts shadowed sides so characters
	# stay readable, standing in for bounced sky light.
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.rotation_degrees = Vector3(-28, 132, 0)
	fill.light_color = Color(0.78, 0.85, 0.98)
	fill.light_energy = 0.28
	fill.shadow_enabled = false
	_root.add_child(fill)

	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.4, 0.58, 0.78)
	sky_material.sky_horizon_color = Color(0.88, 0.82, 0.7)
	sky_material.ground_bottom_color = Color(0.32, 0.36, 0.31)
	sky_material.ground_horizon_color = Color(0.84, 0.79, 0.67)
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.05
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	_root.add_child(world_env)


func _add_ground() -> void:
	var ground: Node3D = Node3D.new()
	ground.name = "Ground"
	_root.add_child(ground)

	var grass: MeshInstance3D = MeshInstance3D.new()
	grass.name = "Grass"
	var grass_mesh: PlaneMesh = PlaneMesh.new()
	grass_mesh.size = Vector2(130, 110)
	var grass_material: StandardMaterial3D = StandardMaterial3D.new()
	grass_material.albedo_texture = load("res://assets/ground/T_Grass_Soft.png")
	grass_material.albedo_color = Color(0.7, 0.74, 0.62)
	grass_material.uv1_scale = Vector3(16, 16, 1)
	grass_material.roughness = 1.0
	grass_mesh.material = grass_material
	grass.mesh = grass_mesh
	ground.add_child(grass)

	var concrete: StandardMaterial3D = StandardMaterial3D.new()
	concrete.albedo_texture = load("res://assets/city/T_Concrete_BaseColor.png")
	concrete.albedo_color = Color(0.64, 0.62, 0.59)
	concrete.roughness = 0.95
	concrete.uv1_scale = Vector3(6, 6, 1)
	# Path hierarchy: wide promenade to the Rec Center, standard cross walk.
	_path(ground, "Promenade", Vector3(0, 0.02, 3.0), Vector2(6.5, 30), concrete)
	_path(ground, "CrossWalk", Vector3(0, 0.02, 4.4), Vector2(46, 4.4), concrete)
	_path(ground, "SignSpur", Vector3(-7.5, 0.02, 8.6), Vector2(3.4, 4.4), concrete)

	var marble: StandardMaterial3D = StandardMaterial3D.new()
	marble.albedo_texture = load("res://assets/city/T_MarbleFloor_BaseColor.png")
	marble.albedo_color = Color(0.72, 0.7, 0.66)
	marble.roughness = 0.85
	marble.uv1_scale = Vector3(8, 8, 1)
	_path(ground, "RecPlaza", Vector3(0, 0.028, -12.6), Vector2(19, 7.4), marble)

	# Center plaza reads as pavement one step lighter than the walks, so the
	# social space is legible without glowing.
	var plaza: StandardMaterial3D = concrete.duplicate()
	plaza.albedo_color = Color(0.71, 0.69, 0.65)
	plaza.uv1_scale = Vector3(9, 9, 1)
	_path(ground, "CenterPlaza", Vector3(0, 0.025, 4.2), Vector2(12, 8.4), plaza)

	var decal: MeshInstance3D = _banner_quad(
		"res://assets/branding/decal_emblem.png", Vector2(3.4, 3.4)
	)
	decal.name = "PlazaEmblem"
	var decal_mesh: QuadMesh = decal.mesh
	decal_mesh.orientation = PlaneMesh.FACE_Y
	decal.position = Vector3(0, 0.045, -11.6)
	ground.add_child(decal)

	var floor_body: StaticBody3D = _box_body(Vector3(0, -0.5, 0), Vector3(130, 1, 110))
	floor_body.name = "FloorBody"
	ground.add_child(floor_body)

	var walls: Node3D = Node3D.new()
	walls.name = "Bounds"
	ground.add_child(walls)
	var specs: Array = [
		[Vector3(BOUNDS.position.x, 1.5, 1), Vector3(0.5, 3, BOUNDS.size.y + 4)],
		[Vector3(BOUNDS.end.x, 1.5, 1), Vector3(0.5, 3, BOUNDS.size.y + 4)],
		[Vector3(0, 1.5, BOUNDS.position.y), Vector3(BOUNDS.size.x + 4, 3, 0.5)],
		[Vector3(0, 1.5, BOUNDS.end.y), Vector3(BOUNDS.size.x + 4, 3, 0.5)],
	]
	for i in specs.size():
		var wall: StaticBody3D = _box_body(specs[i][0], specs[i][1])
		wall.name = "Wall%d" % i
		walls.add_child(wall)


func _path(parent: Node, path_name: String, at: Vector3, size: Vector2,
		material: StandardMaterial3D) -> void:
	var path: MeshInstance3D = MeshInstance3D.new()
	path.name = path_name
	var mesh: PlaneMesh = PlaneMesh.new()
	mesh.size = size
	mesh.material = material
	path.mesh = mesh
	path.position = at
	parent.add_child(path)


func _add_buildings() -> void:
	var buildings: Node3D = Node3D.new()
	buildings.name = "Buildings"
	_root.add_child(buildings)

	var rec: Node3D = _instance("res://scenes/world3d/env/rec_center.tscn")
	rec.position = Vector3(-1, 0, -17.2)
	buildings.add_child(rec)

	# Flanking halls close the composition left and right; two more sit
	# beyond the bounds so the skyline reads as a campus, not a lone block.
	var specs: Array = [
		["WestHall", "res://assets/city/Building_Medium_2_001.gltf", Vector3(-22.5, 0, -5), 90.0],
		["EastHall", "res://assets/city/Building_Small_1.gltf", Vector3(21.5, 0, -3), -90.0],
		["NorthWestHall", "res://assets/city/Building_Small_1.gltf", Vector3(-17, 0, -19.5), 15.0],
		["NorthEastHall", "res://assets/city/Building_Medium_2_001.gltf", Vector3(15.5, 0, -20.5), 0.0],
	]
	for spec: Array in specs:
		var hall: Node3D = _instance(spec[1])
		hall.name = spec[0]
		hall.position = spec[2]
		hall.rotation_degrees.y = spec[3]
		buildings.add_child(hall)
		var mesh: MeshInstance3D = CharacterAppearance.find_mesh(hall)
		if mesh != null:
			var aabb: AABB = mesh.mesh.get_aabb()
			var body: StaticBody3D = _box_body(aabb.get_center(), aabb.size)
			body.name = spec[0] + "Body"
			body.position = spec[2]
			body.rotation_degrees.y = spec[3]
			buildings.add_child(body)


func _add_landmarks() -> void:
	var landmarks: Node3D = Node3D.new()
	landmarks.name = "Landmarks"
	_root.add_child(landmarks)

	var sign: Node3D = _instance("res://scenes/world3d/env/campus_sign.tscn")
	sign.position = Vector3(-7.6, 0, 11.6)
	sign.rotation_degrees.y = -24
	landmarks.add_child(sign)

	var board: Node3D = _instance("res://scenes/world3d/env/info_board.tscn")
	board.position = Vector3(-7.6, 0, 5.2)
	board.rotation_degrees.y = 38
	landmarks.add_child(board)

	var table: Node3D = _instance("res://scenes/world3d/env/club_table.tscn")
	table.position = Vector3(7.8, 0, 2.2)
	table.rotation_degrees.y = -45
	landmarks.add_child(table)


func _add_props() -> void:
	var props: Node3D = Node3D.new()
	props.name = "Props"
	_root.add_child(props)

	# Benches around the center plaza face inward: a social space, not
	# street furniture in a row.
	var bench_specs: Array = [
		["BenchNW", Vector3(-4.6, 0, 1.6), 180.0],
		["BenchNE", Vector3(4.6, 0, 1.6), 180.0],
		["BenchSW", Vector3(-4.6, 0, 7.0), 0.0],
		["BenchSE", Vector3(4.6, 0, 7.0), 0.0],
		["BenchPromenade", Vector3(-4.6, 0, -5.5), 90.0],
	]
	for spec: Array in bench_specs:
		var bench: Node3D = _instance("res://assets/props/Bench.glb")
		bench.name = spec[0]
		bench.position = spec[1]
		bench.rotation_degrees.y = spec[2]
		bench.scale = Vector3(2.4, 2.4, 2.4)
		props.add_child(bench)
		var body: StaticBody3D = _box_body(
			spec[1] + Vector3(0, 0.4, 0), Vector3(2.0, 0.8, 0.9)
		)
		body.name = spec[0] + "Body"
		body.rotation_degrees.y = spec[2]
		props.add_child(body)

	# Banner poles line the promenade. Lamp arms all point outward, away
	# from the walkway, so no arm ever crosses the camera's subject; the
	# banner counter-rotates to keep facing the camera.
	var pole_specs: Array = [
		[Vector3(-5.4, 0, -8.8), 180.0, 180.0, "res://assets/branding/banner_theu.png"],
		[Vector3(5.4, 0, -8.8), 0.0, 0.0, "res://assets/branding/banner_hawks.png"],
		[Vector3(-4.3, 0, -1.8), 180.0, 180.0, "res://assets/branding/banner_hawks.png"],
		[Vector3(4.3, 0, -1.8), 0.0, 0.0, "res://assets/branding/banner_theu.png"],
		[Vector3(-4.3, 0, 12.8), 90.0, -90.0, "res://assets/branding/banner_theu.png"],
		[Vector3(15.8, 0, 6.8), 0.0, 0.0, "res://assets/branding/banner_hawks.png"],
	]
	for i in pole_specs.size():
		var pole: Node3D = _instance("res://scenes/world3d/env/pole_banner.tscn")
		pole.name = "PoleBanner%d" % i
		pole.position = pole_specs[i][0]
		pole.rotation_degrees.y = pole_specs[i][1]
		pole.set("banner_yaw", pole_specs[i][2])
		pole.set("banner_texture", load(pole_specs[i][3]))
		props.add_child(pole)

	for spec: Array in [
		["TrashcanA", Vector3(-6.2, 0, 2.0)], ["TrashcanB", Vector3(6.3, 0, 6.6)],
	]:
		var can: Node3D = _instance("res://assets/props/Trashcan.glb")
		can.name = spec[0]
		can.position = spec[1]
		can.scale = Vector3(0.65, 0.65, 0.65)
		props.add_child(can)
		var body: StaticBody3D = _cylinder_body(0.3)
		body.name = spec[0] + "Body"
		body.position = spec[1] + Vector3(0, 1.5, 0)
		props.add_child(body)

	# Bollards mark where the promenade meets the Rec plaza.
	for i in 4:
		var bollard: Node3D = _instance("res://assets/city/Prop_Bollard.gltf")
		bollard.name = "Bollard%d" % i
		bollard.position = Vector3([-5.6, -4.4, 4.4, 5.6][i], 0, -8.9)
		props.add_child(bollard)

	# Long planters edge the cross walk where it meets the center plaza.
	for spec: Array in [
		["PlanterWest", Vector3(-9.5, 0, 6.9), 0.0],
		["PlanterEast", Vector3(11.0, 0, 1.9), 180.0],
	]:
		var planter: Node3D = _instance("res://assets/city/Sidewalk_Planter.gltf")
		planter.name = spec[0]
		planter.position = spec[1]
		planter.rotation_degrees.y = spec[2]
		props.add_child(planter)


func _add_greenery() -> void:
	var green: Node3D = Node3D.new()
	green.name = "Greenery"
	_root.add_child(green)

	# Trees frame the promenade in two loose lines and fill the corners the
	# camera sees behind the action. None sit on the camera's sightline to
	# the Rec Center or the center plaza.
	var tree_specs: Array = [
		[1, Vector3(-10.5, 0, -8), 1.3], [2, Vector3(-14, 0, -1.5), 1.45],
		[3, Vector3(-17.5, 0, 5), 1.3], [4, Vector3(-19, 0, 12), 1.5],
		[5, Vector3(10.5, 0, -7.5), 1.35], [1, Vector3(15, 0, -1), 1.5],
		[2, Vector3(18, 0, 6.5), 1.3], [3, Vector3(20, 0, 13), 1.45],
		[4, Vector3(-13, 0, 17), 1.4], [5, Vector3(9.5, 0, 16.5), 1.35],
		[2, Vector3(-20.5, 0, -12), 1.55], [4, Vector3(14, 0, -13.5), 1.3],
	]
	for i in tree_specs.size():
		var spec: Array = tree_specs[i]
		var tree: Node3D = _instance("res://assets/nature/CommonTree_%d.gltf" % spec[0])
		tree.name = "Tree%d" % i
		tree.position = spec[1]
		tree.rotation_degrees.y = i * 47.0
		tree.scale = Vector3(spec[2], spec[2], spec[2])
		green.add_child(tree)
		var body: StaticBody3D = _cylinder_body(0.4)
		body.name = "Tree%dBody" % i
		body.position = spec[1] + Vector3(0, 1.5, 0)
		green.add_child(body)

	# Bushes soften building bases and the world edge behind the spawn.
	var bush_specs: Array = [
		Vector3(-6.5, 0, -15.2), Vector3(8.5, 0, -15.2), Vector3(-11.5, 0, -14.6),
		Vector3(13.2, 0, -14.8), Vector3(-21.5, 0, 0), Vector3(-21.8, 0, 6),
		Vector3(20.6, 0, 1.5), Vector3(-9.3, 0, 12.6), Vector3(-6.3, 0, 13.2),
		Vector3(6, 0, 18.6), Vector3(-2, 0, 19.0), Vector3(2, 0, 18.8),
		Vector3(12, 0, 18.4), Vector3(-9, 0, 19.2), Vector3(-16, 0, 18.8),
		Vector3(16.5, 0, 17.8),
	]
	for i in bush_specs.size():
		var bush: Node3D = _instance(
			"res://assets/nature/Bush_Common%s.gltf" % ("" if i % 3 else "_Flowers")
		)
		bush.name = "Bush%d" % i
		bush.position = bush_specs[i]
		bush.rotation_degrees.y = i * 71.0
		green.add_child(bush)

	# Grass clumps and clover break up the lawn along path edges.
	var clump_specs: Array = [
		Vector3(-3.9, 0, 0.2), Vector3(4.0, 0, -3.2), Vector3(-4.1, 0, -6.8),
		Vector3(3.8, 0, 12.4), Vector3(-3.8, 0, 15.8), Vector3(4.2, 0, 8.9),
		Vector3(-8.6, 0, 3.1), Vector3(9.2, 0, 5.9), Vector3(-11.2, 0, 8.3),
		Vector3(12.4, 0, 2.8), Vector3(-6.9, 0, -10.2), Vector3(7.3, 0, -10.6),
		Vector3(-15.5, 0, 13.2), Vector3(16.8, 0, 10.1), Vector3(-17.2, 0, -6.4),
		Vector3(12.8, 0, -5.2), Vector3(6.4, 0, 15.3), Vector3(-12.6, 0, -10.8),
	]
	for i in clump_specs.size():
		var kind: String = ["Grass_Common_Tall", "Grass_Common_Short", "Clover_1"][i % 3]
		var clump: Node3D = _instance("res://assets/nature/%s.gltf" % kind)
		clump.name = "Clump%d" % i
		clump.position = clump_specs[i]
		clump.rotation_degrees.y = i * 53.0
		clump.scale = Vector3(0.85, 0.85, 0.85)
		green.add_child(clump)

	# Flower beds flank the promenade where it opens into the Rec plaza.
	var flower_specs: Array = [
		Vector3(-5.4, 0, -11.2), Vector3(-6.6, 0, -10.4), Vector3(5.6, 0, -11.0),
		Vector3(6.6, 0, -10.2), Vector3(-5.8, 0, 10.6), Vector3(5.8, 0, 11.2),
	]
	for i in flower_specs.size():
		var flowers: Node3D = _instance(
			"res://assets/nature/Flower_%d_Group.gltf" % (3 if i % 2 else 4)
		)
		flowers.name = "Flowers%d" % i
		flowers.position = flower_specs[i]
		flowers.rotation_degrees.y = i * 39.0
		flowers.scale = Vector3(0.4, 0.4, 0.4)
		green.add_child(flowers)


func _add_actors() -> void:
	var actors: Node3D = Node3D.new()
	actors.name = "Actors"
	_root.add_child(actors)

	var player: Node = _instance("res://scenes/world3d/player3d.tscn")
	player.name = "Player"
	player.position = Vector3(0, 0.1, 12)
	actors.add_child(player)

	var jordan: Node = _instance("res://scenes/world3d/npc3d.tscn")
	jordan.name = "Jordan"
	jordan.position = Vector3(2.4, 0, 7.6)
	jordan.rotation_degrees.y = 200
	actors.add_child(jordan)

	var students: Node3D = Node3D.new()
	students.name = "Students"
	actors.add_child(students)

	var student_specs: Array = [
		{
			"name": "WalkerA", "model_key": "female_casual", "activity": 0,
			"position": Vector3(-12, 0, 4.0), "phase_offset": 0.0,
			"shirt_color": Color(0.75, 0.42, 0.5), "pants_color": Color(0.22, 0.24, 0.3),
			"skin_tone": "light", "hair_color": Color(0.32, 0.2, 0.12),
			"waypoints": PackedVector3Array([Vector3(-14, 0, 4.0), Vector3(10.5, 0, 4.0)]),
		},
		{
			"name": "WalkerB", "model_key": "male_shirt", "activity": 0,
			"position": Vector3(-11, 0, 4.9), "phase_offset": 0.4,
			"shirt_color": Color(0.24, 0.35, 0.5), "pants_color": Color(0.2, 0.2, 0.24),
			"skin_tone": "brown", "hair_color": Color(0.1, 0.09, 0.08),
			"waypoints": PackedVector3Array([Vector3(-13.2, 0, 4.9), Vector3(11.5, 0, 4.9)]),
		},
		{
			"name": "RecLeaver", "model_key": "male_longsleeve", "activity": 0,
			"position": Vector3(-0.9, 0, -9.5), "phase_offset": 0.8,
			"shirt_color": Color(0.92, 0.72, 0.3), "pants_color": Color(0.3, 0.32, 0.38),
			"skin_tone": "tan", "hair_color": Color(0.42, 0.3, 0.16),
			"waypoints": PackedVector3Array([Vector3(-0.9, 0, -10.5), Vector3(-0.9, 0, 1.0)]),
		},
		{
			"name": "Jogger", "model_key": "female_tanktop", "activity": 1,
			"position": Vector3(-19, 0, 10), "phase_offset": 0.2,
			"shirt_color": Color(0.12, 0.2, 0.36), "pants_color": Color(0.16, 0.16, 0.2),
			"skin_tone": "deep", "hair_color": Color(0.06, 0.05, 0.05),
			"waypoints": PackedVector3Array([
				Vector3(-19.5, 0, 13), Vector3(-19.5, 0, -7), Vector3(-12, 0, -11.4),
				Vector3(11, 0, -11.4), Vector3(17.5, 0, -5), Vector3(17.5, 0, 12),
				Vector3(8, 0, 16.5), Vector3(-12, 0, 16.5),
			]),
		},
		{
			"name": "BenchSitter", "model_key": "male_shirt", "activity": 2,
			"position": Vector3(-4.5, 0.38, 7.5), "rotation": 180.0, "phase_offset": 0.5,
			"shirt_color": Color(0.36, 0.3, 0.42), "pants_color": Color(0.5, 0.42, 0.32),
			"skin_tone": "light", "hair_color": Color(0.2, 0.14, 0.1),
		},
		{
			"name": "PhoneChecker", "model_key": "female_alternative", "activity": 4,
			"position": Vector3(-6.3, 0, 6.1), "rotation": 130.0, "phase_offset": 0.9,
			"shirt_color": Color(0.85, 0.8, 0.72), "pants_color": Color(0.14, 0.14, 0.16),
			"skin_tone": "tan", "hair_color": Color(0.55, 0.4, 0.2),
		},
		{
			"name": "ClubRep", "model_key": "female_dress", "activity": 3,
			"position": Vector3(8.6, 0, 1.4), "rotation": -45.0, "phase_offset": 0.3,
			"shirt_color": Color(0.92, 0.72, 0.3), "pants_color": Color(0.12, 0.2, 0.36),
			"skin_tone": "brown", "hair_color": Color(0.08, 0.07, 0.07),
		},
	]
	for spec: Dictionary in student_specs:
		var student: Node3D = _instance("res://scenes/world3d/student.tscn")
		student.name = spec["name"]
		student.position = spec["position"]
		if spec.has("rotation"):
			student.rotation_degrees.y = spec["rotation"]
		for key: String in [
			"model_key", "activity", "phase_offset", "shirt_color", "pants_color",
			"skin_tone", "hair_color", "waypoints",
		]:
			if spec.has(key):
				student.set(key, spec[key])
		students.add_child(student)


func _add_camera() -> void:
	var rig: Node3D = Node3D.new()
	rig.name = "CameraRig"
	rig.position = Vector3(0, 0, 8.6)  # matches spawn + look-ahead
	_root.add_child(rig)
	var arm: Node3D = Node3D.new()
	arm.name = "Arm"
	arm.rotation_degrees = Vector3(-38, 20, 0)
	rig.add_child(arm)
	var camera: Camera3D = Camera3D.new()
	camera.name = "Camera"
	camera.position = Vector3(0, 0, 20.5)
	camera.fov = 33.0
	arm.add_child(camera)


func _add_audio() -> void:
	var ambient: AudioStreamPlayer = AudioStreamPlayer.new()
	ambient.name = "Ambient"
	var stream: AudioStream = load("res://assets/audio/ambient_campus.ogg")
	stream.loop = true
	ambient.stream = stream
	ambient.volume_db = -10.0
	_root.add_child(ambient)

	var ui_sound: AudioStreamPlayer = AudioStreamPlayer.new()
	ui_sound.name = "UISound"
	ui_sound.volume_db = -6.0
	_root.add_child(ui_sound)


func _add_ui() -> void:
	var ui: CanvasLayer = CanvasLayer.new()
	ui.name = "UI"
	_root.add_child(ui)

	var hud: PanelContainer = PanelContainer.new()
	hud.name = "HUD"
	hud.set_script(load("res://scripts/ui/hud3d.gd"))
	ui.add_child(hud)

	var joystick: Control = Control.new()
	joystick.name = "Joystick"
	joystick.set_script(load("res://scripts/ui/virtual_joystick.gd"))
	joystick.anchor_left = 0.0
	joystick.anchor_top = 1.0
	joystick.anchor_right = 0.0
	joystick.anchor_bottom = 1.0
	joystick.offset_left = 36
	joystick.offset_top = -200
	joystick.offset_right = 196
	joystick.offset_bottom = -40
	joystick.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui.add_child(joystick)

	var talk: Button = Button.new()
	talk.name = "InteractButton"
	talk.text = "TALK"
	talk.anchor_left = 1.0
	talk.anchor_top = 1.0
	talk.anchor_right = 1.0
	talk.anchor_bottom = 1.0
	talk.offset_left = -148
	talk.offset_top = -148
	talk.offset_right = -44
	talk.offset_bottom = -44
	talk.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	talk.grow_vertical = Control.GROW_DIRECTION_BEGIN
	talk.focus_mode = Control.FOCUS_NONE
	talk.add_theme_font_size_override("font_size", 22)
	var talk_style: StyleBoxFlat = StyleBoxFlat.new()
	talk_style.bg_color = Color(NAVY.r, NAVY.g, NAVY.b, 0.88)
	talk_style.set_corner_radius_all(52)
	talk_style.border_color = Color(GOLD, 0.85)
	talk_style.set_border_width_all(3)
	talk.add_theme_stylebox_override("normal", talk_style)
	var talk_hover: StyleBoxFlat = talk_style.duplicate()
	talk_hover.bg_color = Color(0.18, 0.28, 0.46, 0.92)
	talk.add_theme_stylebox_override("hover", talk_hover)
	talk.add_theme_stylebox_override("pressed", talk_hover)
	talk.add_theme_color_override("font_color", GOLD)
	talk.add_theme_color_override("font_hover_color", GOLD)
	talk.add_theme_color_override("font_pressed_color", GOLD)
	ui.add_child(talk)

	var dialogue: PanelContainer = PanelContainer.new()
	dialogue.name = "Dialogue"
	dialogue.set_script(load("res://scripts/ui/dialogue3d.gd"))
	ui.add_child(dialogue)


# =============================================================================
# Helpers
# =============================================================================

func _instance(path: String) -> Node:
	var node: Node = (load(path) as PackedScene).instantiate()
	return node


func _box(size: Vector3, color: Color, roughness: float) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	mesh.material = material
	mesh_instance.mesh = mesh
	return mesh_instance


func _banner_quad(texture_path: String, size: Vector2) -> MeshInstance3D:
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


func _box_body(at: Vector3, size: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = at
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.name = "Shape"
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	collider.shape = box
	body.add_child(collider)
	return body


func _cylinder_body(radius: float) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = Vector3(0, 1.5, 0)
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.name = "Shape"
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = 3.0
	collider.shape = cylinder
	body.add_child(collider)
	return body
