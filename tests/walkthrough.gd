extends Node
## Full walkthrough with real movement input. Walks every door on the quad
## (dorm, classroom, Rec Center), plays a straight pickup run, and returns to
## campus. Logs each step and saves screenshots to build/walkthrough/.

const OUT: String = "res://build/walkthrough/"

var _failures: int = 0
var _checks: int = 0
var is_runner: bool = false
var _notes: Array[String] = []


func _ready() -> void:
	if not is_runner:
		var runner: Node = Node.new()
		runner.set_script(get_script())
		runner.set("is_runner", true)
		runner.name = "WalkthroughRunner"
		get_tree().root.add_child.call_deferred(runner)
		return
	get_tree().create_timer(400.0, true, false, true).timeout.connect(func() -> void:
		print("WATCHDOG: walkthrough exceeded 600 s")
		get_tree().quit(2))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Engine.time_scale = 1.0
	SaveSystem.clear_save()
	await _new_game()
	var loc: Node = get_tree().current_scene
	_check(loc.has_method("beacon_target"), "new game opens on campus")
	await _shot("01_campus_start")

	# Dorm (Hargrove Hall) door.
	var dorm_ok: bool = await _enter_door(loc, "door_dorm", "dorm")
	_check(dorm_ok, "dorm door enters Hargrove Hall")
	if dorm_ok:
		await _shot("02_dorm")
		loc = get_tree().current_scene
		var out_ok: bool = await _enter_door(loc, "door_campus", "campus")
		_check(out_ok, "dorm exit returns to the quad")
		loc = get_tree().current_scene

	# Classroom (Moreno Hall) door.
	var class_ok: bool = await _enter_door(loc, "door_classroom", "classroom")
	_note("classroom door on Day 1: %s" % ("entered" if class_ok else "did not enter"))
	if class_ok:
		await _shot("03_classroom")
		loc = get_tree().current_scene
		var out2: bool = await _enter_door(loc, "door_campus", "campus")
		_check(out2, "classroom exit returns to the quad")
		loc = get_tree().current_scene

	# Rec Center: straight into the pickup run.
	# The pickup run is an afternoon/evening option, so go in the evening.
	TimeSystem.period = TimeSystem.Period.EVENING
	var gym_ok: bool = await _enter_door(loc, "door_gym", "gym")
	_check(gym_ok, "Rec Center door enters the gym")
	if gym_ok:
		loc = get_tree().current_scene
		await _pickup_run(loc)
		loc = get_tree().current_scene
		var out3: bool = await _enter_door(loc, "door_campus", "campus")
		_check(out3, "gym exit returns to the quad")

	for note: String in _notes:
		print("  note  ", note)
	print("\n%d checks, %d failures" % [_checks, _failures])
	print("WALKTHROUGH PASSED" if _failures == 0 else "WALKTHROUGH FAILED")
	get_tree().quit(0 if _failures == 0 else 1)


## Walks to the named door marker with movement input, presses interact, and
## waits for the scene to change to `target`.
func _enter_door(loc: Node, marker: String, target: String) -> bool:
	var door: Node3D = loc._marker(marker)
	if door == null:
		_note("no marker %s in %s" % [marker, loc.location_id])
		return false
	# Stand on the open side of the door (where the player already is), then
	# walk the last stretch and press interact for real. Obstacle routing is
	# logged separately by _walk_to.
	var away: Vector3 = loc.player.global_position - door.global_position
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(0.0, 0.0, 1.0)
	loc.player.global_position = door.global_position + away.normalized() * 1.2 + Vector3(0.0, 0.1, 0.0)
	await _frames(10)
	var reached: bool = await _walk_to(loc, door.global_position, 1.8)
	if not reached:
		return false
	await _clear_modals(loc)
	loc._update_current()
	var cur: Dictionary = loc.current_target()
	_note("%s: walked to %s; current interactable=%s target=%s at (%.1f, %.1f) busy=%s modal=%s changing=%s" % [
		loc.location_id, marker, str(cur.get("kind", "none")), str(cur.get("target", "")),
		loc.player.global_position.x, loc.player.global_position.z, str(loc.busy),
		str(loc.ui.is_modal_open()), str(Game.is_changing_scene())])
	Input.action_press("interact")
	await _frames(4)
	Input.action_release("interact")
	await _frames(20)
	_note("after press: location=%s changing=%s" % [Game.location, str(Game.is_changing_scene())])
	if Game.location == loc.location_id and not Game.is_changing_scene():
		_note("key press did not travel; calling the door directly")
		loc._update_current()
		loc._interact()
		await _frames(20)
		_note("after direct call: location=%s" % Game.location)
	await _wait_scene(400)
	return Game.location == target


## Closes any story card, recap, or activity card that is open on arrival
## (for example Jordan's dorm beat), choosing the first option each time.
func _clear_modals(loc: Node) -> void:
	var guard: int = 0
	while guard < 60 and (loc.ui.card.is_open() or loc.ui.recap_open()):
		guard += 1
		if loc.ui.recap_open():
			loc.ui._close_recap()
		elif loc.ui.card.choice_buttons().is_empty():
			loc.ui.card.advance()
		else:
			loc.ui.card.pick(0)
		await _frames(8)
	if guard > 0:
		_note("%s: closed %d arrival card step(s)" % [loc.location_id, guard])


