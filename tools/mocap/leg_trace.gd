extends Node3D
## Per-frame leg trace through the right slide: thigh and shin angles and foot offset for both legs,
## in the actor's own frame (x = character's right, y = up, -z = facing).
const Actor = preload("res://scripts/court/court_actor.gd")

func _ready() -> void:
	var a = Actor.new()
	add_child(a)
	a.setup("", {"Shirt": Color(0.8, 0.15, 0.2), "Pants": Color(1, 1, 1), "Skin": Color(0.48, 0.34, 0.24), "Socks": Color(0.95, 0.95, 0.95)}, 0, 0.0)
	a.set("team", 1)
	var sk: Skeleton3D = a.find_children("*", "Skeleton3D", true, false)[0]
	var names: Dictionary = {}
	names["Hips"] = sk.find_bone("Hips")
	for side in ["Left", "Right"]:
		for b in ["UpperLeg", "LowerLeg", "Foot"]:
			names[side + b] = sk.find_bone(side + b)
	print("bones ", names)
	for side in ["L", "R"]:
		var c: int = sk.find_bone("Foot." + side)
		var an: int = sk.find_bone(("Left" if side == "L" else "Right") + "Foot")
		var d: Vector3 = sk.get_bone_global_rest(c).origin - sk.get_bone_global_rest(an).origin
		print("REST ctrl-ankle %s  xz %.3f  full %.3f" % [side, Vector2(d.x, d.z).length(), d.length()])
	for i in 300:
		a.call("pose_reset")
		a.set("team", 1)
		a.call("lock_face", a.position + Vector3(0, 0, -8.0))
		a.call("move_with", Vector3(2.63, 0, 0), 1.0 / 60.0, 16.0)
		a.call("animate", 1.0 / 60.0)
		await get_tree().process_frame
		if i % 15 != 0:
			continue
		var inv: Basis = a.global_transform.basis.inverse()
		var line: String = "f%03d" % i
		for side in ["Left", "Right"]:
			var th: Vector3 = _pos(sk, names[side + "UpperLeg"], inv, a.global_position)
			var kn: Vector3 = _pos(sk, names[side + "LowerLeg"], inv, a.global_position)
			var ft: Vector3 = _pos(sk, names[side + "Foot"], inv, a.global_position)
			var hp: Vector3 = _pos(sk, names["Hips"], inv, a.global_position)
			var thigh_dir: Vector3 = (kn - th).normalized()
			var shin_dir: Vector3 = (ft - kn).normalized()
			var tilt: float = rad_to_deg(acos(clampf(thigh_dir.dot(Vector3.DOWN), -1.0, 1.0)))
			var knee: float = rad_to_deg(acos(clampf(thigh_dir.dot(-shin_dir), -1.0, 1.0)))
			var foot_x: float = ft.x - hp.x
			var foot_z: float = ft.z - hp.z
			var ctrl: int = sk.find_bone("Foot." + side[0])
			var shoe_off: Vector3 = _pos(sk, ctrl, inv, a.global_position) - ft if ctrl >= 0 else Vector3.ZERO
			line += "  %s thigh %5.1f knee %5.1f foot(x %+.2f z %+.2f y %.2f) shoe-ankle(x %+.3f y %+.3f z %+.3f)" % [side[0], tilt, knee, foot_x, foot_z, ft.y, shoe_off.x, shoe_off.y, shoe_off.z]
		print(line + "  ctrlY R %.3f L %.3f  SOLE min R %.3f L %.3f  bodylift %.3f low_n %d" % [_pos(sk, sk.find_bone("Foot.R"), inv, a.global_position).y, _pos(sk, sk.find_bone("Foot.L"), inv, a.global_position).y, _shoe_low(a, sk, "Foot.R"), _shoe_low(a, sk, "Foot.L"), (a.get("_body_floor").last_lift if a.get("_body_floor") != null else -1.0), (a.get("_body_floor")._low.size() if a.get("_body_floor") != null else -1)])
	get_tree().quit(0)

func _pos(sk: Skeleton3D, i: int, inv: Basis, origin: Vector3) -> Vector3:
	return inv * (sk.global_transform * sk.get_bone_global_pose(i).origin - origin)

## Lowest world height of the drawn shoe vertices (dominant weight on the shoe control), in the actor's frame.
func _shoe_low(a: Node, sk: Skeleton3D, ctrl: String) -> float:
	var low: float = INF
	var bone_idx: int = sk.find_bone(ctrl)
	var inv: Basis = a.global_transform.basis.inverse()
	for mi: MeshInstance3D in a.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null or mi.mesh == null:
			continue
		var skin: Skin = mi.skin
		var binds: Array[int] = []
		for i in skin.get_bind_count():
			var b: int = skin.get_bind_bone(i)
			binds.append(b if b >= 0 else sk.find_bone(skin.get_bind_name(i)))
		for s in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			if bones.is_empty() or verts.is_empty():
				continue
			var per: int = bones.size() / verts.size()
			for v in verts.size():
				var best_w: float = 0.0
				var best_b: int = -1
				for k in per:
					var w: float = wts[v * per + k]
					if w > best_w and binds[bones[v * per + k]] >= 0:
						best_w = w
						best_b = bones[v * per + k]
				if best_b < 0 or binds[best_b] != bone_idx or best_w < 0.5:
					continue
				var p: Vector3 = Vector3.ZERO
				for k in per:
					var w: float = wts[v * per + k]
					var bi: int = bones[v * per + k]
					if w <= 0.0 or binds[bi] < 0:
						continue
					var local: Vector3 = skin.get_bind_pose(bi) * verts[v]
					p += (sk.get_bone_global_pose(binds[bi]) * local) * w
				var world: Vector3 = inv * (sk.global_transform * p - a.global_position)
				low = minf(low, world.y)
	return low
