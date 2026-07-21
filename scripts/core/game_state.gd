extends Node
## Single source of truth for the player's simulation state.
## Everything the recap and save file need lives here.

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

var player_name: String = "Freshman"
var identity_id: String = ""
var stats: Dictionary = {}
var choice_history: Array[Dictionary] = []


func _ready() -> void:
	reset()


func reset() -> void:
	player_name = "Freshman"
	identity_id = ""
	stats = {
		"energy": 80,
		"academics": 50,
		"athleticism": 50,
		"basketball_skill": 40,
		"roommate_relationship": 10,
		"coach_interest": 0,
	}
	choice_history.clear()


func get_stat(stat: String) -> int:
	return int(stats.get(stat, 0))


## Applies a dict of integer deltas, clamping every result to 0-100.
## Returns the actual applied deltas (post-clamp) so the UI can report them honestly.
func apply_effects(effects: Dictionary) -> Dictionary:
	var applied: Dictionary = {}
	for key: String in effects.keys():
		if key not in STAT_KEYS:
			push_warning("Unknown stat in effects: %s" % key)
			continue
		var old_value: int = get_stat(key)
		var new_value: int = clampi(old_value + int(effects[key]), STAT_MIN, STAT_MAX)
		if new_value != old_value:
			stats[key] = new_value
			applied[key] = new_value - old_value
			stat_changed.emit(key, old_value, new_value)
	return applied


## True when the player's current state satisfies a choice's requirements block.
func meets_requirements(requirements: Dictionary) -> bool:
	if requirements.has("energy_min") and get_stat("energy") < int(requirements["energy_min"]):
		return false
	return true


func record_choice(beat_id: String, choice_id: String, tags: Array) -> void:
	choice_history.append({"beat": beat_id, "choice": choice_id, "tags": tags})


## Counts choice tags across the run; the recap uses the winner as "primary trait".
func tag_counts() -> Dictionary:
	var counts: Dictionary = {}
	for entry: Dictionary in choice_history:
		for tag: String in entry.get("tags", []):
			counts[tag] = int(counts.get(tag, 0)) + 1
	return counts


func to_save_dict() -> Dictionary:
	return {
		"player_name": player_name,
		"identity": identity_id,
		"stats": stats.duplicate(),
		"choice_history": choice_history.duplicate(true),
	}


func from_save_dict(data: Dictionary) -> void:
	player_name = str(data.get("player_name", "Freshman"))
	identity_id = str(data.get("identity", ""))
	var saved_stats: Dictionary = data.get("stats", {})
	for key in STAT_KEYS:
		stats[key] = clampi(int(saved_stats.get(key, stats.get(key, 0))), STAT_MIN, STAT_MAX)
	choice_history.clear()
	for entry in data.get("choice_history", []):
		if entry is Dictionary:
			choice_history.append(entry)
