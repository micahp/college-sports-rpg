extends SceneTree
## Upper arms against the chest, through each CMU defense clip: out to the side and forward/back, averaged over the clip.
const Retarget = preload("res://scripts/court/mocap_retarget.gd")

func _init() -> void:
	for spec in [["res://assets/court/backpedal.glb", "backpedal"], ["res://assets/court/slide_l.glb", "slide_l"], ["res://assets/court/slide_r.glb", "slide_r"]]:
		var n: String = spec[1]
		var path: String = spec[0]
		var src: Node = (load(path) as PackedScene).instantiate()
		var sk: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0]
		var player: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
		var names: PackedStringArray = player.get_animation_list()
		var anim: Animation = player.get_animation(spec[1])
		var tracks: Dictionary = Retarget._tracks_by_bone(anim)
		var acc: Dictionary = {"La": 0.0, "Lf": 0.0, "Ra": 0.0, "Rf": 0.0, "Lk": 0.0, "Rk": 0.0}
		var steps: int = 40
		for f in steps + 1:
			var g: Array = Retarget._pose_globals(sk, anim, tracks, anim.length * f / steps)
			var ch: Basis = (g[sk.find_bone("Chest")] as Transform3D).basis
			var up: Vector3 = (g[sk.find_bone("Chest")] as Transform3D).origin
			var hp: Vector3 = (g[sk.find_bone("Hips")] as Transform3D).origin
			var cu: Vector3 = (up - hp).normalized()
			var fwd: Vector3 = (ch.z).cross(cu).normalized()
			for side in ["Left", "Right"]:
				var s: Vector3 = (g[sk.find_bone(side + "UpperArm")] as Transform3D).origin
				var e: Vector3 = (g[sk.find_bone(side + "LowerArm")] as Transform3D).origin
				var w: Vector3 = (g[sk.find_bone(side + "Hand")] as Transform3D).origin
				var u: Vector3 = (e - s).normalized()
				var lat: float = rad_to_deg(atan2(absf(u.dot(ch.x)), -u.dot(cu)))
				var ff: float = rad_to_deg(atan2(u.dot(fwd), -u.dot(cu)))
				var el: float = rad_to_deg(acos(clampf(-u.dot((w - e).normalized()), -1.0, 1.0)))
				var k: String = "L" if side == "Left" else "R"
				acc[k + "a"] = acc.get(k + "a", 0.0)
				acc[k + "a" if false else ("La" if side == "Left" else "Ra")] += lat / (steps + 1)
				acc[("Lf" if side == "Left" else "Rf")] += ff / (steps + 1)
				acc[("Lk" if side == "Left" else "Rk")] += el / (steps + 1)
		print("CLIP %s  %s  L out %.0f fwd %+.0f elbow %.0f | R out %.0f fwd %+.0f elbow %.0f  (%.2fs, anim %s)" % [n, "", acc["La"], acc["Lf"], acc["Lk"], acc["Ra"], acc["Rf"], acc["Rk"], anim.length, spec[1]])
		src.free()
	quit(0)
