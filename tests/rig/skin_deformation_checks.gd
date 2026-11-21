extends Node
## Gate 2: skin deformation (docs/animation/RIG_CERTIFICATION.md).
## The real skinned student, every joint driven through its range from the
## rest pose. Two measurements: "rest vs modelled" compares the skinned rest
## pose with the mesh as it was modelled (the skin's bind pose: gate 1 shows
## the rig's rest differs from it); every other pose is compared with the
## skinned rest pose, so it shows what that motion adds with no animation and no correction running (student_feet only on
## the leg poses: the shoe is a root-level control bone that follows the ankle
## through it, the rig's foot control). Per pose and body region (the bone a
## vertex is weighted to most), the mesh is skinned on the CPU as the GPU does
## and every edge compared with its rest length:
##   stretch / squash: longest and shortest edge ratio (posed / rest)
##   inverted: triangles whose normal turned against the way their bone turned
##     (the surface folded through itself: collapse, candy-wrapper, pinching)
## Run with a window to also render each pose (front, side, three-quarter) to
## build/rig/gate2/; those images are the visual acceptance, the numbers are
## not.
##   godot --fixed-fps 60 --path . res://tests/rig/skin_deformation_checks.tscn [-- fault=bad_weight] [only=<pose>]
const F = preload("res://tests/rig/rig_fixture.gd")

const MAX_STRETCH: float = 1.6
const MIN_SQUASH: float = 0.5
const MAX_INVERTED: float = 0.01  # share of a region's triangles
const MIN_EDGE_M: float = 0.005  # edges shorter than this (5 mm) are not measured for stretch

