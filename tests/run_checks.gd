extends SceneTree
## Headless acceptance checks for the core systems and Day 1 content.
## Run from the project root:  godot --headless -s tests/run_checks.gd
## Exits 0 when everything passes, 1 otherwise.
##
## Systems are instantiated directly (not via autoload) so this script
## stays independent of scene setup. SaveSystem is excluded here because
## it depends on the autoload singletons; it is exercised in-game.

const GameStateScript = preload("res://scripts/core/game_state.gd")
const TimeSystemScript = preload("res://scripts/core/time_system.gd")
const ContentDBScript = preload("res://scripts/core/content_db.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_time_system()
	_test_game_state()
	_test_day_content()
	if _failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		printerr("\n%d CHECK(S) FAILED" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok    %s" % label)
	else:
		_failures += 1
		printerr("  FAIL  %s" % label)


func _test_time_system() -> void:
	print("TimeSystem")
	var time: Node = TimeSystemScript.new()
	time.reset()

	_check(time.day == 1 and time.period == time.Period.MORNING, "starts at Day 1 Morning")
	_check(time.advance(1) and time.period == time.Period.AFTERNOON, "Morning + 1 = Afternoon")

	time.period = time.Period.NIGHT
	time.advance(1)
	_check(time.day == 2 and time.period == time.Period.MORNING, "Night + 1 rolls to next day's Morning")

	_check(not time.advance(0), "advancing zero blocks is rejected")
	_check(not time.advance(-3), "advancing negative blocks is rejected")

	time.day = time.FINAL_DAY
	time.period = time.Period.NIGHT
	var completed: Array = [false]
	time.week_completed.connect(func() -> void: completed[0] = true)
	time.advance(1)
	_check(completed[0] and time.day == time.FINAL_DAY, "Day 7 Night + 1 emits week_completed without rolling over")

	var snapshot: Dictionary = time.to_save_dict()
	time.reset()
	time.from_save_dict(snapshot)
	_check(time.day == time.FINAL_DAY and time.period == time.Period.NIGHT, "save/restore preserves day and period")

	time.free()


func _test_game_state() -> void:
	print("GameState")
	var state: Node = GameStateScript.new()
	state.reset()

	_check(state.get_stat("energy") == 80, "starting energy is 80")

	var applied: Dictionary = state.apply_effects({"energy": 50})
	_check(state.get_stat("energy") == 100, "stats clamp at 100")
	_check(int(applied.get("energy", 0)) == 20, "applied deltas report the post-clamp change")

	state.apply_effects({"coach_interest": -30})
	_check(state.get_stat("coach_interest") == 0, "stats clamp at 0")

	state.apply_effects({"swagger": 99})
	_check(not state.stats.has("swagger"), "unknown stat keys are ignored")

	_check(state.meets_requirements({}), "empty requirements always pass")
	_check(not state.meets_requirements({"energy_min": 999}), "energy_min gates correctly")

	state.record_choice("beat_a", "choice_1", ["grind"])
	state.record_choice("beat_b", "choice_2", ["grind", "social"])
	_check(state.has_made_choice("beat_a") and not state.has_made_choice("beat_z"), "has_made_choice tracks visited beats")
	var counts: Dictionary = state.tag_counts()
	_check(int(counts.get("grind", 0)) == 2 and int(counts.get("social", 0)) == 1, "tag counts aggregate across choices")

	var snapshot: Dictionary = state.to_save_dict()
	state.reset()
	state.from_save_dict(snapshot)
	_check(state.get_stat("energy") == 100 and state.choice_history.size() == 2, "save/restore preserves stats and history")

	state.free()


func _test_day_content() -> void:
	print("Day 1 content")
	var content: Node = ContentDBScript.new()

	var beats: Array = content.get_day(1)
	_check(beats.size() == 4, "Day 1 has four beats")
	if beats.size() == 4:
		var periods: Array = beats.map(func(beat: Dictionary) -> String: return str(beat["period"]))
		_check(periods == ["morning", "afternoon", "evening", "night"], "beats cover the four periods in order")

	var state: Node = GameStateScript.new()
	var stat_keys: Array = state.STAT_KEYS
	state.free()
	var gated_choice_found: bool = false
	var all_effects_valid: bool = true
	for beat: Dictionary in beats:
		for choice: Dictionary in beat["choices"]:
			if choice.has("requirements"):
				gated_choice_found = true
			for key: String in choice.get("effects", {}).keys():
				if key not in stat_keys:
					all_effects_valid = false
					printerr("        bad stat key '%s' in choice %s" % [key, choice["id"]])
	_check(all_effects_valid, "every effect targets a canonical stat")
	_check(gated_choice_found, "at least one choice is requirement-gated")

	_check(content.get_identities().size() == 3, "three identities load")

	var npcs: Dictionary = content.get_npc_dialogues()
	_check(npcs.size() == 3 and npcs.has("jordan") and npcs.has("leader") and npcs.has("coach"), "three NPC dialogues load")
	var npc_effects_valid: bool = true
	for npc_id: String in npcs.keys():
		for choice: Dictionary in npcs[npc_id]["choices"]:
			for key: String in choice.get("effects", {}).keys():
				if key not in stat_keys:
					npc_effects_valid = false
					printerr("        bad stat key '%s' in NPC choice %s" % [key, choice["id"]])
	_check(npc_effects_valid, "every NPC choice effect targets a canonical stat")

	content.free()
