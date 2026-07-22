extends Node
## Milestone 1.6 acceptance test, run headless with real physics and input:
##   godot --headless tests/campus3d_autoplay.tscn
## Covers: player exists and moves in all four directions (keyboard + joystick),
## collides with trees and boundaries, Jordan's prompt/TALK behavior, dialogue
## open/close with movement lock, and control resuming afterwards.

var _failures: int = 0
var _campus: Node3D
var _player: CharacterBody3D


func _ready() -> void:
	await _run()
	if _failures == 0:
		print("\nALL 3D CAMPUS CHECKS PASSED")
	else:
		printerr("\n%d 3D CHECK(S) FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	_campus = load("res://scenes/world3d/campus3d.tscn").instantiate()
	add_child(_campus)
	await _frames(10)

	_player = _campus.player
	_check(_player != null, "player exists")
	_check(_campus.get_node_or_null("UI/HUD") != null, "HUD exists")
	_check(_campus.get_node_or_null("UI/Joystick") != null, "joystick exists")

	# Keyboard movement, all four directions.
	for pair: Array in [
		["move_right", Vector3.RIGHT], ["move_left", Vector3.LEFT],
		["move_down", Vector3.BACK], ["move_up", Vector3.FORWARD],
	]:
		var before: Vector3 = _player.global_position
		Input.action_press(pair[0])
		await _frames(40)
		Input.action_release(pair[0])
		await _frames(5)
		var moved: Vector3 = _player.global_position - before
		_check(moved.dot(pair[1]) > 1.0, "keyboard %s moves the player" % pair[0])

	# Joystick movement.
	var joystick: Control = _campus.get_node("UI/Joystick")
	joystick.output = Vector2(1, 0)
	var before_joy: Vector3 = _player.global_position
	await _frames(40)
	joystick.output = Vector2.ZERO
	_check(_player.global_position.x - before_joy.x > 1.0, "joystick moves the player")
	await _frames(5)

	# Collision: tree trunk (tree at (-10.5, 0, -8), approach from the east).
	_player.global_position = Vector3(-8, 0.1, -8)
	Input.action_press("move_left")
	await _frames(80)
	Input.action_release("move_left")
	_check(_player.global_position.x > -10.0, "tree trunk blocks the player")

	# Collision: world boundary (west wall sits at x = -24).
	_player.global_position = Vector3(-22, 0.1, 5)
	Input.action_press("move_left")
	await _frames(80)
	Input.action_release("move_left")
	_check(_player.global_position.x > -24.6, "boundary wall contains the player")

	# Jordan: prompt, TALK, dialogue, movement lock, resume.
	var jordan: Node3D = _campus.jordan
	var dialogue: PanelContainer = _campus.get_node("UI/Dialogue")
	var talk_button: Button = _campus.get_node("UI/InteractButton")

	_player.global_position = Vector3(0, 0.1, 12)
	await _frames(5)
	_check(not talk_button.visible, "TALK hidden when out of range")

	_player.global_position = jordan.global_position + Vector3(-1.5, 0.1, 1.2)
	await _frames(5)
	_check(_campus.current_npc == jordan, "approaching Jordan registers him")
	_check(jordan.player_in_range and jordan._indicator.visible, "speech indicator is showing")
	_check(talk_button.visible, "TALK appears in range")

	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	await _frames(2)
	_check(dialogue.visible, "interact opens dialogue")
	_check(_player.control_locked, "movement locked during dialogue")
	_check(not talk_button.visible, "TALK hides during dialogue")
	var frozen: Vector3 = _player.global_position
	Input.action_press("move_right")
	await _frames(25)
	Input.action_release("move_right")
	_check(_player.global_position.distance_to(frozen) < 0.1, "movement input ignored during dialogue")

	(dialogue.find_child("Continue", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(not dialogue.visible, "Continue closes dialogue")
	_check(not _player.control_locked, "control returns after dialogue")
	var before_free: Vector3 = _player.global_position
	Input.action_press("move_down")
	await _frames(30)
	Input.action_release("move_down")
	_check(_player.global_position.z - before_free.z > 0.8, "player walks again after talking")


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok    %s" % label)
	else:
		_failures += 1
		printerr("  FAIL  %s" % label)