## [name, ops, student_feet on]. Ops: [bone, axis, deg]; axis "x"/"y"/"z" is
## the bone's own (gate 1: forearm and shin flex about +X, the hand's +X is
## the wrist's flexion axis), a Vector3 is skeleton space (+X left, +Y up, +Z front).
## Both sides move together; R mirrors L (s = +1 left, -1 right).
func _poses() -> Array:
	var out: Array = []
	var both := func(ops: Array) -> Array:
		var all: Array = []
		for side: String in ["L", "R"]:
			var s: float = 1.0 if side == "L" else -1.0
			for op: Array in ops:
				var b: String = (op[0] as String).replace("*", "Left" if side == "L" else "Right")
				var ax = op[1]
				var deg: float = float(op[2])
				if ax is Vector3:
					# mirror a skeleton-space rotation: axis (x, -y, -z) for the right side
					ax = ax if side == "L" else Vector3(ax.x, -ax.y, -ax.z)
				elif side == "R" and ax != "x":
					# The right bone's local X is the left's mirrored and negated
					# (gate 1), its Y and Z mirrored only: about Y or Z the same
					# motion is the opposite angle.
					deg = -deg
				all.append([b, ax, deg])
		return all
	var fwd: Array = [["*UpperArm", Vector3.UP, -90.0]]
	var down: Array = [["*UpperArm", Vector3.BACK, -75.0]]
	out.append(["rest", [], false])
	out.append(["rest_feet", [], true])  # the rest pose with the rig's shoe control (student_feet) on
	out.append(["arms_down", both.call(down), false])
	out.append(["arms_overhead", both.call([["*UpperArm", Vector3.BACK, 80.0]]), false])
	out.append(["arms_forward", both.call(fwd), false])
	out.append(["arms_across", both.call([["*UpperArm", Vector3.UP, -125.0]]), false])
	out.append(["arms_back", both.call([["*UpperArm", Vector3.BACK, -75.0], ["*UpperArm", Vector3.RIGHT, 40.0]]), false])
	out.append(["elbow_90", both.call(fwd + [["*LowerArm", "x", 90.0]]), false])
	out.append(["elbow_140", both.call(fwd + [["*LowerArm", "x", 140.0]]), false])
	out.append(["forearm_pronate_80", both.call(fwd + [["*LowerArm", "x", 90.0], ["*LowerArm", "y", 80.0]]), false])
	out.append(["forearm_supinate_80", both.call(fwd + [["*LowerArm", "x", 90.0], ["*LowerArm", "y", -80.0]]), false])
	out.append(["wrist_flex_60", both.call(fwd + [["*LowerArm", "x", 45.0], ["*Hand", "x", 60.0]]), false])
	out.append(["wrist_extend_60", both.call(fwd + [["*LowerArm", "x", 45.0], ["*Hand", "x", -60.0]]), false])
	out.append(["shoulder_rotate_in_70", both.call(down + [["*LowerArm", "x", 90.0], ["*UpperArm", "y", 70.0]]), false])
	out.append(["shoulder_rotate_out_70", both.call(down + [["*LowerArm", "x", 90.0], ["*UpperArm", "y", -70.0]]), false])
	out.append(["knee_lift", both.call([["*UpperLeg", "x", 90.0], ["*LowerLeg", "x", 90.0]]), true])
	out.append(["squat", both.call([["*UpperLeg", "x", 100.0], ["*LowerLeg", "x", 120.0]]), true])
	out.append(["legs_apart_45", both.call([["*UpperLeg", Vector3.BACK, 45.0]]), true])
	out.append(["hip_extend_25", both.call([["*UpperLeg", "x", -25.0]]), true])
	out.append(["knee_120", both.call([["*LowerLeg", "x", 120.0]]), true])
	out.append(["lunge", [["LeftUpperLeg", "x", 80.0], ["LeftLowerLeg", "x", 80.0], ["RightUpperLeg", "x", -20.0], ["RightLowerLeg", "x", 30.0]], true])
	out.append(["ankle_up_30", both.call([["Foot.*", Vector3.RIGHT, -30.0]]).map(func(o): return [str(o[0]).replace("Foot.Left", "Foot.L").replace("Foot.Right", "Foot.R"), o[1], o[2]]), false])
	out.append(["ankle_down_30", both.call([["Foot.*", Vector3.RIGHT, 30.0]]).map(func(o): return [str(o[0]).replace("Foot.Left", "Foot.L").replace("Foot.Right", "Foot.R"), o[1], o[2]]), false])
	out.append(["trunk_flex_40", [["Spine", Vector3.RIGHT, 15.0], ["Chest", Vector3.RIGHT, 15.0], ["UpperChest", Vector3.RIGHT, 10.0]], false])
	out.append(["trunk_extend_20", [["Spine", Vector3.RIGHT, -8.0], ["Chest", Vector3.RIGHT, -7.0], ["UpperChest", Vector3.RIGHT, -5.0]], false])
	out.append(["trunk_twist_45", [["Spine", Vector3.UP, 15.0], ["Chest", Vector3.UP, 15.0], ["UpperChest", Vector3.UP, 15.0]], false])
	out.append(["side_bend_25", [["Spine", Vector3.BACK, 10.0], ["Chest", Vector3.BACK, 10.0], ["UpperChest", Vector3.BACK, 5.0]], false])
	out.append(["head_turn_60", [["Neck", Vector3.UP, 15.0], ["Head", Vector3.UP, 45.0]], false])
	out.append(["head_nod_30", [["Neck", Vector3.RIGHT, 10.0], ["Head", Vector3.RIGHT, 20.0]], false])
	return out


var f: F
var _feet_ref := PackedVector3Array()  # the skinned rest pose with student_feet on: reference for the leg poses
var debug_edges: bool = OS.get_cmdline_user_args().has("debug")
var _mesh: Dictionary = {}  # verts, groups (per vertex [[bone, local, w]]), tris, dominant, rest positions


