extends Node
## Scripted gameplay for the trailer. Recorded with --write-movie at a fixed
## frame rate, so every frame is captured. Uses real input: the player walks
## everywhere (no teleports inside a scene) and the shots are timed on the
## real meter. Captions are drawn on a top layer so they land in the video.

var is_runner: bool = false
var _caption_label: Label
var _shooting: bool = false


func _ready() -> void:
	# Scene changes free the scene's own nodes, so the run is driven from a
	# copy parked on the root that survives every change.
	if not is_runner:
		var runner: Node = Node.new()
		runner.set_script(get_script())
		runner.set("is_runner", true)
		runner.name = "TrailerRunner"
		get_tree().root.add_child.call_deferred(runner)
		queue_free()
		return
	get_tree().create_timer(1200.0, true, false, true).timeout.connect(func() -> void:
		print("WATCHDOG")
		get_tree().quit(2))
	SaveSystem.clear_save()
	Engine.time_scale = 1.0
	_build_caption()
	if "walkthrough" in OS.get_cmdline_user_args():
		await _run_walkthrough()
	else:
		await _run()
	get_tree().quit(0)


func _run() -> void:
	# --- Title -----------------------------------------------------------
	get_tree().change_scene_to_file(Game.SCENES["title"])
	await _frames(90)
	var title: Node = get_tree().current_scene
	title.find_child("NewGame", true, false).pressed.emit()
	await _frames(20)

	# --- Create your character -------------------------------------------
	_caption("Create your character", true)
	for look: Dictionary in ContentDB.get_looks():
		title.find_child("Look_" + str(look["id"]), true, false).pressed.emit()
		await _frames(30)
	for identity: Dictionary in ContentDB.get_identities():
		title.find_child("Identity_" + str(identity["id"]), true, false).pressed.emit()
		await _frames(30)
	title.find_child("Look_" + str(ContentDB.get_looks()[0]["id"]), true, false).pressed.emit()
	title.find_child("Identity_natural", true, false).pressed.emit()
	await _frames(15)
	var edit: LineEdit = title.find_child("NameEdit", true, false) as LineEdit
	var typed: String = ""
	for ch: String in "Marcus":
		typed += ch
		edit.text = typed
		await _frames(6)
	await _frames(35)
	title.find_child("Start", true, false).pressed.emit()
	await _wait_scene(true)
	var loc: Node = get_tree().current_scene
	_caption("Make friends")
	await _frames(30)
	var jordan: Node3D = loc.npcs.get("jordan")
	if jordan != null:
		await _walk_to(loc, jordan.global_position, 1.1)
		await _press_interact(loc)
		await _frames(50)
		await _drive_card(loc, 55)
		await _frames(20)

	# --- Train (jump straight to the gym, then the practice shots) -------
	TimeSystem.period = TimeSystem.Period.AFTERNOON
	Game.change_scene("gym")
	await _wait_scene(true)
	loc = get_tree().current_scene
	_caption("Train")
	await _frames(30)
	var court: Node3D = loc._marker("spot_court")
	await _walk_to(loc, court.global_position, 1.0)
	await _press_interact(loc)
	await _frames(40)
	loc.ui.card.pick(0)
	await _frames(20)
	print("MARK shoot_start ", Engine.get_frames_drawn() / 30.0)
	await _shoot_all(loc)
	print("MARK shoot_end ", Engine.get_frames_drawn() / 30.0)
	await _drive_card(loc, 45)
	await _wait_idle(loc)
	await _frames(20)

	# --- Tryout: the coach outside, Day 2 ----------------------------------
	TimeSystem.day = 2
	TimeSystem.period = TimeSystem.Period.AFTERNOON
	Game.change_scene("campus")
	await _wait_scene(true)
	loc = get_tree().current_scene
	_caption("Try out for the team")
	await _frames(30)
	var coach: Node3D = loc.npcs.get("coach")
	if coach != null:
		await _walk_to(loc, coach.global_position, 1.1)
		await _press_interact(loc)
		await _frames(50)
		await _drive_card(loc, 60)
		await _frames(60)
	await _frames(30)


