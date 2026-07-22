extends Node
## Records the Milestone 1.5 gameplay clip. Run with Movie Maker mode:
##   xvfb-run godot --path . --write-movie build/clip/clip.avi --fixed-fps 30 tests/clip3d.tscn
## Sequence (~12s): walk up the main path, cut right to Jordan, indicator
## appears, open the dialogue, close it, walk off toward the Rec Center.

var _campus: Node3D


func _ready() -> void:
	await _run()
	get_tree().quit(0)


func _run() -> void:
	_campus = load("res://scenes/world3d/campus3d.tscn").instantiate()
	add_child(_campus)
	await _seconds(0.8)

	# Walk north along the main path.
	Input.action_press("move_up")
	await _seconds(2.4)
	Input.action_release("move_up")

	# Cut toward Jordan.
	Input.action_press("move_right")
	Input.action_press("move_up")
	await _seconds(0.9)
	Input.action_release("move_up")
	await _seconds(0.5)
	Input.action_release("move_right")
	await _seconds(1.0)

	# Talk (indicator should already be bobbing).
	_campus._do_interact()
	await _seconds(3.2)
	_campus._dialogue.close()
	await _seconds(0.5)

	# Walk off toward the Rec Center plaza.
	Input.action_press("move_up")
	Input.action_press("move_left")
	await _seconds(0.7)
	Input.action_release("move_left")
	await _seconds(2.2)
	Input.action_release("move_up")
	await _seconds(0.6)


func _seconds(duration: float) -> void:
	var frames: int = int(duration * 30.0)
	for i in frames:
		await get_tree().process_frame
