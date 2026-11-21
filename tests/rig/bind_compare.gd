extends Node
## Evidence for gate 1 "rest pose = skin bind pose": the student FBX as the game
## imports it (retarget rest fixer with fix_silhouette on) next to the same FBX
## imported with fix_silhouette off, both at their own rest pose, no animation,
## no modifier. Renders front, side and back to build/rig/bind_compare/.
## The second import is not in the repo (build/ is ignored); make it with:
##   cp assets/court/students/Male_Casual.fbx build/rigtest/nofix.fbx
##   copy Male_Casual.fbx.import to build/rigtest/nofix.fbx.import with the
##   source path changed, uid/path/dest_files removed and
##   "retarget/rest_fixer/fix_silhouette/enable": false; then godot --import
##   godot --fixed-fps 60 --path . res://tests/rig/bind_compare.tscn [-- other=res://build/rigtest/nofix.fbx]
const GAME: String = "res://assets/court/students/Male_Casual.fbx"


func _ready() -> void:
	var other := "res://build/rigtest/nofix.fbx"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("other="):
			other = a.substr(6)
	get_window().size = Vector2i(900, 700)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.66, 0.72)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	add_child(sun)
	var models: Array = []
	for i in 2:
		var path: String = GAME if i == 0 else other
		var m: Node3D = (load(path) as PackedScene).instantiate()
		add_child(m)
		for ap: AnimationPlayer in m.find_children("*", "AnimationPlayer", true, false):
			ap.stop()
		var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
		sk.reset_bone_poses()
		# Same height on screen whatever the import scale: the crown joint at 1.75 m.
		sk.force_update_all_bone_transforms()
		var top: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head_end")).origin
		var k: float = 1.75 / maxf(top.y - m.global_position.y, 0.001)
		m.scale = Vector3.ONE * k
		m.position = Vector3(-0.55 if i == 0 else 0.55, 0, 0)
		models.append(m)
	var out := "res://build/rig/bind_compare/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	for v: Array in [["front", Vector3(0, 1.0, 4.0)], ["side", Vector3(4.2, 1.0, 0.3)], ["back", Vector3(0, 1.0, -4.0)], ["feet", Vector3(0.4, 0.35, 1.6)], ["shoulders", Vector3(0.0, 1.55, 1.5)]]:
		cam.global_position = v[1]
		var at := Vector3(0, 0.9, 0)
		if v[0] == "feet":
			at = Vector3(0, 0.08, 0)
		elif v[0] == "shoulders":
			at = Vector3(0, 1.4, 0)
		cam.look_at(at, Vector3.UP)
		for i in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out + "%s.png" % v[0]))
	print("left: the game's import (fix_silhouette on); right: ", other, " -> ", ProjectSettings.globalize_path(out))
	get_tree().quit(0)
