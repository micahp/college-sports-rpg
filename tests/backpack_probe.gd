extends Node
## Measures the student model and the backpack in the player's local space.

func _ready() -> void:
	get_tree().create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		get_tree().quit(2))
	GameState.reset()
	TimeSystem.reset()
	GameState.look_id = "look_a"
	GameState.identity_id = "natural"
	Game.in_game = true
	Game.arrival = "start"
	var loc: Node = load(Game.SCENES["campus"]).instantiate()
	add_child(loc)
	await _frames(40)
	var p: CharacterBody3D = loc.player
	var model: Node3D = p._model
	print("player scale=", p.scale, " model scale=", model.scale, " model pos=", model.position)
	print("model forward (-z) in world: ", -model.global_transform.basis.z)
	for c in model.get_children():
		print("model child: ", c.name, " ", c.get_class())
	var box: AABB = _bounds(model, p)
	print("model aabb (player-local): pos=", box.position, " size=", box.size)
	for c in model.get_children():
		if c.name == "Root Scene":
			print("backpack node: ", c.name, " local pos=", c.position, " scale=", c.scale)
			var bb: AABB = _bounds(c, p)
			print("backpack aabb (player-local): pos=", bb.position, " size=", bb.size)
			var own: AABB = _find_mesh_aabb(c)
			print("backpack own mesh aabb (glb units): pos=", own.position, " size=", own.size)
	var skel: Skeleton3D = _find(model)
	if skel != null:
		for b in ["spine", "Spine", "spine_01", "Spine1", "chest", "Chest", "Hips", "hips", "Head", "head"]:
			var idx: int = skel.find_bone(b)
			if idx >= 0:
				print("bone ", b, " player-local y=", p.to_local(skel.to_global(skel.get_bone_global_pose(idx).origin)))
	get_tree().quit(0)


func _bounds(n: Node3D, ref: Node3D) -> AABB:
	var result: AABB = AABB()
	var first: bool = true
	for m in _meshes(n):
		var local_box: AABB = m.get_aabb()
		var xf: Transform3D = ref.global_transform.affine_inverse() * m.global_transform
		var box: AABB = xf * local_box
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result


func _meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out


func _find(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var f: Skeleton3D = _find(c)
		if f != null:
			return f
	return null


func _find_mesh_aabb(n: Node) -> AABB:
	var ms: Array = _meshes(n)
	if ms.is_empty():
		return AABB()
	return ms[0].get_aabb()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
