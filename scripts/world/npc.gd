extends StaticBody2D
## A world NPC: visible sprite, solid feet, an interaction radius, and a
## floating prompt that appears when the player is close enough to talk.

signal range_changed(npc: Node, in_range: bool)

const SpriteFactory: GDScript = preload("res://scripts/world/sprite_factory.gd")

const INTERACT_RADIUS: float = 84.0

@export var npc_name: String = "Student"
@export var shirt_color: Color = Color("c8452e")
@export var hair_color: Color = Color("1d1a17")

var dialogue_lines: Array[String] = []
var player_in_range: bool = false

var _prompt: Label


func _ready() -> void:
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.sprite_frames = SpriteFactory.make_character_frames(
		shirt_color, Color("4a4038"), Color("caa27e"), hair_color
	)
	sprite.scale = Vector2(3, 3)
	sprite.position = Vector2(0, -30)
	add_child(sprite)
	sprite.play("idle_down")

	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 13.0
	collider.shape = shape
	add_child(collider)

	var area: Area2D = Area2D.new()
	var area_collider: CollisionShape2D = CollisionShape2D.new()
	var area_shape: CircleShape2D = CircleShape2D.new()
	area_shape.radius = INTERACT_RADIUS
	area_collider.shape = area_shape
	area.add_child(area_collider)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	_prompt = Label.new()
	_prompt.text = "[E] Talk"
	_prompt.position = Vector2(-36, -102)
	_prompt.add_theme_font_size_override("font_size", 19)
	_prompt.add_theme_color_override("font_color", Color("ffe9a8"))
	_prompt.add_theme_color_override("font_outline_color", Color(0.08, 0.07, 0.09))
	_prompt.add_theme_constant_override("outline_size", 8)
	_prompt.visible = false
	add_child(_prompt)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		_prompt.visible = true
		range_changed.emit(self, true)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		_prompt.visible = false
		range_changed.emit(self, false)
