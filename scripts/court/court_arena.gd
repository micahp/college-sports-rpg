extends RefCounted
## Builds the game arena: lighting, a regulation full court with both
## baskets and painted lines, and stands with a crowd (one MultiMesh).
## Pure geometry; the court game owns all behavior.

const HALF_W: float = 7.5
const BASELINE: float = 14.0
const HOOP_Y: float = 3.05
const HOOP_Z: float = -12.425  # the basket we attack; the other is at +12.425
const ARC_R: float = 6.75
const CORNER_X: float = 6.6
const KEY_HW: float = 2.45
const FT_Z: float = -8.2

var _root: Node3D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func build(root: Node3D) -> void:
	_root = root
	_rng.seed = 7
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.035, 0.045, 0.08)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.75, 0.8)
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	root.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, 25, 0)
	sun.light_energy = 1.05
	root.add_child(sun)

	var wood: Color = Color(0.78, 0.56, 0.32)
	var line: Color = Color(0.97, 0.96, 0.93)
	var paint: Color = Color(0.13, 0.22, 0.42)
	_box(Vector3(0, -0.06, 0), Vector3(HALF_W * 2 + 4, 0.1, BASELINE * 2 + 4), Color(0.1, 0.13, 0.22))
	_box(Vector3(0, -0.04, 0), Vector3(HALF_W * 2, 0.1, BASELINE * 2), wood, 0.4)
	for s: float in [-1.0, 1.0]:
		var hz: float = HOOP_Z if s < 0 else -HOOP_Z
		var base_z: float = -BASELINE if s < 0 else BASELINE
		var ft_z: float = FT_Z if s < 0 else -FT_Z
		var dir: float = 1.0 if s < 0 else -1.0  # toward midcourt
		_box(Vector3(0, 0.012, (base_z + ft_z) / 2.0), Vector3(KEY_HW * 2, 0.01, absf(ft_z - base_z)), paint, 0.5)
		_line(Vector3(-KEY_HW, 0, base_z), Vector3(-KEY_HW, 0, ft_z), line)
		_line(Vector3(KEY_HW, 0, base_z), Vector3(KEY_HW, 0, ft_z), line)
		_line(Vector3(-KEY_HW, 0, ft_z), Vector3(KEY_HW, 0, ft_z), line)
		_arc(Vector3(0, 0, ft_z), 1.8, -PI / 2.0, PI / 2.0, dir, line)
		var corner_len: float = sqrt(ARC_R * ARC_R - CORNER_X * CORNER_X)
		_line(Vector3(-CORNER_X, 0, base_z), Vector3(-CORNER_X, 0, hz + corner_len * dir), line)
		_line(Vector3(CORNER_X, 0, base_z), Vector3(CORNER_X, 0, hz + corner_len * dir), line)
		var t0: float = asin(CORNER_X / ARC_R)
		_arc(Vector3(0, 0, hz), ARC_R, -t0, t0, dir, line)
		_arc(Vector3(0, 0, hz), 1.25, -PI / 2.0, PI / 2.0, dir, line)
		_hoop(hz, dir)
	_line(Vector3(-HALF_W, 0, -BASELINE), Vector3(HALF_W, 0, -BASELINE), line)
	_line(Vector3(-HALF_W, 0, BASELINE), Vector3(HALF_W, 0, BASELINE), line)
	_line(Vector3(-HALF_W, 0, -BASELINE), Vector3(-HALF_W, 0, BASELINE), line)
	_line(Vector3(HALF_W, 0, -BASELINE), Vector3(HALF_W, 0, BASELINE), line)
	_line(Vector3(-HALF_W, 0, 0), Vector3(HALF_W, 0, 0), line)
	_arc(Vector3(0, 0, 0), 1.8, -PI, PI, 1.0, line)
	_stands()


