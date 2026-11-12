extends Node
var is_runner: bool = false
func _ready() -> void:
	if not is_runner:
		var r: Node = Node.new()
		r.set_script(get_script())
		r.set("is_runner", true)
		get_tree().root.add_child.call_deferred(r)
		return
	get_tree().create_timer(30.0, true, false, true).timeout.connect(func() -> void: get_tree().quit(2))
	get_tree().change_scene_to_file(Game.SCENES["title"])
	for i in 5: await get_tree().process_frame
	var t: Node = get_tree().current_scene
	t.find_child("NewGame", true, false).pressed.emit()
	for i in 10: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/looks/looks.png"))
	get_tree().quit()
