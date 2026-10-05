extends Node
## Visual review of the game's key moments:
##   xvfb-run godot --rendering-driver opengl3 tests/moment_shots.tscn
## Saves PNGs to res://build/moments/.

const OUT: String = "res://build/moments/"
var is_runner: bool = false


func _ready() -> void:
	if not is_runner:
		var runner: Node = Node.new()
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	SaveSystem.clear_save()
	get_tree().change_scene_to_file(Game.SCENES["title"])
	await _frames(20)
	await _shoot("title")
	get_tree().current_scene.find_child("NewGame", true, false).pressed.emit()
	await _frames(10)
	await _shoot("create")
	get_tree().current_scene.find_child("Start", true, false).pressed.emit()
	await _settle()
	var loc: Node = get_tree().current_scene
	await _frames(30)
	await _shoot("day1_start")
	# Talk to Jordan.
	loc.player.global_position = loc.npcs["jordan"].global_position + Vector3(-1.2, 0, 1.0)
	await _frames(10)
	loc._interact()
	await _frames(50)
	await _shoot("talk_jordan")
	loc.ui.card.advance()
	loc.ui.card.advance()
	await _frames(10)
	await _shoot("talk_choices")
	loc.ui.card.pick(0)
	await _frames(10)
	await _shoot("talk_result")
	loc.ui.card.advance()
	await _frames(100)
	await _shoot("afternoon_banner")
	await _frames(60)
	# Gym, court activity.
	Game.travel("gym")
	await _settle()
	loc = get_tree().current_scene
	await _frames(20)
	await _shoot("gym_arrive")
	loc.player.global_position = loc._marker("spot_court").global_position + Vector3(0, 0, 0.8)
	await _frames(10)
	loc._interact()
	await _frames(30)
	await _shoot("gym_activity")
	loc.ui.card.pick(0)
	await _frames(90)
	await _shoot("minigame_sweep")
	for i in 6:
		Input.action_press("interact")
		await _frames(1)
		Input.action_release("interact")
		await _frames(25)
		if i == 0:
			await _shoot("minigame_flight")
		await _frames(60)
	await _frames(120)
	await _shoot("minigame_result")
	loc.ui.card.advance()
	await _frames(60)
	loc.ui.toggle_stats()
	await _frames(5)
	await _shoot("stats")
	loc.ui.toggle_stats()
	# Night recap.
	TimeSystem.period = TimeSystem.Period.NIGHT
	Game.spend_time(1)
	loc.ui.show_recap(Game.pending_recap_day)
	await _frames(10)
	await _shoot("recap")
	# Ending.
	GameState.set_flag("signed_up")
	GameState.tryout = {"makes": 8, "perfects": 3, "shots": 12, "score": 53}
	Game.outcome = Game.compute_outcome()
	get_tree().change_scene_to_file(Game.SCENES["ending"])
	await _frames(20)
	await _shoot("ending")
	get_tree().quit(0)


func _settle() -> void:
	await _frames(3)
	while Game.is_changing_scene():
		await _frames(1)
	await _frames(5)


func _shoot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + file + ".png"))
	print("saved ", file)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