func _ready() -> void:
	f = F.new()
	f.build(self)
	var headless: bool = DisplayServer.get_name() == "headless"
	var only_pose: String = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only_pose = a.substr(5)
	var mi: MeshInstance3D = CharacterAppearance.find_mesh(f.actor.get("_model"))
	if F.fault() == "bad_weight":
		# Sensitivity: the left forearm's bind pose 10 cm off (a wrong skin binding).
		var skin: Skin = mi.skin.duplicate()
		for i in skin.get_bind_count():
			if skin.get_bind_name(i) == "LeftLowerArm":
				skin.set_bind_pose(i, Transform3D(Basis.IDENTITY, Vector3(0, 0.1 / f.metres_per_unit(), 0)) * skin.get_bind_pose(i))
		mi.skin = skin
	# Test-only skin variants, to see what the game's own skin edits do:
	#   skin=no_reweight  the imported mesh weights (no _crotch_reweighted), the
	#                     game's Hips->Spine bind rename kept
	#   skin=raw          the imported mesh and skin, both untouched
	for a in OS.get_cmdline_user_args():
		if a in ["skin=no_reweight", "skin=raw"]:
			var raw_scene: Node = (load(CourtPlayerModel.STUDENT) as PackedScene).instantiate()
			var raw_mi: MeshInstance3D = CharacterAppearance.find_mesh(raw_scene)
			mi.mesh = raw_mi.mesh
			if a == "skin=raw":
				mi.skin = raw_mi.skin
			raw_scene.free()
			print("skin variant: ", a.substr(5))
	# Test-only: try the hip pivots higher (cm), rebinding so the rest mesh is
	# unchanged (scripts/court/rig_joints.gd): does the low hip pivot cost
	# deformation, or are the weights painted for it?
	for a in OS.get_cmdline_user_args():
		if a.begins_with("hip_up="):
			var up_cm := float(a.substr(7))
			var moves := {}
			for b: String in ["LeftUpperLeg", "RightUpperLeg"]:
				moves[b] = f.sk.get_bone_global_rest(f.bone(b)).origin + Vector3(0, up_cm / 100.0 / f.metres_per_unit(), 0)
			RigJoints.move(f.sk, moves, [mi.skin])
			for i in f.sk.get_bone_count():
				f.rest_local[i] = f.sk.get_bone_rest(i)
			f.use(f.rest_local)
			print("hip pivots raised %.1f cm (rest mesh unchanged)" % up_cm)
	_build_mesh(mi)
	var out_dir := "res://build/rig/gate2/"
	var cams: Array = []
	if not headless:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
		cams = _stage()
	await f.settle()
	print("GATE 2 skin deformation: %d vertices, %d triangles; limits stretch <= %.1fx, squash >= %.1fx, inverted <= %.0f%% of a region" % [(_mesh["rest"] as PackedVector3Array).size(), (_mesh["tris"] as PackedInt32Array).size() / 3, MAX_STRETCH, MIN_SQUASH, MAX_INVERTED * 100])
	for p: Array in _poses():
		if only_pose != "" and p[0] != only_pose:
			continue
		f.only(["student_feet"] if p[2] else [])
		f.use(f.posed(p[1]))
		await f.settle(2)
		var res := _measure(f.last.g, p[0] in ["rest", "rest_feet"], _feet_ref if p[2] and p[0] != "rest_feet" else PackedVector3Array())
		if p[0] == "rest_feet":
			_feet_ref = _skinned(f.last.g)
		var worst: Array = []
		var region_bad: Array = []
		for region: String in res:
			var r: Dictionary = res[region]
			var inv_share: float = float(r["inv"]) / maxf(1.0, float(r["tris"]))
			if float(r["max"]) > MAX_STRETCH or float(r["min"]) < MIN_SQUASH or inv_share > MAX_INVERTED:
				region_bad.append("%s %.2fx/%.2fx inv %d" % [region, r["max"], r["min"], r["inv"]])
			worst.append([float(r["max"]) + (1.0 / maxf(float(r["min"]), 0.01)) + inv_share * 100.0, region, r])
		worst.sort_custom(func(a, b): return a[0] > b[0])
		var top: String = ""
		for w: Array in worst.slice(0, 3):
			var r: Dictionary = w[2]
			top += "  %s %.2fx/%.2fx inv %d/%d" % [w[1], r["max"], r["min"], r["inv"], r["tris"]]
		if p[0] == "rest":
			# One check per body region at rest, so a defect in one region (a bad
			# binding) is not hidden behind failures elsewhere.
			var names: Array = res.keys()
			names.sort()
			for region: String in names:
				var r: Dictionary = res[region]
				var inv_share: float = float(r["inv"]) / maxf(1.0, float(r["tris"]))
				f.check(float(r["max"]) <= MAX_STRETCH and float(r["min"]) >= MIN_SQUASH and inv_share <= MAX_INVERTED, "skin at rest vs modelled: " + region,
					"%.2fx / %.2fx, %d of %d triangles inverted" % [r["max"], r["min"], r["inv"], r["tris"]])
		else:
			f.check(region_bad.is_empty(), "skin " + str(p[0]) + (" vs modelled" if p[0] == "rest_feet" else ""), ("worst:" + top) if region_bad.is_empty() else ("%s" % [region_bad]))
		if not headless:
			for c: Array in cams:
				(c[1] as Camera3D).make_current()
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out_dir + "%s_%s.png" % [p[0], c[0]]))
	if not headless:
		print("renders in ", ProjectSettings.globalize_path(out_dir))
	print("FAILED_CHECKS: " + ",".join(f.failures))
	f.finish(get_tree(), "GATE 2")


