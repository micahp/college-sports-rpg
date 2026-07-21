extends Node
## End-to-end autoplay of the Day One slice.
## Run from the project root:  godot --headless tests/autoplay.tscn
## Drives the real UI: title -> character creation -> four beats -> recap,
## then verifies the autosave resumes correctly. Exits 0 on success.

var _failures: int = 0
var _main: Control


func _ready() -> void:
	await _run()
	if _failures == 0:
		print("\nAUTOPLAY PASSED")
	else:
		printerr("\n%d AUTOPLAY CHECK(S) FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	SaveSystem.clear_save()
	GameState.reset()
	TimeSystem.reset()
	_main = load("res://scenes/app/main.tscn").instantiate()
	add_child(_main)
	await _settle()

	_check(_press("New Game"), "title screen has New Game")
	await _settle()

	var name_edit: LineEdit = _find_line_edit(_main)
	_check(name_edit != null, "character creation has a name field")
	if name_edit != null:
		name_edit.text = "Testy"
	_check(_buttons().size() == 3, "three identity buttons")
	_check(_press_first_enabled(), "identity can be picked")
	await _settle()

	for beat_number in 4:
		_check(_press_first_enabled(), "beat %d: a choice is pressable" % (beat_number + 1))
		await _settle()
		_check(_press_first_enabled(), "beat %d: reaction continue works" % (beat_number + 1))
		await _settle()

	var recap: String = _body_text()
	_check(recap.contains("TESTY"), "recap names the player")
	_check(recap.contains("Coach Interest"), "recap includes coach interest")
	_check(recap.contains("Primary Trait"), "recap includes primary trait")
	_check(FileAccess.file_exists(SaveSystem.SAVE_PATH), "autosave file exists")

	# Relaunch: a finished save should offer Continue and return to the recap.
	_main.queue_free()
	await _settle()
	_main = load("res://scenes/app/main.tscn").instantiate()
	add_child(_main)
	await _settle()
	_check(_press("Continue"), "relaunch offers Continue")
	await _settle()
	_check(_body_text().contains("TESTY"), "Continue restores the finished run's recap")

	_check(_press("Play Again"), "recap offers Play Again")
	await _settle()
	_check(not SaveSystem.has_save(), "Play Again clears the save")
	_main.queue_free()


# --- Helpers -----------------------------------------------------------------

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok    %s" % label)
	else:
		_failures += 1
		printerr("  FAIL  %s" % label)


func _buttons(node: Node = null) -> Array:
	if node == null:
		node = _main
	var found: Array = []
	for child in node.get_children():
		if child is Button and not child.is_queued_for_deletion() and not (child as Button).disabled:
			found.append(child)
		found.append_array(_buttons(child))
	return found


func _press(label: String) -> bool:
	for button: Button in _buttons():
		if button.text.begins_with(label):
			button.pressed.emit()
			return true
	return false


func _press_first_enabled() -> bool:
	var buttons: Array = _buttons()
	if buttons.is_empty():
		return false
	(buttons[0] as Button).pressed.emit()
	return true


func _find_line_edit(node: Node) -> LineEdit:
	if node is LineEdit and not node.is_queued_for_deletion():
		return node
	for child in node.get_children():
		var result: LineEdit = _find_line_edit(child)
		if result != null:
			return result
	return null


func _body_text(node: Node = null) -> String:
	if node == null:
		node = _main
	if node is RichTextLabel:
		return (node as RichTextLabel).get_parsed_text()
	for child in node.get_children():
		var text: String = _body_text(child)
		if not text.is_empty():
			return text
	return ""