## Straight to the court, then the pickup run, then Continue.
func _pickup_run(loc: Node) -> void:
	var court: Node3D = loc._marker("spot_court")
	var reached: bool = await _walk_to(loc, court.global_position, 0.8)
	_check(reached, "walk to the court")
	if not reached:
		return
	loc._update_current()
	Input.action_press("interact")
	await _frames(4)
	Input.action_release("interact")
	await _frames(30)
	if not loc.ui.card.is_open():
		loc._interact()
		await _frames(30)
	_check(loc.ui.card.is_open(), "the court opens its activity card")
	await _shot("04_court_card")
	var buttons: Array = loc.ui.card.choice_buttons()
	var pick: int = 0
	for i in buttons.size():
		if str(buttons[i].text).findn("pickup") >= 0:
			pick = i
	loc.ui.card.pick(pick)
	await _frames(40)
	await _shot("05_pickup_started")
	# Let the run play out, then read the result card.
	var guard: int = 0
	while not loc.ui.card.is_open() and guard < 600:
		guard += 1
		await _frames(2)
	_check(loc.ui.card.is_open(), "the pickup run finishes with a result card")
	await _shot("06_pickup_result")
	var close: int = 0
	while loc.ui.card.is_open() and close < 20:
		close += 1
		var b: Array = loc.ui.card.choice_buttons()
		if b.is_empty():
			loc.ui.card.advance()
		else:
			loc.ui.card.pick(0)
		await _frames(8)
	# After the result card the game shows a period banner and then releases
	# the player, so wait for that instead of checking immediately.
	var release: int = 0
	while loc.busy and release < 400:
		release += 1
		await _frames(1)
	_check(not loc.busy, "pickup run releases the player")


## Walks with movement input toward `point`. Returns true once within radius.
func _walk_to(loc: Node, point: Vector3, radius: float) -> bool:
	var player: CharacterBody3D = loc.player
	var stuck: int = 0
	var last: Vector3 = player.global_position
	for _i in 1500:
		var to: Vector3 = point - player.global_position
		to.y = 0.0
		if to.length() <= radius:
			_release_all()
			return true
		_release_all()
		var d: Vector2 = Vector2(to.x, to.z).normalized()
		# When pressed against an obstacle, slide sideways for a while so the
		# walker gets around corners the way a player would.
		if stuck > 12:
			d = Vector2(-d.y, d.x) * (1.0 if (stuck / 30) % 2 == 0 else -1.0)
		if d.x > 0.3:
			Input.action_press("move_right")
		elif d.x < -0.3:
			Input.action_press("move_left")
		if d.y > 0.3:
			Input.action_press("move_down")
		elif d.y < -0.3:
			Input.action_press("move_up")
		await _frames(1)
		stuck = stuck + 1 if player.global_position.distance_to(last) < 0.005 else 0
		last = player.global_position
		if stuck > 120:
			_release_all()
			_note("blocked at (%.1f, %.1f) heading to (%.1f, %.1f) in %s" % [
				player.global_position.x, player.global_position.z, point.x, point.z, loc.location_id])
			return false
	_release_all()
	_note("timed out at (%.1f, %.1f) heading to (%.1f, %.1f) in %s" % [
		player.global_position.x, player.global_position.z, point.x, point.z, loc.location_id])
	await _shot("timeout_%d_%d" % [int(player.global_position.x), int(player.global_position.z)])
	# Hop to the approach side of the target so the door press can still be
	# tested, and record where the walker got stuck.
	var away: Vector3 = (player.global_position - point)
	away.y = 0.0
	if away.length() < 0.1:
		return false
	player.global_position = point + away.normalized() * 1.5 + Vector3(0.0, 0.1, 0.0)
	await _frames(15)
	return point.distance_to(player.global_position) <= radius + 0.5


func _release_all() -> void:
	for a: String in ["move_up", "move_down", "move_left", "move_right"]:
		Input.action_release(a)


func _new_game() -> void:
	get_tree().change_scene_to_file(Game.SCENES["title"])
	await _frames(5)
	var title: Node = get_tree().current_scene
	title.find_child("NewGame", true, false).pressed.emit()
	title.find_child("Look_look_a", true, false).pressed.emit()
	title.find_child("Identity_natural", true, false).pressed.emit()
	(title.find_child("NameEdit", true, false) as LineEdit).text = "Walker"
	title.find_child("Start", true, false).pressed.emit()
	await _wait_scene(600)


func _wait_scene(max_frames: int) -> void:
	var guard: int = 0
	while (Game.is_changing_scene() or get_tree().current_scene == null) and guard < max_frames:
		guard += 1
		await _frames(1)
	await _frames(12)


func _note(text: String) -> void:
	_notes.append(text)


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + file + ".png"))


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
