extends Node
## Milestone 1 checkpoint test, run headless with real physics and input:
##   godot --headless tests/campus_autoplay.tscn
## Covers the eight checkpoint items: visible player in the courtyard,
## keyboard movement, touch-joystick movement, collision against a tree and
## the world boundary, NPC interaction prompt, dialogue open/advance/close,
## and regaining control afterwards. Exits 0 on success.

var _failures: int = 0
var _campus: Node2D
var _player: CharacterBody2D


func _ready() -> void:
	await _run()
	if _failures == 0:
		print("\nMILESTONE 1 CHECKPOINT PASSED")
	else:
		printerr("\n%d CHECKPOINT ITEM(S) FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	_campus = load("res://scenes/world/campus.tscn").instantiate()
	add_child(_campus)
	await _frames(5)

	# 1. A player is standing in the courtyard.
	_player = _campus.get_node("Actors/Player")
	_check(_player != null and _player.visible, "player exists and is visible")
	_check(_campus.get_node_or_null("UI/HUD") != null, "HUD exists")
	_check(_campus.get_node_or_null("UI/Joystick") != null, "virtual joystick exists")
	_check(_campus.get_node_or_null("UI/InteractButton") != null, "interact button exists")

	# 2. Keyboard movement in all four directions.
	for pair: Array in [["move_right", Vector2.RIGHT], ["move_left", Vector2.LEFT], ["move_down", Vector2.DOWN], ["move_up", Vector2.UP]]:
		var before: Vector2 = _player.global_position
		Input.action_press(pair[0])
		await _frames(20)
		Input.action_release(pair[0])
		var moved: Vector2 = _player.global_position - before
		_check(moved.dot(pair[1]) > 40.0, "keyboard %s moves the player" % pair[0])
	await _frames(5)

	# 3. Joystick movement.
	var joystick: Control = _campus.get_node("UI/Joystick")
	joystick.output = Vector2(1, 0)
	var before_joy: Vector2 = _player.global_position
	await _frames(20)
	joystick.output = Vector2.ZERO
	_check(_player.global_position.x - before_joy.x > 40.0, "joystick input moves the player")
	await _frames(5)

	# 4. Collision: walk into a tree trunk and stop.
	var tree: Vector2 = _campus.TREES[0]
	_player.global_position = tree + Vector2(70, 0)
	Input.action_press("move_left")
	await _frames(50)
	Input.action_release("move_left")
	_check(_player.global_position.x > tree.x + 14.0, "tree trunk blocks the player")
	var stalled_at: Vector2 = _player.global_position
	Input.action_press("move_left")
	await _frames(20)
	Input.action_release("move_left")
	_check(_player.global_position.distance_to(stalled_at) < 2.0, "player stays blocked while pushing into the tree")

	# 5. Collision: world boundary hedge.
	_player.global_position = Vector2(120, 700)
	Input.action_press("move_left")
	await _frames(60)
	Input.action_release("move_left")
	_check(_player.global_position.x > _campus.HEDGE - 1.0, "boundary hedge contains the player")

	# 6. NPC prompt appears in range and hides out of range.
	var jordan: Node = _campus.get_node("Actors/Jordan")
	_player.global_position = jordan.global_position + Vector2(0, 60)
	await _frames(5)
	_check(_campus.current_npc == jordan, "approaching Jordan registers him as interactable")
	_check(jordan.player_in_range, "Jordan's talk prompt is showing")
	_player.global_position = jordan.global_position + Vector2(0, 400)
	await _frames(5)
	_check(_campus.current_npc == null, "walking away clears the interaction target")
	_player.global_position = jordan.global_position + Vector2(0, 60)
	await _frames(5)

	# 7. Interact opens dialogue; movement is locked during it.
	var dialogue: PanelContainer = _campus.get_node("UI/Dialogue")
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	await _frames(2)
	_check(dialogue.visible, "interact opens the dialogue panel")
	_check(_player.control_locked, "player is locked while talking")
	var frozen: Vector2 = _player.global_position
	Input.action_press("move_right")
	await _frames(15)
	Input.action_release("move_right")
	_check(_player.global_position.distance_to(frozen) < 1.0, "movement input is ignored during dialogue")

	# 8. Advancing through every line closes dialogue and restores control.
	for i in 8:
		if not dialogue.visible:
			break
		Input.action_press("interact")
		await _frames(2)
		Input.action_release("interact")
		await _frames(2)
	_check(not dialogue.visible, "dialogue closes after the last line")
	_check(not _player.control_locked, "control returns after dialogue")
	var before_free: Vector2 = _player.global_position
	Input.action_press("move_down")
	await _frames(15)
	Input.action_release("move_down")
	_check(_player.global_position.y - before_free.y > 30.0, "player can walk again after talking")


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok    %s" % label)
	else:
		_failures += 1
		printerr("  FAIL  %s" % label)
