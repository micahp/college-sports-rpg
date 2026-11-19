extends Node
## Records defender swipes at the ball handler, close up, from the side.
## The game runs as normal; this only starts a reach every 2 s and hands the
## ball back after a poke so the next swipe can be filmed.
##
##   godot --write-movie swipe.avi --fixed-fps 30 --resolution 960x540 res://tests/swipe_clip.tscn

const CourtScene: PackedScene = preload("res://scenes/court/court_game.tscn")
const CourtGame = preload("res://scripts/court/court_game.gd")
const Actor = preload("res://scripts/court/court_actor.gd")
const SWIPES: int = 6
const EVERY: float = 2.0

var _court: Node3D
var _cam: Camera3D
var _t: float = 0.0
var _n: int = 0
var _label: Label
var _outcome: String = ""


func _ready() -> void:
	GameState.reset()
	GameState.look_id = "look_a"
	CourtGame.auto_play = false
	_court = CourtScene.instantiate()
	_court.scenario = CourtGame.demo_scenario()
	add_child(_court)
	_cam = Camera3D.new()
	_cam.fov = 38.0
	seed(417)
	add_child(_cam)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(20, 14)
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_label)
	process_physics_priority = 100
	process_priority = 100




func _physics_process(_delta: float) -> void:
	if _court._phase != CourtGame.Phase.LIVE: return
	var d: Actor = _court._on_ball_defender()
	if d == null: return
	for gap: float in [6.0, 2.5, 2.9, 3.3, 2.9]:
		_court._ball.position = d.position + Vector3.FORWARD * gap
		_court._pose_all()
		d.stop()
		for i in 30: d.animate(1.0/60.0)
		var expected := gap == 2.5 or (gap == 2.9 and _n == 2)
		print("gap ",gap," pressure ",d.pressure_stance," crouch ",d._crouch_now)
		if d.pressure_stance != expected or (not expected and d._crouch_now > 0.001):
			get_tree().quit(1)
			return
		_n += 1
	get_tree().quit()
