extends Node3D
## Thumb direction (perpendicular to the forearm, world-up component) through the slide, game vs CMU source.
const Actor = preload("res://scripts/court/court_actor.gd")
const Tap = preload("res://tests/court_joint_tap.gd")
const R = preload("res://scripts/court/mocap_retarget.gd")
var _tu: Dictionary = {"L": [], "R": []}

func _up(axis_from: Vector3, axis_to: Vector3, thumb_from: Vector3, thumb_to: Vector3) -> float:
	var axis: Vector3 = (axis_to - axis_from).normalized()
	var th: Vector3 = thumb_to - thumb_from
	var perp: Vector3 = th - axis * th.dot(axis)
	return perp.normalized().y if perp.length() > 1e-6 else 0.0

func final_pose(sk: Skeleton3D) -> void:
	for side in ["L", "R"]:
		var s: String = "Left" if side == "L" else "Right"
		var lo := sk.get_bone_global_pose(sk.find_bone(s + "LowerArm")).origin
		var ha := sk.get_bone_global_pose(sk.find_bone(s + "Hand")).origin
		var th := sk.get_bone_global_pose(sk.find_bone("Thumb1." + side)).origin
		_tu[side].append(_up(lo, ha, ha, th))

func _stats(a: Array) -> String:
	var down := 0
	var sum := 0.0
	for v in a:
		sum += v
		if v < 0.0: down += 1
	return "mean %+.2f  thumb-down frames %d%%" % [sum / maxf(a.size(), 1), 100 * down / maxi(a.size(), 1)]

func _ready() -> void:
	var a = Actor.new()
	add_child(a)
	a.setup("", {}, 0, 0.0)
	a.set("team", 1)
	var sk: Skeleton3D = a.get("_skeleton")
	var tap: SkeletonModifier3D = Tap.new()
	tap.qa = self
	sk.add_child(tap)
	for i in 200:
		a.call("pose_reset")
		a.set("team", 1)
		a.call("lock_face", a.position + Vector3(0, 0, -8.0))
		a.call("move_with", Vector3(2.63, 0, 0), 1.0 / 60.0, 16.0)
		a.call("animate", 1.0 / 60.0)
		await get_tree().process_frame
		if i < 80:
			_tu["L"].clear(); _tu["R"].clear()
	print("THUMB game  SlideR  L: ", _stats(_tu["L"]), " | R: ", _stats(_tu["R"]), " gait ", a.get("_gait"))
	# CMU source: its thumb bone sits on the wrist, so take the thumb as the rest thumb direction (T-pose,
	# thumbs forward = +Z) turned by the hand bone's rotation since rest.
	var src: Node = (load("res://assets/court/slide_r.glb") as PackedScene).instantiate()
	var csk: Skeleton3D = CourtPlayerModel.find_skeleton(src)
	var anim: Animation = (src.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer).get_animation("slide_r")
	var tr: Dictionary = R._tracks_by_bone(anim)
	var rest: Array = R._global_rests(csk)
	var cu: Dictionary = {"L": [], "R": []}
	for f in 60:
		var t: float = anim.length * f / 60.0
		var g: Array = R._pose_globals(csk, anim, tr, t)
		for side in ["L", "R"]:
			var s: String = "Left" if side == "L" else "Right"
			var hi: int = csk.find_bone(s + "Hand")
			var li: int = csk.find_bone(s + "LowerArm")
			var d: Basis = (g[hi] as Transform3D).basis * (rest[hi] as Transform3D).basis.inverse()
			var thumb: Vector3 = d * Vector3(0, 0, 1)
			var ho: Vector3 = (g[hi] as Transform3D).origin
			cu[side].append(_up((g[li] as Transform3D).origin, ho, Vector3.ZERO, thumb))
	print("THUMB CMU   slide_r L: ", _stats(cu["L"]), " | R: ", _stats(cu["R"]))
	get_tree().quit(0)
