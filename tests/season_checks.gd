extends Node

const BOARD = preload("res://scenes/app/season.tscn")
var failures := 0
var checks := 0

func check(condition: bool, detail: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(detail)

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	# In-memory fixtures keep the real single-slot save untouched.
	Game.in_game = false
	Game.season = {}
	var board = BOARD.instantiate()
	add_child(board)
	check(board.state.slots == 3, "Fresh week has three slots")
	for week in range(12):
		board.prepare("Practice")
		board.prepare("Rest")
		board.prepare("Visit Avery")
		if week < 4:
			check(board.state.note == board.BEATS[week], "Avery scene order")
		var snapshot: Dictionary = board.state.duplicate(true)
		board.prepare("Gym")
		check(board.state == snapshot, "Fourth activity consumed")
		check(board.state.heat == 3, "Hot Hand from weekly choices")
		if week == 4:
			# Recreate the board with the same JSON representation used by SaveSystem.
			Game.season = JSON.parse_string(JSON.stringify(snapshot))
			board.free()
			board = BOARD.instantiate()
			add_child(board)
			check(board.state.results.size() == week and board.state.bond == 5, "Season restore")
		board.play()
		var court = board.get_child(-1)
		board.play()
		check(board.get_child_count() == 2, "Duplicate court")
		check(court.scenario.opponent.name == board.TEAMS[1 + week % 7], "Wrong opponent")
		check(is_equal_approx(court.scenario.shot_bonus, 1.15), "Shot bonus")
		check(court.scenario.team.off == board.rating() + (4 if week >= 2 else 0), "Practice badge")
		check(court.scenario.team.def == board.rating() + (4 if week >= 2 else 0), "Relationship badge")
		var result := {"pts": 8, "ast": 2, "to": 1, "team_score": 70, "opp_score": 69 + week % 3}
		var prior_wins := int(board.state.wins[0])
		court.finished.emit(result)
		await get_tree().process_frame
		var recorded: Dictionary = board.state.results.back()
		check(recorded.team_score != recorded.opp_score, "Unresolved tie")
		check(board.state.wins[0] == prior_wins + int(recorded.team_score > recorded.opp_score), "Incorrect record")
		check(board.state.results.size() == week + 1 and recorded.pts == 8, "Box score missing")
		check(board.state.slots == 3 and board.state.heat == 0, "Weekly reset")
		var wins := 0
		for value in board.state.wins:
			wins += int(value)
		check(wins == 4 * (week + 1), "Conference games counted incorrectly")
	var labels := []
	for child in board.column.get_children():
		if child is Button or child is Label:
			labels.append(child.text)
	check("Regular season complete" in labels, "Missing ending")
	check("Play game" not in labels and "Practice" not in labels, "Postseason activity exposed")
	board.free()
	print("Season: %d checks, %d failures" % [checks, failures])
	get_tree().quit(int(failures > 0))
