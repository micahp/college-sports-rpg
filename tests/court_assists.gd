extends Node

const COURT = preload("res://scenes/court/court_game.tscn")
var failures := 0

func check(ok: bool, reason: String) -> void:
	if not ok:
		push_error(reason)
		failures += 1

func _ready() -> void:
	var court = COURT.instantiate()
	add_child(court)
	var wing = court._mates[0]
	for spot in court.SPOTS:
		wing.position = spot
		for defender in court._defense:
			defender.position = Vector3(0, 0, 8)
		court._give_ball(court._user)
		court._throw_pass(court._user, wing)
		court._tick_pass(2)
		court._ai_holder(0.2)
		check(court._shooter == wing and court._phase == court.Phase.SHOT, "Open catch must produce a shot")
		var assists := int(court._stats.ast)
		court._time += 4.0
		court._shot_made = true
		court._tick_shot(2)
		court._tick_shot(2) if court._phase == court.Phase.SHOT else null
		check(court._stats.ast == assists + 1, "Credit passer even after long shot flight")
	var before := int(court._stats.ast)
	court._give_ball(wing)
	court._take_shot(wing, true, "mid")
	court._tick_shot(2)
	if court._phase == court.Phase.SHOT:
		court._tick_shot(2)
	check(court._stats.ast == before, "New possession cannot inherit assist")
	court._give_ball(wing)
	court._defense[0].position = wing.position
	court._ai_holder(0.2)
	check(court._ball_mode == "pass", "Guarded wing should pass to open user")
	print("Assist checks: ", failures, " failures")
	get_tree().quit(int(failures > 0))
