extends Node
## Milestone 1 + 2 acceptance test, run headless with real physics and input:
##   godot --headless tests/campus_autoplay.tscn
## M1: visible player, keyboard + joystick movement, collision, camera scene.
## M2: three spatial NPCs, interaction range, dialogue choices, immediate stat
## changes, one-time conversations, and TALK button visibility rules.

var _failures: int = 0
var _campus: Node2D
var _player: CharacterBody2D
var _dialogue: PanelContainer
var _talk_button: Button


func _ready() -> void:
	await _run()
	if _failures == 0:
		print("\nALL CAMPUS CHECKS PASSED")
	else:
		printerr("\n%d CAMPUS CHECK(S) FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	GameState.reset()
	TimeSystem.reset()
	_campus = load("res://scenes/world/campus.tscn").instantiate()
	add_child(_campus)
	await _frames(5)

	_player = _campus.get_node("Actors/Player")
	_dialogue = _campus.get_node("UI/Dialogue")
	_talk_button = _campus.get_node("UI/InteractButton")

	await _test_movement_and_collision()
	await _test_npc_presence()
	await _test_conversation("Jordan", "jordan")
	await _test_conversation("Leader", "leader")
	await _test_conversation("Coach", "coach")
	await _test_repeat_visit("Jordan", "jordan")
	_test_prompt_helpers()
	_test_hud_reflects_stats()


# --- M1 regression -----------------------------------------------------------

func _test_movement_and_collision() -> void:
	print("Movement and collision")
	_check(_player != null and _player.visible, "player exists and is visible")

	for pair: Array in [["move_right", Vector2.RIGHT], ["move_left", Vector2.LEFT], ["move_down", Vector2.DOWN], ["move_up", Vector2.UP]]:
		var before: Vector2 = _player.global_position
		Input.action_press(pair[0])
		await _frames(20)
		Input.action_release(pair[0])
		_check((_player.global_position - before).dot(pair[1]) > 40.0, "keyboard %s moves the player" % pair[0])
	await _frames(5)

	var joystick: Control = _campus.get_node("UI/Joystick")
	joystick.output = Vector2(1, 0)
	var before_joy: Vector2 = _player.global_position
	await _frames(20)
	joystick.output = Vector2.ZERO
	_check(_player.global_position.x - before_joy.x > 40.0, "joystick input moves the player")
	await _frames(5)

	var tree: Vector2 = _campus.TREES[0]
	_player.global_position = tree + Vector2(70, 0)
	Input.action_press("move_left")
	await _frames(50)
	Input.action_release("move_left")
	_check(_player.global_position.x > tree.x + 14.0, "tree trunk blocks the player")

	_player.global_position = Vector2(120, 700)
	Input.action_press("move_left")
	await _frames(60)
	Input.action_release("move_left")
	_check(_player.global_position.x > _campus.HEDGE - 1.0, "boundary hedge contains the player")


# --- M2: NPCs and conversations ------------------------------------------------

func _test_npc_presence() -> void:
	print("NPC presence")
	for spawn: Dictionary in _campus.NPC_SPAWNS:
		var npc: Node = _campus.get_node_or_null("Actors/" + str(spawn["node"]))
		_check(npc != null and npc.visible, "%s is in the world" % spawn["node"])
	_player.global_position = Vector2(700, 660)
	await _frames(5)
	_check(not _talk_button.visible, "TALK button is hidden with nobody in range")


func _test_conversation(node_name: String, npc_id: String) -> void:
	print("Conversation: %s" % node_name)
	var npc: Node = _campus.get_node("Actors/" + node_name)
	var data: Dictionary = ContentDB.get_npc_dialogues()[npc_id]

	_player.global_position = npc.global_position + Vector2(0, 60)
	await _frames(5)
	_check(_campus.current_npc == npc, "approaching registers %s as interactable" % node_name)
	_check(npc.player_in_range, "%s shows the talk prompt" % node_name)
	_check(_talk_button.visible, "TALK button appears in range")

	_talk_button.pressed.emit()
	await _frames(2)
	_check(_dialogue.visible, "TALK opens dialogue")
	_check(_dialogue._name_label.text == data["name"], "dialogue shows the NPC name")
	_check(_player.control_locked, "player is locked while talking")
	_check(not _talk_button.visible, "TALK button hides during dialogue")
	_check(not _campus.get_node("UI/Joystick").visible, "joystick hides during dialogue")

	for i in (data["lines"] as Array).size():
		await _press_interact()
	_check(_dialogue.state == _dialogue.State.CHOICES, "choices appear after the last line")
	var buttons: Array = _dialogue._choices_box.get_children()
	_check(buttons.size() == (data["choices"] as Array).size(), "all %d choices are shown" % (data["choices"] as Array).size())

	var choice: Dictionary = data["choices"][0]
	var expected: Dictionary = {}
	for stat: String in choice["effects"].keys():
		expected[stat] = clampi(GameState.get_stat(stat) + int(choice["effects"][stat]), 0, 100)
	(buttons[0] as Button).pressed.emit()
	await _frames(2)
	var stats_match: bool = true
	for stat: String in expected.keys():
		if GameState.get_stat(stat) != expected[stat]:
			stats_match = false
			printerr("        %s expected %d got %d" % [stat, expected[stat], GameState.get_stat(stat)])
	_check(stats_match, "picking '%s' applies its exact stat effects" % choice["id"])
	_check(_dialogue.state == _dialogue.State.REACTION, "reaction text is showing")
	_check(GameState.has_made_choice("npc_" + npc_id), "the choice is recorded")

	await _press_interact()
	_check(not _dialogue.visible, "reaction closes the dialogue")
	_check(not _player.control_locked, "control returns after talking")

	_player.global_position = npc.global_position + Vector2(0, 400)
	await _frames(5)


func _test_repeat_visit(node_name: String, npc_id: String) -> void:
	print("Repeat visit: %s" % node_name)
	var npc: Node = _campus.get_node("Actors/" + node_name)
	var stats_before: Dictionary = GameState.stats.duplicate()

	_player.global_position = npc.global_position + Vector2(0, 60)
	await _frames(5)
	await _press_interact()
	_check(_dialogue.visible, "second visit opens dialogue")
	await _press_interact()
	_check(not _dialogue.visible, "repeat line closes without choices")
	_check(str(GameState.stats) == str(stats_before), "repeat visit changes no stats")
	_player.global_position = npc.global_position + Vector2(0, 400)
	await _frames(5)


func _test_prompt_helpers() -> void:
	print("Touch-aware prompts")
	var npc_script: GDScript = load("res://scripts/world/npc.gd")
	var panel_script: GDScript = load("res://scripts/ui/dialogue_panel.gd")
	_check(not npc_script.prompt_text(true).contains("[E]"), "touch prompt has no keyboard hint")
	_check(npc_script.prompt_text(false).contains("[E]"), "keyboard prompt names the key")
	_check(not panel_script.hint_text(true).contains("E /"), "touch dialogue hint has no keyboard hint")


func _test_hud_reflects_stats() -> void:
	await _frames(2)
	var hud: PanelContainer = _campus.get_node("UI/HUD")
	var expected: String = "Coach %d" % GameState.get_stat("coach_interest")
	_check((hud._label.text as String).contains(expected), "HUD shows the updated coach interest")


# --- Helpers -----------------------------------------------------------------

func _press_interact() -> void:
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok    %s" % label)
	else:
		_failures += 1
		printerr("  FAIL  %s" % label)