func _stage() -> Array:
	get_window().size = Vector2i(540, 720)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.66, 0.72)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.1
	add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6, 6)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.42, 0.36, 0.3)
	floor.material_override = fm
	add_child(floor)
	var out: Array = []
	for v: Array in [["front", Vector3(0, 1.0, 3.6)], ["side", Vector3(3.6, 1.0, 0)], ["three_quarter", Vector3(2.4, 1.3, 2.6)]]:
		var c := Camera3D.new()
		c.fov = 38.0
		add_child(c)
		c.global_position = v[1]
		c.look_at(Vector3(0, 0.88, 0), Vector3.UP)
		out.append([v[0], c])
	return out


func _build_mesh(mi: MeshInstance3D) -> void:
	var sk := f.sk
	var skin: Skin = mi.skin
	var binds: Array = []
	for i in skin.get_bind_count():
		binds.append(sk.find_bone(skin.get_bind_name(i)))
	var groups: Array = []
	var rest := PackedVector3Array()
	var model := PackedVector3Array()
	# The modelled mesh in skeleton space, through the Spine's bind (gate 1: it
	# agrees with its rest), and each bone as it was when the skin was bound.
	var mesh_to_sk := Transform3D.IDENTITY
	for i in skin.get_bind_count():
		if skin.get_bind_name(i) == &"Spine":
			mesh_to_sk = sk.get_bone_global_rest(sk.find_bone("Spine")) * skin.get_bind_pose(i)
	var bound: Dictionary = {}
	for i in skin.get_bind_count():
		bound[binds[i]] = mesh_to_sk * skin.get_bind_pose(i).affine_inverse()
	var dominant := PackedInt32Array()
	var tris := PackedInt32Array()
	for s in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var per: int = bones.size() / verts.size()
		var base: int = rest.size()
		for v in verts.size():
			var g: Array = []
			var p := Vector3.ZERO
			var best := -1
			var bw := 0.0
			for k in per:
				var w: float = wts[v * per + k]
				if w <= 0.0:
					continue
				var bi: int = bones[v * per + k]
				var local: Vector3 = skin.get_bind_pose(bi) * verts[v]
				g.append([binds[bi], local, w])
				if w > bw:
					bw = w
					best = binds[bi]
			for inf: Array in g:
				p += sk.get_bone_global_rest(inf[0]) * (inf[1] as Vector3) * float(inf[2])
			model.append(mesh_to_sk * verts[v])
			groups.append(g)
			rest.append(p)
			dominant.append(best)
		if idx.is_empty():
			for v in verts.size():
				tris.append(base + v)
		else:
			for i in idx:
				tris.append(base + i)
	_mesh = {"groups": groups, "rest": rest, "dominant": dominant, "tris": tris, "bound": bound, "model": model}


