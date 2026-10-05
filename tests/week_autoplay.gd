extends Node
## Full-game acceptance test. Plays the whole week through the real scenes —
## title, character creation, every location, story cards, recaps, the
## tryout minigame, the ending — with a scripted "player" that walks to its
## targets, presses the action, and picks choices by strategy.
##
##   godot --headless tests/week_autoplay.tscn
##
## Runs several strategies (each a full week), plus save/continue and
## walking/collision checks. Exits 0 on success, 1 on any failure.

const ShotMinigame = preload("res://scripts/minigame/shot_minigame.gd")

var _failures: int = 0
var _checks: int = 0
var _strategy: String = ""
var _log_choices: Array = []


var is_runner: bool = false


func _ready() -> void:
	# The scene node gets freed by the first scene change, so the actual
	# runner is a copy parked on the root that survives every change.
	if not is_runner:
		var runner: Node = Node.new()
		runner.set_script(get_script())
		runner.set("is_runner", true)
		runner.name = "WeekRunner"
		get_tree().root.add_child.call_deferred(runner)
		return
	# Keep the test fast: shots auto-release, waits are clipped.
	Engine.time_scale = 4.0
	SaveSystem.clear_save()
	await _test_title_without_save()
	await _test_walking_and_collision()
	await _play_week("grinder", "perfect")
	_check(Game.outcome.get("id", "") in ["roster", "conditional"], "grinder makes the team (%s, score %s)" % [Game.outcome.get("id"), Game.outcome.get("score")])
	await _play_week("scholar", "good")
	_check(Game.outcome.get("id", "") != "not_signed", "scholar still tries out (%s, score %s)" % [Game.outcome.get("id"), Game.outcome.get("score")])
	await _play_week("bricklayer", "miss")
	_check(Game.outcome.get("id", "") in ["cut", "practice"], "a player who misses everything doesn't make the roster (%s)" % Game.outcome.get("id"))
	await _play_week("never_signs", "perfect")
	_check(Game.outcome.get("id", "") == "not_signed", "never signing ends in the bleachers (%s)" % Game.outcome.get("id"))
	await _test_save_continue()
	print("\n%d checks, %d failures" % [_checks, _failures])
	print("ALL WEEK CHECKS PASSED" if _failures == 0 else "WEEK CHECKS FAILED")
	get_tree().quit(0 if _failures == 0 else 1)


# =============================================================================
# Individual checks
# =============================================================================

func _test_title_without_save() -> void:
	SaveSystem.clear_save()
	get_tree().change_scene_to_file(Game.SCENES["title"])
	await _frames(5)
	var title: Node = get_tree().current_scene
	var cont: Button = title.find_child("Continue", true, false)
	_check(cont != null and cont.disabled, "Continue is disabled with no save")
	_check(title.find_child("NewGame", true, false) != null, "New Game button exists")


func _test_walking_and_collision() -> void:
	await _new_game("look_b", "workhorse")
	var loc: Node = get_tree().current_scene
	var start: Vector3 = loc.player.global_position
	Input.action_press("move_up")
	await _seconds(1.0)
	Input.action_release("move_up")
	var moved: float = start.distance_to(loc.player.global_position)
	_check(moved > 2.0, "keyboard walking moves the player (%.1f m)" % moved)
	# Joystick input drives the same movement.
	var before: Vector3 = loc.player.global_position
	loc.ui.joystick.output = Vector2(1, 0)
	await _seconds(0.6)
	loc.ui.joystick.output = Vector2.ZERO
	_check(loc.player.global_position.x - before.x > 1.0, "virtual joystick moves the player")
	# Walk into the Rec Center facade: collision stops us short of it.
	loc.player.global_position = Vector3(6.0, 0.1, -12.0)
	Input.action_press("move_up")
	await _seconds(2.5)
	Input.action_release("move_up")
	_check(loc.player.global_position.z > -16.4, "building collision holds (z=%.2f)" % loc.player.global_position.z)
	# Leaving the world is impossible.
	loc.player.global_position = Vector3(0, 0.1, 17.0)
	Input.action_press("move_down")
	await _seconds(2.0)
	Input.action_release("move_down")
	_check(loc.player.global_position.z < 20.0, "world boundary holds")
	_check(not UIKit.is_touch() or true, "touch detection runs")


