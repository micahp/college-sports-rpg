extends StaticBody3D
## A named campus NPC: recolored shared rig, a solid body, and two floating
## markers — a gold "!" while they have something new to say, and a speech
## bubble when the player is close enough to talk. The location script
## decides who stands where and drives both markers.

const INDICATOR_HEIGHT: float = 2.35

@export var npc_name: String = "Jordan Hayes"
@export var model_key: String = "male_longsleeve"
@export var shirt_color: Color = Color(0.5, 0.16, 0.2)
@export var pants_color: Color = Color(0.2, 0.19, 0.18)
@export var skin_tone: String = "deep"
@export var hair_color: Color = Color(0.08, 0.07, 0.06)

var player_near: bool = false
var story_pending: bool = false

var _model: Node3D
var _anim: AnimationPlayer
var _bubble: Sprite3D
var _alert: Label3D
var _time: float = 0.0


func _ready() -> void:
	_model = CharacterAppearance.build(model_key, {
		"Shirt": shirt_color,
		"Pants": pants_color,
		"Skin": CharacterAppearance.SKIN_TONES[skin_tone],
		"Hair": hair_color,
	})
	add_child(_model)
	add_child(CharacterAppearance.blob_shadow())
	_anim = _model.get_node("AnimationPlayer")
	for anim_name in _anim.get_animation_list():
		_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_anim.play("HumanArmature|%s_Idle" % CharacterAppearance.anim_prefix(model_key))
	_anim.seek(randf() * 2.0, true)

	var collider: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.7
	collider.shape = capsule
	collider.position = Vector3(0, 0.85, 0)
	add_child(collider)

	_bubble = Sprite3D.new()
	_bubble.texture = _bubble_texture()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.pixel_size = 0.0034
	_bubble.position = Vector3(0, INDICATOR_HEIGHT, 0)
	_bubble.shaded = false
	_bubble.no_depth_test = true
	_bubble.render_priority = 10
	_bubble.visible = false
	add_child(_bubble)

	_alert = Label3D.new()
	_alert.text = "!"
	_alert.font_size = 120
	_alert.outline_size = 22
	_alert.modulate = UIKit.GOLD
	_alert.outline_modulate = Color(0.08, 0.12, 0.22)
	_alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert.pixel_size = 0.004
	_alert.no_depth_test = true
	_alert.render_priority = 10
	_alert.position = Vector3(0, INDICATOR_HEIGHT, 0)
	_alert.visible = false
	add_child(_alert)


func _process(delta: float) -> void:
	_time += delta
	var bob: float = sin(_time * 3.0) * 0.06
	_bubble.position.y = INDICATOR_HEIGHT + bob
	_alert.position.y = INDICATOR_HEIGHT + 0.05 + bob


func set_player_near(near: bool) -> void:
	player_near = near
	_refresh_markers()


func set_story_pending(pending: bool) -> void:
	story_pending = pending
	if is_node_ready():
		_refresh_markers()


func _refresh_markers() -> void:
	_bubble.visible = player_near
	_alert.visible = story_pending and not player_near


func face_toward(point: Vector3) -> void:
	var to_point: Vector3 = point - global_position
	_model.rotation.y = atan2(to_point.x, to_point.z)


func face_direction(direction: Vector3) -> void:
	if Vector2(direction.x, direction.z).length() > 0.01:
		_model.rotation.y = atan2(direction.x, direction.z)


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
	for dot_x in [44, 64, 84]:
		for x in range(dot_x - 6, dot_x + 6):
			for y in range(44, 56):
				if Vector2(x - dot_x, y - 50).length() < 5.5:
					img.set_pixel(x, y, Color(0.12, 0.2, 0.36))
	return ImageTexture.create_from_image(img)
