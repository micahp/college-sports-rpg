extends SceneTree
## Prints the student and CMU skeletons as the game imports them, and the
## track paths of the game's JumpShot clip.

func _init() -> void:
	var student: Node = (load("res://assets/court/students/Male_Casual.fbx") as PackedScene).instantiate()
	var sk: Skeleton3D = student.find_children("*", "Skeleton3D", true, false)[0]
	print("STUDENT skeleton path from root: ", student.get_path_to(sk), " unique=", sk.unique_name_in_owner, " name=", sk.name)
	for i in sk.get_bone_count():
		var g: Transform3D = sk.get_bone_global_rest(i)
		print("  S %2d %-14s parent=%-14s rest_y=%.3f pos=%s" % [i, sk.get_bone_name(i), sk.get_bone_name(sk.get_bone_parent(i)) if sk.get_bone_parent(i) >= 0 else "-", g.origin.y, g.origin.snapped(Vector3.ONE * 0.001)])
	var cmu: Node = (load("res://assets/court/jumpshot.glb") as PackedScene).instantiate()
	var ck: Skeleton3D = cmu.find_children("*", "Skeleton3D", true, false)[0]
	print("CMU skeleton: ", cmu.get_path_to(ck), " bones=", ck.get_bone_count())
	for i in ck.get_bone_count():
		var g: Transform3D = ck.get_bone_global_rest(i)
		print("  C %2d %-16s parent=%-16s pos=%s" % [i, ck.get_bone_name(i), ck.get_bone_name(ck.get_bone_parent(i)) if ck.get_bone_parent(i) >= 0 else "-", g.origin.snapped(Vector3.ONE * 0.001)])
	var ap: AnimationPlayer = cmu.find_children("*", "AnimationPlayer", true, false)[0]
	print("CMU anims: ", ap.get_animation_list(), " player root_node=", ap.root_node)
	var a: Animation = ap.get_animation("jumpshot")
	print("jumpshot length ", a.length, " tracks ", a.get_track_count())
	for t in mini(a.get_track_count(), 12):
		print("  T ", a.track_get_type(t), " ", a.track_get_path(t), " keys=", a.track_get_key_count(t))
	var sap: AnimationPlayer = student.get_node("AnimationPlayer")
	print("student AnimationPlayer root_node=", sap.root_node, " path from model=", student.get_path_to(sap))
	student.free(); cmu.free()
	quit(0)
