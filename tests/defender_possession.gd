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



var defender: Actor
var frame := 0
func _physics_process(delta: float) -> void:
	if _court._phase != CourtGame.Phase.LIVE:
		if frame > 0: get_tree().quit()
		return
	if defender == null: defender = _court._on_ball_defender()
	if defender == null: return
	_t += delta
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_press("move_left" if _t < 1.5 or _t > 3 else "move_right")

func _process(_delta: float) -> void:
	if defender == null: return
	frame += 1
	var focus := defender.position + Vector3.UP * 0.93
	_cam.current = true
	_cam.position = focus + Vector3(2,0.45,2.8)
	_cam.look_at(focus)
	_court._layer.hide()
	_label.text = "%.2fs  %s   hand IK  %.2f / %.2f" % [_t, defender._gait, defender.w_l, defender.w_r]
	if frame % 2 == 0:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0]+"/%04d.png" % frame)
	if frame >= 150: get_tree().quit()
