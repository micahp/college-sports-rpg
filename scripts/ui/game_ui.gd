extends CanvasLayer
## Everything drawn over the 3D world while playing: the HUD chip (day,
## period, energy), the current objective, the stats sheet, the pause menu,
## the joystick and context action button, the story card, the period banner
## and the nightly recap. Built in code so every location shares one UI.

signal action_pressed
signal recap_closed

const JoystickScript = preload("res://scripts/ui/virtual_joystick.gd")
const StoryCardScript = preload("res://scripts/ui/story_card.gd")

var joystick: Control
var card: PanelContainer

var _day_label: Label
var _period_label: Label
var _energy_fill: ColorRect
var _energy_value: Label
var _objective: Label
var _place: Label
var _action: Button
var _action_hint: Label
var _top_buttons: HBoxContainer
var _stats_sheet: Control
var _menu: Control
var _recap: Control
var _banner: Control
var _banner_title: Label
var _banner_sub: Label
var _toast: Label
var _toast_tween: Tween


func _ready() -> void:
	layer = 10
	_build_hud()
	_build_top_buttons()
	_build_controls()
	card = PanelContainer.new()
	card.name = "StoryCard"
	card.set_script(StoryCardScript)
	add_child(card)
	_build_banner()
	_build_toast()
	_stats_sheet = _build_stats_sheet()
	_menu = _build_menu()
	_recap = Control.new()
	_recap.visible = false
	_recap.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_recap)
	GameState.stat_changed.connect(func(_s: String, _a: int, _b: int) -> void: refresh())
	TimeSystem.time_advanced.connect(func(_d: int, _p: int) -> void: refresh())
	Game.objective_changed.connect(refresh)
	refresh()


func _process(_delta: float) -> void:
	var modal: bool = is_modal_open()
	joystick.visible = not modal
	_top_buttons.visible = not modal or _stats_sheet.visible
	if modal:
		_action.visible = false
		_action_hint.visible = false


## True while something on screen needs the player's attention instead of
## the world: story card, stats sheet, pause menu, recap, banner.
func is_modal_open() -> bool:
	return card.visible or _stats_sheet.visible or _menu.visible or _recap.visible \
		or _banner.visible


func refresh() -> void:
	_day_label.text = "DAY %d · %s" % [TimeSystem.day, TimeSystem.weekday_name().to_upper()]
	_period_label.text = TimeSystem.period_name().to_upper()
	var energy: int = GameState.get_stat("energy")
	_energy_fill.anchor_right = energy / 100.0
	_energy_fill.color = UIKit.GOLD if energy >= 25 else UIKit.BAD
	_energy_value.text = str(energy)
	var objective: Dictionary = Game.objective()
	_objective.text = objective.get("text", "")
	_place.text = Game.LOCATION_NAMES.get(Game.location, "")


## Context action: shows the button (touch) or a key hint (keyboard).
func set_action(text: String) -> void:
	if is_modal_open() or text == "":
		_action.visible = false
		_action_hint.visible = false
		return
	_action.text = text
	_action.visible = true
	_action_hint.visible = not UIKit.is_touch()
	_action_hint.text = "[E]"


func set_place(text: String) -> void:
	_place.text = text


func toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)


## Big centered title card, e.g. "AFTERNOON" when time advances.
func show_banner(title: String, subtitle: String, seconds: float = 1.6) -> void:
	_banner_title.text = title
	_banner_sub.text = subtitle
	_banner.visible = true
	_banner.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(_banner, "modulate:a", 1.0, 0.3)
	tween.tween_interval(seconds)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.35)
	await tween.finished
	_banner.visible = false


# =============================================================================
# Nightly recap
# =============================================================================

## End-of-day summary: what changed today and the choices that did it.
## Emits recap_closed when the player continues.
func show_recap(day: int) -> void:
	for child in _recap.get_children():
		child.queue_free()
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_recap.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_recap.add_child(center)
	var panel: PanelContainer = UIKit.panel(0.97)
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	col.add_child(UIKit.label("DAY %d · %s — DONE" % [day, TimeSystem.weekday_name(day).to_upper()], 15, UIKit.GOLD))
	var days_left: int = TimeSystem.FINAL_DAY - day
	var headline: String = "Tomorrow is the evaluation." if days_left == 1 \
		else "%d days until the walk-on evaluation." % days_left
	if not GameState.has_flag("signed_up") and day >= 2:
		headline = "Your name isn't on the walk-on sheet."
	col.add_child(UIKit.label(headline, 28))
	var deltas: Dictionary = GameState.day_deltas()
	if deltas.is_empty():
		col.add_child(UIKit.label("A quiet day. Nothing moved.", 18, UIKit.MUTED))
	else:
		col.add_child(UIKit.label("Today", 15, UIKit.MUTED))
		col.add_child(UIKit.delta_row(deltas))
	col.add_child(_stat_grid())
	var spacer: Control = Control.new()
	spacer.custom_minimum_size.y = 4
	col.add_child(spacer)
	var go: Button = UIKit.button("Sleep — start %s" % TimeSystem.weekday_name(day + 1), true, 52)
	go.name = "RecapContinue"
	go.pressed.connect(_close_recap)
	col.add_child(go)
	_recap.visible = true


