class_name RigJoints
extends RefCounted
## Moves joint pivots on a skinned skeleton without moving the mesh: each moved
## bone's rest position changes, every child keeps where it was, and each
## affected skin bind is rebound so the rest pose skins exactly as before
## (rest = bind is preserved; RIG_SPEC.md). Used at import by
## assets/court/students/student_rig_fix.gd, and by tests to try a pivot before
## committing to it (tests/rig/joint_experiment.gd).


## moves: bone name -> new skeleton-space rest position of that joint.
## Rotations are kept. Skins: every Skin bound to `sk` (their binds are
## rewritten in place). Returns the bones whose global rest changed.
static func move(sk: Skeleton3D, moves: Dictionary, skins: Array) -> Array:
	var old_g: Array = []
	for i in sk.get_bone_count():
		old_g.append(sk.get_bone_global_rest(i))
	var new_g: Array = old_g.duplicate()
	var changed: Array = []
	for n: String in moves:
		var i := sk.find_bone(n)
		if i < 0:
			push_warning("RigJoints: no bone %s" % n)
			continue
		new_g[i] = Transform3D((old_g[i] as Transform3D).basis, moves[n])
		changed.append(i)
	# Local rests from the new globals, parents first (bone order is parent-first).
	for i in sk.get_bone_count():
		var p := sk.get_bone_parent(i)
		var pg: Transform3D = new_g[p] if p >= 0 else Transform3D.IDENTITY
		sk.set_bone_rest(i, pg.affine_inverse() * (new_g[i] as Transform3D))
	sk.reset_bone_poses()
	sk.force_update_all_bone_transforms()
	# Rebind: skinning is global_rest * bind * v; keep it equal for every vertex.
	for skin: Skin in skins:
		for b in skin.get_bind_count():
			var bi := sk.find_bone(skin.get_bind_name(b)) if skin.get_bind_name(b) != &"" else skin.get_bind_bone(b)
			if bi in changed:
				skin.set_bind_pose(b, (new_g[bi] as Transform3D).affine_inverse() * (old_g[bi] as Transform3D) * skin.get_bind_pose(b))
	return changed


## The right side's joint, mirrored across the mesh's midplane (the Spine
## joint's x: gate 1 finds the mesh symmetric about it to 0.00 cm): where the
## matching left joint belongs on the symmetric body.
static func mirrored(sk: Skeleton3D, right_bone: String) -> Vector3:
	var mid: float = sk.get_bone_global_rest(sk.find_bone("Spine")).origin.x
	var r: Vector3 = sk.get_bone_global_rest(sk.find_bone(right_bone)).origin
	return Vector3(2.0 * mid - r.x, r.y, r.z)


static func _r_to_l(n: String) -> String:
	return n.replace("Right", "Left").replace(".R", ".L")


## Gives the left-side vertices of `regions` (dominant bone names, left side)
## the weights of their mirror-image vertex on the right, bones renamed right
## to left. The mesh must be symmetric (gate 1 measures it: 0.00 cm), so each
## left vertex has a right twin within TWIN. Rest skinning is unchanged as long
## as rest = bind (each bone puts the vertex at the same place). Returns the
## number of vertices rewritten and the number with no twin.
const TWIN: float = 0.02
static func mirror_weights(sk: Skeleton3D, mi: MeshInstance3D, regions: Array) -> Array:
	var skin: Skin = mi.skin
	var mesh: ArrayMesh = mi.mesh
	var bind_of: Dictionary = {}
	for b in skin.get_bind_count():
		bind_of[str(skin.get_bind_name(b))] = b
	var mid: float = sk.get_bone_global_rest(sk.find_bone("Spine")).origin.x
	# Every vertex at rest (skeleton space), its surface and index.
	var all: Array = []
	var arrays: Array = []
	for s in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(s)
		arrays.append(arr)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		if bones.is_empty():
			continue
		var per: int = bones.size() / verts.size()
		for v in verts.size():
			var p := Vector3.ZERO
			var dom := ""
			var dw := 0.0
			for k in per:
				var w: float = wts[v * per + k]
				if w <= 0.0:
					continue
				var n := str(skin.get_bind_name(bones[v * per + k]))
				p += sk.get_bone_global_rest(sk.find_bone(n)) * (skin.get_bind_pose(bones[v * per + k]) * verts[v]) * w
				if w > dw:
					dw = w
					dom = n
			all.append([p, s, v, per, dom])
	var grid: Dictionary = {}
	for e: Array in all:
		var c := Vector3i((e[0] as Vector3) / TWIN)
		if not grid.has(c):
			grid[c] = []
		grid[c].append(e)
	var done := 0
	var lone := 0
	for e: Array in all:
		if not (e[4] in regions):
			continue
		var p: Vector3 = e[0]
		if p.x <= mid:
			continue
		var q := Vector3(2.0 * mid - p.x, p.y, p.z)
		var twin: Array = []
		var bd := INF
		var c := Vector3i(q / TWIN)
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for dz in range(-1, 2):
					for o: Array in grid.get(c + Vector3i(dx, dy, dz), []):
						var d: float = (o[0] as Vector3).distance_to(q)
						if d < bd:
							bd = d
							twin = o
		if twin.is_empty() or bd > TWIN:
			lone += 1
			continue
		var dst: Array = arrays[e[1]]
		var src: Array = arrays[twin[1]]
		var per: int = e[3]
		var sper: int = twin[3]
		var db: PackedInt32Array = dst[Mesh.ARRAY_BONES]
		var dw2: PackedFloat32Array = dst[Mesh.ARRAY_WEIGHTS]
		var sb: PackedInt32Array = src[Mesh.ARRAY_BONES]
		var sw: PackedFloat32Array = src[Mesh.ARRAY_WEIGHTS]
		# Staged: the vertex is only rewritten if every twin bone has a left bind.
		var nb: Array = []
		var nw: Array = []
		var ok := true
		for k in mini(per, sper):
			var w: float = sw[twin[2] * sper + k]
			var name := _r_to_l(str(skin.get_bind_name(sb[twin[2] * sper + k])))
			if w > 0.0 and not bind_of.has(name):
				ok = false
				push_warning("RigJoints.mirror_weights: no bind %s for a left twin" % name)
				break
			nb.append(bind_of.get(name, 0) if w > 0.0 else 0)
			nw.append(w if w > 0.0 else 0.0)
		if not ok:
			lone += 1
			continue
		for k in per:
			db[e[2] * per + k] = int(nb[k]) if k < nb.size() else 0
			dw2[e[2] * per + k] = float(nw[k]) if k < nw.size() else 0.0
		dst[Mesh.ARRAY_BONES] = db
		dst[Mesh.ARRAY_WEIGHTS] = dw2
		done += 1
	# Rebuild the mesh with the new weights (same surfaces, materials, names).
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arr: Array = arrays[s]
		var flags: int = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if (arr[Mesh.ARRAY_BONES] as PackedInt32Array).size() == 8 * (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() else 0
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arr, [], {}, flags)
		out.surface_set_material(s, mesh.surface_get_material(s))
		out.surface_set_name(s, mesh.surface_get_name(s))
	mi.mesh = out
	return [done, lone]
