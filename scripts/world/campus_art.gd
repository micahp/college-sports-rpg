extends Node2D
## Draws the entire static campus in one canvas item from the layout the
## Campus scene passes in: grass, paths, buildings with doors and windows,
## trees, benches, hedges, and the campus sign. Clean geometric placeholder
## art — no imported assets. Collision lives in campus.gd, not here.

const GRASS: Color = Color("4f8f4a")
const GRASS_SPECKLE: Color = Color("47823f")
const PATH: Color = Color("d8c9a3")
const PATH_EDGE: Color = Color("c4b58f")
const HEDGE: Color = Color("2e5c33")
const TRUNK: Color = Color("6b4a2f")
const CANOPY: Color = Color("3a7a3c")
const CANOPY_LIGHT: Color = Color("4c8f47")
const BENCH: Color = Color("8a6238")
const SIGN_BOARD: Color = Color("27436b")
const SIGN_POST: Color = Color("5a4a3a")
const DOOR: Color = Color("3a2f28")
const WINDOW: Color = Color("bcd8e8")

var world: Rect2
var paths: Array = []
var buildings: Array = []
var trees: Array = []
var benches: Array = []
var sign_board: Rect2


func setup(layout: Dictionary) -> void:
	world = layout["world"]
	paths = layout["paths"]
	buildings = layout["buildings"]
	trees = layout["trees"]
	benches = layout["benches"]
	sign_board = layout["sign_board"]
	queue_redraw()


func _draw() -> void:
	draw_rect(world, GRASS)
	for x in range(int(world.position.x) + 45, int(world.end.x), 90):
		for y in range(int(world.position.y) + 45, int(world.end.y), 90):
			if (x * 31 + y * 17) % 3 != 0:
				draw_rect(Rect2(x, y, 10, 6), GRASS_SPECKLE)

	for path: Rect2 in paths:
		draw_rect(path.grow(4), PATH_EDGE)
	for path: Rect2 in paths:
		draw_rect(path, PATH)

	# Perimeter hedges (match the boundary collision in campus.gd)
	var hedge_thickness: float = 40.0
	draw_rect(Rect2(world.position, Vector2(world.size.x, hedge_thickness)), HEDGE)
	draw_rect(Rect2(Vector2(world.position.x, world.end.y - hedge_thickness), Vector2(world.size.x, hedge_thickness)), HEDGE)
	draw_rect(Rect2(world.position, Vector2(hedge_thickness, world.size.y)), HEDGE)
	draw_rect(Rect2(Vector2(world.end.x - hedge_thickness, world.position.y), Vector2(hedge_thickness, world.size.y)), HEDGE)

	for building: Dictionary in buildings:
		_draw_building(building)

	for bench: Rect2 in benches:
		draw_rect(bench.grow(2), Color(0, 0, 0, 0.25))
		draw_rect(bench, BENCH)

	draw_rect(Rect2(sign_board.get_center().x - 8, sign_board.end.y, 16, 34), SIGN_POST)
	draw_rect(sign_board.grow(3), Color("1a2c47"))
	draw_rect(sign_board, SIGN_BOARD)

	for tree: Vector2 in trees:
		draw_rect(Rect2(tree.x - 7, tree.y - 10, 14, 22), TRUNK)
		draw_circle(tree + Vector2(0, -38), 34.0, CANOPY)
		draw_circle(tree + Vector2(-10, -46), 22.0, CANOPY_LIGHT)


func _draw_building(building: Dictionary) -> void:
	var rect: Rect2 = building["rect"]
	var wall: Color = building["color"]
	draw_rect(rect.grow(3), wall.darkened(0.45))
	draw_rect(rect, wall)
	# Roof band
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 26)), wall.darkened(0.25))

	# Window grid
	var cols: int = int(rect.size.x / 96.0)
	for c in cols:
		for r in 2:
			draw_rect(Rect2(rect.position.x + 34 + c * 96, rect.position.y + 60 + r * 90, 40, 48), WINDOW)
			draw_rect(Rect2(rect.position.x + 34 + c * 96, rect.position.y + 60 + r * 90, 40, 6), wall.darkened(0.2))

	# Door on the side that faces the courtyard
	var door_x: float = building["door_x"]
	var door: Rect2
	if building["door_side"] == "bottom":
		door = Rect2(door_x - 36, rect.end.y - 20, 72, 20)
	else:
		door = Rect2(door_x - 36, rect.position.y, 72, 20)
	draw_rect(door.grow(4), wall.darkened(0.35))
	draw_rect(door, DOOR)
