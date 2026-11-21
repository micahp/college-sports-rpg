extends Node
## Rest pose against skin bind pose, two imports of the student FBX side by side
## at their own rest pose: no animation, no modifier, same cameras.
##   left:  the ORIGINAL import (retarget rest fixer with fix_silhouette on)
##   right: the game's import (fix_silhouette off since rig/bind-pose-import)
## Prints, for each import, how far apart the bones sharing a vertex put it at
## rest (0 everywhere when rest = bind) and where the skin was bound each joint
## relative to its rest, and renders front, side, back, shoulders and feet to
## build/rig/bind_compare/.
## The original import is not in the repo (build/ is ignored); make it with:
##   cp assets/court/students/Male_Casual.fbx build/rigtest/orig.fbx
##   copy the old Male_Casual.fbx.import (fix_silhouette true) to
##   build/rigtest/orig.fbx.import with the source path changed and
##   uid/path/dest_files removed; then godot --headless --import
##   godot --fixed-fps 60 --path . res://tests/rig/bind_compare.tscn [-- left=<res path> right=<res path>]
const GAME: String = "res://assets/court/students/Male_Casual.fbx"
const Checks = preload("res://tests/rig/skeleton_checks.gd")


func _ready() -> void:
	var paths := ["res://build/rigtest/orig.fbx", GAME]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("left="):
			paths[0] = a.substr(5)
		elif a.begins_with("right="):
			paths[1] = a.substr(6)
	var headless: bool = DisplayServer.get_name() == "headless"
	if not headless:
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
	for i in 2:
		var m: Node3D = (load(paths[i]) as PackedScene).instantiate()
		add_child(m)
		for ap: AnimationPlayer in m.find_children("*", "AnimationPlayer", true, false):
			ap.stop()
		var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
		sk.reset_bone_poses()
		sk.force_update_all_bone_transforms()
		var mi: MeshInstance3D = m.find_children("*", "MeshInstance3D", true, false)[0]
		# Measurements, in % of the mesh's own height so the two imports compare.
		var verts := Checks._rest_vertices(sk, mi)
		var lo := INF
		var hi := -INF
		for v: Array in verts:
			lo = minf(lo, (v[0] as Vector3).y)
			hi = maxf(hi, (v[0] as Vector3).y)
		var cm: float = 181.0 / (hi - lo)  # cm per skeleton unit for a 1.81 m body
		var mism := Checks.bind_mismatch(sk, mi)
		var pairs: Array = []
		for k: String in mism:
			pairs.append([float(mism[k]) * cm, k])
		pairs.sort_custom(func(a, b): return a[0] > b[0])
		var over := pairs.filter(func(p): return float(p[0]) > 0.5).size()
		print("%s %s: mesh %.3f units tall at rest; %d bone pairs disagree on a shared vertex by more than 0.5 cm (at 1.81 m), worst %s" % [
			"LEFT " if i == 0 else "RIGHT", paths[i], hi - lo, over, ("%.1f cm %s" % [pairs[0][0], pairs[0][1]]) if not pairs.is_empty() else "-"])
		for b: String in ["LeftUpperLeg", "LeftLowerLeg", "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "Head", "Foot.L"]:
			var d: Vector3 = Checks.bind_joint(sk, mi, b) - sk.get_bone_global_rest(sk.find_bone(b)).origin
			print("      %-14s bound %s cm from its rest (x left, y up, z front)" % [b, (d * cm).snapped(Vector3.ONE * 0.1)])
		if headless:
			m.queue_free()
			continue
		var top: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head_end")).origin
		m.scale = Vector3.ONE * (1.75 / maxf(top.y - m.global_position.y, 0.001))
		m.position = Vector3(-0.55 if i == 0 else 0.55, 0, 0)
	if headless:
		get_tree().quit(0)
		return
	var out := "res://build/rig/bind_compare/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	for v: Array in [["front", Vector3(0, 1.0, 4.0), Vector3(0, 0.9, 0)], ["side", Vector3(4.2, 1.0, 0.3), Vector3(0, 0.9, 0)],
			["back", Vector3(0, 1.0, -4.0), Vector3(0, 0.9, 0)], ["shoulders", Vector3(0.0, 1.55, 1.5), Vector3(0, 1.4, 0)],
			["hips", Vector3(0.0, 0.9, 1.6), Vector3(0, 0.85, 0)], ["feet", Vector3(0.4, 0.35, 1.6), Vector3(0, 0.08, 0)]]:
		cam.global_position = v[1]
		cam.look_at(v[2], Vector3.UP)
		for k in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out + "%s.png" % v[0]))
	print("renders: left ", paths[0], ", right ", paths[1], " -> ", ProjectSettings.globalize_path(out))
	get_tree().quit(0)
