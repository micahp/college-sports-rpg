extends Node
## Visual review rig: renders every location at several moments of the week.
##   xvfb-run godot --rendering-driver opengl3 tests/tour_shots.tscn
## Saves PNGs to res://build/tour/.

const OUT: String = "res://build/tour/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	GameState.reset()
	TimeSystem.reset()
	GameState.look_id = "look_a"
	Game.in_game = true
	var shots: Array = OS.get_cmdline_user_args()
	await _shot("campus", "start", 1, 0, "campus_d1_morning")
	await _shot("campus", "door_gym", 1, 2, "campus_d1_evening")
	await _shot("campus", "door_dorm", 2, 3, "campus_night")
	await _shot("dorm", "bed", 1, 3, "dorm_night")
	await _shot("classroom", "door", 2, 0, "classroom")
	await _shot("gym", "door", 3, 2, "gym_evening")
	await _shot("campus", "door_classroom", 2, 1, "campus_east")
	get_tree().quit(0)


func _shot(location: String, arrival: String, day: int, period: int, file: String) -> void:
	TimeSystem.day = day
	TimeSystem.period = period
	Game.arrival = arrival
	var scene: Node = load(Game.SCENES[location]).instantiate()
	add_child(scene)
	await _frames(40)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + file + ".png"))
	print("saved ", file)
	scene.queue_free()
	await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
