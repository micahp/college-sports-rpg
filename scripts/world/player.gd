extends CharacterBody2D
## The controllable student. Origin sits at the feet; collision covers the
## feet only so the body can overlap scenery edges the way top-down RPGs do.
## Reads keyboard actions plus `external_input` fed by the virtual joystick.

const SpriteFactory: GDScript = preload("res://scripts/world/sprite_factory.gd")

const SPEED: float = 210.0

## Set true while dialogue or menus own the screen.
var control_locked: bool = false
## Analog vector from the on-screen joystick; keyboard wins when both are active.
var external_input: Vector2 = Vector2.ZERO
var facing: String = "down"

var _sprite: AnimatedSprite2D


func _ready() -> void:
	add_to_group("player")

	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = SpriteFactory.make_character_frames(
		Color("2f6fdb"), Color("343a4a"), Color("e0b089"), Color("2b2320")
	)
	_sprite.scale = Vector2(3, 3)
	_sprite.position = Vector2(0, -30)
	add_child(_sprite)
	_sprite.play("idle_down")

	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(34, 18)
	collider.shape = shape
	add_child(collider)

	var camera: Camera2D = Camera2D.new()
	camera.name = "Camera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)
	camera.make_current()


func set_camera_limits(world: Rect2) -> void:
	var camera: Camera2D = $Camera
	camera.limit_left = int(world.position.x)
	camera.limit_top = int(world.position.y)
	camera.limit_right = int(world.end.x)
	camera.limit_bottom = int(world.end.y)


func _physics_process(_delta: float) -> void:
	var input: Vector2 = Vector2.ZERO
	if not control_locked:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input == Vector2.ZERO and external_input.length() > 0.15:
			input = external_input.limit_length(1.0)
	velocity = input * SPEED
	move_and_slide()
	_animate(input)


func _animate(input: Vector2) -> void:
	if input.length() < 0.05:
		_sprite.play("idle_" + facing)
		return
	if absf(input.x) >= absf(input.y):
		facing = "right" if input.x > 0.0 else "left"
	else:
		facing = "down" if input.y > 0.0 else "up"
	_sprite.play("walk_" + facing)
