extends Node
## Game flow: which place the player is in, what is happening there right
## now (story events, NPCs, activities), what consuming a choice does to the
## clock, and the end-of-week verdict. Scenes ask this autoload questions and
## report choices back; they never decide story or time themselves.

signal objective_changed

const SCENES: Dictionary = {
	"title": "res://scenes/app/title.tscn",
	"ending": "res://scenes/app/ending.tscn",
	"campus": "res://scenes/world3d/campus3d.tscn",
	"dorm": "res://scenes/interiors/dorm.tscn",
	"classroom": "res://scenes/interiors/classroom.tscn",
	"gym": "res://scenes/interiors/gym.tscn",
}

const LOCATION_NAMES: Dictionary = {
	"campus": "The Quad",
	"dorm": "Hargrove Hall · Room 214",
	"classroom": "Moreno Hall 104",
	"gym": "Rec Center",
}

## Where each interior's door lands you on the quad.
const CAMPUS_DOORS: Dictionary = {
	"dorm": "door_dorm",
	"classroom": "door_classroom",
	"gym": "door_gym",
}

var location: String = "dorm"
var arrival: String = "bed"
## True between New Game/Continue and the ending; false on the title screen.
var in_game: bool = false
## Set when a night activity rolled the clock over; the next scene shows
## the recap of `recap_day` before play resumes.
var pending_recap_day: int = 0
## Last computed verdict, read by the ending scene.
var outcome: Dictionary = {}

var _fade_layer: CanvasLayer
var _fade: ColorRect
var _changing: bool = false


func _ready() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.04, 0.06, 0.1, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade)


# =============================================================================
# Lifecycle
# =============================================================================

func new_game(player_name: String, identity_id: String, look_id: String) -> void:
	GameState.reset()
	TimeSystem.reset()
	GameState.player_name = player_name.strip_edges() if player_name.strip_edges() != "" else "Freshman"
	GameState.identity_id = identity_id
	GameState.look_id = look_id
	for identity: Dictionary in ContentDB.get_identities():
		if identity.get("id", "") == identity_id:
			GameState.apply_effects(identity.get("effects", {}))
	GameState.begin_day()
	outcome = {}
	pending_recap_day = 0
	in_game = true
	# Day one starts on the quad: you've just been dropped off.
	location = "campus"
	arrival = "start"
	save()
	change_scene(location)


func continue_game() -> bool:
	var flow: Variant = SaveSystem.load_game()
	if flow == null:
		return false
	location = str((flow as Dictionary).get("location", "dorm"))
	arrival = str((flow as Dictionary).get("arrival", "bed"))
	if not SCENES.has(location):
		location = "dorm"
		arrival = "bed"
	pending_recap_day = 0
	outcome = {}
	in_game = true
	change_scene(location)
	return true


func save() -> void:
	if in_game:
		SaveSystem.save_game({"location": location, "arrival": arrival})


func quit_to_title() -> void:
	save()
	in_game = false
	change_scene("title")


# =============================================================================
# Movement between places
# =============================================================================

## Interior → quad lands at that building's door; quad → interior lands inside its door.
func travel(to_location: String) -> void:
	if _changing:
		return
	var from: String = location
	location = to_location
	if to_location == "campus":
		arrival = CAMPUS_DOORS.get(from, "start")
	else:
		arrival = "door"
	save()
	change_scene(to_location)


func change_scene(key: String) -> void:
	if _changing:
		return
	_changing = true
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.28)
	await tween.finished
	get_tree().change_scene_to_file(SCENES[key])
	# Two frames so the new scene's _ready has run before revealing it.
	await get_tree().process_frame
	await get_tree().process_frame
	_changing = false
	var reveal: Tween = create_tween()
	reveal.tween_property(_fade, "color:a", 0.0, 0.35)


func is_changing_scene() -> bool:
	return _changing


# =============================================================================
# What is here, right now
# =============================================================================

func is_final_day() -> bool:
	return TimeSystem.day >= TimeSystem.FINAL_DAY


func is_event_done(event: Dictionary) -> bool:
	return GameState.has_made_choice(str(event.get("id", "")))


