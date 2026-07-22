extends Node3D
## Behavior for the campus courtyard scene. The environment itself — ground,
## buildings, props, greenery, actors, UI — is authored in campus3d.tscn
## (see tools/build_campus_scene.gd for the scaffold that generated it).
## This script only runs the scene: camera follow with look-ahead, the
## conversation camera move, interaction wiring, and audio.

## Gameplay camera: fixed three-quarter view, no rotation. The rig leads the
## player north so the frame favors where they're going, not the ground.
const CAM_LOOK_AHEAD: Vector3 = Vector3(0, 0, -3.4)
const CAM_PITCH: float = -38.0
const CAM_YAW: float = 20.0
const CAM_DISTANCE: float = 20.5
## Conversation camera: the same axis, eased closer. Aim sits at chest
## height so the frame centers on the two speakers' upper bodies — the
## bottom-anchored dialogue card then sits under empty pavement, not faces.
const TALK_DISTANCE: float = 10.5
const TALK_PITCH: float = -33.0
const TALK_HEIGHT: float = 1.5

@onready var player: CharacterBody3D = $Actors/Player
@onready var jordan: Node3D = $Actors/Jordan
@onready var _rig: Node3D = $CameraRig
@onready var _arm: Node3D = $CameraRig/Arm
@onready var _camera: Camera3D = $CameraRig/Arm/Camera
@onready var _joystick: Control = $UI/Joystick
@onready var _interact_button: Button = $UI/InteractButton
@onready var _dialogue: PanelContainer = $UI/Dialogue
@onready var _ambient: AudioStreamPlayer = $Ambient
@onready var _ui_sound: AudioStreamPlayer = $UISound

var current_npc: Node = null

var _cam_tween: Tween


func _ready() -> void:
	jordan.range_changed.connect(_on_npc_range_changed)
	_dialogue.closed.connect(_on_dialogue_closed)
	_interact_button.pressed.connect(_do_interact)
	_rig.global_position = player.global_position + CAM_LOOK_AHEAD
	_camera.position.z = CAM_DISTANCE
	_camera.make_current()
	_ambient.play()


func _process(delta: float) -> void:
	player.external_input = _joystick.output
	var talking: bool = _dialogue.visible
	_joystick.visible = not talking
	_interact_button.visible = current_npc != null and not talking
	if not talking:
		var target: Vector3 = player.global_position + CAM_LOOK_AHEAD
		_rig.global_position = _rig.global_position.lerp(target, minf(1.0, 7.0 * delta))
	if Input.is_action_just_pressed("interact"):
		_do_interact()


func _do_interact() -> void:
	if _dialogue.visible:
		_dialogue.close()
	elif current_npc != null:
		player.control_locked = true
		current_npc.face_toward(player.global_position)
		player.face_toward(current_npc.global_position)
		current_npc.set_indicator_hidden(true)
		_play_ui("res://assets/audio/ui_open.ogg")
		_dialogue.open(
			current_npc.npc_name,
			"First day too? I'm trying to figure out whether this place is a campus or a whole city."
		)
		_move_camera_to_conversation()


func _on_dialogue_closed() -> void:
	player.control_locked = false
	if current_npc != null:
		current_npc.set_indicator_hidden(false)
	_play_ui("res://assets/audio/ui_close.ogg")
	_move_camera(
		player.global_position + CAM_LOOK_AHEAD,
		Vector3(CAM_PITCH, CAM_YAW, 0), CAM_DISTANCE
	)


## Eases into a profile two-shot: the camera swings perpendicular to the
## line between the speakers so both are seen side-on, facing each other,
## and picks whichever perpendicular is the shorter swing from gameplay yaw.
func _move_camera_to_conversation() -> void:
	var between: Vector3 = current_npc.global_position - player.global_position
	# Perpendicular to the speakers' line in the XZ plane (stored x, z).
	var perp: Vector2 = Vector2(between.z, -between.x)
	var yaw_a: float = rad_to_deg(atan2(perp.x, perp.y))
	var yaw_b: float = rad_to_deg(atan2(-perp.x, -perp.y))
	var chosen: float = yaw_a
	if absf(angle_difference(deg_to_rad(CAM_YAW), deg_to_rad(yaw_b))) \
			< absf(angle_difference(deg_to_rad(CAM_YAW), deg_to_rad(yaw_a))):
		chosen = yaw_b
	var midpoint: Vector3 = (player.global_position + current_npc.global_position) / 2.0
	_move_camera(
		midpoint + Vector3(0, TALK_HEIGHT, 0), Vector3(TALK_PITCH, chosen, 0), TALK_DISTANCE
	)


func _move_camera(target: Vector3, arm_rotation: Vector3, distance: float) -> void:
	if _cam_tween != null:
		_cam_tween.kill()
	_cam_tween = create_tween().set_parallel()
	_cam_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(_rig, "global_position", target, 0.7)
	_cam_tween.tween_property(_arm, "rotation_degrees", arm_rotation, 0.7)
	_cam_tween.tween_property(_camera, "position:z", distance, 0.7)


func _play_ui(path: String) -> void:
	_ui_sound.stream = load(path)
	_ui_sound.play()


func _on_npc_range_changed(npc: Node, in_range: bool) -> void:
	if in_range:
		current_npc = npc
		_play_ui("res://assets/audio/ui_confirm.ogg")
	elif current_npc == npc:
		current_npc = null
