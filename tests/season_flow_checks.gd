extends Node
## Regular season flow: save round trip, ending wiring, schedule, activities,
## stats, badges, shot bonus, the finished season screen, and overtime.

const BOARD = preload("res://scenes/app/season.tscn")
const ENDING = preload("res://scenes/app/ending.tscn")
const SAVE_PATH: String = "user://save_v2.json"
var failures := 0
var checks := 0


func check(condition: bool, detail: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(detail)


func _ready() -> void:
	run.call_deferred()


func fresh_season() -> Dictionary:
	return {"results": [], "slots": 3, "heat": 0, "practice": 0, "bond": 0, "note": "",
		"wins": [0, 0, 0, 0, 0, 0, 0, 0], "games": [0, 0, 0, 0, 0, 0, 0, 0]}


func new_board() -> Node:
	Game.season = fresh_season()
	GameState.reset()
	var board = BOARD.instantiate()
	add_child(board)
	return board


func texts(node: Node) -> Array:
	var out: Array = []
	for child in node.find_children("*", "", true, false):
		if child is Label or child is Button:
			out.append(child.text)
	return out


func button_named(node: Node, label: String) -> Button:
	for child in node.find_children("*", "Button", true, false):
		if child.text == label:
			return child
	return null


func run() -> void:
	Game.in_game = false
	test_save_round_trip()
	test_ending_button()
	test_schedule()
	test_study_and_stats()
	test_visit_beats()
	test_badges()
	test_shot_bonus()
	test_finished_screen()
	test_overtime()
	# Last: the press starts a real scene change, which would replace this test scene.
	test_ending_transition()
	print("Season flow: %d checks, %d failures" % [checks, failures])
	get_tree().quit(int(failures > 0))


## 1. A save written by the season screen comes back from the save file.
func test_save_round_trip() -> void:
	var had_save: bool = FileAccess.file_exists(SAVE_PATH)
	var backup: String = ""
	if had_save:
		backup = FileAccess.open(SAVE_PATH, FileAccess.READ).get_as_text()
	Game.in_game = true
	var board = new_board()
	board.prepare("Practice")
	board.prepare("Visit Avery")
	var expected: String = JSON.stringify(JSON.parse_string(JSON.stringify(Game.season)))
	Game.location = "season"
	Game.save()
	check(SAVE_PATH == SaveSystem.SAVE_PATH and FileAccess.file_exists(SAVE_PATH), "Test writes the real save path")
	var on_disk: Variant = JSON.parse_string(FileAccess.open(SAVE_PATH, FileAccess.READ).get_as_text())
	check(on_disk is Dictionary and str(on_disk.get("flow", {}).get("location", "")) == "season", "Save file on disk holds the season location")
	check(on_disk is Dictionary and JSON.stringify(on_disk.get("flow", {}).get("season", {})) == expected, "Save file on disk holds the season state")
	var flow: Variant = SaveSystem.load_game()
	check(flow is Dictionary, "Save file reads back")
	if flow is Dictionary:
		check(str(flow.get("location", "")) == "season", "Season location saved")
		check(JSON.stringify(flow.get("season", {})) == expected, "Season state round-trips through the save file")
	check("season" in Game.SCENES and str(Game.SCENES["season"]) == "res://scenes/app/season.tscn", "Season scene is registered")
	Game.in_game = false
	board.free()
	if had_save:
		var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		file.store_string(backup)
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


## 2. The ending offers the regular season only after an eligible verdict.
func test_ending_button() -> void:
	for id in ["roster", "conditional", "practice", "cut"]:
		Game.outcome = {"id": id, "score": 50, "title": "T", "text": "x"}
		var ending = ENDING.instantiate()
		add_child(ending)
		var offered: bool = "Start regular season" in texts(ending)
		check(offered == (id in ["roster", "conditional"]), "Regular season offered only for roster/conditional, got %s for %s" % [offered, id])
		ending.free()
	Game.outcome = {}


## 2b. Pressing the ending's button starts the change to the season scene.
func test_ending_transition() -> void:
	Game.outcome = {"id": "roster", "score": 60, "title": "T", "text": "x"}
	Game.in_game = false
	var ending = ENDING.instantiate()
	add_child(ending)
	var button: Button = button_named(ending, "Start regular season")
	check(button != null, "Ending offers the regular season for a roster outcome")
	if button != null:
		button.pressed.emit()
		check(Game.location == "season", "Button sets the location to season")
		check(Game.in_game, "Button marks the game as in progress")
		check(Game.is_changing_scene(), "Button starts the scene change")
	check(ResourceLoader.exists(str(Game.SCENES["season"])), "Season scene file exists for the change")
	ending.free()
	Game.outcome = {}


## 3. Twelve games: six home, six away, and every team plays twelve games.
func test_schedule() -> void:
	var board = new_board()
	var home: Array = []
	var away: Array = []
	for week in range(12):
		var opp: int = board.opponent(week)
		check(opp >= 1 and opp <= 7, "Opponent index in range for week %d" % (week + 1))
		if week < 6:
			home.append(opp)
		else:
			away.append(opp)
	var distinct_home: Dictionary = {}
	for opp in home:
		distinct_home[opp] = true
	check(distinct_home.size() == 6, "Six different home opponents")
	for week in range(12):
		board.finish_game({"pts": 8, "ast": 2, "to": 1, "team_score": 80, "opp_score": 70})
	for team in range(8):
		check(int(board.state.games[team]) == 12, "Team %d plays twelve games, got %d" % [team, int(board.state.games[team])])
	check(int(board.state.wins[0]) == 12, "Player wins every game in this run")
	board.free()


## 4 and 5. Each activity applies its stat changes, using the same diminishing-gain rule.
func test_study_and_stats() -> void:
	var board = new_board()
	GameState.stats["energy"] = 60
	GameState.stats["academics"] = 40
	GameState.stats["basketball_skill"] = 30
	GameState.stats["athleticism"] = 30
	var acad: int = GameState.get_stat("academics")
	var expected_acad: int = acad + GameState.scaled_gain("academics", acad, 4)
	board.prepare("Study")
	check(GameState.get_stat("academics") == expected_acad, "Study adds academics, got %d want %d" % [GameState.get_stat("academics"), expected_acad])
	check(GameState.get_stat("energy") == 60, "Study leaves energy alone")
	check(int(board.state.slots) == 2 and board.state.note == "Study complete.", "Study spends one slot and notes it")

	var skill: int = GameState.get_stat("basketball_skill")
	board.state.slots = 3
	board.prepare("Practice")
	check(GameState.get_stat("basketball_skill") == skill + GameState.scaled_gain("basketball_skill", skill, 3), "Practice adds basketball skill")
	check(GameState.get_stat("energy") == 56, "Practice costs 4 energy, got %d" % GameState.get_stat("energy"))

	var athl: int = GameState.get_stat("athleticism")
	board.state.slots = 3
	board.prepare("Gym")
	check(GameState.get_stat("athleticism") == athl + GameState.scaled_gain("athleticism", athl, 3), "Gym adds athleticism")
	check(GameState.get_stat("energy") == 52, "Gym costs 4 energy, got %d" % GameState.get_stat("energy"))

	board.state.slots = 3
	board.prepare("Rest")
	check(GameState.get_stat("energy") == 60, "Rest restores 8 energy, got %d" % GameState.get_stat("energy"))

	board.state.slots = 3
	board.prepare("Visit Avery")
	check(GameState.get_stat("energy") == 62, "Visit Avery adds 2 energy, got %d" % GameState.get_stat("energy"))

	var s: Dictionary = GameState.stats
	var rating_want: int = roundi((int(s["basketball_skill"]) + int(s["energy"]) + int(s["academics"]) + int(s["athleticism"])) / 4.0)
	check(board.rating() == rating_want, "Rating averages the four stats, got %d want %d" % [board.rating(), rating_want])
	board.free()


## 6. Visit Avery moves through the four beats, then the catch-up note.
func test_visit_beats() -> void:
	var board = new_board()
	var notes: Array = []
	for visit in range(5):
		board.state.slots = 3
		board.prepare("Visit Avery")
		notes.append(board.state.note)
	for i in range(4):
		check(notes[i] == board.BEATS[i], "Visit %d shows beat %d" % [i + 1, i + 1])
	check(notes[4] == "You and Avery catch up over dinner.", "Fifth visit shows the catch-up note")
	board.free()


## 7. Badges switch from the goal text to the earned name at three.
func test_badges() -> void:
	var board = new_board()
	var line: String = ""
	for text in texts(board.column):
		if str(text).begins_with("Avery bond"):
			line = str(text)
	check("Practice three times" in line and "Visit Avery three times" in line, "Badge goals shown at the start")
	for i in range(3):
		board.state.slots = 3
		board.prepare("Practice")
	for text in texts(board.column):
		if str(text).begins_with("Avery bond"):
			line = str(text)
	check("Gym Rat" in line, "Gym Rat after three practices")
	for i in range(3):
		board.state.slots = 3
		board.prepare("Visit Avery")
	for text in texts(board.column):
		if str(text).begins_with("Avery bond"):
			line = str(text)
	check("Support Crew" in line, "Support Crew after three visits")
	board.free()


## 8. Shot bonus rises 5% per heat point, from 1.00 to 1.15.
func test_shot_bonus() -> void:
	for heat in range(4):
		var board = new_board()
		for i in range(heat):
			board.prepare("Gym")
		board.play()
		var court = board.get_child(-1)
		var bonus: float = court.scenario.shot_bonus
		check(is_equal_approx(bonus, 1.0 + 0.05 * heat), "Shot bonus at heat %d" % heat)
		board.remove_child(court)
		court.free()
		board.free()


## 9. After week twelve the board shows the finished state and no game controls.
func test_finished_screen() -> void:
	var board = new_board()
	for i in range(12):
		board.state.results.append({"pts": 8, "ast": 2, "to": 1, "team_score": 70, "opp_score": 60})
	board.draw_board()
	var labels: Array = texts(board.column)
	check("Regular season complete" in labels, "Finished label shown")
	check("Play game" not in labels, "No Play game button after the season")
	check("Practice" not in labels and "Gym" not in labels, "No activity buttons after the season")
	var save: Button = button_named(board.column, "Save and return to title")
	check(save != null, "Save and return button shown")
	if save != null:
		check(save.pressed.is_connected(Game.quit_to_title), "Save and return calls quit_to_title")
	board.free()


## 10. A tie is decided in overtime and the winner is credited once.
func test_overtime() -> void:
	var board = new_board()
	var result: Dictionary = {"pts": 8, "ast": 2, "to": 1, "team_score": 70, "opp_score": 70}
	board.finish_game(result)
	var recorded: Dictionary = board.state.results.back()
	check(recorded.team_score != recorded.opp_score, "Overtime breaks the tie")
	check(str(board.state.note).ends_with("Decided in overtime."), "Overtime is noted")
	var player_won: bool = int(recorded.team_score) > int(recorded.opp_score)
	check(int(board.state.wins[0]) == (1 if player_won else 0), "Overtime winner gets the win")
	var total: int = 0
	for value in board.state.wins:
		total += int(value)
	check(total == 4, "Four wins credited per week, got %d" % total)
	board.free()
