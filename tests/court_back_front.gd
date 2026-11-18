extends Node3D
## Dribbler cutting right then left: which hand has the ball, frame by frame.
##   godot tests/court_switch_view.tscn -- shots <dir>
const Actor = preload("res://scripts/court/court_actor.gd")
var _a: Node3D
var _cam: Camera3D
var _ball: MeshInstance3D
var _t: float = 0.0
var _out: String = ""
var _n: int = 0
var _acc: float = 0.0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[args.find("shots") + 1]
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
	var pl: PlaneMesh = PlaneMesh.new()
	pl.size = Vector2(60, 60)
	fm.mesh = pl
	add_child(fm)
	_a = Actor.new()
	add_child(_a)
	_a.setup("", {"Shirt": Color(0.92, 0.72, 0.3), "Pants": Color(0.12, 0.2, 0.42), "Skin": Color(0.48, 0.34, 0.24), "Socks": Color.WHITE}, 0, 0.15)
	_ball = MeshInstance3D.new()
	_ball.visible = false
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	_ball.mesh = sm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.35, 0.05)
	_ball.material_override = m
	add_child(_ball)
	_cam = Camera3D.new()
	_cam.fov = 40
	add_child(_cam)


func _physics_process(delta: float) -> void:
	_t += delta
	var v: Vector3 = Vector3.ZERO
	if _t > 1.0:
		v = Vector3(0, 0, 2.0)  # backpedal: facing -Z
	if _t > 3.5:
		get_tree().quit(0)
	_a.pose_reset()
	_a.team = 1
	_a.lock_face(_a.position + Vector3(0, 0, -8.0))
	_a.move_with(v, delta, 16.0)
	_a.animate(delta)


func _process(delta: float) -> void:
	_cam.position = _a.position + Vector3(0.3, 1.4, -4.0) 
	_cam.look_at(_a.position + Vector3(0, 0.9, 0))
	if _t > 1.6:
		_acc += delta
		if _acc >= 0.1:
			_acc = 0.0
			get_viewport().get_texture().get_image().save_png("%s/f_%03d.png" % [_out, _n])
			_n += 1
