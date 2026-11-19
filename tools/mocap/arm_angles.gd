extends Node3D
const Actor = preload("res://scripts/court/court_actor.gd")
const Tap = preload("res://tests/court_joint_tap.gd")
var _rows: Array = []

func final_pose(sk: Skeleton3D) -> void:
	var r := {}
	for side in ["Left", "Right"]:
		var sh: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(side + "UpperArm")).origin
		var el: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(side + "LowerArm")).origin
		var wr: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(side + "Hand")).origin
		var ua: Vector3 = (el - sh).normalized()
		var fa: Vector3 = (wr - el).normalized()
		r[side + "_elbow_bend"] = rad_to_deg(acos(clampf(-ua.dot(fa), -1.0, 1.0)))
		r[side + "_upper_from_down"] = rad_to_deg(acos(clampf(-ua.y, -1.0, 1.0)))
		r[side + "_forearm_from_horiz"] = rad_to_deg(asin(clampf(absf(fa.y), 0.0, 1.0)))
	_rows.append(r)

func _report(label: String, rows: Array) -> void:
	var m := {}
	for r in rows:
		for k in r: m[k] = m.get(k, 0.0) + r[k]
	var s := label
	for k in ["Left_elbow_bend", "Left_upper_from_down", "Right_elbow_bend", "Right_upper_from_down"]:
		s += "  %s %.0f" % [k, m[k] / maxf(rows.size(), 1)]
	print("ANG ", s)

func _ready() -> void:
	var a = Actor.new()
	add_child(a)
	a.setup("", {}, 0, 0.0)
	var sk: Skeleton3D = a.get("_skeleton")
	sk.add_child(Tap.new())
	(sk.get_child(sk.get_child_count() - 1) as SkeletonModifier3D).set("qa", self)
	for i in 120:
		a.call("pose_reset")
		a.set("team", 1)
		a.call("lock_face", a.position + Vector3(0, 0, -8.0))
		a.call("animate", 1.0 / 60.0)
		await get_tree().process_frame
	_report("stance(idle):", _rows)
	_rows.clear()
	var o = Actor.new()
	add_child(o)
	o.setup("", {}, 0, 0.0)
	o.position = Vector3(0, 0, 3.0)
	var d = a
	d.position = Vector3(0, 0, 0)
	var dsk: Skeleton3D = o.get("_skeleton")
	var tap := Tap.new()
	tap.set("qa", self)
	dsk.add_child(tap)
	for i in 120:
		o.call("pose_reset")
		o.call("animate", 1.0 / 60.0)
		d.call("pose_reset")
		d.set("team", 1)
		d.call("lock_face", o.position)
		for side in ["L", "R"]:
			var lateral := 1.0 if side == "R" else -1.0
			var palm: Vector3 = d.body_point(0.34 + 0.06 * 0.5, lateral * (0.30 - 0.06 * 0.5), 0.98 + 0.05 * 0.5)
			d.call("hand", side, palm - d.facing() * 0.08, 1.0)
			d.call("palm_on", side, palm, palm + d.facing() - Vector3.UP * 0.3 - d.right() * lateral * 0.5, 1.0)
		d.set("guard_elbow", true)
		d.call("animate", 1.0 / 60.0)
		await get_tree().process_frame
	_report("guard(held):", _rows)
	for fwd in [0.18]:
		for lat in [0.20]:
			for h in [0.90]:
				await _sweep(fwd, lat, h)
	get_tree().quit(0)

func _sweep(fwd: float, lat: float, h: float) -> void:
	_rows.clear()
	var o = Actor.new()
	add_child(o)
	o.setup("", {}, 0, 0.0)
	o.position = Vector3(0, 0, 3.0)
	var d = Actor.new()
	add_child(d)
	d.setup("", {}, 0, 0.0)
	d.position = Vector3(0, 0, 0)
	var dsk: Skeleton3D = d.get("_skeleton")
	var tap := Tap.new()
	tap.set("qa", self)
	dsk.add_child(tap)
	for i in 100:
		o.call("pose_reset")
		o.call("animate", 1.0 / 60.0)
		d.call("pose_reset")
		d.set("team", 1)
		d.call("lock_face", o.position)
		for side in ["L", "R"]:
			var lateral := 1.0 if side == "R" else -1.0
			var palm: Vector3 = d.body_point(fwd, lateral * lat, h)
			d.call("hand", side, palm - d.facing() * 0.08, 1.0)
			d.call("palm_on", side, palm, palm + d.facing() - Vector3.UP * 0.3 - d.right() * lateral * 0.5, 1.0)
		d.set("guard_elbow", true)
		d.call("animate", 1.0 / 60.0)
		await get_tree().process_frame
	_report("fwd %.2f lat %.2f h %.2f:" % [fwd, lat, h], _rows)
	o.queue_free()
	d.queue_free()
	await get_tree().process_frame
