extends PanelContainer
## Compact dialogue box over the game world. Flow per conversation:
## lines (advance with interact/tap) -> choice buttons -> reaction with the
## stat deltas spelled out -> close. Repeat visits get lines only, no choices.
## The campus applies choice effects; this panel only presents.

signal choice_selected(choice: Dictionary)
signal finished

enum State { LINES, CHOICES, REACTION }

var state: int = State.LINES

var _lines: Array = []
var _choices: Array = []
var _index: int = 0
var _name_label: Label
var _text_label: Label
var _choices_box: VBoxContainer
var _hint: Label


## Touch devices never see keyboard hints.
static func hint_text(touch: bool) -> String:
	return "tap to continue" if touch else "E / tap to continue"


func _ready() -> void:
	position = Vector2(200, 415)
	size = Vector2(880, 290)
	visible = false

	var margin: MarginContainer = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 20)
	add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.add_theme_color_override("font_color", Color("e8b64c"))
	column.add_child(_name_label)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 20)
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_text_label)

	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 8)
	_choices_box.visible = false
	column.add_child(_choices_box)

	_hint = Label.new()
	_hint.text = hint_text(DisplayServer.is_touchscreen_available())
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	column.add_child(_hint)


func open(speaker: String, lines: Array, choices: Array) -> void:
	_lines = lines
	_choices = choices
	_index = 0
	state = State.LINES
	_name_label.text = speaker
	_text_label.text = str(_lines[0]) if not _lines.is_empty() else ""
	_clear_choice_buttons()
	_choices_box.visible = false
	_hint.visible = true
	visible = true


## Interact/tap. Steps lines forward, then either surfaces choices or closes.
## Ignored while choices are on screen — the player must pick one.
func advance() -> void:
	match state:
		State.LINES:
			_index += 1
			if _index < _lines.size():
				_text_label.text = str(_lines[_index])
			elif _choices.is_empty():
				_close()
			else:
				_show_choices()
		State.CHOICES:
			pass
		State.REACTION:
			_close()


## Called by the campus after applying a choice's effects.
func show_reaction(text: String) -> void:
	state = State.REACTION
	_clear_choice_buttons()
	_choices_box.visible = false
	_text_label.text = text
	_hint.visible = true


func _show_choices() -> void:
	state = State.CHOICES
	_hint.visible = false
	_choices_box.visible = true
	for choice: Dictionary in _choices:
		var button: Button = Button.new()
		button.text = str(choice["label"])
		button.custom_minimum_size = Vector2(0, 50)
		button.focus_mode = Control.FOCUS_NONE
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(func() -> void: choice_selected.emit(choice))
		_choices_box.add_child(button)


func _clear_choice_buttons() -> void:
	for child in _choices_box.get_children():
		child.queue_free()


func _close() -> void:
	visible = false
	finished.emit()


func _gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if visible and tapped and state != State.CHOICES:
		advance()
		accept_event()
