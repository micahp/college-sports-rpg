extends Control

const COURT = preload("res://scenes/court/court_game.tscn")
const TEAMS = ["North Valley State", "Ridge Tech", "Lake City", "Central Plains", "Summit State", "Harbor College", "Western Union", "Eastgate"]
const ACTIVITIES = {
	"Practice": {"basketball_skill": 3, "energy": -4},
	"Gym": {"athleticism": 3, "energy": -4},
	"Study": {"academics": 4},
	"Rest": {"energy": 8},
	"Visit Avery": {"energy": 2}
}
const BEATS = [
	"Avery keeps score for campus radio. Over coffee, you compare the plays nobody in the stands noticed.",
	"Avery saves you a seat in the booth. You stay after the broadcast to help edit the highlights.",
	"On the walk home Avery asks if next time it could be a date. You pick Friday at the diner.",
	"Friday at the diner runs past closing. Avery takes your hand on the walk back to campus."
]
var state: Dictionary
var board := ScrollContainer.new()
var column := VBoxContainer.new()

func _ready() -> void:
	state = Game.season
	if state.is_empty():
		state.merge({"results": [], "slots": 3, "heat": 0, "practice": 0, "bond": 0, "note": "", "wins": [0,0,0,0,0,0,0,0], "games": [0,0,0,0,0,0,0,0]})
		Game.save()
	add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.add_child(column)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	draw_board()

func action(label: String, callback: Callable) -> void:
	var button := UIKit.button(label)
	column.add_child(button)
	button.pressed.connect(callback)

func opponent(week: int) -> int:
	return 1 + week % 7

func draw_board() -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	var week: int = state.results.size()
	column.add_child(UIKit.label("North Valley State  /  Season board", 32, UIKit.GOLD))
	column.add_child(UIKit.label("Record %d–%d" % [state.wins[0], week-int(state.wins[0])], 24))
	if week < 12:
		column.add_child(UIKit.label("Week %d  ·  %s %s" % [week+1, "vs." if week < 6 else "at", TEAMS[opponent(week)]], 24))
		column.add_child(UIKit.label("Weekly slots %d   ·   Rating %d   ·   Hot Hand %d/3" % [state.slots, rating(), state.heat], 18))
		if state.slots > 0:
			for key: String in ACTIVITIES:
				action(key, prepare.bind(key))
		action("Play game", play)
	else:
		column.add_child(UIKit.label("Regular season complete", 26))
	column.add_child(UIKit.wrap_label(str(state.note), 18))
	column.add_child(UIKit.label("Avery bond %d   ·   Badges: %s / %s" % [state.bond, "Gym Rat" if state.practice >= 3 else "Practice three times", "Support Crew" if state.bond >= 3 else "Visit Avery three times"], 18))
	var order := range(TEAMS.size())
	order.sort_custom(func(a,b): return state.wins[a] > state.wins[b])
	column.add_child(UIKit.label("Conference standings", 22))
	for team in order:
		column.add_child(UIKit.label("%s   %d wins" % [TEAMS[team],state.wins[team]], 18))
	column.add_child(UIKit.label("Schedule and box scores", 22))
	for i in range(12):
		var line := "%02d   %s %s" % [i+1, "vs." if i < 6 else "at", TEAMS[opponent(i)]]
		if i < week:
			var r: Dictionary = state.results[i]
			line += "   %d–%d   ·   %d pts   %d ast   %d TO" % [r.team_score,r.opp_score,r.pts,r.ast,r.to]
		column.add_child(UIKit.label(line, 18))
	action("Save and return to title", Game.quit_to_title)

func rating() -> int:
	return roundi((GameState.get_stat("basketball_skill") + GameState.get_stat("energy") + GameState.get_stat("academics") + GameState.get_stat("athleticism")) / 4.0)

func prepare(key: String) -> void:
	if state.slots <= 0:
		return
	GameState.apply_effects(ACTIVITIES[key])
	state.slots -= 1
	state.heat += 1
	state.note = key + " complete."
	if key in ["Practice","Gym"]:
		state.practice += 1
	if key == "Visit Avery":
		state.note = BEATS[mini(state.bond,3)] if state.bond < 4 else "You and Avery catch up over dinner."
		state.bond += 1
	Game.save()
	draw_board()

func play() -> void:
	if not board.visible:
		return
	board.hide()
	var week: int = state.results.size()
	var court = COURT.instantiate()
	var scenario: Dictionary = court.demo_scenario()
	var rival := opponent(week)
	scenario.opponent.name = TEAMS[rival]
	scenario.opponent.short = TEAMS[rival].left(3).to_upper()
	scenario.opponent.off = 48 + rival * 3
	scenario.opponent.pnr = ["drop","switch","hedge"][week % 3]
	scenario.team.off = rating() + (4 if state.practice >= 3 else 0)
	scenario.team.def = rating() + (4 if state.bond >= 3 else 0)
	scenario.shot_bonus = 1.0 + 0.05 * int(state.heat)
	scenario.team_score = 52 + roundi(float(scenario.team.off)/5)
	scenario.opp_score = 52 + roundi(float(scenario.opponent.off)/5)
	court.scenario = scenario
	court.finished.connect(func(result: Dictionary):
		court.queue_free()
		finish_game(result), CONNECT_ONE_SHOT)
	add_child(court)

func finish_game(result: Dictionary) -> void:
	var week: int = state.results.size()
	var rival := opponent(week)
	state.note = "Final against " + TEAMS[rival] + "."
	if result.team_score == result.opp_score:
		var winner := "team_score" if randf() < 0.5 else "opp_score"
		result[winner] += 2
		state.note += " Decided in overtime."
	state.wins[0 if result.team_score > result.opp_score else rival] += 1
	state.games[0] += 1
	state.games[rival] += 1
	# Pair the remaining teams in the same round of the conference schedule.
	var rotation := range(1,8)
	for i in range(week % 7):
		rotation.append(rotation.pop_front())
	for pair in [[1,6],[2,5],[3,4]]:
		state.games[rotation[pair[0]]] += 1
		state.games[rotation[pair[1]]] += 1
		state.wins[rotation[pair[randi_range(0,1)]]] += 1
	state.results.append(result)
	state.slots = 3
	state.heat = 0
	Game.save()
	board.show()
	draw_board()
