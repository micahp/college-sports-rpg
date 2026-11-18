extends Node3D
## Where is the lowest point of the drawn body, per movement? Skins every mesh
## vertex on the CPU from the final bone pose and reports its height above the
## floor (y = 0). Negative = the shoe is through the floor.
##   godot tests/court_sole_probe.tscn -- shots <dir>

const Actor = preload("res://scripts/court/court_actor.gd")
const PLAN: Array = [
	["idle", "loco", Vector2(0, 0), 1.2],
	["walk", "loco", Vector2(0, -1.6), 2.0],
	["jog", "loco", Vector2(0, -3.4), 2.0],
	["sprint", "loco", Vector2(0, -5.0), 2.0],
	["dribble", "dribble", Vector2(0, -3.0), 2.0],
	["defense", "defense", Vector2(0, 0), 1.2],
	["slide", "defense", Vector2(2.5, 0), 2.0],
	["backpedal", "defense", Vector2(0, 2.0), 2.0],
]

var _actor: Node3D
var _sk: Skeleton3D
var _cam: Camera3D
var _step: int = 0
var _left: float = 0.0
var _min: float = INF
var _max_low: float = -INF
var _out: String = ""
var _shot_n: int = 0
var _meshes: Array = []
var _under_n: int = 0
var _lowbone: String = ""
var _lowpos: Vector3 = Vector3.ZERO


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[args.find("shots") + 1] if args.find("shots") >= 0 else ""
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
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
	var fm: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(400, 400)
	fm.mesh = plane
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.74, 0.55, 0.33)
	fm.material_override = m
	add_child(fm)
	_actor = Actor.new()
	add_child(_actor)
	_actor.setup("", {"Shirt": Color(0.92, 0.72, 0.3), "Pants": Color(0.12, 0.2, 0.42),
		"Skin": Color(0.48, 0.34, 0.24), "Socks": Color(0.95, 0.95, 0.95)}, 0, 0.15)
	_sk = _actor.get("_skeleton")
	_collect(_actor)
	var tap: SkeletonModifier3D = SkeletonModifier3D.new()
	var ts: GDScript = GDScript.new()
	ts.source_code = "extends SkeletonModifier3D
var qa: Node
func _process_modification_with_delta(_d: float) -> void:
	qa.tapped()
"
	ts.reload()
	tap.set_script(ts)
	tap.set("qa", self)
	_sk.add_child(tap)
	print("meshes skinned to skeleton: ", _meshes.size())
	_sk.reset_bone_poses()
	_sk.force_update_all_bone_transforms()
	var cnt: Dictionary = {}
	for mi: MeshInstance3D in _meshes:
		var skin: Skin = mi.skin
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var arr: Array = mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var per: int = bones.size() / verts.size()
			for v in verts.size():
				var bind: Transform3D = Transform3D.IDENTITY
				var p: Vector3 = Vector3.ZERO
				for k in per:
					var w: float = wts[v * per + k]
					if w > 0.0:
						var bi: int = bones[v * per + k]
						var bb: int = skin.get_bind_bone(bi)
						if bb < 0:
							bb = _sk.find_bone(skin.get_bind_name(bi))
						p += (_sk.get_bone_global_pose(bb) * skin.get_bind_pose(bi) * verts[v]) * w
				if p.y < 0.12:
					var bi2: int = bones[v * per]
					var nm: String = skin.get_bind_name(bi2)
					if nm == "":
						nm = _sk.get_bone_name(skin.get_bind_bone(bi2))
					var key: String = "%s (w0=%.2f)" % [nm, wts[v * per]]
					cnt[nm] = int(cnt.get(nm, 0)) + 1
	print("verts below 12cm at rest, by dominant bone: ", cnt)
	_cam = Camera3D.new()
	_cam.fov = 35.0
	add_child(_cam)
	_left = PLAN[0][3]


func _collect(n: Node) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).skin != null and (n as MeshInstance3D).mesh != null:
		_meshes.append(n)
	for c in n.get_children():
		_collect(c)


