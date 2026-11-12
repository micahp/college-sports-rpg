extends Node
## Puts the player directly behind a tree (from the camera's view) and checks
## that the tree hides, then moves the player away and checks it returns.

func _ready() -> void:
	get_tree().create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		print("WATCHDOG")
		get_tree().quit(2))
	GameState.reset()
	TimeSystem.reset()
	Game.in_game = true
	Game.arrival = "start"
	var loc: Node = load(Game.SCENES["campus"]).instantiate()
	add_child(loc)
	await _frames(60)
	var tree: Node3D = loc.find_child("Tree0", true, false)
	print("tree found: ", tree != null)
	if tree == null:
		get_tree().quit(1)
		return
	var cam: Vector3 = loc._camera.global_position
	var t: Vector3 = tree.global_position + Vector3(0, 1.0, 0)
	var dir: Vector3 = (t - cam).normalized()
	loc.player.control_locked = true
	loc.player.global_position = t + dir * 1.5
	loc.player.global_position.y = 0.1
	await _frames(40)
	var hidden_while_behind: bool = not tree.visible
	print("tree hides when player is behind it: ", hidden_while_behind)
	loc.player.global_position = t - dir * 6.0
	loc.player.global_position.y = 0.1
	await _frames(60)
	print("tree visible again when clear: ", tree.visible)
	get_tree().quit(0 if hidden_while_behind and tree.visible else 1)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