## Story events that are live at this moment (any location), in file order.
func live_events() -> Array:
	var live: Array = []
	var key: String = TimeSystem.period_key()
	for event: Dictionary in ContentDB.get_events():
		if int(event.get("day", 0)) != TimeSystem.day:
			continue
		if key not in event.get("periods", []):
			continue
		if not GameState.meets_requirements(event.get("requires", {})):
			continue
		live.append(event)
	return live


## Who stands where in a location right now. Each entry:
## { npc, spot, event (Dictionary or {}), lines (ambient chatter) }.
## Live story events claim their NPC first; ambient chatter fills in.
func npcs_at(loc: String) -> Array:
	var placed: Dictionary = {}
	var result: Array = []
	for event: Dictionary in live_events():
		var npc: String = str(event["npc"])
		if event["location"] != loc or placed.has(npc):
			continue
		placed[npc] = true
		result.append({"npc": npc, "spot": event["spot"], "event": event, "lines": []})
	var key: String = TimeSystem.period_key()
	for ambient: Dictionary in ContentDB.get_ambient():
		var npc: String = str(ambient["npc"])
		if ambient.get("location") != loc or placed.has(npc):
			continue
		if not has_day(ambient.get("days", []), TimeSystem.day) or key not in ambient.get("periods", []):
			continue
		# An NPC busy with a live event somewhere else is not also here.
		if _npc_busy_elsewhere(npc, loc):
			continue
		placed[npc] = true
		result.append({"npc": npc, "spot": ambient["spot"], "event": {}, "lines": ambient["lines"]})
	return result


## JSON numbers load as floats; compare day lists numerically.
static func has_day(days: Array, day: int) -> bool:
	for d: Variant in days:
		if int(d) == day:
			return true
	return false


func _npc_busy_elsewhere(npc: String, loc: String) -> bool:
	for event: Dictionary in live_events():
		if event["npc"] == npc and event["location"] != loc and not is_event_done(event):
			return true
	return false


## Activity spots in a location whose choices have at least one option for
## this day and period. Each entry is the spot dictionary from content.
func spots_at(loc: String) -> Array:
	var result: Array = []
	for spot: Dictionary in ContentDB.get_activity_spots():
		if spot.get("location") != loc:
			continue
		if not available_choices(spot.get("choices", [])).is_empty():
			result.append(spot)
	return result


## Choices offered right now (day/period filters only). Requirement failures
## stay in the list — the UI shows them disabled with the reason.
func available_choices(choices: Array) -> Array:
	var result: Array = []
	var key: String = TimeSystem.period_key()
	for choice: Dictionary in choices:
		if choice.has("periods") and key not in choice["periods"]:
			continue
		if choice.has("days") and not has_day(choice["days"], TimeSystem.day):
			continue
		# Saturday morning belongs to the evaluation; nothing else runs.
		if is_final_day() and int(choice.get("duration_blocks", 0)) > 0:
			continue
		if choice.has("requirements"):
			var req: Dictionary = choice["requirements"]
			# One-time options vanish once done instead of showing disabled.
			if req.has("not_flag") and GameState.has_flag(str(req["not_flag"])):
				continue
		result.append(choice)
	return result


## "" when the choice can be picked, otherwise why not.
func choice_block_reason(choice: Dictionary) -> String:
	return GameState.requirement_failure(choice.get("requirements", {}))


# =============================================================================
# Consuming choices
# =============================================================================