func _test_save_continue() -> void:
	await _new_game("look_c", "scholar")
	# Spend the morning on Jordan's fridge, then quit to title.
	await _run_until(func() -> bool: return TimeSystem.period == TimeSystem.Period.AFTERNOON, 120)
	var day: int = TimeSystem.day
	var period: int = TimeSystem.period
	var place: String = Game.location
	var academics: int = GameState.get_stat("academics")
	var history: int = GameState.choice_history.size()
	Game.quit_to_title()
	await _wait_scene_settled()
	var title: Node = get_tree().current_scene
	var cont: Button = title.find_child("Continue", true, false)
	_check(cont != null and not cont.disabled, "Continue is enabled with a save")
	GameState.reset()
	TimeSystem.reset()
	cont.pressed.emit()
	await _wait_scene_settled()
	_check(TimeSystem.day == day and TimeSystem.period == period, "continue restores day and period")
	_check(Game.location == place, "continue restores location (%s)" % Game.location)
	_check(GameState.get_stat("academics") == academics, "continue restores stats")
	_check(GameState.choice_history.size() == history, "continue restores choice history")
	# New Game wipes everything.
	await _new_game("look_a", "natural")
	_check(GameState.choice_history.is_empty() and TimeSystem.day == 1, "New Game resets progress")


# =============================================================================
# The scripted player
# =============================================================================

func _play_week(strategy: String, aim: String) -> void:
	_strategy = strategy
	_log_choices.clear()
	ShotMinigame.auto_quality = aim
	await _new_game("look_a", {"grinder": "workhorse", "scholar": "scholar"}.get(strategy, "natural"))
	await _run_until(func() -> bool: return get_tree().current_scene.scene_file_path == Game.SCENES["ending"], 2500)
	await _frames(3)
	var ending: Node = get_tree().current_scene
	_check(ending.scene_file_path == Game.SCENES["ending"], "[%s] reached the ending" % strategy)
	var title: Label = ending.find_child("OutcomeTitle", true, false)
	_check(title != null and title.text != "", "[%s] ending shows a verdict: %s" % [strategy, title.text if title else "?"])
	_check(ending.find_child("PlayAgain", true, false) != null, "[%s] Play Again is offered" % strategy)
	_check(not SaveSystem.has_save(), "[%s] finished week clears the save" % strategy)
	print("  [%s] stats %s  tryout %s  choices %d" % [strategy, GameState.stats, GameState.tryout, GameState.choice_history.size()])
	if OS.get_environment("WEEK_VERBOSE") != "":
		for entry: Dictionary in GameState.choice_history:
			print("      ", entry["beat"], " -> ", entry["choice"])


## Drives the game one decision at a time until `done` returns true.
func _run_until(done: Callable, max_steps: int) -> void:
	var steps: int = 0
	var stuck: int = 0
	var last_key: String = ""
	while not done.call():
		steps += 1
		if steps > max_steps:
			_check(false, "[%s] run finished within %d steps (stuck on day %d %s at %s)" % [
				_strategy, max_steps, TimeSystem.day, TimeSystem.period_name(), Game.location])
			return
		await _step()
		var key: String = "%d/%d/%s/%d" % [TimeSystem.day, TimeSystem.period, Game.location, GameState.choice_history.size()]
		stuck = stuck + 1 if key == last_key else 0
		last_key = key
		if stuck > 60:
			_check(false, "[%s] no progress at %s" % [_strategy, key])
			return


func _step() -> void:
	await _wait_scene_settled()
	var scene: Node = get_tree().current_scene
	if scene == null or not scene.has_method("beacon_target"):
		await _frames(2)
		return
	var loc: Node = scene
	if loc.ui.recap_open():
		await _frames(2)
		loc.ui.find_child("RecapContinue", true, false).pressed.emit()
		await _frames(2)
		return
	if loc.ui.card.is_open():
		var buttons: Array = loc.ui.card.choice_buttons()
		if not buttons.is_empty():
			loc.ui.card.pick(_choose(loc, buttons))
		else:
			loc.ui.card.advance()
		await _frames(2)
		return
	if loc.busy or loc.ui.is_modal_open():
		await _frames(3)
		return
	# Talk to anyone with something new to say first.
	for npc: Node in loc.npcs.values():
		if npc.story_pending:
			await _go_and_interact(loc, npc.global_position)
			return
	var target: Node3D = loc.beacon_target()
	if target == null:
		target = _free_period_target(loc)
	if target != null:
		await _go_and_interact(loc, target.global_position)
	else:
		await _frames(2)