func _region(b: int) -> String:
	var n: String = f.sk.get_bone_name(b)
	for k: Array in [["Shoulder", "shoulder"], ["UpperArm", "upper arm"], ["LowerArm", "forearm"], ["Hand", "hand"], ["Fingers", "hand"], ["Thumb", "hand"],
			["UpperLeg", "thigh"], ["LowerLeg", "shin"], ["Foot", "foot"], ["Spine", "pelvis"], ["Chest", "chest"], ["Neck", "neck"], ["Head", "head"]]:
		if n.contains(k[0]):
			var side := ""
			if n.begins_with("Left") or n.ends_with(".L"):
				side = " L"
			elif n.begins_with("Right") or n.ends_with(".R"):
				side = " R"
			return str(k[1]) + side
	return n


func _skinned(g: Array) -> PackedVector3Array:
	var groups: Array = _mesh["groups"]
	var posed := PackedVector3Array()
	posed.resize(groups.size())
	for v in groups.size():
		var p := Vector3.ZERO
		for inf: Array in groups[v]:
			p += (g[inf[0]] as Transform3D) * (inf[1] as Vector3) * float(inf[2])
		posed[v] = p
	return posed


func _measure(g: Array, against_model: bool = false, ref_override := PackedVector3Array()) -> Dictionary:
	var groups: Array = _mesh["groups"]
	var rest: PackedVector3Array = _mesh["model"] if against_model else (ref_override if not ref_override.is_empty() else _mesh["rest"])
	var dom: PackedInt32Array = _mesh["dominant"]
	var tris: PackedInt32Array = _mesh["tris"]
	var posed := _skinned(g)
	var out: Dictionary = {}
	for t in range(0, tris.size(), 3):
		var a := tris[t]
		var b := tris[t + 1]
		var c := tris[t + 2]
		var region := _region(dom[a])
		if not out.has(region):
			out[region] = {"max": 1.0, "min": 1.0, "inv": 0, "tris": 0}
		var r: Dictionary = out[region]
		r["tris"] = int(r["tris"]) + 1
		for e: Array in [[a, b], [b, c], [c, a]]:
			var l0 := rest[e[0]].distance_to(rest[e[1]])
			# A ratio on a sliver edge measures the triangulation, not the skin:
			# the left shoe cuff has a 1.4 mm edge the right does not, and moving
			# 1.2 cm read as 9x while the two shoes skin to within 0.16 cm.
			if l0 * f.metres_per_unit() < MIN_EDGE_M:
				continue
			var ratio := posed[e[0]].distance_to(posed[e[1]]) / l0
			if debug_edges and ratio > float(r["max"]) and ratio > 3.0:
				print("    edge %s: rest %s -> %s  posed %s -> %s  bones %s | %s" % [region, rest[e[0]], rest[e[1]], posed[e[0]], posed[e[1]], (groups[e[0]] as Array).map(func(x): return [f.sk.get_bone_name(x[0]), snappedf(x[2], 0.01)]), (groups[e[1]] as Array).map(func(x): return [f.sk.get_bone_name(x[0]), snappedf(x[2], 0.01)])])
			r["max"] = maxf(float(r["max"]), ratio)
			r["min"] = minf(float(r["min"]), ratio)
		var n0 := (rest[b] - rest[a]).cross(rest[c] - rest[a])
		var n1 := (posed[b] - posed[a]).cross(posed[c] - posed[a])
		if n0.length() < 1e-6 or n1.length() < 1e-6:
			continue
		# The way the triangle's own bone turned it: the normal should turn with it.
		var ref: Basis = ((_mesh["bound"] as Dictionary)[dom[a]] as Transform3D).basis if against_model else f.sk.get_bone_global_rest(dom[a]).basis
		var turn: Basis = (g[dom[a]] as Transform3D).basis.orthonormalized() * ref.orthonormalized().inverse()
		if (turn * n0.normalized()).dot(n1.normalized()) < 0.0:
			r["inv"] = int(r["inv"]) + 1
	return out
