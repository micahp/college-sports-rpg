extends Node
## Records the Milestone 1.6 gameplay clip (~13s). Run with Movie Maker mode:
##   xvfb-run godot --path . --write-movie build/clip/clip.avi --fixed-fps 30 tests/clip3d.tscn
## Sequence: establish the branded courtyard, walk up and approach Jordan,
## his speech indicator appears, open the conversation (camera eases into the
## profile two-shot), close it, then walk off toward the Rec Center plaza.

var _campus: Node3D


func _ready() -> void:
	await _run()
	get_tree().quit(0)


func _run() -> void:
	_campus = load("res://scenes/world3d/campus3d.tscn").instantiate()
	add_child(_campus)
	await _seconds(1.2)

	# Walk north up the promenade to show the space.
	Input.action_press("move_up")
	await _seconds(1.0)

	# Angle toward Jordan, standing in the center plaza.
	Input.action_press("move_right")
	await _seconds(1.0)
	Input.action_release("move_up")
	Input.action_release("move_right")
	await _seconds(0.8)

	# Talk — indicator is bobbing; camera eases into the two-shot.
	_campus._do_interact()
	await _seconds(4.2)
	_campus._dialogue.close()
	await _seconds(0.8)

	# Walk off toward the Rec Center, curving onto the plaza emblem.
	Input.action_press("move_up")
	await _seconds(1.2)
	Input.action_press("move_left")
	await _seconds(1.4)
	Input.action_release("move_left")
	await _seconds(0.6)
	Input.action_release("move_up")
	await _seconds(0.8)


func _seconds(duration: float) -> void:
	var frames: int = int(duration * 30.0)
	for i in frames:
		await get_tree().process_frame