## Lowest world y over every skinned vertex.
var _final_low: float = 0.0


func tapped() -> void:
	_final_low = _lowest()


func _lowest() -> float:
	var low: float = INF
	for mi: MeshInstance3D in _meshes:
		var skin: Skin = mi.skin
		var mats: Array[Transform3D] = []
		for i in skin.get_bind_count():
			var b: int = skin.get_bind_bone(i)
			if b < 0:
				b = _sk.find_bone(skin.get_bind_name(i))
			mats.append(_sk.global_transform * _sk.get_bone_global_pose(b) * skin.get_bind_pose(i) if b >= 0 else Transform3D.IDENTITY)
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var arr: Array = mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			if bones.is_empty():
				continue
			var per: int = bones.size() / verts.size()
			for v in verts.size():
				var p: Vector3 = Vector3.ZERO
				var tw: float = 0.0
				for k in per:
					var w: float = wts[v * per + k]
					if w > 0.0:
						p += (mats[bones[v * per + k]] * verts[v]) * w
						tw += w
				if tw > 0.0:
					if p.y / tw < low:
						low = p.y / tw
						_lowpos = p / tw
						var bi: int = 0
						var bw: float = -1.0
						for k in per:
							if wts[v * per + k] > bw:
								bw = wts[v * per + k]
								bi = bones[v * per + k]
						_lowbone = skin.get_bind_name(bi) if skin.get_bind_name(bi) != "" else _sk.get_bone_name(skin.get_bind_bone(bi))
	return low


func _physics_process(delta: float) -> void:
	if _step >= PLAN.size():
		return
	var p: Array = PLAN[_step]
	var mode: String = p[1]
	var v: Vector2 = p[2]
	_actor.pose_reset()
	_actor.team = 1 if mode == "defense" else 0
	_actor.has_ball = mode == "dribble"
	if mode == "defense":
		_actor.lock_face(_actor.position + Vector3(0, 0, -8.0))
	_actor.move_with(Vector3(v.x, 0, v.y), delta, 16.0)
	_actor.animate(delta)
	_left -= delta


func _process(_delta: float) -> void:
	if _step >= PLAN.size():
		return
	_cam.position = _actor.position + Vector3(2.2, 0.35, 1.6)
	_cam.look_at(_actor.position + Vector3(0, 0.2, 0))
	if _left < PLAN[_step][3] - 0.5:  # skip the cross-fade
		var low: float = _final_low
		if low < -0.01:
			print("   [%s @ %s] under: %s t=%.2f low=%+.3f L toe y=%.3f R toe y=%.3f" % [_lowbone, _lowpos - _actor.position, PLAN[_step][0], PLAN[_step][3]-_left, low, (_sk.global_transform*_sk.get_bone_global_pose(_sk.find_bone("Foot.L")).origin).y, (_sk.global_transform*_sk.get_bone_global_pose(_sk.find_bone("Foot.R")).origin).y])
		if _out != "" and low < -0.035 and _under_n < 6:
			get_viewport().get_texture().get_image().save_png("%s/under_%s_%d.png" % [_out, PLAN[_step][0], _under_n])
			_under_n += 1
		_min = minf(_min, low)
		_max_low = maxf(_max_low, low)
		if _out != "" and _shot_n % 3 == 0 and _shot_n < 24 and get_viewport() != null:
			get_viewport().get_texture().get_image().save_png("%s/%s_%02d.png" % [_out, PLAN[_step][0], _shot_n / 3])
		_shot_n += 1
	if _left <= 0.0:
		print("%-8s lowest vertex: min %+.3f m  (highest 'lowest' %+.3f m)" % [PLAN[_step][0], _min, _max_low])
		_step += 1
		_under_n = 0
		_min = INF
		_max_low = -INF
		_shot_n = 0
		if _step >= PLAN.size():
			get_tree().quit(0)
			return
		_left = PLAN[_step][3]
