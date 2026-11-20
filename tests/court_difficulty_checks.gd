extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := root.get_node("GameState")
	for mode: String in state.DIFFICULTIES:
		state.court_difficulty = mode
		var saved: Dictionary = state.to_save_dict()
		state.reset()
		assert(state.court_difficulty == "Medium")
		state.from_save_dict(saved)
		assert(state.court_difficulty == mode)
	state.from_save_dict({})
	assert(state.court_difficulty == "Medium")
	state.from_save_dict({"court_difficulty": "unknown"})
	assert(state.court_difficulty == "Medium")
	print("Court difficulty save checks passed")
	quit()
