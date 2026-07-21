extends PanelContainer
## Slim always-on status strip: day, period, and the three stats that matter
## moment to moment. Reads the autoload singletons; owns no state.

var _label: Label


func _ready() -> void:
	position = Vector2(16, 12)
	self_modulate = Color(1, 1, 1, 0.9)

	var margin: MarginContainer = MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_%s" % side, 16)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 8)
	add_child(margin)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 19)
	margin.add_child(_label)


func _process(_delta: float) -> void:
	_label.text = "Day %d · %s      Energy %d    Grades %d    Coach %d" % [
		TimeSystem.day,
		TimeSystem.period_name(),
		GameState.get_stat("energy"),
		GameState.get_stat("academics"),
		GameState.get_stat("coach_interest"),
	]
