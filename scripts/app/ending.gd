extends Control
## The end of the week: the verdict, the tryout line, where every stat
## landed, an epilogue per relationship, and Play Again.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if Game.outcome.is_empty():
		Game.outcome = Game.compute_outcome()
	var bg: ColorRect = ColorRect.new()
	bg.color = UIKit.NAVY_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	if ResourceLoader.exists("res://assets/branding/ending_bg.png"):
		var tex: TextureRect = TextureRect.new()
		tex.texture = load("res://assets/branding/ending_bg.png")
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex.modulate = Color(1, 1, 1, 0.35)
		add_child(tex)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 60)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	scroll.add_child(margin)
	var center: CenterContainer = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(center)
	var panel: PanelContainer = UIKit.panel(0.95)
	panel.custom_minimum_size = Vector2(900, 0)
	center.add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	col.add_child(UIKit.label("SATURDAY · WALK-ON EVALUATION", 15, UIKit.GOLD))
	var title: Label = UIKit.label(str(Game.outcome.get("title", "")), 40, UIKit.GOLD)
	title.name = "OutcomeTitle"
	col.add_child(title)
	col.add_child(UIKit.wrap_label(str(Game.outcome.get("text", "")), 19))

	if not GameState.tryout.is_empty():
		var t: Dictionary = GameState.tryout
		col.add_child(UIKit.label("Tryout: %d of %d made · %d swishes · evaluation score %d" % [
			int(t.get("makes", 0)), int(t.get("shots", 0)), int(t.get("perfects", 0)),
			int(Game.outcome.get("score", 0))], 18, UIKit.GOLD_SOFT))

	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	for stat: String in GameState.STAT_KEYS:
		grid.add_child(UIKit.label(GameState.STAT_LABELS[stat], 17))
		grid.add_child(UIKit.stat_bar(stat, GameState.get_stat(stat), 300))
		grid.add_child(UIKit.label(str(GameState.get_stat(stat)), 17, UIKit.GOLD))
	col.add_child(grid)

	for line: String in Game.epilogue_lines():
		col.add_child(UIKit.wrap_label(line, 18, Color(0.9, 0.9, 0.88)))

	var again: Button = UIKit.button("Play again — make different choices", true, 56)
	again.name = "PlayAgain"
	again.pressed.connect(func() -> void: Game.change_scene("title"))
	col.add_child(again)
