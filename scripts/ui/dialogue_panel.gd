extends PanelContainer
## Compact dialogue box over the game world: speaker name, one line at a time,
## advanced by the interact action, the TALK button, or tapping the panel.
## Milestone 1 shows linear lines only; response choices arrive in Milestone 2.

signal finished

var _lines: Array[String] = []
var _index: int = 0
var _name_label: Label
var _text_label: Label


func _ready() -> void:
	position = Vector2(240, 480)
	size = Vector2(800, 200)
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
	_text_label.add_theme_font_size_override("font_size", 21)
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_text_label)

	var hint: Label = Label.new()
	hint.text = "E / tap to continue"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	column.add_child(hint)


func open(speaker: String, lines: Array[String]) -> void:
	_lines = lines
	_index = 0
	_name_label.text = speaker
	_text_label.text = _lines[0] if not _lines.is_empty() else ""
	visible = true


func advance() -> void:
	_index += 1
	if _index >= _lines.size():
		visible = false
		finished.emit()
	else:
		_text_label.text = _lines[_index]


func _gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if visible and tapped:
		advance()
		accept_event()
