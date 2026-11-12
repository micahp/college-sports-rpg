extends Node
## Renders the Rec Center steps from the plaza, from two spots.

func _ready() -> void:
	get_tree().create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		get_tree().quit(2))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/checks/"))
	GameState.reset()
	TimeSystem.reset()
	Game.in_game = true
	Game.arrival = "start"
	var loc: Node = load(Game.SCENES["campus"]).instantiate()
	add_child(loc)
	await _frames(40)
	loc.player.control_locked = true
	loc.player.global_position = Vector3(0.5, 0.1, -10.5)
	await _frames(40)
	await _shot("steps_plaza")
	loc.player.global_position = Vector3(-4.0, 0.1, -12.5)
	await _frames(40)
	await _shot("steps_side")
	get_tree().quit(0)


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/checks/" + file + ".png"))


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
