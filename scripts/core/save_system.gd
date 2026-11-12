extends Node
## Single-slot JSON save in user://. Autosaved after every choice.
## Versioned: a mismatched version is treated as no save (MVP has no migrations).

const SAVE_PATH: String = "user://save_v2.json"
const SAVE_VERSION: int = 2


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
	_web_store(JSON.stringify(payload, "\t"))


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
	_web_clear()


## Reads and validates the save file without touching game state.
func _read_payload() -> Variant:
	var text: String = ""
	if FileAccess.file_exists(SAVE_PATH):
		var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			text = file.get_as_text()
	if text.is_empty():
		# Web builds keep a mirror in localStorage, which survives when the
		# browser's IndexedDB file storage does not.
		text = _web_fetch()
	if text.is_empty():
		return null
	var payload: Variant = JSON.parse_string(text)
	if not payload is Dictionary or int(payload.get("version", -1)) != SAVE_VERSION:
		return null
	return payload


const WEB_KEY: String = "the_u_save_v2"


func _web_store(text: String) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("try { localStorage.setItem(%s, %s); } catch (e) {}" % [
		JSON.stringify(WEB_KEY), JSON.stringify(text)], true)


func _web_fetch() -> String:
	if not OS.has_feature("web"):
		return ""
	var value: Variant = JavaScriptBridge.eval(
		"(function () { try { return localStorage.getItem(%s) || ''; } catch (e) { return ''; } })()"
		% JSON.stringify(WEB_KEY), true)
	return str(value) if value != null else ""


func _web_clear() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("try { localStorage.removeItem(%s); } catch (e) {}" % JSON.stringify(WEB_KEY), true)
