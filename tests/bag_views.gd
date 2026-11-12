extends Node
## Renders the player from its back and front so the backpack placement can be
## checked in both directions.
const OUT: String = "res://build/checks/"

func _ready() -> void:
	get_tree().create_timer(100.0, true, false, true).timeout.connect(func() -> void:
		get_tree().quit(2))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	GameState.reset()
	TimeSystem.reset()
	Game.in_game = true
	Game.arrival = "start"
	var loc: Node = load(Game.SCENES["campus"]).instantiate()
	add_child(loc)
	await _frames(40)
	loc.player.control_locked = true
	loc.player.global_position = Vector3(0.0, 0.1, -6.0)
	loc.player._model.rotation.y = 0.0
	await _frames(30)
	await _shot("bag_facing_plus_z")
	loc.player._model.rotation.y = PI
	await _frames(30)
	await _shot("bag_facing_minus_z")
	get_tree().quit(0)

func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + file + ".png"))

func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