func _run_walkthrough() -> void:
	get_tree().change_scene_to_file(Game.SCENES["title"])
	await _frames(100)
	var title: Node = get_tree().current_scene
	title.find_child("NewGame", true, false).pressed.emit()
	await _frames(45)
	_caption("Pick your look", true)
	for look: Dictionary in ContentDB.get_looks():
		title.find_child("Look_" + str(look["id"]), true, false).pressed.emit()
		await _frames(32)
	title.find_child("Look_" + str(ContentDB.get_looks()[0]["id"]), true, false).pressed.emit()
	await _frames(30)
	_caption("Pick your story", true)
	for identity: Dictionary in ContentDB.get_identities():
		title.find_child("Identity_" + str(identity["id"]), true, false).pressed.emit()
		await _frames(38)
	title.find_child("Identity_natural", true, false).pressed.emit()
	await _frames(20)
	var edit: LineEdit = title.find_child("NameEdit", true, false) as LineEdit
	var typed: String = ""
	for ch: String in "Marcus":
		typed += ch
		edit.text = typed
		await _frames(6)
	await _frames(40)
	title.find_child("Start", true, false).pressed.emit()
	await _wait_scene()
	var loc: Node = get_tree().current_scene
	await _frames(70)
	# The quad walk is cut in post: "MARK walk_start/walk_end" bracket it.
	_caption("Make friends")
	print("MARK walk_start ", Engine.get_frames_drawn() / 30.0)
	var jordan: Node3D = loc.npcs.get("jordan")
	if jordan != null:
		await _walk_to(loc, jordan.global_position, 1.1)
		await _press_interact(loc)
		await _frames(2)
		print("MARK walk_end ", Engine.get_frames_drawn() / 30.0)
		await _frames(48)
		await _drive_card(loc, 55)
		await _frames(30)
	_caption("Train")
	await _walk_to_door(loc, "door_gym")
	await _wait_scene()
	loc = get_tree().current_scene
	await _frames(50)
	var weights: Node3D = loc._marker("spot_weights")
	if weights != null:
		await _walk_to(loc, weights.global_position, 1.0)
		await _press_interact(loc)
		await _frames(50)
		loc.ui.card.pick(0)
		await _frames(100)
		await _drive_card(loc, 50)
		await _wait_idle(loc)
		await _frames(30)
	_caption("Then, tryout day")
	await _frames(60)
	GameState.set_flag("signed_up")
	GameState.apply_effects({"basketball_skill": 45, "athleticism": 20, "energy": 80})
	TimeSystem.day = 7
	TimeSystem.period = TimeSystem.Period.MORNING
	Game.change_scene("gym")
	await _wait_scene()
	loc = get_tree().current_scene
	_caption("Try out for the team")
	await _frames(60)
	var coach: Node3D = loc.npcs.get("coach")
	if coach != null:
		await _walk_to(loc, coach.global_position, 1.2)
		await _press_interact(loc)
		await _frames(60)
		for i in 6:
			if not loc.ui.card.is_open():
				break
			var b: Array = loc.ui.card.choice_buttons()
			if b.is_empty():
				loc.ui.card.advance()
			else:
				loc.ui.card.pick(0)
				break
			await _frames(70)
		await _frames(30)
		_caption("")
		print("MARK shoot_start ", Engine.get_frames_drawn() / 30.0)
		await _shoot_all(loc)
		print("MARK shoot_end ", Engine.get_frames_drawn() / 30.0)
	var guard: int = 0
	while get_tree().current_scene != null and Game.location != "ending" and guard < 900:
		guard += 1
		await _frames(1)
	await _wait_scene()
	await _frames(170)
	_caption("THE U", true)
	await _frames(80)


# --- Input-driven helpers ------------------------------------------------

