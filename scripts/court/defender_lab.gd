extends Node
## Play the normal court stretch while the camera follows a defender.
const Court := preload("res://scenes/court/court_game.tscn")
var court := Court.instantiate()
var camera := Camera3D.new()
var picker := OptionButton.new()
var status := Label.new()

func _ready() -> void:
	add_child(court)
	add_child(camera)
	camera.fov = 42.0
	camera.make_current()
	var overlay := CanvasLayer.new()
	overlay.layer = 50
	add_child(overlay)
	var panel := VBoxContainer.new()
	panel.position = Vector2(12, 54)
	overlay.add_child(panel)
	panel.add_child(picker)
	picker.add_item("Follow ball defender")
	for i in court._defense.size():
		picker.add_item("Follow defender %d" % (i + 1))
	panel.add_child(status)
	process_priority = 100

func _process(_delta: float) -> void:
	var d = court._on_ball_defender() if picker.selected == 0 else court._defense[picker.selected - 1]
	if not is_instance_valid(d):
		return
	var focus: Vector3 = d.position + Vector3.UP * 0.95
	camera.position = focus + Vector3(2.0, 0.55, 3.4)
	camera.look_at(focus)
	status.text = "%s   Ball %.1f m   Hand IK %.0f%% / %.0f%%" % [d._gait,
		d.flat().distance_to(Vector3(court._ball.position.x, 0, court._ball.position.z)), d.w_l * 100, d.w_r * 100]
