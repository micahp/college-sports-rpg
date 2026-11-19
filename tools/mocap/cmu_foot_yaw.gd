extends SceneTree
## CMU source foot heading relative to the hips, over the slide clip (no student involved).
const Retarget = preload("res://scripts/court/mocap_retarget.gd")

func _init() -> void:
	for spec in [["res://assets/court/slide_r.glb", "slide_r"], ["res://assets/court/slide_l.glb", "slide_l"]]:
		var src: Node = (load(spec[0]) as PackedScene).instantiate()
		var sk: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0]
		var player: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
		var anim: Animation = player.get_animation(spec[1])
		var tracks: Dictionary = Retarget._tracks_by_bone(anim)
		var hips: int = sk.find_bone("Hips")
		var rf: int = sk.find_bone("RightFoot")
		var lf: int = sk.find_bone("LeftFoot")
		var lo: float = INF
		var hi: float = -INF
		var lo_l: float = INF
		var hi_l: float = -INF
		var steps: int = 120
		for f in steps + 1:
			var t: float = anim.length * f / steps
			var g: Array = Retarget._pose_globals(sk, anim, tracks, t)
			var hb: Basis = (g[hips] as Transform3D).basis
			var yaw_hips: float = atan2(hb.z.x, hb.z.z)
			for pair in [[rf, "R"], [lf, "L"]]:
				var fb: Basis = (g[pair[0]] as Transform3D).basis
				var heading: Vector3 = fb * Vector3.BACK
				var yaw: float = rad_to_deg(wrapf(atan2(heading.x, heading.z) - yaw_hips, -PI, PI))
				if pair[1] == "R":
					lo = minf(lo, yaw); hi = maxf(hi, yaw)
				else:
					lo_l = minf(lo_l, yaw); hi_l = maxf(hi_l, yaw)
		print("%s  RightFoot yaw vs hips %.0f .. %.0f deg   LeftFoot %.0f .. %.0f deg  (clip %.2fs)" % [spec[1], lo, hi, lo_l, hi_l, anim.length])
		src.free()
	quit(0)
