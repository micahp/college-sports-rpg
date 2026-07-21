extends Node
## Captures PNG screenshots of the campus for visual review:
##   xvfb-run godot --path . tests/screenshot.tscn
## Saves wide and close-up shots to res://build/shots/ then quits.

var _campus: Node2D


func _ready() -> void:
	await _run()
	get_tree().quit(0)


func _run() -> void:
	_campus = load("res://scenes/world/campus.tscn").instantiate()
	add_child(_campus)
	await _frames(20)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shots"))

	await _shoot("res://build/shots/courtyard.png")

	# Jordan: proximity prompt.
	var jordan: Node = _campus.get_node("Actors/Jordan")
	_campus.get_node("Actors/Player").global_position = jordan.global_position + Vector2(-10, 64)
	await _frames(30)
	await _shoot("res://build/shots/npc_prompt.png")

	# Coach Delgado: dialogue advanced to the choice buttons.
	var coach: Node = _campus.get_node("Actors/Coach")
	_campus.get_node("Actors/Player").global_position = coach.global_position + Vector2(0, 64)
	await _frames(30)
	_campus._do_interact()
	await _frames(10)
	await _shoot("res://build/shots/dialogue.png")
	var dialogue: PanelContainer = _campus.get_node("UI/Dialogue")
	while dialogue.state == dialogue.State.LINES and dialogue.visible:
		dialogue.advance()
		await _frames(5)
	await _shoot("res://build/shots/choices.png")


func _shoot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
