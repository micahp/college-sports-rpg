extends Node
## Places the player beside the dorm door on the quad, presses interact, and
## logs the state each frame.

func _ready() -> void:
	get_tree().create_timer(90.0, true, false, true).timeout.connect(func() -> void:
		print("WATCHDOG")
		get_tree().quit(2))
	GameState.reset()
	TimeSystem.reset()
	Game.in_game = true
	Game.arrival = "start"
	var loc: Node = load(Game.SCENES["campus"]).instantiate()
	add_child(loc)
	await _frames(60)
	var door: Node3D = loc._marker("door_dorm")
	print("door: ", door.global_position)
	var away: Vector3 = loc.player.global_position - door.global_position
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(0, 0, 1)
	loc.player.global_position = door.global_position + away.normalized() * 1.2 + Vector3(0, 0.1, 0)
	await _frames(20)
	loc._update_current()
	_log(loc, "ready")
	Input.action_press("interact")
	for i in 5:
		await _frames(1)
		_log(loc, "press%d" % i)
	Input.action_release("interact")
	for i in 30:
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
