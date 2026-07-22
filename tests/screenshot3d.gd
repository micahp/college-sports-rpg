extends Node
## Captures PNG screenshots of the 3D campus for visual review:
##   xvfb-run godot --path . tests/screenshot3d.tscn
## Shots: spawn view, walking mid-courtyard, near Jordan with indicator,
## and the open dialogue. Saves to res://build/shots3d/ then quits.

var _campus: Node3D


func _ready() -> void:
	await _run()
	get_tree().quit(0)


func _run() -> void:
	_campus = load("res://scenes/world3d/campus3d.tscn").instantiate()
	add_child(_campus)
	await _frames(30)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shots3d"))

	await _shoot("res://build/shots3d/spawn.png")

	# Walk north for a moving shot (walk animation mid-stride).
	Input.action_press("move_up")
	await _frames(45)
	await _shoot("res://build/shots3d/walking.png")
	Input.action_release("move_up")
	await _frames(10)

	# Hero shot: the Rec Center entrance plaza, far enough back to frame the facade.
	_campus.player.global_position = Vector3(0.5, 0.1, -3.0)
	await _frames(50)
	await _shoot("res://build/shots3d/entrance.png")

	# Approach Jordan: indicator visible.
	_campus.player.global_position = _campus.jordan.global_position + Vector3(-1.6, 0.1, 1.4)
	await _frames(40)
	print("indicator visible: ", _campus.jordan._indicator.visible,
		" at ", _campus.jordan._indicator.global_position)
	await _shoot("res://build/shots3d/near_jordan.png")

	# Dialogue open — wait out the 0.7s camera ease before shooting.
	_campus._do_interact()
	await _frames(60)
	await _shoot("res://build/shots3d/dialogue.png")


func _shoot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