## Applies a choice made in a conversation or at an activity spot.
## `beat_id` is the event id or spot id. `bonus` merges extra stat deltas
## (from a minigame). Returns { applied, reaction, duration }.
func apply_choice(beat_id: String, choice: Dictionary, bonus: Dictionary = {},
		bonus_text: String = "") -> Dictionary:
	var effects: Dictionary = (choice.get("effects", {}) as Dictionary).duplicate()
	var reaction: String = str(choice.get("reaction", ""))
	var flags: Array = (choice.get("set_flags", []) as Array).duplicate()
	if choice.has("check"):
		var check: Dictionary = choice["check"]
		var passed: bool = GameState.get_stat(str(check["stat"])) >= int(check["min"])
		var branch: Dictionary = check["pass"] if passed else check["fail"]
		for stat: String in (branch.get("effects", {}) as Dictionary).keys():
			effects[stat] = int(effects.get(stat, 0)) + int(branch["effects"][stat])
		reaction = str(branch.get("reaction", reaction))
		flags.append_array(branch.get("set_flags", []))
	for stat: String in bonus.keys():
		effects[stat] = int(effects.get(stat, 0)) + int(bonus[stat])
	if bonus_text != "":
		reaction = (reaction + " " + bonus_text).strip_edges()
	var applied: Dictionary = GameState.apply_effects(effects)
	for flag: String in flags:
		GameState.set_flag(flag)
	GameState.record_choice(beat_id, str(choice.get("id", "")), choice.get("tags", []))
	save()
	objective_changed.emit()
	return {
		"applied": applied,
		"reaction": reaction,
		"duration": int(choice.get("duration_blocks", 0)),
	}


## Spends periods. Returns true when the day rolled over (a night activity
## finished), in which case the caller shows the recap and wakes the player
## in the dorm.
func spend_time(blocks: int) -> bool:
	if blocks <= 0:
		return false
	var day_before: int = TimeSystem.day
	TimeSystem.advance(blocks)
	var rolled: bool = TimeSystem.day != day_before
	if rolled:
		pending_recap_day = day_before
	save()
	objective_changed.emit()
	return rolled


## After the nightly recap: begin the new day waking up in 214.
func start_new_day() -> void:
	pending_recap_day = 0
	GameState.begin_day()
	location = "dorm"
	arrival = "bed"
	save()
	change_scene("dorm")


# =============================================================================
# Objective
# =============================================================================

## What the HUD should nudge the player toward: { text, location, spot }.
## `spot` is an NPC/activity spot id inside `location` ("" for none).
func objective() -> Dictionary:
	for event: Dictionary in live_events():
		if event.has("objective") and not is_event_done(event):
			return {"text": event["objective"], "location": event["location"], "spot": event["spot"]}
	match TimeSystem.period:
		TimeSystem.Period.NIGHT:
			return {"text": "Head back to Hargrove Hall — pick how your night ends", "location": "dorm", "spot": "bed"}
		TimeSystem.Period.MORNING:
			if TimeSystem.day in [2, 3, 4, 5]:
				return {"text": "Kinesiology lecture this morning at Moreno Hall — or skip it", "location": "classroom", "spot": "seat"}
			if TimeSystem.day == 6:
				return {"text": "Kinesiology quiz this morning at Moreno Hall", "location": "classroom", "spot": "seat"}
	return {"text": "Free %s — class, the gym, or the quad. Each activity takes the period." % TimeSystem.period_name().to_lower(), "location": "", "spot": ""}


# =============================================================================
# Minigame tuning
# =============================================================================

## Rounds for each shooting mode. speed/zone multiply the stat-driven base.
func minigame_rounds(kind: String) -> Array:
	match kind:
		"tryout":
			var legs: float = 0.75 + GameState.get_stat("athleticism") * 0.004
			return [
				{"name": "Station 1 · Spot-up", "shots": 5, "speed": 1.0, "zone": 1.0},
				{"name": "Station 2 · Off the dribble", "shots": 4, "speed": 1.22, "zone": 0.92},
				{"name": "Station 3 · Free throws, legs gone", "shots": 3, "speed": 1.12, "zone": legs},
			]
		"showcase":
			return [{"name": "Thursday run · Delgado watching", "shots": 5, "speed": 1.12, "zone": 0.95}]
		_:
			return [{"name": "Shootaround", "shots": 6, "speed": 0.95, "zone": 1.05}]


## Base meter tuning from current stats: zone width (0..1 of the meter)
## and sweep speed (meter lengths per second).
func meter_tuning() -> Dictionary:
	var skill: float = GameState.get_stat("basketball_skill") / 100.0
	var ath: float = GameState.get_stat("athleticism") / 100.0
	var zone: float = lerpf(0.09, 0.25, skill)
	if GameState.has_flag("wristband"):
		zone *= 1.08
	var speed: float = lerpf(1.45, 0.95, ath)
	if GameState.get_stat("energy") < 25:
		speed *= 1.2
		zone *= 0.85
	return {"zone": zone, "speed": speed}


