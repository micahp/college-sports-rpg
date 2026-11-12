extends Node
## Fast smoke test (~20-30 s). Starts a new game, completes the first
## activity of Day 1, and checks the core loop is alive: title → character
## creation → campus → one activity → time advances → HUD up, no script
## errors. Use it after every change; run the full week_autoplay before a
## release.
##
##   godot --headless tests/smoke.tscn

var _failures: int = 0
var _checks: int = 0
var is_runner: bool = false


func _ready() -> void:
	# The scene node gets freed by the first scene change; run from a copy
	# parked on the root.
	if not is_runner:
		var runner: Node = Node.new()
		runner.set_script(get_script())
		runner.set("is_runner", true)
		runner.name = "SmokeRunner"
		get_tree().root.add_child.call_deferred(runner)
		return
	Engine.time_scale = 4.0
	SaveSystem.clear_save()
	await _run()
	print("\n%d checks, %d failures" % [_checks, _failures])
	print("SMOKE PASSED" if _failures == 0 else "SMOKE FAILED")
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	# Title and character creation.
	get_tree().change_scene_to_file(Game.SCENES["title"])
	await _frames(5)
	var title: Node = get_tree().current_scene
	_check(title.find_child("NewGame", true, false) != null, "title screen has New Game")
	title.find_child("NewGame", true, false).pressed.emit()
	title.find_child("Look_look_a", true, false).pressed.emit()
	title.find_child("Identity_natural", true, false).pressed.emit()
	(title.find_child("NameEdit", true, false) as LineEdit).text = "Smoke"
	title.find_child("Start", true, false).pressed.emit()
	await _wait_scene_settled()

	# Campus loads with HUD and player.
	var loc: Node = get_tree().current_scene
	_check(loc.has_method("beacon_target"), "campus scene loads")
	_check(loc.player != null, "player exists on campus")
	_check(loc.ui != null, "game UI exists on campus")

	# Complete the first activity: walk to the next beacon and press interact.
	var start_period: int = TimeSystem.period
	var start_choices: int = GameState.choice_history.size()
	var done: bool = false
	for _i in 300:
		await _wait_scene_settled()
		loc = get_tree().current_scene
		if loc == null or not loc.has_method("beacon_target"):
			await _frames(2)
			continue
		if loc.ui.recap_open():
			loc.ui.find_child("RecapContinue", true, false).pressed.emit()
			await _frames(2)
			continue
		if loc.ui.card.is_open():
			var buttons: Array = loc.ui.card.choice_buttons()
			if buttons.is_empty():
				loc.ui.card.advance()
			else:
				loc.ui.card.pick(_first_enabled(buttons))
			await _frames(2)
			continue
		if loc.busy or loc.ui.is_modal_open():
			await _frames(3)
			continue
		var target: Node3D = loc.beacon_target()
		if target == null:
			await _frames(2)
			continue
		await _go_and_interact(loc, target.global_position)
		if TimeSystem.period != start_period or GameState.choice_history.size() > start_choices:
			done = true
			break

	done = done or TimeSystem.period != start_period or GameState.choice_history.size() > start_choices
	_check(done, "completed one activity (period %s → %s)" % [start_period, TimeSystem.period])
	_check(GameState.choice_history.size() > start_choices, "activity recorded a choice")
	_check(TimeSystem.day == 1, "still on Day 1 after one activity")

	# Save exists after a meaningful action.
	_check(SaveSystem.has_save(), "autosave written after an activity")


func _first_enabled(buttons: Array) -> int:
	for i in buttons.size():
		if not buttons[i].disabled:
			return i
	return 0


func _go_and_interact(loc: Node, point: Vector3) -> void:
	var player: CharacterBody3D = loc.player
	player.global_position = Vector3(point.x, player.global_position.y, point.z) + Vector3(0.0, 0.0, 1.0)
	player.velocity = Vector3.ZERO
	await _frames(3)
	Input.action_press("interact")
	await _frames(1)
	Input.action_release("interact")
	await _frames(3)


func _wait_scene_settled() -> void:
	await _frames(1)
	var guard: int = 0
	while Game.is_changing_scene() and guard < 600:
		guard += 1
		await _frames(1)
	await _frames(2)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if ok:
		print("  ok    ", label)
	else:
		_failures += 1
		print("  FAIL  ", label)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
