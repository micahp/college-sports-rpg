extends Node3D
## Upper arm against the torso, per side, through the stance: abduction (out to the side, from
## straight down), flexion (forward, + = toward the facing), elbow bend, and torso lean.
const Actor = preload("res://scripts/court/court_actor.gd")

func _ready() -> void:
	var a = Actor.new()
	add_child(a)
	a.setup("", {"Shirt": Color(0.8, 0.15, 0.2), "Pants": Color(1, 1, 1), "Skin": Color(0.48, 0.34, 0.24), "Socks": Color(0.95, 0.95, 0.95)}, 0, 0.0)
	a.set("team", 1)
	var sk: Skeleton3D = a.find_children("*", "Skeleton3D", true, false)[0]
	print("bones ", sk.find_bone("LeftUpperArm"), " ", sk.find_bone("LeftLowerArm"), " ", sk.find_bone("LeftHand"), " ", sk.find_bone("UpperChest"), " ", sk.find_bone("Hips"))
	var rinv: Basis = a.global_transform.basis.inverse()
	var rh: Vector3 = _r(sk, "Hips", a, rinv)
	var rc: Vector3 = _r(sk, "UpperChest", a, rinv)
	print("REST torso lean fwd %+.1f" % rad_to_deg(atan2(-(rc - rh).z, (rc - rh).y)))
	for side in ["Left", "Right"]:
		var rs: Vector3 = _r(sk, side + "UpperArm", a, rinv)
		var re: Vector3 = _r(sk, side + "LowerArm", a, rinv)
		var ru: Vector3 = (re - rs).normalized()
		var sg: float = 1.0 if side == "Left" else -1.0
		print("REST %s abd %+.1f flex %+.1f" % [side[0], rad_to_deg(atan2(absf(ru.x), -ru.y)) * (1.0 if ru.x * sg < 0 else -1.0), rad_to_deg(atan2(-ru.z, -ru.y))])
	for i in 240:
		a.call("pose_reset")
		a.set("team", 1)
		a.call("lock_face", a.position + Vector3(0, 0, -8.0))
		a.call("animate", 1.0 / 60.0)
		await get_tree().process_frame
		if i % 40 != 0:
			continue
		var inv: Basis = a.global_transform.basis.inverse()
		var line: String = "f%03d" % i
		var hips: Vector3 = _p(sk, "Hips", a, inv)
		var chest: Vector3 = _p(sk, "UpperChest", a, inv)
		var lean: float = rad_to_deg(atan2(-(chest - hips).z, (chest - hips).y))
		line += "  torso lean fwd %+.0f" % lean
		for side in ["Left", "Right"]:
			var sh: Vector3 = _p(sk, side + "UpperArm", a, inv)
			var el: Vector3 = _p(sk, side + "LowerArm", a, inv)
			var wr: Vector3 = _p(sk, side + "Hand", a, inv)
			var u: Vector3 = (el - sh).normalized()
			var f: Vector3 = (wr - el).normalized()
			var abd: float = rad_to_deg(atan2(absf(u.x), -u.y))
			var sgn: float = 1.0 if (side == "Left") else -1.0
			var abd_signed: float = abd * (1.0 if u.x * sgn > 0 else -1.0)
			var flex: float = rad_to_deg(atan2(-u.z, -u.y))
			var elbow: float = rad_to_deg(acos(clampf(-u.dot(f), -1.0, 1.0)))
			line += "  %s abd %+.0f flex %+.0f elbow %.0f" % [side[0], abd_signed, flex, elbow]
		var cen: Vector3 = _p(sk, "Chest", a, inv)
		var lsh: Vector3 = _p(sk, "LeftUpperArm", a, inv)
		var rsh: Vector3 = _p(sk, "RightUpperArm", a, inv)
		var le: Vector3 = _p(sk, "LeftLowerArm", a, inv)
		var re2: Vector3 = _p(sk, "RightLowerArm", a, inv)
		var lpe: Vector3 = _p(sk, "LeftUpperLeg", a, inv)
		line += "  | L elbow x %+.3f z %+.3f y %.3f  R elbow x %+.3f z %+.3f y %.3f  | L shoulder x %+.3f  R shoulder x %+.3f  hips y %.3f chest y %.3f" % [le.x - cen.x, le.z - cen.z, le.y, re2.x - cen.x, re2.z - cen.z, re2.y, lsh.x - cen.x, rsh.x - cen.x, hips.y, chest.y]
		print(line)
		if i == 120:
			print("TORSO width at elbow height: ", _torso_halfwidth(sk, a, inv, le.y, cen))
	get_tree().quit(0)

func _p(sk: Skeleton3D, bone: String, a: Node3D, inv: Basis) -> Vector3:
	var i: int = sk.find_bone(bone)
	return inv * (sk.global_transform * sk.get_bone_global_pose(i).origin - a.global_position)

func _r(sk: Skeleton3D, bone: String, a: Node3D, inv: Basis) -> Vector3:
	var i: int = sk.find_bone(bone)
	return inv * (sk.global_transform * sk.get_bone_global_rest(i).origin - a.global_position)

## Half-width (x, from the chest centre) of the torso mesh at height y: the widest torso-bound vertex in a 4 cm band.
func _torso_halfwidth(sk: Skeleton3D, a: Node3D, inv: Basis, y: float, cen: Vector3) -> String:
	var torso: Array = [sk.find_bone("Spine"), sk.find_bone("Chest"), sk.find_bone("UpperChest"), sk.find_bone("Hips")]
	var best_r: float = 0.0
	var best_z: float = 0.0
	var bpos: Vector3 = Vector3.ZERO
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
				var bw: float = 0.0
				var bb: int = -1
				for k in per:
					var w: float = wts[v * per + k]
					if w > bw and binds[bones[v * per + k]] >= 0:
						bw = w
						bb = binds[bones[v * per + k]]
				if bb < 0 or not torso.has(bb) or bw < 0.5:
					continue
				var p: Vector3 = Vector3.ZERO
				for k in per:
					var w: float = wts[v * per + k]
					var bi: int = bones[v * per + k]
					if w <= 0.0 or binds[bi] < 0:
						continue
					p += (sk.get_bone_global_pose(binds[bi]) * (skin.get_bind_pose(bi) * verts[v])) * w
				var world: Vector3 = inv * (sk.global_transform * p - a.global_position)
				if absf(world.y - y) < 0.02 and absf(world.x - cen.x) > best_r:
					best_r = absf(world.x - cen.x)
					best_z = world.z - cen.z
					bpos = world
	return "half-width %.3f m at z %+.3f (y %.3f)" % [best_r, best_z, bpos.y]