## Converts a minigame result {makes, perfects, shots} into stat bonuses
## and a sentence for the reaction.
func minigame_bonus(kind: String, result: Dictionary) -> Dictionary:
	var makes: int = int(result.get("makes", 0))
	var shots: int = maxi(1, int(result.get("shots", 1)))
	match kind:
		"showcase":
			var interest: int = makes * 2 + int(result.get("perfects", 0))
			var line: String = "You hit %d of %d with Delgado in the doorway." % [makes, shots]
			if makes >= 4:
				line += " On your way out he says, \"Saturday,\" like it's a sentence with more words in it."
			elif makes <= 1:
				line += " He leaves before the run ends. You try not to read into it. You read into it."
			return {"effects": {"coach_interest": interest}, "text": line}
		_:
			var gain: int = makes / 2
			return {
				"effects": {"basketball_skill": gain},
				"text": "%d of %d. %s" % [makes, shots,
					"Your release is starting to feel automatic." if makes >= 4 else "Plenty of rim. That's what practice is for."],
			}


# =============================================================================
# Ending
# =============================================================================

## Records the tryout and decides the verdict. `result` = {makes, perfects, shots}.
func finish_tryout(result: Dictionary) -> void:
	var shots: int = maxi(1, int(result.get("shots", 1)))
	var score: float = 100.0 * (2.0 * int(result.get("makes", 0)) + int(result.get("perfects", 0))) / (3.0 * shots)
	GameState.tryout = {
		"makes": int(result.get("makes", 0)),
		"perfects": int(result.get("perfects", 0)),
		"shots": shots,
		"score": int(round(score)),
	}
	outcome = compute_outcome()
	finish_week()


## The player never signed up: they watch from the bleachers.
func finish_as_spectator() -> void:
	GameState.tryout = {}
	outcome = compute_outcome()
	finish_week()


func finish_week() -> void:
	SaveSystem.clear_save()
	in_game = false
	location = "ending"
	change_scene("ending")


func compute_outcome() -> Dictionary:
	var endings: Dictionary = ContentDB.get_endings()
	var scoring: Dictionary = endings.get("scoring", {})
	var id: String = "not_signed"
	var total: float = 0.0
	if GameState.has_flag("signed_up") and not GameState.tryout.is_empty():
		total = float(GameState.tryout.get("score", 0)) * float(scoring.get("tryout_weight", 0.55)) \
			+ GameState.get_stat("coach_interest") * float(scoring.get("coach_interest_weight", 0.3)) \
			+ GameState.get_stat("basketball_skill") * float(scoring.get("skill_weight", 0.1)) \
			+ GameState.get_stat("athleticism") * float(scoring.get("athleticism_weight", 0.05))
		var eligible: bool = GameState.get_stat("academics") >= int(scoring.get("eligibility_academics_min", 50)) \
			and not GameState.has_flag("quiz_failed")
		if total >= float(scoring.get("roster_min", 52)):
			id = "roster" if eligible else "conditional"
		elif total >= float(scoring.get("practice_min", 40)):
			id = "practice"
		else:
			id = "cut"
	var text: Dictionary = (endings.get("outcomes", {}) as Dictionary).get(id, {})
	return {"id": id, "score": int(round(total)), "title": text.get("title", ""), "text": text.get("text", "")}


## Epilogue sentences for the ending card, keyed by the endings.json tables.
func epilogue_lines() -> Array[String]:
	var lines: Array[String] = []
	var epilogues: Dictionary = ContentDB.get_endings().get("epilogues", {})
	for pair: Array in [["jordan", "roommate_relationship"], ["academics", "academics"]]:
		for tier: Dictionary in epilogues.get(pair[0], []):
			if GameState.get_stat(pair[1]) >= int(tier.get("min", 0)):
				lines.append(str(tier["text"]))
				break
	var trait_lines: Dictionary = epilogues.get("trait", {})
	lines.append(str(trait_lines.get(GameState.primary_tag(), trait_lines.get("", ""))))
	return lines
