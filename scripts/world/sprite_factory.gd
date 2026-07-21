extends RefCounted
## Generates pixel-art character SpriteFrames at runtime so the project needs
## no imported image assets. 16x24 sprites, four facings, idle + walk cycles.
## Render with an AnimatedSprite2D scaled 3x and nearest-neighbor filtering.

const FRAME_W: int = 16
const FRAME_H: int = 24
const DIRECTIONS: Array[String] = ["down", "up", "left", "right"]

const OUTLINE: Color = Color(0.10, 0.09, 0.11)


static func make_character_frames(shirt: Color, pants: Color, skin: Color, hair: Color) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation("default")
	for dir in DIRECTIONS:
		var idle: String = "idle_" + dir
		frames.add_animation(idle)
		frames.set_animation_speed(idle, 2.0)
		frames.add_frame(idle, _frame(dir, 0, shirt, pants, skin, hair))

		var walk: String = "walk_" + dir
		frames.add_animation(walk)
		frames.set_animation_speed(walk, 8.0)
		frames.set_animation_loop(walk, true)
		for pose: int in [1, 0, 2, 0]:
			frames.add_frame(walk, _frame(dir, pose, shirt, pants, skin, hair))
	return frames


## pose: 0 = standing, 1 = left leg forward, 2 = right leg forward.
static func _frame(dir: String, pose: int, shirt: Color, pants: Color, skin: Color, hair: Color) -> ImageTexture:
	var img: Image = Image.create(FRAME_W, FRAME_H, false, Image.FORMAT_RGBA8)

	# Head (y2..9) and hair
	_fill(img, 4, 2, 8, 8, skin)
	if dir == "up":
		_fill(img, 4, 2, 8, 5, hair)
	else:
		_fill(img, 4, 2, 8, 3, hair)
		match dir:
			"down":
				img.set_pixel(6, 6, OUTLINE)
				img.set_pixel(9, 6, OUTLINE)
			"left":
				img.set_pixel(5, 6, OUTLINE)
				img.set_pixel(8, 6, OUTLINE)
			"right":
				img.set_pixel(7, 6, OUTLINE)
				img.set_pixel(10, 6, OUTLINE)

	# Torso (y10..16) and arms with skin hands
	_fill(img, 4, 10, 8, 7, shirt)
	_fill(img, 3, 10, 1, 4, shirt)
	_fill(img, 12, 10, 1, 4, shirt)
	_fill(img, 3, 14, 1, 2, skin)
	_fill(img, 12, 14, 1, 2, skin)

	# Hips (y17..18) and legs (y19..23), one leg shortened while walking
	_fill(img, 4, 17, 8, 2, pants)
	var left_len: int = 5 if pose != 2 else 3
	var right_len: int = 5 if pose != 1 else 3
	_fill(img, 5, 19, 2, left_len, pants)
	_fill(img, 9, 19, 2, right_len, pants)
	_fill(img, 5, 19 + left_len - 1, 2, 1, OUTLINE)
	_fill(img, 9, 19 + right_len - 1, 2, 1, OUTLINE)

	return ImageTexture.create_from_image(img)


static func _fill(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for px in range(x, x + w):
		for py in range(y, y + h):
			img.set_pixel(px, py, color)
