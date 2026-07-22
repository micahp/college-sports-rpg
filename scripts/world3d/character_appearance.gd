class_name CharacterAppearance
extends RefCounted
## Shared factory for the Quaternius student rigs. Every human in the campus
## comes through here: pick a model, recolor its named surfaces (Skin, Hair,
## Shirt, Pants, ...), and get a ready-to-animate node with a soft blob
## shadow that grounds the feet. Animation names differ per rig sex, so the
## factory also reports the "Man"/"Female" prefix.

const MODELS: Dictionary = {
	"male_casual": "res://assets/characters/Male_Casual.fbx",
	"male_shirt": "res://assets/characters/Male_Shirt.fbx",
	"male_longsleeve": "res://assets/characters/Male_LongSleeve.fbx",
	"male_suit": "res://assets/characters/Male_Suit.fbx",
	"female_casual": "res://assets/characters/Female_Casual.fbx",
	"female_tanktop": "res://assets/characters/Female_TankTop.fbx",
	"female_dress": "res://assets/characters/Female_Dress.fbx",
	"female_alternative": "res://assets/characters/Female_Alternative.fbx",
}

## A few ready palettes so scene instances can stay declarative.
## Keys match FBX surface material names.
const SKIN_TONES: Dictionary = {
	"light": Color(0.85, 0.68, 0.54),
	"tan": Color(0.66, 0.54, 0.4),
	"brown": Color(0.48, 0.34, 0.24),
	"deep": Color(0.32, 0.22, 0.16),
}


static func build(model_key: String, colors: Dictionary) -> Node3D:
	var scene: PackedScene = load(MODELS[model_key])
	var model: Node3D = scene.instantiate()
	model.name = "Model"
	# Rigs name their top layer differently (Shirt, Dress, Jacket); callers
	# just say "Shirt" and the alias covers whichever this model has.
	var wanted: Dictionary = colors.duplicate()
	if wanted.has("Shirt"):
		for alias: String in ["Dress", "Jacket"]:
			if not wanted.has(alias):
				wanted[alias] = wanted["Shirt"]
	var mesh_instance: MeshInstance3D = find_mesh(model)
	if mesh_instance != null:
		for i in mesh_instance.mesh.get_surface_count():
			var base: Material = mesh_instance.mesh.surface_get_material(i)
			if base == null or not wanted.has(base.resource_name):
				continue
			var override: StandardMaterial3D = (base as StandardMaterial3D).duplicate()
			override.albedo_color = wanted[base.resource_name]
			mesh_instance.set_surface_override_material(i, override)
	return model


static func anim_prefix(model_key: String) -> String:
	return "Female" if model_key.begins_with("female") else "Man"


static func find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found: MeshInstance3D = find_mesh(child)
		if found != null:
			return found
	return null


static func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found: Skeleton3D = find_skeleton(child)
		if found != null:
			return found
	return null


## A soft dark disc under the feet: reads as ambient occlusion contact and
## keeps characters from floating visually. Far cheaper than SSAO on mobile.
static func blob_shadow(radius: float = 0.42) -> MeshInstance3D:
	var blob: MeshInstance3D = MeshInstance3D.new()
	blob.name = "BlobShadow"
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(radius * 2.0, radius * 2.0)
	quad.orientation = PlaneMesh.FACE_Y
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _blob_texture()
	material.albedo_color = Color(0, 0, 0, 0.34)
	material.no_depth_test = false
	quad.material = material
	blob.mesh = quad
	blob.position = Vector3(0, 0.03, 0)
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return blob


static var _cached_blob: ImageTexture = null


static func _blob_texture() -> ImageTexture:
	if _cached_blob != null:
		return _cached_blob
	var size: int = 64
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for x in size:
		for y in size:
			var d: float = Vector2(x - size / 2.0, y - size / 2.0).length() / (size / 2.0)
			var alpha: float = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha * alpha))
	_cached_blob = ImageTexture.create_from_image(img)
	return _cached_blob
