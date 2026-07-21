extends Node2D
## The campus courtyard: builds the world from layout data, spawns the player
## and NPCs, owns collision, and wires the UI layer (HUD, joystick, interact
## button, dialogue panel). Milestone 1 scope: walk, collide, talk to Jordan.

const PlayerScene: PackedScene = preload("res://scenes/world/player.tscn")
const NpcScene: PackedScene = preload("res://scenes/world/npc.tscn")
const CampusArtScript: GDScript = preload("res://scripts/world/campus_art.gd")
const JoystickScript: GDScript = preload("res://scripts/ui/virtual_joystick.gd")
const DialogueScript: GDScript = preload("res://scripts/ui/dialogue_panel.gd")
const HudScript: GDScript = preload("res://scripts/ui/hud.gd")

const WORLD: Rect2 = Rect2(0, 0, 2200, 1400)
const HEDGE: float = 40.0
const PLAYER_SPAWN: Vector2 = Vector2(1100, 880)

const PATHS: Array = [
	Rect2(40, 660, 2120, 80),     # main east-west walk
	Rect2(1060, 40, 80, 1320),    # main north-south walk
	Rect2(344, 420, 72, 240),     # dorm spur
	Rect2(1784, 420, 72, 240),    # academic spur
	Rect2(344, 740, 72, 240),     # student center spur
	Rect2(1784, 740, 72, 240),    # gym spur
]

const BUILDINGS: Array = [
	{"name": "Hargrove Hall", "rect": Rect2(140, 120, 480, 300), "color": Color("9a5d43"), "door_side": "bottom", "door_x": 380.0},
	{"name": "Moreno Hall", "rect": Rect2(1580, 120, 480, 300), "color": Color("8a7a5a"), "door_side": "bottom", "door_x": 1820.0},
	{"name": "Student Center", "rect": Rect2(140, 980, 480, 300), "color": Color("6d7a8a"), "door_side": "top", "door_x": 380.0},
	{"name": "Rec Center", "rect": Rect2(1580, 980, 480, 300), "color": Color("7a5a6d"), "door_side": "top", "door_x": 1820.0},
]

const TREES: Array = [
	Vector2(800, 1150), Vector2(200, 560), Vector2(340, 820), Vector2(760, 540),
	Vector2(880, 240), Vector2(1400, 240), Vector2(1900, 560), Vector2(1750, 820),
	Vector2(240, 900), Vector2(1350, 1100), Vector2(1500, 1250), Vector2(2000, 780),
]

const BENCHES: Array = [
	Rect2(880, 592, 76, 24), Rect2(1280, 592, 76, 24), Rect2(1580, 764, 76, 24),
]

const SIGN_BOARD: Rect2 = Rect2(860, 780, 196, 84)

var player: CharacterBody2D
var current_npc: Node = null

var _joystick: Control
var _interact_button: Button
var _dialogue: PanelContainer


func _ready() -> void:
	_build_world()
	_build_actors()
	_build_ui()


func _process(_delta: float) -> void:
	player.external_input = _joystick.output
	_interact_button.disabled = current_npc == null and not _dialogue.visible
	if Input.is_action_just_pressed("interact"):
		_do_interact()


func _do_interact() -> void:
	if _dialogue.visible:
		_dialogue.advance()
	elif current_npc != null:
		player.control_locked = true
		_dialogue.open(current_npc.npc_name, current_npc.dialogue_lines)


# --- World -------------------------------------------------------------------

