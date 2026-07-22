extends PanelContainer
## Top-left HUD chip in North Valley State branding: a gold "NVS" badge,
## the day/period, and the energy bar. Anchored with safe margins so it
## survives any mobile landscape ratio.

const NAVY: Color = Color(0.12, 0.2, 0.36)
const GOLD: Color = Color(0.92, 0.72, 0.3)

var _energy_fill: ColorRect


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = 20
	offset_top = 16

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(NAVY.r, NAVY.g, NAVY.b, 0.88)
	style.set_corner_radius_all(22)
	style.border_color = Color(GOLD, 0.35)
	style.set_border_width_all(1)
	style.content_margin_left = 12
	style.content_margin_right = 20
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	var badge: PanelContainer = PanelContainer.new()
	var badge_style: StyleBoxFlat = StyleBoxFlat.new()
	badge_style.bg_color = GOLD
	badge_style.set_corner_radius_all(14)
	badge_style.content_margin_left = 10
	badge_style.content_margin_right = 10
	badge_style.content_margin_top = 3
	badge_style.content_margin_bottom = 3
	badge.add_theme_stylebox_override("panel", badge_style)
	var badge_label: Label = Label.new()
	badge_label.text = "NVS"
	badge_label.add_theme_font_size_override("font_size", 17)
	badge_label.add_theme_color_override("font_color", NAVY)
	badge.add_child(badge_label)
	row.add_child(badge)

	var day_label: Label = Label.new()
	day_label.text = "DAY 1 · MORNING"
	day_label.add_theme_font_size_override("font_size", 17)
	day_label.add_theme_color_override("font_color", Color(0.97, 0.95, 0.9))
	row.add_child(day_label)

	var divider: ColorRect = ColorRect.new()
	divider.color = Color(1, 1, 1, 0.15)
	divider.custom_minimum_size = Vector2(1, 20)
	row.add_child(divider)

	var energy_label: Label = Label.new()
	energy_label.text = "Energy"
	energy_label.add_theme_font_size_override("font_size", 14)
	energy_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	row.add_child(energy_label)

	var bar_frame: Control = Control.new()
	bar_frame.custom_minimum_size = Vector2(100, 10)
	bar_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar_frame)

	var bar_bg: ColorRect = ColorRect.new()
	bar_bg.color = Color(1, 1, 1, 0.14)
	bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_frame.add_child(bar_bg)

	_energy_fill = ColorRect.new()
	_energy_fill.color = GOLD
	_energy_fill.anchor_bottom = 1.0
	bar_frame.add_child(_energy_fill)
	_energy_fill.anchor_right = 0.8  # 80/100 starting energy
