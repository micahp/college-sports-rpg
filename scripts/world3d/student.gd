extends Node3D
## A lightweight background student. No physics, no dialogue — just a
## recolored shared rig doing one legible campus activity: walking a
## waypoint loop, jogging it, sitting, or standing around (optionally
## looking at a phone). They exist to make the courtyard feel occupied.

enum Activity { WALK, JOG, SIT, STAND, PHONE }

@export var model_key: String = "male_casual"
@export var activity: Activity = Activity.WALK
@export var waypoints: PackedVector3Array = []
@export var walk_speed: float = 1.9
@export var jog_speed: float = 4.2
@export var shirt_color: Color = Color(0.5, 0.5, 0.55)
@export var pants_color: Color = Color(0.25, 0.25, 0.28)
@export var skin_tone: String = "tan"
@export var hair_color: Color = Color(0.15, 0.12, 0.1)
## Desync so identical activities don't animate in lockstep.
@export var phase_offset: float = 0.0

const TURN_SPEED: float = 7.0

var _model: Node3D
var _anim: AnimationPlayer
var _prefix: String
var _target_index: int = 0


func _ready() -> void:
	_prefix = CharacterAppearance.anim_prefix(model_key)
	_model = CharacterAppearance.build(model_key, {
		"Shirt": shirt_color,
		"Pants": pants_color,
		"Skin": CharacterAppearance.SKIN_TONES[skin_tone],
		"Hair": hair_color,
	})
	add_child(_model)
	if activity != Activity.SIT:
		add_child(CharacterAppearance.blob_shadow(0.38))
	_anim = _model.get_node("AnimationPlayer")
	for anim_name in _anim.get_animation_list():
		_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	match activity:
		Activity.WALK:
			_start("Walk")
		Activity.JOG:
			_start("Run")
		Activity.SIT:
			_start("Sitting")
		Activity.STAND, Activity.PHONE:
			_start("Idle")


func _start(anim_name: String) -> void:
	_anim.play("HumanArmature|%s_%s" % [_prefix, anim_name])
	_anim.seek(phase_offset, true)


var _phone_posed: bool = false


## Freezes the idle mid-frame and poses head + forearm into a
## looking-at-phone stance. Paused animation keeps manual bone poses.
func _pose_for_phone() -> void:
	_anim.pause()
	var skeleton: Skeleton3D = CharacterAppearance.find_skeleton(_model)
	if skeleton == null:
		return
	var head: int = skeleton.find_bone("Head")
	if head >= 0:
		skeleton.set_bone_pose_rotation(
			head, skeleton.get_bone_pose_rotation(head) * Quaternion(Vector3.RIGHT, 0.55)
		)
	var forearm: int = skeleton.find_bone("LowerArm.R")
	if forearm >= 0:
		skeleton.set_bone_pose_rotation(
			forearm, skeleton.get_bone_pose_rotation(forearm) * Quaternion(Vector3.RIGHT, -1.5)
		)


func _process(delta: float) -> void:
	if activity == Activity.PHONE and not _phone_posed and _anim.current_animation_position > 0.2:
		_phone_posed = true
		_pose_for_phone()
	if waypoints.size() < 2 or (activity != Activity.WALK and activity != Activity.JOG):
		return
	var speed: float = jog_speed if activity == Activity.JOG else walk_speed
	var target: Vector3 = waypoints[_target_index]
	var to_target: Vector3 = target - global_position
	to_target.y = 0
	if to_target.length() < 0.25:
		_target_index = (_target_index + 1) % waypoints.size()
		return
	var step: Vector3 = to_target.normalized() * speed * delta
	global_position += step
	var target_yaw: float = atan2(to_target.x, to_target.z)
	_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, TURN_SPEED * delta)