func _close_recap() -> void:
	_recap.visible = false
	recap_closed.emit()


func recap_open() -> bool:
	return _recap.visible


# =============================================================================
# Builders
# =============================================================================

func _build_hud() -> void:
	var chip: PanelContainer = PanelContainer.new()
	chip.name = "HUD"
	chip.position = Vector2(18, 14)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(UIKit.NAVY, 0.88)
	style.set_corner_radius_all(22)
	style.border_color = Color(UIKit.GOLD, 0.35)
	style.set_border_width_all(1)
	style.content_margin_left = 10
	style.content_margin_right = 18
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	chip.add_theme_stylebox_override("panel", style)
	add_child(chip)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 11)
	chip.add_child(row)

	var badge: PanelContainer = PanelContainer.new()
	var badge_style: StyleBoxFlat = StyleBoxFlat.new()
	badge_style.bg_color = UIKit.GOLD
	badge_style.set_corner_radius_all(14)
	badge_style.content_margin_left = 9
	badge_style.content_margin_right = 9
	badge_style.content_margin_top = 2
	badge_style.content_margin_bottom = 2
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.add_child(UIKit.label("NVS", 16, UIKit.NAVY))
	row.add_child(badge)

	_day_label = UIKit.label("", 16)
	_day_label.name = "DayLabel"
	row.add_child(_day_label)
	_period_label = UIKit.label("", 16, UIKit.GOLD)
	_period_label.name = "PeriodLabel"
	row.add_child(_period_label)

	var divider: ColorRect = ColorRect.new()
	divider.color = Color(1, 1, 1, 0.15)
	divider.custom_minimum_size = Vector2(1, 20)
	row.add_child(divider)
	row.add_child(UIKit.label("Energy", 13, UIKit.MUTED))
	var bar: Control = UIKit.stat_bar("energy", 80, 96)
	_energy_fill = bar.get_node("Fill")
	row.add_child(bar)
	_energy_value = UIKit.label("", 14)
	row.add_child(_energy_value)

	var info: VBoxContainer = VBoxContainer.new()
	info.position = Vector2(26, 62)
	info.add_theme_constant_override("separation", 0)
	add_child(info)
	_place = UIKit.label("", 14, UIKit.MUTED)
	_place.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_place.add_theme_constant_override("outline_size", 4)
	info.add_child(_place)
	_objective = UIKit.label("", 17, UIKit.GOLD_SOFT)
	_objective.name = "Objective"
	_objective.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.1, 0.9))
	_objective.add_theme_constant_override("outline_size", 6)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.custom_minimum_size.x = 560
	info.add_child(_objective)


func _build_top_buttons() -> void:
	_top_buttons = HBoxContainer.new()
	_top_buttons.anchor_left = 1.0
	_top_buttons.anchor_right = 1.0
	_top_buttons.offset_left = -250
	_top_buttons.offset_right = -18
	_top_buttons.offset_top = 14
	_top_buttons.offset_bottom = 60
	_top_buttons.alignment = BoxContainer.ALIGNMENT_END
	_top_buttons.add_theme_constant_override("separation", 10)
	add_child(_top_buttons)
	var stats: Button = UIKit.button("STATS", false, 44)
	stats.name = "StatsButton"
	stats.pressed.connect(toggle_stats)
	_top_buttons.add_child(stats)
	var menu: Button = UIKit.button("MENU", false, 44)
	menu.name = "MenuButton"
	menu.pressed.connect(func() -> void: _menu.visible = true)
	_top_buttons.add_child(menu)


func _build_controls() -> void:
	joystick = Control.new()
	joystick.name = "Joystick"
	joystick.set_script(JoystickScript)
	joystick.anchor_top = 1.0
	joystick.anchor_bottom = 1.0
	joystick.offset_left = 36
	joystick.offset_top = -200
	joystick.offset_right = 196
	joystick.offset_bottom = -40
	add_child(joystick)

	_action = Button.new()
	_action.name = "ActionButton"
	_action.anchor_left = 1.0
	_action.anchor_top = 1.0
	_action.anchor_right = 1.0
	_action.anchor_bottom = 1.0
	_action.offset_left = -170
	_action.offset_top = -170
	_action.offset_right = -40
	_action.offset_bottom = -40
	_action.focus_mode = Control.FOCUS_NONE
	_action.add_theme_font_size_override("font_size", 20)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(UIKit.NAVY, 0.9)
	style.set_corner_radius_all(65)
	style.border_color = Color(UIKit.GOLD, 0.9)
	style.set_border_width_all(3)
	_action.add_theme_stylebox_override("normal", style)
	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = Color(0.2, 0.3, 0.5, 0.95)
	_action.add_theme_stylebox_override("hover", hover)
	_action.add_theme_stylebox_override("pressed", hover)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		_action.add_theme_color_override(state, UIKit.GOLD)
	_action.visible = false
	_action.pressed.connect(func() -> void: action_pressed.emit())
	add_child(_action)

	_action_hint = UIKit.label("[E]", 16, UIKit.TEXT)
	_action_hint.anchor_left = 1.0
	_action_hint.anchor_right = 1.0
	_action_hint.anchor_top = 1.0
	_action_hint.anchor_bottom = 1.0
	_action_hint.offset_left = -122
	_action_hint.offset_top = -200
	_action_hint.offset_right = -88
	_action_hint.offset_bottom = -176
	_action_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_action_hint.add_theme_constant_override("outline_size", 5)
	_action_hint.visible = false
	add_child(_action_hint)


