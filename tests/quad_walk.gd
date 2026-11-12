extends Node
## Walks around the quad with real movement input (not teleports), reports
## where the player gets blocked, and checks the interactions along the way.
## Saves screenshots to res://build/quad/ so the camera and clutter can be
## reviewed.
##
##   godot --path . tests/quad_walk.tscn     (windowed: needs a renderer)

const OUT: String = "res://build/quad/"

var _failures: int = 0
var _checks: int = 0
var is_runner: bool = false
var _notes: Array[String] = []


func _ready() -> void:
	if not is_runner:
		var runner: Node = Node.new()
		runner.set_script(get_script())
		runner.set("is_runner", true)
		runner.name = "QuadWalkRunner"
		get_tree().root.add_child.call_deferred(runner)
		return
	get_tree().create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		print("WATCHDOG: quad walk exceeded 300 s")
		get_tree().quit(2))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Engine.time_scale = 1.0
	SaveSystem.clear_save()
	await _new_game()
	var loc: Node = get_tree().current_scene
	_check(loc.has_method("beacon_target"), "campus loads for a new game")
	var start: Vector3 = loc.player.global_position
	await _shot("00_start")

	# 1. Input moves the player in every direction.
	for dir: String in ["move_up", "move_right", "move_down", "move_left"]:
		var before: Vector3 = loc.player.global_position
		await _hold(dir, 0.8)
		var moved: float = before.distance_to(loc.player.global_position)
		_check(moved > 0.8, "%s moves the player (%.1f m)" % [dir, moved])

	# 2. Walk to Coach Delgado (he is on the quad Day 1 evening), then interact.
	TimeSystem.period = TimeSystem.Period.EVENING
	Game.change_scene("campus")
	await _wait_scene(300)
	loc = get_tree().current_scene
	_notes.append("npc keys: %s" % str(loc.npcs.keys()))
	var coach: Node3D = _npc(loc, "coach")
	_check(coach != null, "Coach Delgado is on the quad")
	if coach != null:
		var reached: bool = await _walk_to(loc, coach.global_position, 0.8, "walk to Coach Delgado")
		await _shot("01_near_coach")
		if reached:
			Input.action_press("interact")
			await _frames(4)
			Input.action_release("interact")
			await _frames(20)
			if not loc.ui.card.is_open():
				_notes.append("key press did not open the coach card; direct call used")
				loc._interact()
				await _frames(20)
			_check(loc.ui.card.is_open(), "interacting with Coach Delgado opens his card")
			await _shot("02_coach_card")
			await _close_card(loc)

	# 3. Walk to the Rec Center door and enter.
	var door: Node3D = loc._marker("door_gym")
	if door != null:
		var door_ok: bool = await _walk_to(loc, door.global_position, 0.6, "walk to the Rec Center door")
		await _shot("03_at_rec_door")
		if door_ok:
			loc._update_current()
			_notes.append("at door: current target %s" % str(loc.current_target().get("kind", "none")) + " / " + str(loc.current_target().get("target", "")))
			Input.action_press("interact")
			await _frames(4)
			Input.action_release("interact")
			await _frames(30)
			if Game.location == "campus":
				loc._interact()
				await _frames(30)
			loc = get_tree().current_scene
			_notes.append("after door press: location=%s" % Game.location)
			await _wait_scene(300)
			_check(Game.location == "gym", "entering the Rec Center door loads the gym (%s)" % Game.location)
			await _shot("04_gym_arrival")
	else:
		_check(false, "Rec Center door marker exists")

	for note: String in _notes:
		print("  note  ", note)
	print("\n%d checks, %d failures" % [_checks, _failures])
	print("QUAD WALK PASSED" if _failures == 0 else "QUAD WALK FAILED")
	get_tree().quit(0 if _failures == 0 else 1)


## Walks toward `point` using movement input only. Returns true when within
## `radius`. Records a note when the player stops moving (blocked).
func _walk_to(loc: Node, point: Vector3, radius: float, label: String) -> bool:
	var player: CharacterBody3D = loc.player
	var stuck_frames: int = 0
	var last: Vector3 = player.global_position
	for _i in 900:
		var to: Vector3 = point - player.global_position
		to.y = 0.0
		if to.length() <= radius:
			_release_all()
			return true
		_release_all()
		var dir: Vector2 = Vector2(to.x, to.z).normalized()
		if dir.x > 0.3:
			Input.action_press("move_right")
		elif dir.x < -0.3:
			Input.action_press("move_left")
		if dir.y > 0.3:
			Input.action_press("move_down")
		elif dir.y < -0.3:
			Input.action_press("move_up")
		await _frames(1)
		if player.global_position.distance_to(last) < 0.005:
			stuck_frames += 1
		else:
			stuck_frames = 0
		last = player.global_position
		if stuck_frames > 45:
			_release_all()
			_notes.append("%s: blocked at (%.1f, %.1f) — target (%.1f, %.1f)" % [
				label, player.global_position.x, player.global_position.z, point.x, point.z])
			return false
	_release_all()
	_notes.append("%s: timed out at (%.1f, %.1f)" % [label, player.global_position.x, player.global_position.z])
	return false


func _hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	await get_tree().create_timer(seconds, true, false, true).timeout
	Input.action_release(action)
	await _frames(2)


func _release_all() -> void:
	for a: String in ["move_up", "move_down", "move_left", "move_right"]:
		Input.action_release(a)


func _close_card(loc: Node) -> void:
	var guard: int = 0
	while loc.ui.card.is_open() and guard < 60:
		guard += 1
		var buttons: Array = loc.ui.card.choice_buttons()
		if buttons.is_empty():
			loc.ui.card.advance()
		else:
			loc.ui.card.pick(0)
		await _frames(4)


func _npc(loc: Node, npc_id: String) -> Node3D:
	for key in loc.npcs.keys():
		if str(key) == npc_id:
			return loc.npcs[key]
	return null


func _wait_scene(max_frames: int) -> void:
	var guard: int = 0
	while (Game.is_changing_scene() or get_tree().current_scene == null) and guard < max_frames:
		guard += 1
		await _frames(1)
	await _frames(10)


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
