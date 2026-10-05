extends Control
## Title screen and character creation. New Game → name, identity, look →
## Game.new_game(). Continue is disabled (with the reason) when there is no
## save, and shows where the save left off when there is one.

const BACKGROUND: String = "res://assets/branding/title_bg.png"
const PORTRAIT_DIR: String = "res://assets/portraits/"

var _main: Control
var _create: Control
var _name_edit: LineEdit
var _identity_id: String = ""
var _look_id: String = ""
var _identity_buttons: Dictionary = {}
var _look_buttons: Dictionary = {}
var _start_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Game.in_game = false
	_build_background()
	_main = _build_main()
	_create = _build_create()
	_create.visible = false


func _build_background() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = UIKit.NAVY_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	if ResourceLoader.exists(BACKGROUND):
		var tex: TextureRect = TextureRect.new()
		tex.texture = load(BACKGROUND)
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(tex)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.03, 0.05, 0.1, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)


func _build_main() -> Control:
	var center: CenterContainer = CenterContainer.new()
	center.name = "Main"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col: VBoxContainer = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)
	var emblem: TextureRect = TextureRect.new()
	emblem.texture = load("res://assets/branding/emblem.png")
	emblem.custom_minimum_size = Vector2(150, 150)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	col.add_child(emblem)
	var title: Label = UIKit.label("THE U", 88, UIKit.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", UIKit.NAVY_DEEP)
	title.add_theme_constant_override("outline_size", 14)
	col.add_child(title)
	var sub: Label = UIKit.label("North Valley State  ·  One week. One walk-on tryout.", 21)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_outline_color", UIKit.NAVY_DEEP)
	sub.add_theme_constant_override("outline_size", 6)
	col.add_child(sub)
	var gap: Control = Control.new()
	gap.custom_minimum_size.y = 16
	col.add_child(gap)

	var new_game: Button = UIKit.button("New Game", true, 58)
	new_game.name = "NewGame"
	new_game.custom_minimum_size.x = 340
	new_game.pressed.connect(_show_create)
	col.add_child(new_game)

	var cont: Button = UIKit.button("Continue", false, 58)
	cont.name = "Continue"
	var has_save: bool = SaveSystem.has_save()
	cont.disabled = not has_save
	cont.pressed.connect(func() -> void: Game.continue_game())
	col.add_child(cont)
	var note: Label = UIKit.label("", 16, UIKit.MUTED)
	note.name = "SaveNote"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.text = _save_summary() if has_save else "No saved game yet"
	col.add_child(note)
	return center


func _save_summary() -> String:
	var file: FileAccess = FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.READ)
	if file == null:
		return ""
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return ""
	var time: Dictionary = data.get("time", {})
	var day: int = int(time.get("day", 1))
	var period: int = clampi(int(time.get("period", 0)), 0, 3)
	var who: String = str((data.get("player", {}) as Dictionary).get("player_name", ""))
	return "%s — Day %d, %s %s" % [who, day, TimeSystem.weekday_name(day), TimeSystem.PERIOD_NAMES[period]]


func _show_create() -> void:
	_main.visible = false
	_create.visible = true


func _build_create() -> Control:
	var center: CenterContainer = CenterContainer.new()
	center.name = "Create"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = UIKit.panel(0.95)
	panel.custom_minimum_size = Vector2(980, 0)
	center.add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	col.add_child(UIKit.label("Move-in day. Who are you?", 30, UIKit.GOLD))

	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 14)
	col.add_child(name_row)
	var name_label: Label = UIKit.label("Name", 19)
	name_label.custom_minimum_size.x = 90
	name_row.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.name = "NameEdit"
	_name_edit.placeholder_text = "Your name"
	_name_edit.max_length = 18
	_name_edit.custom_minimum_size = Vector2(320, 46)
	_name_edit.add_theme_font_size_override("font_size", 20)
	_name_edit.virtual_keyboard_enabled = true
	name_row.add_child(_name_edit)

	col.add_child(UIKit.label("How did you get here?", 19, UIKit.MUTED))
	var ids: HBoxContainer = HBoxContainer.new()
	ids.add_theme_constant_override("separation", 12)
	col.add_child(ids)
	for identity: Dictionary in ContentDB.get_identities():
		var card: Button = UIKit.button("", false, 132)
		card.name = "Identity_" + str(identity["id"])
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.x = 0
		var inner: VBoxContainer = VBoxContainer.new()
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 16
		inner.offset_right = -16
		inner.offset_top = 10
		inner.offset_bottom = -10
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t: Label = UIKit.label(str(identity["name"]), 20, UIKit.GOLD)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(t)
		var blurb: Label = UIKit.wrap_label(str(identity["blurb"]), 15)
		blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(blurb)
		card.add_child(inner)
		card.pressed.connect(_pick_identity.bind(str(identity["id"])))
		ids.add_child(card)
		_identity_buttons[identity["id"]] = card

	col.add_child(UIKit.label("Look", 19, UIKit.MUTED))
	var looks: HBoxContainer = HBoxContainer.new()
	looks.add_theme_constant_override("separation", 12)
	col.add_child(looks)
	for look: Dictionary in ContentDB.get_looks():
		var b: Button = UIKit.button("", false, 112)
		b.name = "Look_" + str(look["id"])
		b.custom_minimum_size.x = 112
		var path: String = PORTRAIT_DIR + str(look["id"]) + ".png"
		if ResourceLoader.exists(path):
			var pic: TextureRect = TextureRect.new()
			pic.texture = load(path)
			pic.set_anchors_preset(Control.PRESET_FULL_RECT)
			pic.offset_left = 6
			pic.offset_top = 6
			pic.offset_right = -6
			pic.offset_bottom = -6
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(pic)
		else:
			b.text = str(look.get("name", look["id"]))
		b.pressed.connect(_pick_look.bind(str(look["id"])))
		looks.add_child(b)
		_look_buttons[look["id"]] = b

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	col.add_child(buttons)
	var back: Button = UIKit.button("Back", false, 52)
	back.custom_minimum_size.x = 140
	back.pressed.connect(func() -> void:
		_create.visible = false
		_main.visible = true)
	buttons.add_child(back)
	_start_button = UIKit.button("Start Day One", true, 52)
	_start_button.name = "Start"
	_start_button.custom_minimum_size.x = 220
	_start_button.pressed.connect(_start)
	buttons.add_child(_start_button)

	var identities: Array = ContentDB.get_identities()
	if not identities.is_empty():
		_pick_identity(str(identities[0]["id"]))
	var all_looks: Array = ContentDB.get_looks()
	if not all_looks.is_empty():
		_pick_look(str(all_looks[0]["id"]))
	return center


func _pick_identity(id: String) -> void:
	_identity_id = id
	for key: String in _identity_buttons.keys():
		_highlight(_identity_buttons[key], key == id)


func _pick_look(id: String) -> void:
	_look_id = id
	for key: String in _look_buttons.keys():
		_highlight(_look_buttons[key], key == id)


func _highlight(b: Button, on: bool) -> void:
	var style: StyleBoxFlat = (b.get_theme_stylebox("normal") as StyleBoxFlat).duplicate()
	style.border_color = UIKit.GOLD if on else Color(UIKit.GOLD, 0.25)
	style.set_border_width_all(4 if on else 2)
	style.bg_color = Color(0.18, 0.28, 0.48, 0.98) if on else Color(UIKit.NAVY, 0.95)
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("hover", style)


func _start() -> void:
	_start_button.disabled = true
	Game.new_game(_name_edit.text, _identity_id, _look_id)
