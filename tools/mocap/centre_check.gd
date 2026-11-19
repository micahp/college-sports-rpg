extends Node3D
const Actor = preload("res://scripts/court/court_actor.gd")
func _ready() -> void:
	var a = Actor.new()
	add_child(a)
	a.setup("", {}, 0, 0.0)
	await get_tree().process_frame
	var sk: Skeleton3D = a.get("_skeleton")
	for i in 30:
		a.call("pose_reset")
		a.call("animate", 1.0 / 60.0)
		await get_tree().process_frame
	var ls: Vector3 = sk.get_bone_global_pose(sk.find_bone("LeftUpperArm")).origin
	var rs: Vector3 = sk.get_bone_global_pose(sk.find_bone("RightUpperArm")).origin
	var mid := (ls + rs) * 0.5
	var lat: Vector3 = (ls - rs).normalized()
	var off: Vector3 = mid - a.global_position
	var right: Vector3 = a.right()
	print("CENTRE shoulder midline vs body centre: lateral %.3f  forward %.3f  (metres)" % [off.dot(right), off.dot(a.facing())])
	print("CENTRE left-right shoulder offset along right axis: L %.3f R %.3f" % [(ls - a.global_position).dot(right), (rs - a.global_position).dot(right)])
	get_tree().quit(0)