func _hoop(hz: float, dir: float) -> void:
	var board_z: float = hz - 0.375 * dir
	_box(Vector3(0, 3.4, board_z), Vector3(1.8, 1.05, 0.05), Color(0.95, 0.96, 0.98), 0.3)
	_box(Vector3(0, 3.25, board_z + 0.03 * dir), Vector3(0.59, 0.45, 0.02), Color(0.9, 0.35, 0.15))
	_box(Vector3(0, 3.25, board_z + 0.035 * dir), Vector3(0.5, 0.36, 0.02), Color(0.95, 0.96, 0.98))
	_box(Vector3(0, 1.75, board_z - 1.1 * dir), Vector3(0.22, 3.5, 0.22), Color(0.12, 0.14, 0.2))
	_box(Vector3(0, 3.2, board_z - 0.55 * dir), Vector3(0.12, 0.12, 1.1), Color(0.12, 0.14, 0.2))
	_box(Vector3(0, 0.5, board_z - 1.3 * dir), Vector3(1.2, 1.0, 1.2), Color(0.12, 0.2, 0.36))
	var rim: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.215
	torus.outer_radius = 0.24
	rim.mesh = torus
	rim.material_override = mat(Color(0.95, 0.4, 0.12))
	rim.position = Vector3(0, HOOP_Y, hz)
	_root.add_child(rim)
	var net: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.22
	cyl.bottom_radius = 0.14
	cyl.height = 0.42
	net.mesh = cyl
	var nm: StandardMaterial3D = mat(Color(1, 1, 1, 0.55))
	nm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	nm.cull_mode = BaseMaterial3D.CULL_DISABLED
	net.material_override = nm
	net.position = Vector3(0, HOOP_Y - 0.22, hz)
	_root.add_child(net)


func _stands() -> void:
	var seat: Color = Color(0.16, 0.18, 0.26)
	var rows: int = 7
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var palette: Array[Color] = [Color(0.12, 0.2, 0.42), Color(0.92, 0.72, 0.3), Color(0.92, 0.92, 0.9),
		Color(0.3, 0.32, 0.36), Color(0.12, 0.2, 0.42), Color(0.92, 0.72, 0.3), Color(0.6, 0.16, 0.18)]
	for side: float in [-1.0, 1.0]:
		for r in rows:
			var x: float = side * (HALF_W + 2.6 + r * 0.85)
			var y: float = 0.3 + r * 0.5
			_box(Vector3(x, y / 2.0, 0), Vector3(0.85, y, BASELINE * 2 - 2), seat.lightened(r * 0.02))
			var z: float = -BASELINE + 1.6
			while z < BASELINE - 1.6:
				if _rng.randf() < 0.85:
					xforms.append(Transform3D(Basis(), Vector3(x + _rng.randf_range(-0.12, 0.12), y + 0.42, z)))
					colors.append(palette[_rng.randi() % palette.size()])
				z += 0.62
	for r in rows:
		var zb: float = -(BASELINE + 2.6 + r * 0.85)
		var yb: float = 0.3 + r * 0.5
		_box(Vector3(0, yb / 2.0, zb), Vector3(HALF_W * 2 + 2, yb, 0.85), seat.lightened(r * 0.02))
		var xb: float = -HALF_W
		while xb < HALF_W:
			if _rng.randf() < 0.85:
				xforms.append(Transform3D(Basis(), Vector3(xb, yb + 0.42, zb + _rng.randf_range(-0.12, 0.12))))
				colors.append(palette[_rng.randi() % palette.size()])
			xb += 0.62
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = 0.2
	cap.height = 0.85
	var cm: StandardMaterial3D = StandardMaterial3D.new()
	cm.vertex_color_use_as_albedo = true
	cm.roughness = 0.9
	cap.material = cm
	mm.mesh = cap
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	var crowd: MultiMeshInstance3D = MultiMeshInstance3D.new()
	crowd.multimesh = mm
	crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(crowd)


static func mat(c: Color, roughness: float = 0.8) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = roughness
	return m


func _box(center: Vector3, size: Vector3, c: Color, roughness: float = 0.8) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var b: BoxMesh = BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat(c, roughness)
	mi.position = center
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(mi)
	return mi


func _line(a: Vector3, b: Vector3, c: Color, width: float = 0.06) -> void:
	var d: Vector3 = b - a
	var length: float = Vector2(d.x, d.z).length()
	if length < 0.01:
		return
	var mi: MeshInstance3D = _box((a + b) / 2.0 + Vector3(0, 0.02, 0), Vector3(length, 0.008, width), c, 0.5)
	mi.rotation.y = -atan2(d.z, d.x)


func _arc(center: Vector3, radius: float, from_angle: float, to_angle: float, dir: float, c: Color) -> void:
	var segments: int = maxi(8, int(absf(to_angle - from_angle) * radius * 3.0))
	var prev: Vector3 = center + Vector3(sin(from_angle) * radius, 0, cos(from_angle) * radius * dir)
	for i in range(1, segments + 1):
		var t: float = lerpf(from_angle, to_angle, float(i) / segments)
		var p: Vector3 = center + Vector3(sin(t) * radius, 0, cos(t) * radius * dir)
		_line(prev, p, c)
		prev = p
