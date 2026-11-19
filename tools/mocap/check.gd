extends SceneTree
## Checks the retargeted court clips against the CMU source on the student skeleton:
## segment direction error (degrees) and ankle height range, for the game's
## library clip and for the engine import retarget it replaces.
##   godot --headless -s tools/mocap/check.gd

const R = preload("res://scripts/court/mocap_retarget.gd")
const PAIRS: Array = [["Hips", "Chest"], ["Chest", "UpperChest"], ["UpperChest", "Head"], ["LeftShoulder", "LeftUpperArm"],
	["LeftUpperArm", "LeftLowerArm"], ["LeftLowerArm", "LeftHand"], ["RightUpperArm", "RightLowerArm"], ["RightLowerArm", "RightHand"],
	["LeftUpperLeg", "LeftLowerLeg"], ["LeftLowerLeg", "LeftFoot"], ["RightUpperLeg", "RightLowerLeg"], ["RightLowerLeg", "RightFoot"]]

func _init() -> void:
	var lib: AnimationLibrary = CourtPlayerModel.library()
	var student: Node = (load(CourtPlayerModel.STUDENT) as PackedScene).instantiate()
	var sk: Skeleton3D = CourtPlayerModel.find_skeleton(student)
	var s_rest: Array = R._global_rests(sk)
	for clip: String in CourtPlayerModel.RETARGETED:
		var spec: Array = CourtPlayerModel.CLIPS[clip]
		var src: Node = (load(spec[0]) as PackedScene).instantiate()
		var csk: Skeleton3D = CourtPlayerModel.find_skeleton(src)
		var canim: Animation = (src.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer).get_animation(spec[1])
		var c_rest: Array = R._global_rests(csk)
		var lat_c: Vector3 = R._flat(c_rest[csk.find_bone("LeftUpperLeg")].origin - c_rest[csk.find_bone("RightUpperLeg")].origin)
		var lat_s: Vector3 = R._flat(s_rest[sk.find_bone("LeftUpperLeg")].origin - s_rest[sk.find_bone("RightUpperLeg")].origin)
		var face: Quaternion = Quaternion(lat_c, lat_s)
		var k: float = R._leg(s_rest, sk) / R._leg(c_rest, csk)
		for which: String in ["new", "import"]:
			var anim: Animation = lib.get_animation(clip) if which == "new" else canim
			var tr: Dictionary = R._tracks_by_bone(anim)
			var ctr: Dictionary = R._tracks_by_bone(canim)
			var worst: Dictionary = {}
			var lo: float = INF
			var hi: float = -INF
			var clo: float = INF
			var chi: float = -INF
			for f in 31:
				var t: float = canim.length * f / 30.0
				var g: Array = R._pose_globals(sk, anim, tr, t)
				var c: Array = R._pose_globals(csk, canim, ctr, t)
				for pr: Array in PAIRS:
					var dc: Vector3 = c[csk.find_bone(pr[1])].origin - c[csk.find_bone(pr[0])].origin
					var ds: Vector3 = g[sk.find_bone(pr[1])].origin - g[sk.find_bone(pr[0])].origin
					if dc.length() < 1e-4 or ds.length() < 1e-4:
						continue
					var e: float = rad_to_deg((face * dc.normalized()).angle_to(ds.normalized()))
					worst[pr[0]] = maxf(worst.get(pr[0], 0.0), e)
				var ay: float = minf(g[sk.find_bone("LeftFoot")].origin.y, g[sk.find_bone("RightFoot")].origin.y)
				lo = minf(lo, ay); hi = maxf(hi, ay)
				var cy: float = minf(c[csk.find_bone("LeftFoot")].origin.y, c[csk.find_bone("RightFoot")].origin.y) * k
				clo = minf(clo, cy); chi = maxf(chi, cy)
			var parts: PackedStringArray = []
			for b: String in worst:
				parts.append("%s %.0f" % [b, worst[b]])
			print("%-10s %-6s ankle lift %.2f (CMU scaled %.2f) | worst seg err deg: %s" % [clip, which, hi - lo, chi - clo, ", ".join(parts)])
		src.free()
	student.free()
	quit(0)
