extends Node
func _ready() -> void:
	var scene: PackedScene = load("res://assets/city/Stairs_Entrance_Concrete.gltf")
	var inst: Node3D = scene.instantiate()
	add_child(inst)
	var box: AABB = AABB()
	var first: bool = true
	for m in _meshes(inst):
		var xf: Transform3D = inst.global_transform.affine_inverse() * m.global_transform
		var b: AABB = xf * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	print("planter aabb pos=", box.position, " size=", box.size)
	get_tree().quit(0)
func _meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out
