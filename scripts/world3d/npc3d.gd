extends StaticBody3D
## A campus NPC: animated model, solid body, an interaction radius, and a
## floating speech-bubble indicator that appears when the player is close.
## Turns to face the player when a conversation starts.

signal range_changed(npc: Node, in_range: bool)

const CharacterModel: PackedScene = preload("res://assets/characters/Male_Shirt.fbx")
const INTERACT_RADIUS: float = 2.4
const MODEL_YAW_OFFSET: float = 0.0

@export var npc_name: String = "Jordan Hayes"

var player_in_range: bool = false

var _model: Node3D
var _anim: AnimationPlayer
var _indicator: Sprite3D
var _time: float = 0.0


func _ready() -> void:
	_model = CharacterModel.instantiate()
	_model.name = "Model"
	add_child(_model)
	_anim = _model.get_node("AnimationPlayer")
	for anim_name in _anim.get_animation_list():
		_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_anim.play("HumanArmature|Man_Idle")

	var collider: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	collider.shape = capsule
	collider.position = Vector3(0, 0.85, 0)
	add_child(collider)

	var area: Area3D = Area3D.new()
	var area_collider: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = INTERACT_RADIUS
	area_collider.shape = sphere
	area_collider.position = Vector3(0, 1, 0)
	area.add_child(area_collider)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	_indicator = Sprite3D.new()
	_indicator.texture = _bubble_texture()
	_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_indicator.pixel_size = 0.006
	_indicator.position = Vector3(0, 2.75, 0)
	_indicator.shaded = false
	_indicator.no_depth_test = true
	_indicator.render_priority = 10
	_indicator.visible = false
	add_child(_indicator)


func _process(delta: float) -> void:
	if _indicator.visible:
		_time += delta
		_indicator.position.y = 2.75 + sin(_time * 3.0) * 0.07


func face_toward(point: Vector3) -> void:
	var to_point: Vector3 = point - global_position
	_model.rotation.y = atan2(to_point.x, to_point.z) + MODEL_YAW_OFFSET


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		_indicator.visible = true
		range_changed.emit(self, true)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		_indicator.visible = false
		range_changed.emit(self, false)


## Draws a small rounded speech bubble with a tail — crisp at 128px.
func _bubble_texture() -> ImageTexture:
	var size: int = 128
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var body_color: Color = Color(1, 1, 1, 0.95)
	var center: Vector2 = Vector2(64, 50)
	for x in size:
		for y in size:
			var p: Vector2 = Vector2(x, y)
			var d: float = Vector2(absf(p.x - center.x) / 1.35, absf(p.y - center.y)).length()
			if d < 38.0:
				img.set_pixel(x, y, body_color)
			elif y > 80 and y < 108 and absf(x - 64.0) < (108.0 - y) * 0.45:
				img.set_pixel(x, y, body_color)
	# Three dots
	for dot_x in [44, 64, 84]:
		for x in range(dot_x - 6, dot_x + 6):
			for y in range(44, 56):
				if Vector2(x - dot_x, y - 50).length() < 5.5:
					img.set_pixel(x, y, Color(0.16, 0.2, 0.3))
	return ImageTexture.create_from_image(img)
