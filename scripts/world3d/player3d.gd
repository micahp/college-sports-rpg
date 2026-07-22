extends CharacterBody3D
## The controllable student. Movement has acceleration and braking so it
## feels weighty; the model turns toward travel direction and blends between
## idle and walk, with footstep audio on a stride cadence. Appearance is
## data: model + surface colors + a backpack, all set in the scene.

@export var model_key: String = "male_casual"
@export var shirt_color: Color = Color(0.92, 0.72, 0.3)
@export var pants_color: Color = Color(0.16, 0.22, 0.38)
@export var skin_tone: String = "brown"
@export var hair_color: Color = Color(0.1, 0.08, 0.07)
@export var wears_backpack: bool = true

const WALK_SPEED: float = 3.4
const ACCELERATION: float = 14.0
const BRAKING: float = 18.0
const TURN_SPEED: float = 11.0
const STRIDE_SECONDS: float = 0.42

var control_locked: bool = false
var external_input: Vector2 = Vector2.ZERO

var _model: Node3D
var _anim: AnimationPlayer
var _prefix: String
var _current_anim: String = ""
var _stride_clock: float = 0.0
var _steps: AudioStreamPlayer3D
var _step_sounds: Array[AudioStream] = []


func _ready() -> void:
	add_to_group("player")
	_prefix = CharacterAppearance.anim_prefix(model_key)
	_model = CharacterAppearance.build(model_key, {
		"Shirt": shirt_color,
		"Pants": pants_color,
		"Skin": CharacterAppearance.SKIN_TONES[skin_tone],
		"Hair": hair_color,
		"Socks": Color(0.9, 0.88, 0.85),
	})
	add_child(_model)
	add_child(CharacterAppearance.blob_shadow())
	_anim = _model.get_node("AnimationPlayer")
	for anim_name in _anim.get_animation_list():
		_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_play("Idle")

	if wears_backpack:
		_attach_backpack()

	var collider: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	collider.shape = capsule
	collider.position = Vector3(0, 0.85, 0)
	add_child(collider)

	_steps = AudioStreamPlayer3D.new()
	_steps.max_distance = 12.0
	_steps.volume_db = -8.0
	add_child(_steps)
	for i in range(1, 5):
		_step_sounds.append(load("res://assets/audio/footstep_%d.ogg" % i))


func _attach_backpack() -> void:
	var backpack: Node3D = (load("res://assets/props/Backpack.glb") as PackedScene).instantiate()
	# Attached to the model root, not the spine bone: the torso barely bends
	# during idle/walk, and root attachment keeps the transform predictable.
	# Recolored to campus navy so it reads as gear, not a random brown bag.
	backpack.scale = Vector3(0.45, 0.45, 0.45)
	backpack.position = Vector3(0, 1.35, -0.16)
	_model.add_child(backpack)
	var mesh: MeshInstance3D = CharacterAppearance.find_mesh(backpack)
	if mesh != null:
		for i in mesh.mesh.get_surface_count():
			var base: Material = mesh.mesh.surface_get_material(i)
			if base is StandardMaterial3D:
				var override: StandardMaterial3D = (base as StandardMaterial3D).duplicate()
				match base.resource_name:
					"DarkBrown":
						override.albedo_color = Color(0.13, 0.18, 0.3)
					"Brown":
						override.albedo_color = Color(0.19, 0.26, 0.42)
					"Gold":
						override.albedo_color = Color(0.92, 0.72, 0.3)
				mesh.set_surface_override_material(i, override)


func input_vector() -> Vector2:
	if control_locked:
		return Vector2.ZERO
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input == Vector2.ZERO and external_input.length() > 0.15:
		input = external_input.limit_length(1.0)
	return input


func _physics_process(delta: float) -> void:
	var input: Vector2 = input_vector()
	var wish: Vector3 = Vector3(input.x, 0, input.y) * WALK_SPEED
	var rate: float = ACCELERATION if wish.length() > 0.01 else BRAKING
	velocity.x = move_toward(velocity.x, wish.x, rate * delta)
	velocity.z = move_toward(velocity.z, wish.z, rate * delta)
	velocity.y = velocity.y - 9.8 * delta if not is_on_floor() else 0.0
	move_and_slide()

	var planar: Vector3 = Vector3(velocity.x, 0, velocity.z)
	if planar.length() > 0.3:
		var target_yaw: float = atan2(planar.x, planar.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, TURN_SPEED * delta)
		_play("Walk")
		_stride_clock -= delta * planar.length() / WALK_SPEED
		if _stride_clock <= 0.0:
			_stride_clock = STRIDE_SECONDS
			_steps.stream = _step_sounds[randi() % _step_sounds.size()]
			_steps.pitch_scale = randf_range(0.92, 1.08)
			_steps.play()
	else:
		_play("Idle")
		_stride_clock = 0.12  # first step lands quickly when moving again


func face_toward(point: Vector3) -> void:
	var to_point: Vector3 = point - global_position
	_model.rotation.y = atan2(to_point.x, to_point.z)


func _play(anim_name: String) -> void:
	var full: String = "HumanArmature|%s_%s" % [_prefix, anim_name]
	if _current_anim == full:
		return
	_current_anim = full
	_anim.play(full, 0.25)
