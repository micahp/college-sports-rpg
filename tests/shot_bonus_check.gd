extends Node
## The season's Hot Hand (scenario.shot_bonus) widens the shot meter's window.
## Plays the same open jump shot at bonus 1.0 and 1.15 and compares the window.
const CourtScene: PackedScene = preload("res://scenes/court/court_game.tscn")
const CourtGame = preload("res://scripts/court/court_game.gd")


func _zone(bonus: float) -> float:
	var court: Node3D = CourtScene.instantiate()
	var scenario: Dictionary = CourtGame.demo_scenario()
	scenario["shot_bonus"] = bonus
	court.scenario = scenario
	add_child(court)
	while court._phase != CourtGame.Phase.LIVE:
		await get_tree().physics_frame
	court._user.position = CourtGame.HOOP_FLAT + Vector3(-2.2, 0, 4.6)
	for d: Node3D in court._defense:
		d.position = Vector3(d.position.x, 0, 9.0)  # far away: the same open shot both times
		d.track = d.position
	await get_tree().physics_frame
	court._begin_shot()
	var z: float = court._zone_w
	court.queue_free()
	await get_tree().process_frame
	return z


func _ready() -> void:
	GameState.reset()
	CourtGame.auto_play = false
	var base: float = await _zone(1.0)
	var hot: float = await _zone(1.15)
	var ok: bool = base > 0.0 and is_equal_approx(hot / base, 1.15) or (hot >= 0.42 * 0.999 and hot > base)
	print("Shot bonus: window %.3f at 1.00, %.3f at 1.15 (ratio %.3f) -> %s" % [base, hot, hot / base, "ok" if ok else "FAIL"])
	get_tree().quit(0 if ok else 1)
