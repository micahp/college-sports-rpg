extends Node
## Loads and validates JSON content from res://data/.
## All narrative and mechanical content flows through here so the
## simulation code never hardcodes story.

const IDENTITIES_PATH: String = "res://data/characters/identities.json"
const LOOKS_PATH: String = "res://data/characters/looks.json"
const NPCS_PATH: String = "res://data/world/npcs.json"
const ACTIVITIES_PATH: String = "res://data/world/activities.json"
const EVENTS_PATH: String = "res://data/story/events.json"
const ENDINGS_PATH: String = "res://data/story/endings.json"
const LOCATIONS: Array[String] = ["campus", "dorm", "classroom", "gym"]

const VALID_PERIODS: Array[String] = ["morning", "afternoon", "evening", "night"]
const STAT_KEYS: Array[String] = [
	"energy", "academics", "athleticism", "basketball_skill",
	"roommate_relationship", "coach_interest",
]

var _cache: Dictionary = {}


func get_identities() -> Array:
	var data: Variant = _load_json(IDENTITIES_PATH)
	if data == null or not data is Dictionary:
		return []
	return data.get("identities", [])


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Content file missing: %s" % path)
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null:
		push_error("Content file is not valid JSON: %s" % path)
	return parsed


# =============================================================================
# Week content (full game)
# =============================================================================

func get_looks() -> Array:
	return _cached_list(LOOKS_PATH, "looks")


func get_look(look_id: String) -> Dictionary:
	for look: Dictionary in get_looks():
		if look.get("id", "") == look_id:
			return look
	var looks: Array = get_looks()
	return looks[0] if not looks.is_empty() else {}


## { npc_id: {name, role, model, skin, shirt, pants, hair} }
func get_npcs() -> Dictionary:
	if not _cache.has(NPCS_PATH):
		var data: Variant = _load_json(NPCS_PATH)
		_cache[NPCS_PATH] = (data as Dictionary).get("npcs", {}) if data is Dictionary else {}
	return _cache[NPCS_PATH]


func get_activity_spots() -> Array:
	return _cached_list(ACTIVITIES_PATH, "spots")


func get_events() -> Array:
	return _cached_list(EVENTS_PATH, "events")


func get_ambient() -> Array:
	return _cached_list(EVENTS_PATH, "ambient")


func get_endings() -> Dictionary:
	if not _cache.has(ENDINGS_PATH):
		var data: Variant = _load_json(ENDINGS_PATH)
		_cache[ENDINGS_PATH] = data if data is Dictionary else {}
	return _cache[ENDINGS_PATH]


func _cached_list(path: String, key: String) -> Array:
	var cache_key: String = path + "#" + key
	if not _cache.has(cache_key):
		var data: Variant = _load_json(path)
		_cache[cache_key] = (data as Dictionary).get(key, []) if data is Dictionary else []
	return _cache[cache_key]


## Validates every week content file. Returns a list of human-readable
## problems; empty means the content is sound. Used by tests/run_checks.gd.
func validate_week_content() -> Array[String]:
	var problems: Array[String] = []
	var npcs: Dictionary = get_npcs()
	if npcs.is_empty():
		problems.append("npcs.json has no npcs")
	for npc_id: String in npcs.keys():
		for field in ["name", "model", "skin", "shirt", "pants", "hair"]:
			if not (npcs[npc_id] as Dictionary).has(field):
				problems.append("npc %s missing %s" % [npc_id, field])
	var seen: Dictionary = {}
	for spot: Dictionary in get_activity_spots():
		for field in ["id", "location", "spot", "prompt", "title", "choices"]:
			if not spot.has(field):
				problems.append("activity spot %s missing %s" % [spot.get("id", "?"), field])
		if str(spot.get("location", "")) not in LOCATIONS:
			problems.append("activity spot %s has bad location" % spot.get("id", "?"))
		for choice: Dictionary in spot.get("choices", []):
			_validate_choice("spot " + str(spot.get("id")), choice, problems, seen)
	for event: Dictionary in get_events():
		var label: String = "event " + str(event.get("id", "?"))
		for field in ["id", "npc", "location", "spot", "day", "periods", "lines", "choices"]:
			if not event.has(field):
				problems.append("%s missing %s" % [label, field])
		if not npcs.has(str(event.get("npc", ""))):
			problems.append("%s references unknown npc" % label)
		if str(event.get("location", "")) not in LOCATIONS:
			problems.append("%s has bad location" % label)
		for p: String in event.get("periods", []):
			if p not in VALID_PERIODS:
				problems.append("%s has bad period %s" % [label, p])
		if seen.has("event:" + str(event.get("id"))):
			problems.append("%s is duplicated" % label)
		seen["event:" + str(event.get("id"))] = true
		for choice: Dictionary in event.get("choices", []):
			_validate_choice(label, choice, problems, {})
	for ambient: Dictionary in get_ambient():
		if not npcs.has(str(ambient.get("npc", ""))):
			problems.append("ambient entry references unknown npc")
		if (ambient.get("lines", []) as Array).is_empty():
			problems.append("ambient entry for %s has no lines" % ambient.get("npc", "?"))
	var endings: Dictionary = get_endings()
	for outcome in ["roster", "conditional", "practice", "cut", "not_signed"]:
		if not (endings.get("outcomes", {}) as Dictionary).has(outcome):
			problems.append("endings missing outcome %s" % outcome)
	return problems


func _validate_choice(owner: String, choice: Dictionary, problems: Array[String],
		seen: Dictionary) -> void:
	for field in ["id", "label", "reaction"]:
		if not choice.has(field) and not choice.has("check"):
			problems.append("%s choice missing %s" % [owner, field])
	var id_key: String = "choice:" + str(choice.get("id", ""))
	if seen.has(id_key):
		problems.append("%s duplicate choice id %s" % [owner, choice.get("id")])
	seen[id_key] = true
	var effect_blocks: Array = [choice.get("effects", {})]
	if choice.has("check"):
		var check: Dictionary = choice["check"]
		for branch in ["pass", "fail"]:
			if not check.has(branch):
				problems.append("%s check missing %s" % [owner, branch])
			else:
				effect_blocks.append((check[branch] as Dictionary).get("effects", {}))
	for effects: Dictionary in effect_blocks:
		for stat: String in effects.keys():
			if stat not in STAT_KEYS:
				problems.append("%s choice %s targets unknown stat %s" % [owner, choice.get("id"), stat])
	for p: String in choice.get("periods", []):
		if p not in VALID_PERIODS:
			problems.append("%s choice %s has bad period %s" % [owner, choice.get("id"), p])
