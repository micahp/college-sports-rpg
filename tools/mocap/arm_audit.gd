extends Node3D
const Actor = preload("res://scripts/court/court_actor.gd")

func _ready() -> void:
	var a = Actor.new()
	add_child(a)
	a.setup("", {}, 0, 0.0)
	await get_tree().process_frame
	var sk: Skeleton3D = a.get("_skeleton")
	var k: float = sk.global_transform.basis.get_scale().x
	var rest := func(n: String) -> Vector3: return sk.get_bone_global_rest(sk.find_bone(n)).origin * k
	for side in ["Left", "Right"]:
		var up: Vector3 = rest.call(side + "UpperArm")
		var lo: Vector3 = rest.call(side + "LowerArm")
		var ha: Vector3 = rest.call(side + "Hand")
		var mf: Vector3 = rest.call("MiddleHand." + side[0])
		print("ARM %s upper %.3f forearm %.3f hand %.3f shoulder->wrist %.3f" % [side, up.distance_to(lo), lo.distance_to(ha), ha.distance_to(mf), up.distance_to(ha)])
	print("ARM shoulder width %.3f" % (rest.call("LeftUpperArm") - rest.call("RightUpperArm")).length())
	print("ARM hips %.3f shoulder %.3f head %.3f" % [rest.call("Hips").y, rest.call("LeftUpperArm").y, rest.call("Head").y])
	get_tree().quit(0)