func _build_world() -> void:
	var art: Node2D = Node2D.new()
	art.name = "Art"
	art.set_script(CampusArtScript)
	add_child(art)
	art.setup({
		"world": WORLD, "paths": PATHS, "buildings": BUILDINGS,
		"trees": TREES, "benches": BENCHES, "sign_board": SIGN_BOARD,
	})

	# Boundary hedges
	_add_static_rect(Rect2(WORLD.position, Vector2(WORLD.size.x, HEDGE)))
	_add_static_rect(Rect2(Vector2(0, WORLD.end.y - HEDGE), Vector2(WORLD.size.x, HEDGE)))
	_add_static_rect(Rect2(WORLD.position, Vector2(HEDGE, WORLD.size.y)))
	_add_static_rect(Rect2(Vector2(WORLD.end.x - HEDGE, 0), Vector2(HEDGE, WORLD.size.y)))

	for building: Dictionary in BUILDINGS:
		_add_static_rect(building["rect"])
		var label: Label = Label.new()
		label.text = building["name"]
		label.position = (building["rect"] as Rect2).position + Vector2(28, 32)
		label.add_theme_font_size_override("font_size", 30)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
		label.add_theme_constant_override("outline_size", 6)
		add_child(label)

	for bench: Rect2 in BENCHES:
		_add_static_rect(bench)
	_add_static_rect(SIGN_BOARD.grow_individual(0.0, 0.0, 0.0, 34.0))

	for tree: Vector2 in TREES:
		_add_static_circle(tree, 12.0)

	var sign_label: Label = Label.new()
	sign_label.text = "NORTH VALLEY\nSTATE UNIVERSITY"
	sign_label.position = SIGN_BOARD.position + Vector2(22, 14)
	sign_label.add_theme_font_size_override("font_size", 20)
	sign_label.add_theme_color_override("font_color", Color("f2e6c8"))
	add_child(sign_label)


func _build_actors() -> void:
	var actors: Node2D = Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	actors.z_index = 5
	add_child(actors)

	player = PlayerScene.instantiate()
	player.name = "Player"
	player.position = PLAYER_SPAWN
	actors.add_child(player)
	player.set_camera_limits(WORLD)

	var jordan: StaticBody2D = NpcScene.instantiate()
	jordan.name = "Jordan"
	jordan.npc_name = "Jordan Hayes"
	jordan.position = Vector2(1220, 700)
	actors.add_child(jordan)
	var jordan_lines: Array[String] = [
		"Yo! You made it. Jordan Hayes — room 214, and fair warning, the top bunk is spoken for.",
		"Quick tour: classes are northeast in Moreno, the Rec Center's southeast, food's at the Student Center southwest. The quad is the shortcut to everything.",
		"Go get your bearings. I'll catch you back at Hargrove tonight.",
	]
	jordan.dialogue_lines = jordan_lines
	jordan.range_changed.connect(_on_npc_range_changed)


func _on_npc_range_changed(npc: Node, in_range: bool) -> void:
	if in_range:
		current_npc = npc
	elif current_npc == npc:
		current_npc = null


func _add_static_rect(rect: Rect2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = rect.get_center()
	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)


func _add_static_circle(center: Vector2, radius: float) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = center
	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = radius
	collider.shape = shape
	body.add_child(collider)
	add_child(body)


# --- UI ----------------------------------------------------------------------

func _build_ui() -> void:
	var ui: CanvasLayer = CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)

	var hud: PanelContainer = PanelContainer.new()
	hud.name = "HUD"
	hud.set_script(HudScript)
	ui.add_child(hud)

	_joystick = Control.new()
	_joystick.name = "Joystick"
	_joystick.set_script(JoystickScript)
	_joystick.position = Vector2(48, 452)
	_joystick.size = Vector2(220, 220)
	ui.add_child(_joystick)

	_interact_button = Button.new()
	_interact_button.name = "InteractButton"
	_interact_button.text = "TALK"
	_interact_button.position = Vector2(1040, 560)
	_interact_button.size = Vector2(190, 96)
	_interact_button.focus_mode = Control.FOCUS_NONE
	_interact_button.add_theme_font_size_override("font_size", 28)
	_interact_button.pressed.connect(_do_interact)
	ui.add_child(_interact_button)

	_dialogue = PanelContainer.new()
	_dialogue.name = "Dialogue"
	_dialogue.set_script(DialogueScript)
	ui.add_child(_dialogue)
	_dialogue.finished.connect(_on_dialogue_finished)


func _on_dialogue_finished() -> void:
	player.control_locked = false
