extends SceneTree
## Prints the node tree and animation list of imported character/building assets.


func _initialize() -> void:
	for path in [
		"res://assets/characters/Male_Casual.fbx",
		"res://assets/characters/Male_Shirt.fbx",
		"res://assets/city/Building_Large_2.gltf",
		"res://assets/nature/CommonTree_1.gltf",
	]:
		print("\n=== ", path)
		var scene: PackedScene = load(path)
		if scene == null:
			printerr("  FAILED TO LOAD")
			continue
		var node: Node = scene.instantiate()
		_dump(node, 1)
		node.free()
	quit(0)


func _dump(node: Node, depth: int) -> void:
	if depth > 3:
		return
	var info: String = "%s- %s (%s)" % ["  ".repeat(depth), node.name, node.get_class()]
	if node is AnimationPlayer:
		info += "  anims: " + str((node as AnimationPlayer).get_animation_list())
	if node is MeshInstance3D:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh != null:
			info += "  aabb: " + str(mesh.get_aabb())
	print(info)
	for child in node.get_children():
		_dump(child, depth + 1)
