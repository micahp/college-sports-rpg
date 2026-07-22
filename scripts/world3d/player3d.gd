extends CharacterBody3D
## The controllable student in the 3D campus. Movement has acceleration and
## braking so it feels weighty; the model turns toward travel direction and
## blends between idle and walk. Camera is owned by the campus rig, not here.

const CharacterModel: PackedScene = preload("res://assets/characters/Male_Casual.fbx")

const WALK_SPEED: float = 3.4
const ACCELERATION: float = 14.0
const BRAKING: float = 18.0
const TURN_SPEED: float = 11.0
## The FBX model's authored forward direction relative to Godot's -Z.
const MODEL_YAW_OFFSET: float = 0.0

var control_locked: bool = false
var external_input: Vector2 = Vector2.ZERO

var _model: Node3D
var _anim: AnimationPlayer
var _current_anim: String = ""


func _ready() -> void:
	add_to_group("player")

	_model = CharacterModel.instantiate()
	_model.name = "Model"
	add_child(_model)
	_anim = _model.get_node("AnimationPlayer")
	for anim_name in _anim.get_animation_list():
		_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_play("HumanArmature|Man_Idle")

	var collider: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	collider.shape = capsule
	collider.position = Vector3(0, 0.85, 0)
	add_child(collider)


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
		var target_yaw: float = atan2(planar.x, planar.z) + MODEL_YAW_OFFSET
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, TURN_SPEED * delta)
		_play("HumanArmature|Man_Walk")
	else:
		_play("HumanArmature|Man_Idle")


func face_toward(point: Vector3) -> void:
	var to_point: Vector3 = point - global_position
	_model.rotation.y = atan2(to_point.x, to_point.z) + MODEL_YAW_OFFSET


func _play(anim_name: String) -> void:
	if _current_anim == anim_name:
		return
	_current_anim = anim_name
	_anim.play(anim_name, 0.25)
