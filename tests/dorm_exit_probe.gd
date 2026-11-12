extends Node
## Enters the dorm, then presses interact at the exit door and logs state per
## frame, to find out why the exit does not change scenes.

func _ready() -> void:
	get_tree().create_timer(90.0, true, false, true).timeout.connect(func() -> void:
		print("WATCHDOG")
		get_tree().quit(2))
	GameState.reset()
	TimeSystem.reset()
	Game.in_game = true
	Game.arrival = "door"
	Game.location = "dorm"
	var loc: Node = load(Game.SCENES["dorm"]).instantiate()
	add_child(loc)
	await _frames(60)
	var exit_marker: Node3D = loc._marker("door_campus")
	print("exit marker: ", exit_marker.global_position if exit_marker else "MISSING")
	loc.player.global_position = exit_marker.global_position + Vector3(0.6, 0.1, 0.0)
	await _frames(20)
	loc._update_current()
	_log(loc, "ready")
	Input.action_press("interact")
	for i in 6:
		await _frames(1)
		_log(loc, "press%d" % i)
	Input.action_release("interact")
	for i in 40:
		await _frames(1)
		if i % 10 == 0:
			_log(loc, "wait%d" % i)
	get_tree().quit(0)


func _log(loc: Node, tag: String) -> void:
	var cur: Dictionary = loc.current_target()
	print("%-8s loc=%s kind=%s target=%s card=%s modal=%s busy=%s changing=%s" % [
		tag, Game.location, str(cur.get("kind", "none")), str(cur.get("target", "")),
		str(loc.ui.card.is_open()), str(loc.ui.is_modal_open()), str(loc.busy),
		str(Game.is_changing_scene())])


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
