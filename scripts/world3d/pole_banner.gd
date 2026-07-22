extends Node3D
## A streetlight dressed with a hanging campus banner. The banner artwork is
## chosen per instance in the editor; applied as a material copy so instances
## don't share state.

@export var banner_texture: Texture2D
## Counter-rotation so the banner can face the camera regardless of which
## way the pole is turned to aim its lamp arm.
@export var banner_yaw: float = 0.0


func _ready() -> void:
	var banner: MeshInstance3D = get_node("Banner")
	banner.rotation_degrees.y = banner_yaw
	if banner_texture == null:
		return
	var mesh: QuadMesh = banner.mesh.duplicate()
	var material: StandardMaterial3D = mesh.material.duplicate()
	material.albedo_texture = banner_texture
	mesh.material = material
	banner.mesh = mesh
