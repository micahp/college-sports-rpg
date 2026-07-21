extends Node
## Single-slot JSON save in user://. Autosaved after every choice.
## Versioned: a mismatched version is treated as no save (MVP has no migrations).

const SAVE_PATH: String = "user://save_v1.json"
const SAVE_VERSION: int = 1


func has_save() -> bool:
	return _read_payload() != null


## Persists global state plus the caller's flow position (e.g. beat index).
func save_game(flow_state: Dictionary) -> void:
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"time": TimeSystem.to_save_dict(),
		"player": GameState.to_save_dict(),
		"flow": flow_state,
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not open save file for writing: %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(payload, "\t"))


## Restores GameState and TimeSystem from disk and returns the flow_state dict,
## or null when there is no usable save. Only call when resuming is intended.
func load_game() -> Variant:
	var payload: Variant = _read_payload()
	if payload == null:
		return null
	GameState.from_save_dict(payload.get("player", {}))
	TimeSystem.from_save_dict(payload.get("time", {}))
	return payload.get("flow", {})


func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


## Reads and validates the save file without touching game state.
func _read_payload() -> Variant:
	if not FileAccess.file_exists(SAVE_PATH):
		return null
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return null
	var payload: Variant = JSON.parse_string(file.get_as_text())
	if not payload is Dictionary or int(payload.get("version", -1)) != SAVE_VERSION:
		return null
	return payload