func _build_banner() -> void:
	_banner = CenterContainer.new()
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.mouse_filter = Control.MOUSE_FILTER_STOP
	_banner.visible = false
	add_child(_banner)
	var bg: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(UIKit.NAVY_DEEP, 0.86)
	style.set_corner_radius_all(24)
	style.border_color = Color(UIKit.GOLD, 0.6)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.content_margin_left = 60
	style.content_margin_right = 60
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	bg.add_theme_stylebox_override("panel", style)
	_banner.add_child(bg)
	var col: VBoxContainer = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	bg.add_child(col)
	_banner_title = UIKit.label("", 44, UIKit.GOLD)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_banner_title)
	_banner_sub = UIKit.label("", 19, UIKit.TEXT)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_banner_sub)


func _build_toast() -> void:
	_toast = UIKit.label("", 18, UIKit.TEXT)
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_left = -300
	_toast.offset_right = 300
	_toast.offset_top = 110
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.visible = false
	add_child(_toast)


func toggle_stats() -> void:
	if _stats_sheet.visible:
		_stats_sheet.visible = false
		return
	var holder: VBoxContainer = _stats_sheet.find_child("Holder", true, false)
	for child in holder.get_children():
		child.queue_free()
	var who: String = GameState.player_name
	for identity: Dictionary in ContentDB.get_identities():
		if identity.get("id") == GameState.identity_id:
			who += "  ·  " + str(identity.get("name", ""))
	holder.add_child(UIKit.label(who, 24, UIKit.GOLD))
	holder.add_child(_stat_grid())
	holder.add_child(UIKit.label("Status", 15, UIKit.MUTED))
	var notes: Array[String] = []
	notes.append("Walk-on sheet: " + ("signed" if GameState.has_flag("signed_up") else "NOT signed"))
	if GameState.has_flag("quiz_passed"):
		notes.append("Kinesiology quiz: passed")
	elif GameState.has_flag("quiz_failed"):
		notes.append("Kinesiology quiz: failed — eligibility at risk")
	if GameState.has_flag("wristband"):
		notes.append("Wearing Jordan's lucky wristband")
	for note in notes:
		holder.add_child(UIKit.wrap_label("•  " + note, 17))
	_stats_sheet.visible = true


func _stat_grid() -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	for stat: String in GameState.STAT_KEYS:
		grid.add_child(UIKit.label(GameState.STAT_LABELS[stat], 17))
		grid.add_child(UIKit.stat_bar(stat, GameState.get_stat(stat), 240))
		grid.add_child(UIKit.label(str(GameState.get_stat(stat)), 17, UIKit.GOLD))
	return grid


func _build_stats_sheet() -> Control:
	var root: Control = _modal_root("StatsSheet")
	var panel: PanelContainer = UIKit.panel(0.97)
	panel.custom_minimum_size = Vector2(560, 0)
	root.get_child(1).add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	var holder: VBoxContainer = VBoxContainer.new()
	holder.name = "Holder"
	holder.add_theme_constant_override("separation", 10)
	col.add_child(holder)
	var close: Button = UIKit.button("Close", true, 48)
	close.pressed.connect(func() -> void: root.visible = false)
	col.add_child(close)
	return root


func _build_menu() -> Control:
	var root: Control = _modal_root("Menu")
	var panel: PanelContainer = UIKit.panel(0.97)
	panel.custom_minimum_size = Vector2(380, 0)
	root.get_child(1).add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	var title: Label = UIKit.label("Paused", 26, UIKit.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var note: Label = UIKit.wrap_label("Your progress saves automatically after every choice.", 16, UIKit.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(note)
	var resume: Button = UIKit.button("Resume", true, 50)
	resume.pressed.connect(func() -> void: root.visible = false)
	col.add_child(resume)
	var quit: Button = UIKit.button("Save & quit to title", false, 50)
	quit.name = "QuitToTitle"
	quit.pressed.connect(func() -> void:
		root.visible = false
		Game.quit_to_title())
	col.add_child(quit)
	return root


func _modal_root(node_name: String) -> Control:
	var root: Control = Control.new()
	root.name = node_name
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	return root
