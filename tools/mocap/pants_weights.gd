extends SceneTree
## Weight layout of the student's pants (surface 4) and shirt (surface 3), using the skin's own bind names.
func _init() -> void:
	var n: Node = (load("res://assets/court/students/Male_Casual.fbx") as PackedScene).instantiate()
	var sk: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = n.find_children("*", "MeshInstance3D", true, false)[0]
	var skin: Skin = mi.skin
	var m: ArrayMesh = mi.mesh
	var names: Array = []
	for i in skin.get_bind_count():
		var nm: String = skin.get_bind_name(i)
		if nm == "":
			nm = sk.get_bone_name(skin.get_bind_bone(i))
		names.append(nm)
	for s in [3, 4]:
		var arr: Array = m.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per: int = bones.size() / verts.size()
		var ymin := INF; var ymax := -INF
		for v in verts:
			ymin = minf(ymin, v.y); ymax = maxf(ymax, v.y)
		var span: float = ymax - ymin
		print("SURF %d %s: %d verts, %d weights per vertex" % [s, m.surface_get_material(s).resource_name, verts.size(), per])
		var combos: Dictionary = {}
		for v in verts.size():
			var parts: Array = []
			for k in per:
				var w: float = weights[v * per + k]
				if w > 0.02:
					parts.append([names[bones[v * per + k]], w])
			parts.sort_custom(func(a, b): return a[1] > b[1])
			var key: String = ""
			for p in parts.slice(0, 3):
				key += "%s %.2f | " % [p[0], p[1]]
			var band: int = int((verts[v].y - ymin) / span * 4.0)  # 0 = hem .. 3 = top
			var ck: String = "band%d  %s" % [min(band, 3), (parts[0][0] if parts.size() > 0 else "-")]
			combos[ck] = combos.get(ck, 0) + 1
		var keys: Array = combos.keys()
		keys.sort()
		for k in keys:
			print("  %-34s %3d verts" % [k, combos[k]])
	n.free()
	quit(0)
