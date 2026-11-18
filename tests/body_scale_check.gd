extends Node
## Measures the court rig's segment lengths and joint placement, against the
## football body's reference (web/stack/skeleton.js) scaled to the same height.
const CourtScene: PackedScene = preload("res://scenes/court/court_game.tscn")
const CourtGame = preload("res://scripts/court/court_game.gd")
# Football reference, metres, for a 1.81 m body (its pelvis-to-head length defines the scale).
const REF := {"upper_arm": 0.29, "forearm": 0.26, "hand": 0.19, "thigh": 0.45, "shin": 0.43,
	"shoulder_span": 0.43, "pelvis_height": 0.99, "neck_to_head": 0.09}
var c
func _ready() -> void:
	GameState.reset()
	GameState.look_id = "look_a"
	CourtGame.auto_play = false
	c = CourtScene.instantiate()
	c.scenario = CourtGame.demo_scenario()
	add_child(c)
	while c._phase != CourtGame.Phase.LIVE:
		await get_tree().physics_frame
	var a = c._defense[0]
	var sk: Skeleton3D = a._skeleton
	var g: Transform3D = sk.global_transform
	var sc: float = g.basis.get_scale().x
	print("skeleton world scale %.3f  model scale %.3f  STATURE %.2f" % [sc, a._model.scale.x, a.STATURE])
	var P := func(b: String) -> Vector3: return g * sk.get_bone_global_rest(sk.find_bone(b)).origin
	var seg := func(x: String, y: String) -> float: return (P.call(x) as Vector3).distance_to(P.call(y))
	var ltop: float = (P.call("Head") as Vector3).y - (P.call("LeftFoot") as Vector3).y
	var s: float = a.STATURE / ltop  # scale this rig to the standard 1.81 m body
	print("rig foot-to-head height %.3f m -> scale to 1.81 m: x%.3f" % [ltop, s])
	var rows := {
		"upper_arm": seg.call("RightUpperArm", "RightLowerArm"),
		"forearm": seg.call("RightLowerArm", "RightHand"),
		"thigh": seg.call("RightUpperLeg", "RightLowerLeg"),
		"shin": seg.call("RightLowerLeg", "RightFoot"),
		"shoulder_span": seg.call("RightUpperArm", "LeftUpperArm"),
		"pelvis_height": (P.call("Hips") as Vector3).y - (P.call("LeftFoot") as Vector3).y,
	}
	for k in rows:
		var raw: float = rows[k]
		var ref: float = REF[k]
		print("%-14s rig %.3f m  reference %.3f m  off by %+.1f%%" % [k, raw, ref, (raw / ref - 1.0) * 100.0])
	var top: float = (P.call("Head_end") as Vector3).y - (P.call("LeftFoot") as Vector3).y if sk.find_bone("Head_end") >= 0 else -1.0
	print("ankle-to-head joint %.3f m (football: 1.61 m)   top of head %.3f m (football: 1.81 m)" % [ltop, top])
	get_tree().quit(0)
