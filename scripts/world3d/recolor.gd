extends Node3D
## Recolors named surfaces of any child model at runtime. Attach to an
## instanced asset and fill `recolors` in the editor — keys are surface
## material names (e.g. "LightRed"), values are the replacement colors.
## Lets one CC0 asset serve many palettes without duplicating files.

@export var recolors: Dictionary = {}


func _ready() -> void:
	_apply(self)


func _apply(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node
		for i in mesh_instance.mesh.get_surface_count():
			var base: Material = mesh_instance.mesh.surface_get_material(i)
			if base is StandardMaterial3D and recolors.has(base.resource_name):
				var override: StandardMaterial3D = base.duplicate()
				override.albedo_color = recolors[base.resource_name]
				mesh_instance.set_surface_override_material(i, override)
	for child in node.get_children():
		_apply(child)