## Walks with movement input only. Never teleports; sidesteps when blocked.
func _walk_to(loc: Node, point: Vector3, radius: float) -> void:
	var player: CharacterBody3D = loc.player
	var stuck: int = 0
	var last: Vector3 = player.global_position
	var side: int = 1
	for _i in 1200:
		var to: Vector3 = point - player.global_position
		to.y = 0.0
		if to.length() <= radius:
			break
		_release_move()
		var dir: Vector2 = Vector2(to.x, to.z).normalized()
		if stuck > 20:
			# Slide around whatever is in the way.
			dir = Vector2(-dir.y, dir.x) * side
		if dir.x > 0.3:
			Input.action_press("move_right")
		elif dir.x < -0.3:
			Input.action_press("move_left")
		if dir.y > 0.3:
			Input.action_press("move_down")
		elif dir.y < -0.3:
			Input.action_press("move_up")
		await _frames(1)
		if player.global_position.distance_to(last) < 0.004:
			stuck += 1
			if stuck > 60:
				stuck = 0
				side = -side
		else:
			stuck = maxi(stuck - 2, 0)
		last = player.global_position
	_release_move()
	await _frames(25)
	print("walk end: dist ", player.global_position.distance_to(point))


func _walk_to_door(loc: Node, marker: String) -> void:
	var door: Node3D = loc._marker(marker)
	if door == null:
		return
	await _walk_to(loc, door.global_position, 0.7)
	await _press_interact(loc)


func _press_interact(loc: Node) -> void:
	loc._update_current()
	Input.action_press("interact")
	await _frames(5)
	Input.action_release("interact")
	await _frames(20)


func _release_move() -> void:
	for a: String in ["move_up", "move_down", "move_left", "move_right"]:
		Input.action_release(a)


## Reads a card at a readable pace: Continue through lines, choose the first
## option, Continue through the result.
func _drive_card(loc: Node, pace: int) -> void:
	for i in 20:
		if not loc.ui.card.is_open():
			break
		var b: Array = loc.ui.card.choice_buttons()
		if b.is_empty():
			loc.ui.card.advance()
		else:
			loc.ui.card.pick(0)
		await _frames(pace)


func _wait_idle(loc: Node) -> void:
	var n: int = 0
	while (loc.busy or loc.ui.recap_open()) and n < 1500:
		n += 1
		await _frames(1)


## Plays every shot of a minigame on the real meter: waits for the sweep to
## cross the gold zone, then presses interact.
func _shoot_all(loc: Node) -> void:
	var game: Node = null
	var waited: int = 0
	while game == null and waited < 400:
		waited += 1
		for child in loc.get_children():
			if child.get_script() != null and str(child.get_script().resource_path).ends_with("shot_minigame.gd"):
				game = child
		await _frames(1)
	if game == null:
		return
	var cooldown: int = 0
	while is_instance_valid(game):
		cooldown -= 1
		if game.get("_sweeping") and cooldown <= 0:
			var p: float = game.get("_position")
			var c: float = game.get("_zone_center")
			var w: float = game.get("_zone_width")
			if absf(p - c) < w * 0.22:
				Input.action_press("interact")
				await _frames(2)
				Input.action_release("interact")
				cooldown = 30
		await _frames(1)


func _wait_scene(quick: bool = false) -> void:
	await _frames(6 if quick else 20)
	var guard: int = 0
	while (Game.is_changing_scene() or get_tree().current_scene == null) and guard < 600:
		guard += 1
		await _frames(1)
	await _frames(3 if quick else 30)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


# --- Captions --------------------------------------------------------------

func _build_caption() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_caption_label = Label.new()
	_caption_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_caption_label.anchor_left = 0.0
	_caption_label.anchor_right = 1.0
	_caption_label.offset_top = 100
	_caption_label.offset_bottom = 168
	_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_label.add_theme_font_size_override("font_size", 46)
	_caption_label.add_theme_color_override("font_color", Color("f5c542"))
	_caption_label.add_theme_color_override("font_outline_color", Color(0.04, 0.07, 0.15, 1.0))
	_caption_label.add_theme_constant_override("outline_size", 12)
	_caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_caption_label)


func _caption(text: String, bottom: bool = false) -> void:
	_caption_label.offset_top = 640 if bottom else 100
	_caption_label.offset_bottom = 708 if bottom else 168
	_caption_label.text = text
	_caption_label.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(_caption_label, "modulate:a", 1.0, 0.4)
	tween.tween_interval(2.0)
	tween.tween_property(_caption_label, "modulate:a", 0.0, 0.6)
