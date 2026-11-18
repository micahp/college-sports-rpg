extends Node
## Court game check: auto-plays one stretch and validates the box score.
## With `-- shots <dir>` it also saves a screenshot every 1.5 s (needs a window).
##
##   godot --headless tests/court_proto.tscn
##   godot tests/court_proto.tscn -- shots C:/path/out

const CourtScene: PackedScene = preload("res://scenes/court/court_game.tscn")
const CourtGame = preload("res://scripts/court/court_game.gd")

var _shots_dir: String = ""
var _dense: bool = OS.get_cmdline_user_args().has("dense")
var _failures: int = 0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = args.find("shots")
	if i >= 0 and i + 1 < args.size():
		_shots_dir = args[i + 1]
	GameState.reset()
	GameState.look_id = "look_a"
	CourtGame.debug_close_cam = args.has("close")
	(load("res://scripts/court/court_actor.gd") as GDScript).set("dribble_log", args.has("dribble_log"))
	CourtGame.auto_play = true
	CourtGame.auto_quality = "good"
	Engine.time_scale = 1.0 if (_shots_dir != "" or args.has("realtime")) else 3.0
	var court: Node3D = CourtScene.instantiate()
	var s: Dictionary = CourtGame.demo_scenario()
	s["clock"] = 120.0
	court.scenario = s
	add_child(court)
	if _shots_dir != "":
		_capture_loop()
	var timeout: SceneTreeTimer = get_tree().create_timer(240.0, true, false, true)
	timeout.timeout.connect(func() -> void:
		print("COURT FAILED: timeout")
		get_tree().quit(1))
	var result: Dictionary = await court.finished
	print("RESULT ", result)
	_check(int(result["fga"]) > 0, "user took shots")
	_check(int(result["fgm"]) <= int(result["fga"]), "makes <= attempts")
	_check(int(result["pts"]) == (int(result["fgm"]) - int(result["tpm"])) * 2 + int(result["tpm"]) * 3, "points add up")
	_check(int(result["team_score"]) >= int(s["team_score"]) + int(result["pts"]), "team score includes user points")
	_check(int(result["opp_score"]) >= int(s["opp_score"]), "opponent score never drops")
	print("COURT PASSED" if _failures == 0 else "COURT FAILED")
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL: ", what)


func _capture_loop() -> void:
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	var n: int = 0
	while n < 40:
		await get_tree().create_timer(0.1 if _dense else (0.25 if CourtGame.debug_close_cam else 0.7)).timeout
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("%s/court_%02d.png" % [_shots_dir, n])
		n += 1
