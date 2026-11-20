extends Node
## Record two cuts from the unmodified gameplay camera using the court inputs.
const Court = preload("res://scripts/court/court_game.gd")
const Scene = preload("res://scenes/court/court_game.tscn")

func _ready() -> void:
	GameState.reset()
	GameState.look_id = "look_a"
	Court.auto_play = false
	var court := Scene.instantiate()
	court.scenario = Court.demo_scenario()
	add_child(court)
	while court._phase != Court.Phase.LIVE:
		await get_tree().physics_frame
	court._rng.seed = 2001
	for direction: String in ["move_left", "move_right"]:
		Input.action_press("sprint")
		Input.action_press(direction)
		for tick in 60:
			await get_tree().physics_frame
			if tick in [0, 30, 59]:
				print(direction, " tick ", tick, " user holds ball ", court._holder == court._user, " speed ", court._user.vel.length())
		Input.action_release(direction)
		Input.action_release("sprint")
		for tick in 40:
			await get_tree().physics_frame
		if direction == "move_left":
			# Isolate off-ball footwork in the same possession and camera.
			court._give_ball(court._mates[0])
			court._ai_decide = 3.0
	get_tree().quit()
