extends Node
## Ending -> regular season: presses "Start regular season" and waits for the
## scene change to finish, then checks the season screen is the live scene.

const ENDING = preload("res://scenes/app/ending.tscn")
const SEASON_PATH: String = "res://scenes/app/season.tscn"
const SAVE_PATH: String = "user://save_v2.json"
var failures := 0
var checks := 0


func check(condition: bool, detail: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(detail)


func _ready() -> void:
	call_deferred("_detach")


## The scene change frees the current scene, so this runner moves to the root first.
func _detach() -> void:
	var tree: SceneTree = get_tree()
	get_parent().remove_child(self)
	tree.root.add_child(self)
	run()


func run() -> void:
	var had_save: bool = FileAccess.file_exists(SAVE_PATH)
	var backup: String = ""
	if had_save:
		backup = FileAccess.open(SAVE_PATH, FileAccess.READ).get_as_text()
	Game.in_game = false
	Game.season = {}
	Game.outcome = {"id": "roster", "score": 60, "title": "T", "text": "x"}
	var ending = ENDING.instantiate()
	add_child(ending)
	var button: Button = null
	for child in ending.find_children("*", "Button", true, false):
		if child.text == "Start regular season":
			button = child
	check(button != null, "Ending shows the regular season button")
	if button != null:
		button.pressed.emit()
	var arrived := false
	for frame in 600:
		await get_tree().process_frame
		var scene: Node = get_tree().current_scene
		if scene != null and scene.scene_file_path == SEASON_PATH and not Game.is_changing_scene():
			arrived = true
			break
	check(arrived, "Scene change completes into the season scene")
	if arrived:
		var labels: Array = []
		for child in get_tree().current_scene.find_children("*", "Label", true, false):
			labels.append(child.text)
		var has_board: bool = false
		for text in labels:
			if str(text).begins_with("North Valley State  /  Season board"):
				has_board = true
		check(has_board, "Season board is drawn after the transition")
		check(Game.location == "season" and Game.in_game, "Game state is in the season after the transition")
	if had_save:
		var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		file.store_string(backup)
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	print("Season transition: %d checks, %d failures" % [checks, failures])
	get_tree().quit(int(failures > 0))
