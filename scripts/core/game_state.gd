extends Node
## Single source of truth for the player's simulation state.
## Everything the recaps, the ending, and the save file need lives here.

signal stat_changed(stat: String, old_value: int, new_value: int)

const STAT_MIN: int = 0
const STAT_MAX: int = 100

const STAT_KEYS: Array[String] = [
	"energy",
	"academics",
	"athleticism",
	"basketball_skill",
	"roommate_relationship",
	"coach_interest",
]

const STAT_LABELS: Dictionary = {
	"energy": "Energy",
	"academics": "Academics",
	"athleticism": "Athleticism",
	"basketball_skill": "Basketball",
	"roommate_relationship": "Jordan",
	"coach_interest": "Coach Interest",
}

var player_name: String = "Freshman"
var identity_id: String = ""
var look_id: String = ""
var stats: Dictionary = {}
var choice_history: Array[Dictionary] = []
## Story switches set by choices (e.g. "signed_up"). Values are always true;
## absence means unset.
var flags: Dictionary = {}
## Stats at the start of the current day, for the nightly recap.
var day_start_stats: Dictionary = {}
## Filled in by the tryout minigame; read by the ending.
var tryout: Dictionary = {}


func _ready() -> void:
	reset()


func reset() -> void:
	player_name = "Freshman"
	identity_id = ""
	look_id = ""
	stats = {
		"energy": 80,
		"academics": 50,
		"athleticism": 50,
		"basketball_skill": 40,
		"roommate_relationship": 10,
		"coach_interest": 0,
	}
	choice_history.clear()
	flags.clear()
	tryout.clear()
	day_start_stats = stats.duplicate()


func get_stat(stat: String) -> int:
	return int(stats.get(stat, 0))


## Skills get harder to raise the better you already are: gains shrink as
## the stat climbs (full value up to 25, about half at 75). Relationships,
## coach interest and energy are not scaled.
const DIMINISHING_STATS: Array[String] = ["academics", "athleticism", "basketball_skill"]


static func scaled_gain(stat: String, current: int, delta: int) -> int:
	if delta <= 0 or stat not in DIMINISHING_STATS:
		return delta
	var scale: float = clampf(1.25 - current / 100.0, 0.25, 1.0)
	return maxi(1, int(round(delta * scale)))


## Applies a dict of integer deltas, clamping every result to 0-100.
## Returns the actual applied deltas (post-clamp, post-diminishing) so the
## UI can report them honestly.
func apply_effects(effects: Dictionary) -> Dictionary:
	var applied: Dictionary = {}
	for key: String in effects.keys():
		if key not in STAT_KEYS:
			push_warning("Unknown stat in effects: %s" % key)
			continue
		var old_value: int = get_stat(key)
		var delta: int = scaled_gain(key, old_value, int(effects[key]))
		var new_value: int = clampi(old_value + delta, STAT_MIN, STAT_MAX)
		if new_value != old_value:
			stats[key] = new_value
			applied[key] = new_value - old_value
			stat_changed.emit(key, old_value, new_value)
	return applied


## True when the player's current state satisfies a requirements block.
## Supported keys: energy_min (int), stat_min ({stat: int}), flag (String),
## not_flag (String).
func meets_requirements(requirements: Dictionary) -> bool:
	return requirement_failure(requirements) == ""


## Human-readable reason a requirements block fails, or "" when it passes.
## Shown on disabled buttons — choices are never silently hidden for stats.
func requirement_failure(requirements: Dictionary) -> String:
	if requirements.has("energy_min") and get_stat("energy") < int(requirements["energy_min"]):
		return "Needs %d energy" % int(requirements["energy_min"])
	var stat_min: Dictionary = requirements.get("stat_min", {})
	for stat: String in stat_min.keys():
		if get_stat(stat) < int(stat_min[stat]):
			return "Needs %d %s" % [int(stat_min[stat]), STAT_LABELS.get(stat, stat)]
	if requirements.has("flag") and not has_flag(str(requirements["flag"])):
		return "Not available yet"
	if requirements.has("not_flag") and has_flag(str(requirements["not_flag"])):
		return "Already done"
	return ""


func set_flag(flag: String) -> void:
	flags[flag] = true


func has_flag(flag: String) -> bool:
	return flags.has(flag)


func record_choice(beat_id: String, choice_id: String, tags: Array) -> void:
	choice_history.append({"beat": beat_id, "choice": choice_id, "tags": tags})


## True when any choice has been recorded for this beat — used to make
## one-time conversations unrepeatable for stat farming.
func has_made_choice(beat_id: String) -> bool:
	for entry: Dictionary in choice_history:
		if entry.get("beat", "") == beat_id:
			return true
	return false


func choice_for(beat_id: String) -> String:
	for entry: Dictionary in choice_history:
		if entry.get("beat", "") == beat_id:
			return str(entry.get("choice", ""))
	return ""


## Counts choice tags across the run; the recaps use the winner as "primary trait".
func tag_counts() -> Dictionary:
	var counts: Dictionary = {}
	for entry: Dictionary in choice_history:
		for tag: String in entry.get("tags", []):
			counts[tag] = int(counts.get(tag, 0)) + 1
	return counts


func primary_tag() -> String:
	var counts: Dictionary = tag_counts()
	var best: String = ""
	var best_count: int = 0
	# Stable order so ties resolve the same way every time.
	for tag: String in ["grind", "scholar", "social", "rest"]:
		if int(counts.get(tag, 0)) > best_count:
			best = tag
			best_count = int(counts[tag])
	return best


func begin_day() -> void:
	day_start_stats = stats.duplicate()


## Stat changes since the current day began, non-zero entries only.
func day_deltas() -> Dictionary:
	var deltas: Dictionary = {}
	for key in STAT_KEYS:
		var d: int = get_stat(key) - int(day_start_stats.get(key, get_stat(key)))
		if d != 0:
			deltas[key] = d
	return deltas


func to_save_dict() -> Dictionary:
	return {
		"player_name": player_name,
		"identity": identity_id,
		"look": look_id,
		"stats": stats.duplicate(),
		"choice_history": choice_history.duplicate(true),
		"flags": flags.duplicate(),
		"day_start_stats": day_start_stats.duplicate(),
		"tryout": tryout.duplicate(),
	}


func from_save_dict(data: Dictionary) -> void:
	player_name = str(data.get("player_name", "Freshman"))
	identity_id = str(data.get("identity", ""))
	look_id = str(data.get("look", ""))
	var saved_stats: Dictionary = data.get("stats", {})
	for key in STAT_KEYS:
		stats[key] = clampi(int(saved_stats.get(key, stats.get(key, 0))), STAT_MIN, STAT_MAX)
	choice_history.clear()
	for entry in data.get("choice_history", []):
		if entry is Dictionary:
			choice_history.append(entry)
	flags = (data.get("flags", {}) as Dictionary).duplicate()
	var saved_start: Dictionary = data.get("day_start_stats", {})
	day_start_stats = stats.duplicate()
	for key in STAT_KEYS:
		if saved_start.has(key):
			day_start_stats[key] = int(saved_start[key])
	tryout = (data.get("tryout", {}) as Dictionary).duplicate()