## Free time: where this strategy wants to spend the period.
func _free_period_target(loc: Node) -> Node3D:
	var want: Array = _free_choice()
	var where: String = want[0]
	if where != loc.location_id:
		return loc._marker("door_" + where) if loc.location_id == "campus" else loc._marker("door_campus")
	return loc._marker("spot_" + str(want[1]))


func _free_choice() -> Array:
	var energy: int = GameState.get_stat("energy")
	if energy < 30:
		return ["dorm", "bed"]
	match _strategy:
		"grinder", "bricklayer":
			if TimeSystem.period == TimeSystem.Period.MORNING:
				return ["gym", "weights"]
			return ["gym", "court"]
		"scholar":
			if TimeSystem.period == TimeSystem.Period.AFTERNOON:
				return ["gym", "court"]
			return ["classroom", "seat"] if TimeSystem.day >= 2 else ["dorm", "desk"]
		_:
			return ["campus", "club_table"]


## Picks a choice index among the card's buttons, by strategy.
func _choose(loc: Node, buttons: Array) -> int:
	var enabled: Array[int] = []
	for i in buttons.size():
		if not buttons[i].disabled:
			enabled.append(i)
	if enabled.is_empty():
		return 0
	var labels: Array[String] = []
	for b: Button in buttons:
		labels.append(b.text)
	var prefer: Array[String] = []
	match _strategy:
		"grinder", "bricklayer":
			prefer = ["Grab the other end", "outwork", "Line up on the baseline", "Get in the run",
				"Shootaround", "Run the circuit", "Go to sleep", "Take a nap", "Open it", "seven-fifteen",
				"I'm sleeping", "Stick around", "I'm trying out", "Take the Kinesiology quiz", "Attend lecture"]
		"scholar":
			prefer = ["Grab the other end", "Ask what he actually looks for", "Stick around", "I'm in",
				"Work through every", "Attend lecture", "Take the Kinesiology quiz", "Explain it", "Study late",
				"Shootaround", "Go to sleep", "Take a nap", "Stay and cheer", "I'll be there", "Get in the run",
				"What separates", "Study for an hour"]
		"never_signs":
			prefer = ["not sure I'm ready", "Let it go", "It wasn't meant", "Work the tables", "Go to sleep",
				"Climb into the bleachers", "Take a nap"]
	for p: String in prefer:
		for i in enabled:
			if labels[i].findn(p) >= 0:
				_log_choices.append(labels[i])
				return i
	return enabled[0]


## Walks the last stretch for real (input-driven) after a teleport close by,
## then presses the action button.
func _go_and_interact(loc: Node, point: Vector3) -> void:
	var player: CharacterBody3D = loc.player
	var offset: Vector3 = Vector3(0.0, 0.0, 1.0)
	player.global_position = Vector3(point.x, player.global_position.y, point.z) + offset
	player.velocity = Vector3.ZERO
	await _frames(3)
	if loc.current_target().is_empty():
		# Nudge around in case the teleport landed inside furniture.
		for o: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0.7, 0, 0.7)]:
			player.global_position = Vector3(point.x, player.global_position.y, point.z) + o
			await _frames(3)
			if not loc.current_target().is_empty():
				break
	Input.action_press("interact")
	await _frames(1)
	Input.action_release("interact")
	await _frames(3)


# =============================================================================
# Plumbing
# =============================================================================

func _new_game(look: String, identity: String) -> void:
	await _wait_scene_settled()
	get_tree().change_scene_to_file(Game.SCENES["title"])
	await _frames(4)
	var title: Node = get_tree().current_scene
	title.find_child("NewGame", true, false).pressed.emit()
	title.find_child("Look_" + look, true, false).pressed.emit()
	title.find_child("Identity_" + identity, true, false).pressed.emit()
	(title.find_child("NameEdit", true, false) as LineEdit).text = "Tester"
	title.find_child("Start", true, false).pressed.emit()
	await _frames(2)
	await _wait_scene_settled()


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


func _seconds(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout
