extends Control
## Day One prototype: a menu-driven flow over the simulation systems.
## All screens are built in code so iterating needs no editor work;
## all content comes from ContentDB. This scene is an interface to the
## simulation — it owns no game rules beyond presentation.

const BG_COLOR: Color = Color("141a26")
const ACCENT_COLOR: Color = Color("e8b64c")
const MUTED_COLOR: Color = Color("8a93a6")

const STAT_DISPLAY: Array = [
	["energy", "Energy"],
	["academics", "Grades"],
	["athleticism", "Athletic"],
	["basketball_skill", "Ball"],
	["roommate_relationship", "Jordan"],
	["coach_interest", "Coach"],
]

const STAT_SHORT_NAMES: Dictionary = {
	"energy": "Energy",
	"academics": "Grades",
	"athleticism": "Athleticism",
	"basketball_skill": "Basketball",
	"roommate_relationship": "Jordan",
	"coach_interest": "Coach Interest",
}

const TRAIT_NAMES: Dictionary = {
	"grind": "Relentless",
	"social": "People Person",
	"scholar": "The Student",
	"rest": "Well Rested",
}

## Choice ids worth calling back to on the recap screen, in priority order.
const HIGHLIGHTS: Array = [
	["open_gym", "Someone in a North Valley polo watched your last two games at open gym."],
	["confident_pitch", "You told Coach Delgado you'd outwork the other thirty-nine walk-ons."],
	["hang_jordan", "Jordan promised to be at every home game if you make the team."],
	["help_unpack", "You and Jordan wrestled a mini-fridge up the stairs. That's a friendship now."],
	["ask_questions", "You left Delgado's office with a checklist: conditioning, hands, grades."],
	["sleep_in", "You slept through move-in morning. Jordan remembers."],
]

var _beats: Array = []
var _beat_index: int = 0
## The day whose beats are loaded. Can lag TimeSystem.day: finishing the Night
## beat advances the clock to the next morning while the recap still belongs
## to this day, so saves must record it explicitly.
var _content_day: int = 1

var _header_label: Label
var _stat_labels: Dictionary = {}
var _title_label: Label
var _body_label: RichTextLabel
var _choices_box: VBoxContainer
var _name_edit: LineEdit


func _ready() -> void:
	RenderingServer.set_default_clear_color(BG_COLOR)
	_build_ui()
	_show_title()


# --- Screen flow -------------------------------------------------------------

func _show_title() -> void:
	_set_header_visible(false)
	_title_label.text = "THE U"
	_body_label.text = "[center]North Valley State — Freshman Year\n\nOne life. Four years. Every choice closes a door.[/center]"
	_clear_choices()
	if SaveSystem.has_save():
		_add_button("Continue", _on_continue_pressed)
	_add_button("New Game", _on_new_game_pressed)


func _on_new_game_pressed() -> void:
	GameState.reset()
	TimeSystem.reset()
	SaveSystem.clear_save()
	_show_character_creation()


func _on_continue_pressed() -> void:
	var flow: Variant = SaveSystem.load_game()
	if flow == null:
		_on_new_game_pressed()
		return
	_content_day = int((flow as Dictionary).get("content_day", TimeSystem.day))
	_beats = ContentDB.get_day(_content_day)
	_beat_index = int((flow as Dictionary).get("beat_index", 0))
	_set_header_visible(true)
	_refresh_stats()
	if _beat_index >= _beats.size():
		_show_recap()
	else:
		_show_beat()


func _show_character_creation() -> void:
	_set_header_visible(false)
	_title_label.text = "Who are you?"
	_body_label.text = "Pick a name and the reputation you're bringing to campus. It sets your starting stats — it doesn't decide who you become."
	_clear_choices()

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Your name"
	_name_edit.max_length = 20
	_name_edit.custom_minimum_size = Vector2(0, 56)
	_name_edit.add_theme_font_size_override("font_size", 22)
	_choices_box.add_child(_name_edit)

	for identity: Dictionary in ContentDB.get_identities():
		var button: Button = _add_button(
			"%s — %s" % [identity["name"], identity["blurb"]],
			_on_identity_picked.bind(identity)
		)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _on_identity_picked(identity: Dictionary) -> void:
	var typed_name: String = _name_edit.text.strip_edges()
	GameState.player_name = typed_name if not typed_name.is_empty() else "Freshman"
	GameState.identity_id = str(identity["id"])
	GameState.apply_effects(identity.get("effects", {}))
	GameState.record_choice("character_creation", str(identity["id"]), [str(identity.get("tag", ""))])

	_content_day = 1
	_beats = ContentDB.get_day(_content_day)
	_beat_index = 0
	SaveSystem.save_game({"beat_index": _beat_index, "content_day": _content_day})
	_set_header_visible(true)
	_refresh_stats()
	_show_beat()


func _show_beat() -> void:
	var beat: Dictionary = _beats[_beat_index]
	_update_header()
	_title_label.text = str(beat.get("title", ""))
	_body_label.text = str(beat["text"])
	_clear_choices()

	for choice: Dictionary in beat["choices"]:
		var button: Button = _add_button(str(choice["label"]), _on_choice_pressed.bind(beat, choice))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var requirements: Dictionary = choice.get("requirements", {})
		if not GameState.meets_requirements(requirements):
			button.disabled = true
			button.text += "  (needs %d energy — you have %d)" % [
				int(requirements.get("energy_min", 0)), GameState.get_stat("energy"),
			]


func _on_choice_pressed(beat: Dictionary, choice: Dictionary) -> void:
	var applied: Dictionary = GameState.apply_effects(choice.get("effects", {}))
	GameState.record_choice(str(beat["id"]), str(choice["id"]), choice.get("tags", []))
	TimeSystem.advance(int(choice.get("duration_blocks", 1)))
	_beat_index += 1
	SaveSystem.save_game({"beat_index": _beat_index, "content_day": _content_day})

	_refresh_stats()
	_update_header()
	_title_label.text = str(beat.get("title", ""))
	_body_label.text = str(choice.get("reaction", "")) + "\n\n" + _format_deltas(applied)
	_clear_choices()
	if _beat_index >= _beats.size():
		_add_button("See your Day One report", _show_recap)
	else:
		_add_button("Continue", _show_beat)


func _show_recap() -> void:
	_update_header()
	_title_label.text = "DAY ONE REPORT"
	_body_label.text = _build_recap_text()
	_clear_choices()
	_add_button("Play Again", _on_play_again_pressed)


func _on_play_again_pressed() -> void:
	SaveSystem.clear_save()
	GameState.reset()
	TimeSystem.reset()
	_show_title()


# --- Recap -------------------------------------------------------------------

func _build_recap_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[b]%s[/b] — Freshman, North Valley State\n" % GameState.player_name.to_upper())
	lines.append("Academic Standing: [b]%s[/b]" % _letter_grade(GameState.get_stat("academics")))
	lines.append("Basketball: [b]%d[/b]   Athleticism: [b]%d[/b]" % [
		GameState.get_stat("basketball_skill"), GameState.get_stat("athleticism"),
	])
	lines.append("Coach Interest: [b]%d[/b]" % GameState.get_stat("coach_interest"))
	lines.append("Jordan Hayes: [b]%s[/b]" % _relationship_word(GameState.get_stat("roommate_relationship")))
	lines.append("Primary Trait: [b]%s[/b]\n" % _primary_trait())

	var highlight: String = _pick_highlight()
	if not highlight.is_empty():
		lines.append(highlight + "\n")
	lines.append(_outcome_line())
	lines.append("\n[color=#8a93a6]Six days until the walk-on evaluation.[/color]")
	return "\n".join(lines)


func _letter_grade(academics: int) -> String:
	if academics >= 72:
		return "A"
	if academics >= 58:
		return "B"
	if academics >= 45:
		return "C"
	return "D"


func _relationship_word(value: int) -> String:
	if value >= 30:
		return "Actual friend"
	if value >= 15:
		return "Friendly"
	if value >= 5:
		return "Roommates, technically"
	return "It's tense"


func _primary_trait() -> String:
	var counts: Dictionary = GameState.tag_counts()
	var best_tag: String = ""
	var best_count: int = 0
	for tag: String in counts.keys():
		if int(counts[tag]) > best_count and TRAIT_NAMES.has(tag):
			best_tag = tag
			best_count = int(counts[tag])
	return TRAIT_NAMES.get(best_tag, "Undeclared")


func _pick_highlight() -> String:
	var chosen_ids: Array = []
	for entry: Dictionary in GameState.choice_history:
		chosen_ids.append(entry.get("choice", ""))
	for pair: Array in HIGHLIGHTS:
		if pair[0] in chosen_ids:
			return str(pair[1])
	return ""


func _outcome_line() -> String:
	var interest: int = GameState.get_stat("coach_interest")
	if interest >= 15:
		return "[b]Coach Delgado knows your name.[/b] Saturday is yours to take."
	if interest >= 8:
		return "[b]You're on the walk-on list.[/b] Saturday will decide the rest."
	return "[b]Nobody in the program knows you yet.[/b] Saturday is your only shot at changing that."


# --- UI plumbing -------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 32)
	add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var header: HBoxContainer = HBoxContainer.new()
	header.name = "Header"
	column.add_child(header)

	_header_label = Label.new()
	_header_label.add_theme_font_size_override("font_size", 24)
	_header_label.add_theme_color_override("font_color", ACCENT_COLOR)
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_header_label)

	for pair: Array in STAT_DISPLAY:
		var stat_label: Label = Label.new()
		stat_label.add_theme_font_size_override("font_size", 16)
		stat_label.add_theme_color_override("font_color", MUTED_COLOR)
		header.add_child(stat_label)
		_stat_labels[pair[0]] = stat_label
		var spacer: Control = Control.new()
		spacer.custom_minimum_size = Vector2(14, 0)
		header.add_child(spacer)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 34)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title_label)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = true
	_body_label.fit_content = true
	_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.add_theme_font_size_override("normal_font_size", 21)
	_body_label.add_theme_font_size_override("bold_font_size", 21)
	scroll.add_child(_body_label)

	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 10)
	column.add_child(_choices_box)


func _add_button(label: String, handler: Callable) -> Button:
	var button: Button = Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 60)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(handler)
	_choices_box.add_child(button)
	return button


func _clear_choices() -> void:
	for child in _choices_box.get_children():
		child.queue_free()


func _set_header_visible(header_visible: bool) -> void:
	_header_label.get_parent().visible = header_visible


func _update_header() -> void:
	_header_label.text = "Day %d — %s" % [TimeSystem.day, TimeSystem.period_name()]


func _refresh_stats() -> void:
	for pair: Array in STAT_DISPLAY:
		var key: String = pair[0]
		(_stat_labels[key] as Label).text = "%s %d" % [pair[1], GameState.get_stat(key)]


func _format_deltas(applied: Dictionary) -> String:
	if applied.is_empty():
		return "[color=#8a93a6]No stat changes.[/color]"
	var parts: PackedStringArray = PackedStringArray()
	for key: String in applied.keys():
		var delta: int = int(applied[key])
		parts.append("%s %s%d" % [STAT_SHORT_NAMES.get(key, key), "+" if delta > 0 else "", delta])
	return "[color=#e8b64c]" + "   ".join(parts) + "[/color]"
