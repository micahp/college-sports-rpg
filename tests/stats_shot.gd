extends Node
## Renders the stats sheet with every status line present (walk-on signed,
## quiz failed, lucky wristband). Used to check the sheet still fits.
const OUT: String = "res://build/checks/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	GameState.reset()
	TimeSystem.reset()
	GameState.look_id = "look_a"
	GameState.identity_id = "workhorse"
	GameState.set_flag("signed_up")
	GameState.set_flag("quiz_failed")
	GameState.set_flag("wristband")
	Game.in_game = true
	TimeSystem.day = 2
	TimeSystem.period = 2
	Game.arrival = "start"
	var scene: Node = load(Game.SCENES["campus"]).instantiate()
	add_child(scene)
	await _frames(60)
	scene.ui.toggle_stats()
	await _frames(10)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "stats_all_flags.png"))
	print("saved stats_all_flags")
	get_tree().quit(0)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
