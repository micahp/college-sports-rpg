extends Node
## Goes straight from the gym into the pickup run and captures the HUD at
## several moments, so overlaps during a pickup game can be reviewed.
const OUT: String = "res://build/checks/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	get_tree().create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("WATCHDOG: pickup capture exceeded 240 s")
		get_tree().quit(2))
	GameState.reset()
	TimeSystem.reset()
	GameState.look_id = "look_a"
	GameState.identity_id = "workhorse"
	Game.in_game = true
	TimeSystem.day = 1
	TimeSystem.period = 2
	Game.arrival = "door"
	var loc: Node = load(Game.SCENES["gym"]).instantiate()
	add_child(loc)
	await _frames(40)
	loc.player.global_position = loc._marker("spot_court").global_position + Vector3(0, 0, 0.8)
	await _frames(10)
	loc._interact()
	await _frames(30)
	await _shot("pickup_card")
	var buttons: Array = loc.ui.card.choice_buttons()
	var pick: int = 0
	for i in buttons.size():
		if str(buttons[i].text).findn("pickup") >= 0:
			pick = i
	loc.ui.card.pick(pick)
	for t in [30, 90, 180, 300]:
		await _frames(t - (0 if t == 30 else 30))
		await _shot("pickup_%03d" % t)
	print("saved pickup shots")
	get_tree().quit(0)


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + file + ".png"))


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
