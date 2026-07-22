extends PanelContainer
## Branded dialogue card: speaker portrait in a gold frame, name, one line,
## Continue. Anchored to the bottom-center with responsive offsets so it
## works on any landscape ratio, and kept shallow so the scene stays visible.

signal closed

const NAVY: Color = Color(0.12, 0.2, 0.36)
const GOLD: Color = Color(0.92, 0.72, 0.3)
const PORTRAITS: Dictionary = {
	"Jordan Hayes": "res://assets/branding/portrait_jordan.png",
}

var _portrait: TextureRect


func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -370
	offset_right = 370
	offset_top = -172
	offset_bottom = -20
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	visible = false

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.085, 0.15, 0.93)
	style.set_corner_radius_all(18)
	style.border_color = Color(GOLD, 0.4)
	style.set_border_width_all(1)
	style.border_width_left = 5
	style.content_margin_left = 18
	style.content_margin_right = 22
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 16
	add_theme_stylebox_override("panel", style)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)

	var frame: PanelContainer = PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var frame_style: StyleBoxFlat = StyleBoxFlat.new()
	frame_style.bg_color = NAVY
	frame_style.set_corner_radius_all(14)
	frame_style.border_color = GOLD
	frame_style.set_border_width_all(2)
	frame_style.set_content_margin_all(3)
	frame.add_theme_stylebox_override("panel", frame_style)
	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.custom_minimum_size = Vector2(108, 108)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	frame.add_child(_portrait)
	row.add_child(frame)

	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)
	row.add_child(column)

	var name_label: Label = Label.new()
	name_label.name = "Name"
	name_label.add_theme_font_size_override("font_size", 21)
	name_label.add_theme_color_override("font_color", GOLD)
	column.add_child(name_label)

	var text_label: Label = Label.new()
	text_label.name = "Text"
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 20)
	text_label.add_theme_color_override("font_color", Color(0.97, 0.96, 0.93))
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(text_label)

	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(button_row)

	var continue_button: Button = Button.new()
	continue_button.name = "Continue"
	continue_button.text = "Continue"
	continue_button.custom_minimum_size = Vector2(150, 42)
	continue_button.focus_mode = Control.FOCUS_NONE
	continue_button.add_theme_font_size_override("font_size", 18)
	var button_style: StyleBoxFlat = StyleBoxFlat.new()
	button_style.bg_color = GOLD
	button_style.set_corner_radius_all(21)
	continue_button.add_theme_stylebox_override("normal", button_style)
	var button_hover: StyleBoxFlat = button_style.duplicate()
	button_hover.bg_color = Color(1.0, 0.8, 0.4)
	continue_button.add_theme_stylebox_override("hover", button_hover)
	continue_button.add_theme_stylebox_override("pressed", button_hover)
	continue_button.add_theme_color_override("font_color", Color(0.12, 0.1, 0.05))
	continue_button.add_theme_color_override("font_hover_color", Color(0.12, 0.1, 0.05))
	continue_button.add_theme_color_override("font_pressed_color", Color(0.12, 0.1, 0.05))
	continue_button.pressed.connect(close)
	button_row.add_child(continue_button)


func open(speaker: String, text: String) -> void:
	(find_child("Name", true, false) as Label).text = speaker
	(find_child("Text", true, false) as Label).text = text
	var portrait_path: String = PORTRAITS.get(speaker, "")
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		_portrait.texture = load(portrait_path)
		_portrait.get_parent().visible = true
	else:
		_portrait.get_parent().visible = false
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()
