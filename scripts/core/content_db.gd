extends Node
## Loads and validates JSON content from res://data/.
## All narrative and mechanical content flows through here so the
## simulation code never hardcodes story.

const DAYS_DIR: String = "res://data/days/"
const IDENTITIES_PATH: String = "res://data/characters/identities.json"
const NPC_DIALOGUE_PATH: String = "res://data/dialogue/day1_npcs.json"

const VALID_PERIODS: Array[String] = ["morning", "afternoon", "evening", "night"]

var _npc_cache: Dictionary = {}


## Returns the ordered beat list for a day, or [] with an error pushed on failure.
func get_day(day: int) -> Array:
	var data: Variant = _load_json(DAYS_DIR + "day_%d.json" % day)
	if data == null or not data is Dictionary:
		return []
	var beats: Array = data.get("beats", [])
	if not _validate_beats(beats):
		return []
	return beats


func get_identities() -> Array:
	var data: Variant = _load_json(IDENTITIES_PATH)
	if data == null or not data is Dictionary:
		return []
	return data.get("identities", [])


## Returns { npc_id: {name, lines, choices, repeat_line} }, cached after first load.
func get_npc_dialogues() -> Dictionary:
	if not _npc_cache.is_empty():
		return _npc_cache
	var data: Variant = _load_json(NPC_DIALOGUE_PATH)
	if data == null or not data is Dictionary:
		return {}
	var npcs: Dictionary = data.get("npcs", {})
	if _validate_npcs(npcs):
		_npc_cache = npcs
	return _npc_cache


func _validate_npcs(npcs: Dictionary) -> bool:
	if npcs.is_empty():
		push_error("NPC dialogue file has no npcs")
		return false
	for npc_id: String in npcs.keys():
		var npc: Dictionary = npcs[npc_id]
		for field in ["name", "lines", "choices", "repeat_line"]:
			if not npc.has(field):
				push_error("NPC %s missing field '%s'" % [npc_id, field])
				return false
		if (npc["lines"] as Array).is_empty():
			push_error("NPC %s has no lines" % npc_id)
			return false
		for choice: Dictionary in npc["choices"]:
			for field in ["id", "label", "effects", "reaction"]:
				if not choice.has(field):
					push_error("NPC %s choice missing '%s'" % [npc_id, field])
					return false
	return true


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Content file missing: %s" % path)
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null:
		push_error("Content file is not valid JSON: %s" % path)
	return parsed


func _validate_beats(beats: Array) -> bool:
	if beats.is_empty():
		push_error("Day file has no beats")
		return false
	var last_period_index: int = -1
	for beat: Dictionary in beats:
		for field in ["id", "period", "text", "choices"]:
			if not beat.has(field):
				push_error("Beat %s missing field '%s'" % [beat.get("id", "?"), field])
				return false
		var period_index: int = VALID_PERIODS.find(str(beat["period"]))
		if period_index < 0:
			push_error("Beat %s has invalid period '%s'" % [beat["id"], beat["period"]])
			return false
		if period_index < last_period_index:
			push_error("Beat %s is out of period order" % beat["id"])
			return false
		last_period_index = period_index
		if (beat["choices"] as Array).is_empty():
			push_error("Beat %s has no choices" % beat["id"])
			return false
	return true
