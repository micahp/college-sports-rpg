class_name UIKit
extends RefCounted
## Shared North Valley State look for every screen: navy glass panels, gold
## accents, big touch-safe buttons. Screens build their controls through
## these helpers so the whole game reads as one product.

const NAVY: Color = Color(0.12, 0.2, 0.36)
const NAVY_DEEP: Color = Color(0.055, 0.085, 0.15)
const GOLD: Color = Color(0.92, 0.72, 0.3)
const GOLD_SOFT: Color = Color(1.0, 0.82, 0.45)
const INK: Color = Color(0.12, 0.1, 0.05)
const TEXT: Color = Color(0.97, 0.96, 0.93)
const MUTED: Color = Color(1, 1, 1, 0.62)
const GOOD: Color = Color(0.5, 0.86, 0.55)
const BAD: Color = Color(1.0, 0.5, 0.45)

const STAT_COLORS: Dictionary = {
	"energy": Color(0.95, 0.78, 0.32),
	"academics": Color(0.45, 0.68, 0.98),
	"athleticism": Color(0.98, 0.55, 0.38),
	"basketball_skill": Color(0.96, 0.48, 0.2),
	"roommate_relationship": Color(0.6, 0.84, 0.5),
	"coach_interest": Color(0.82, 0.62, 0.95),
}


static func panel_style(alpha: float = 0.93, radius: int = 18) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(NAVY_DEEP, alpha)
	style.set_corner_radius_all(radius)
	style.border_color = Color(GOLD, 0.4)
	style.set_border_width_all(1)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 16
	return style


static func panel(alpha: float = 0.93) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(alpha))
	return p


static func label(text: String, size: int = 20, color: Color = TEXT) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func wrap_label(text: String, size: int = 20, color: Color = TEXT) -> Label:
	var l: Label = label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## Gold pill for the primary action, navy outline for secondary choices.
static func button(text: String, primary: bool = true, min_height: int = 50) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, min_height)
	b.add_theme_font_size_override("font_size", 19)
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.set_corner_radius_all(mini(min_height / 2, 26))
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	if primary:
		normal.bg_color = GOLD
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(state, INK)
	else:
		normal.bg_color = Color(NAVY, 0.95)
		normal.border_color = Color(GOLD, 0.7)
		normal.set_border_width_all(2)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(state, TEXT)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = GOLD_SOFT if primary else Color(0.2, 0.31, 0.52, 0.98)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.2, 0.22, 0.27, 0.9)
	disabled.border_color = Color(1, 1, 1, 0.12)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", normal)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.4))
	return b


## "+8 Academics" chips. Green for gains, coral for losses; energy loss is
## shown neutral-coral like any other cost.
static func delta_row(applied: Dictionary) -> HFlowContainer:
	var row: HFlowContainer = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
	for stat: String in GameState.STAT_KEYS:
		if not applied.has(stat):
			continue
		var delta: int = int(applied[stat])
		var chip: PanelContainer = PanelContainer.new()
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(GOOD if delta > 0 else BAD, 0.18)
		style.border_color = Color(GOOD if delta > 0 else BAD, 0.8)
		style.set_border_width_all(1)
		style.set_corner_radius_all(12)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		chip.add_theme_stylebox_override("panel", style)
		chip.add_child(label("%+d %s" % [delta, GameState.STAT_LABELS[stat]], 16,
			GOOD if delta > 0 else BAD))
		row.add_child(chip)
	return row


## Horizontal stat bar used by the stats sheet and recaps.
static func stat_bar(stat: String, value: int, width: float = 220.0) -> Control:
	var frame: Control = Control.new()
	frame.custom_minimum_size = Vector2(width, 12)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(1, 1, 1, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(bg)
	var fill: ColorRect = ColorRect.new()
	fill.name = "Fill"
	fill.color = STAT_COLORS.get(stat, GOLD)
	fill.anchor_bottom = 1.0
	fill.anchor_right = clampf(value / 100.0, 0.0, 1.0)
	frame.add_child(fill)
	return frame


static func is_touch() -> bool:
	return DisplayServer.is_touchscreen_available()
