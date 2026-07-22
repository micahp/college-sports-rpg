extends PanelContainer
## Compact rounded dialogue card over the world: speaker name, one line,
## a Continue button. Sized for mobile landscape; keeps the scene visible.

signal closed


func _ready() -> void:
	position = Vector2(280, 500)
	size = Vector2(720, 170)
	visible = false

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.1, 0.16, 0.92)
	style.set_corner_radius_all(20)
	style.border_color = Color(1, 1, 1, 0.1)
	style.set_border_width_all(1)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 16
	add_theme_stylebox_override("panel", style)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)

	var name_label: Label = Label.new()
	name_label.name = "Name"
	name_label.add_theme_font_size_override("font_size", 21)
	name_label.add_theme_color_override("font_color", Color(0.92, 0.72, 0.3))
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
	continue_button.custom_minimum_size = Vector2(150, 44)
	continue_button.focus_mode = Control.FOCUS_NONE
	continue_button.add_theme_font_size_override("font_size", 18)
	var button_style: StyleBoxFlat = StyleBoxFlat.new()
	button_style.bg_color = Color(0.92, 0.72, 0.3)
	button_style.set_corner_radius_all(22)
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
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()
