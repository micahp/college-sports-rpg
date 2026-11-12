extends Node
## Diagnoses why a real interact press sometimes does not open an NPC card.
## Walks to Coach Delgado with movement input, then logs state per frame
## around the press.

func _ready() -> void:
	get_tree().create_timer(200.0, true, false, true).timeout.connect(func() -> void:
		print("WATCHDOG")
		get_tree().quit(2))
	GameState.reset()
	TimeSystem.reset()
	GameState.look_id = "look_a"
	GameState.identity_id = "natural"
	Game.in_game = true
	TimeSystem.day = 1
	TimeSystem.period = TimeSystem.Period.EVENING
	Game.arrival = "start"
	var loc: Node = load(Game.SCENES["campus"]).instantiate()
	add_child(loc)
	await _frames(60)
	var coach: Node3D = loc.npcs.get("coach")
	print("coach present: ", coach != null)
	await _walk(loc, coach.global_position, 0.8)
	print("after walk: player=", loc.player.global_position, " coach=", coach.global_position)
	for i in 3:
		await _frames(1)
		_log(loc, "pre%d" % i)
	Input.action_press("interact")
	for i in 6:
		await _frames(1)
		_log(loc, "press%d" % i)
	Input.action_release("interact")
	for i in 3:
		await _frames(1)
		_log(loc, "rel%d" % i)
	get_tree().quit(0)


func _log(loc: Node, tag: String) -> void:
	var cur: Dictionary = loc.current_target()
	print("%-7s kind=%-6s card=%s modal=%s busy=%s locked=%s changing=%s" % [
		tag, str(cur.get("kind", "none")), str(loc.ui.card.is_open()), str(loc.ui.is_modal_open()),
		str(loc.busy), str(loc.player.control_locked), str(Game.is_changing_scene())])


func _walk(loc: Node, point: Vector3, radius: float) -> void:
	var player: CharacterBody3D = loc.player
	for _i in 900:
		var to: Vector3 = point - player.global_position
		to.y = 0.0
		if to.length() <= radius:
			break
		for a: String in ["move_up", "move_down", "move_left", "move_right"]:
			Input.action_release(a)
		var d: Vector2 = Vector2(to.x, to.z).normalized()
		if d.x > 0.3:
			Input.action_press("move_right")
		elif d.x < -0.3:
			Input.action_press("move_left")
		if d.y > 0.3:
			Input.action_press("move_down")
		elif d.y < -0.3:
			Input.action_press("move_up")
		await _frames(1)
	for a: String in ["move_up", "move_down", "move_left", "move_right"]:
		Input.action_release(a)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
