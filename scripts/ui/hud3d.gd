extends PanelContainer
## Minimal polished HUD for the visual slice: day, period, and an energy bar
## in one rounded pill, top-left, mobile-safe. No other stats yet.

var _energy_fill: ColorRect


func _ready() -> void:
	position = Vector2(20, 16)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.1, 0.16, 0.82)
	style.set_corner_radius_all(22)
	style.border_color = Color(1, 1, 1, 0.08)
	style.set_border_width_all(1)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	add_theme_stylebox_override("panel", style)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)

	var day_label: Label = Label.new()
	day_label.text = "Day 1 · Morning"
	day_label.add_theme_font_size_override("font_size", 19)
	day_label.add_theme_color_override("font_color", Color(0.97, 0.95, 0.9))
	row.add_child(day_label)

	var divider: ColorRect = ColorRect.new()
	divider.color = Color(1, 1, 1, 0.15)
	divider.custom_minimum_size = Vector2(1, 20)
	row.add_child(divider)

	var energy_label: Label = Label.new()
	energy_label.text = "Energy"
	energy_label.add_theme_font_size_override("font_size", 15)
	energy_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	row.add_child(energy_label)

	var bar_frame: Control = Control.new()
	bar_frame.custom_minimum_size = Vector2(110, 12)
	bar_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar_frame)

	var bar_bg: ColorRect = ColorRect.new()
	bar_bg.color = Color(1, 1, 1, 0.14)
	bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_frame.add_child(bar_bg)

	_energy_fill = ColorRect.new()
	_energy_fill.color = Color(0.5, 0.85, 0.45)
	_energy_fill.anchor_bottom = 1.0
	bar_frame.add_child(_energy_fill)
	_energy_fill.anchor_right = 0.8  # 80/100 starting energy
