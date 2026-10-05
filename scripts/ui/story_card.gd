extends PanelContainer
## The one card every face-to-face moment uses: NPC conversations, activity
## spots, and the result of a choice. Flow: lines (Continue) → choices →
## result with stat chips (Continue) → `finished`. Bottom-anchored and kept
## shallow so the world stays visible behind it.

signal choice_made(choice: Dictionary)
signal finished

const PORTRAIT_DIR: String = "res://assets/portraits/"

var _portrait_frame: PanelContainer
var _portrait: TextureRect
var _name: Label
var _role: Label
var _text: Label
var _choices: VBoxContainer
var _result_row: Control
var _continue: Button
var _close: Button
var _lines: Array = []
var _line_index: int = 0
var _pending_choices: Array = []
var _must_answer: bool = false
var _block_reason: Callable = func(_c: Dictionary) -> String: return ""


func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -440
	offset_right = 440
	offset_top = -200
	offset_bottom = -18
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = UIKit.panel_style(0.94)
	style.border_width_left = 5
	add_theme_stylebox_override("panel", style)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	add_child(row)

	_portrait_frame = PanelContainer.new()
	_portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var frame_style: StyleBoxFlat = StyleBoxFlat.new()
	frame_style.bg_color = UIKit.NAVY
	frame_style.set_corner_radius_all(14)
	frame_style.border_color = UIKit.GOLD
	frame_style.set_border_width_all(2)
	frame_style.set_content_margin_all(3)
	_portrait_frame.add_theme_stylebox_override("panel", frame_style)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(104, 104)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_portrait_frame.add_child(_portrait)
	row.add_child(_portrait_frame)

	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	row.add_child(column)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	_name = UIKit.label("", 22, UIKit.GOLD)
	header.add_child(_name)
	_role = UIKit.label("", 15, UIKit.MUTED)
	_role.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_role)

	_text = UIKit.wrap_label("", 19)
	_text.name = "Text"
	column.add_child(_text)

	_result_row = Control.new()
	column.add_child(_result_row)

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 8)
	column.add_child(_choices)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	column.add_child(buttons)
	_close = UIKit.button("Not now", false, 46)
	_close.custom_minimum_size.x = 130
	_close.pressed.connect(_on_close)
	buttons.add_child(_close)
	_continue = UIKit.button("Continue", true, 46)
	_continue.name = "Continue"
	_continue.custom_minimum_size.x = 150
	_continue.pressed.connect(advance)
	buttons.add_child(_continue)


func is_open() -> bool:
	return visible


## Lines shown one at a time, then the choices (if any). With no choices
## the card closes after the last line.
func open_conversation(npc_id: String, speaker: String, role: String, lines: Array,
		choices: Array, block_reason: Callable) -> void:
	_set_header(speaker, role, npc_id)
	_lines = lines.duplicate()
	_line_index = 0
	_pending_choices = choices
	_block_reason = block_reason
	_must_answer = true
	_clear_result()
	_show_line()
	visible = true


## An activity spot: description, the options, and a way out.
func open_activity(title: String, text: String, choices: Array, block_reason: Callable) -> void:
	_set_header(title, "", "")
	_lines = [text]
	_line_index = 0
	_pending_choices = choices
	_block_reason = block_reason
	_must_answer = false
	_clear_result()
	_text.text = text
	_show_choices()
	visible = true


## Result of a choice: reaction text plus "+8 Academics" chips, then Continue.
func show_result(text: String, applied: Dictionary) -> void:
	_clear_choices()
	_clear_result()
	_text.text = text
	var chips: HFlowContainer = UIKit.delta_row(applied)
	chips.name = "Deltas"
	_result_row.add_child(chips)
	_result_row.custom_minimum_size.y = 30 if not applied.is_empty() else 0
	_lines = []
	_pending_choices = []
	_continue.visible = true
	_continue.text = "Continue"
	_close.visible = false
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	finished.emit()


## Continue: next line, then the choices, then close.
func advance() -> void:
	if not visible or not _continue.visible:
		return
	_line_index += 1
	if _line_index < _lines.size():
		_show_line()
	elif not _pending_choices.is_empty() and _choices.get_child_count() == 0:
		_show_choices()
	else:
		close()


func choice_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for child in _choices.get_children():
		if child is Button:
			result.append(child)
	return result


func pick(index: int) -> void:
	var buttons: Array[Button] = choice_buttons()
	if index >= 0 and index < buttons.size() and not buttons[index].disabled:
		buttons[index].pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = (event as InputEventKey).physical_keycode
		if key >= KEY_1 and key <= KEY_4 and _choices.get_child_count() > 0:
			pick(key - KEY_1)
			get_viewport().set_input_as_handled()
		elif key == KEY_ESCAPE and _close.visible:
			_on_close()
			get_viewport().set_input_as_handled()


func _set_header(title: String, role: String, npc_id: String) -> void:
	_name.text = title
	_role.text = role
	var path: String = PORTRAIT_DIR + npc_id + ".png"
	if npc_id != "" and ResourceLoader.exists(path):
		_portrait.texture = load(path)
		_portrait_frame.visible = true
	else:
		_portrait_frame.visible = false


func _show_line() -> void:
	_clear_choices()
	_text.text = str(_lines[_line_index])
	_continue.visible = true
	var last: bool = _line_index >= _lines.size() - 1
	_continue.text = "Continue" if not last or _pending_choices.is_empty() else "Respond"
	_close.visible = false


func _show_choices() -> void:
	_clear_choices()
	_continue.visible = false
	_close.visible = true
	_close.text = "Not now"
	var number: int = 1
	for choice: Dictionary in _pending_choices:
		var reason: String = _block_reason.call(choice)
		var text: String = str(choice.get("label", ""))
		if not UIKit.is_touch():
			text = "%d   %s" % [number, text]
		if reason != "":
			text += "   — " + reason
		var b: Button = UIKit.button(text, false, 48)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.disabled = reason != ""
		b.pressed.connect(_on_choice.bind(choice))
		_choices.add_child(b)
		number += 1
	# Conversations with an NPC must be answered, unless every option is locked.
	if _must_answer:
		var any_enabled: bool = false
		for b in choice_buttons():
			any_enabled = any_enabled or not b.disabled
		_close.visible = not any_enabled


func _on_choice(choice: Dictionary) -> void:
	_clear_choices()
	_close.visible = false
	choice_made.emit(choice)


func _on_close() -> void:
	close()


func _clear_choices() -> void:
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()


func _clear_result() -> void:
	for child in _result_row.get_children():
		_result_row.remove_child(child)
		child.queue_free()
	_result_row.custom_minimum_size.y = 0
