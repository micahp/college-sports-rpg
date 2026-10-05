extends Node3D
## Runtime behavior shared by every place the player can stand: the quad and
## each interior. The environment is authored in the scene; this script only
## runs it — spawns the player at the right door, places whoever is here this
## period, finds the nearest thing to interact with, drives the story card,
## spends time, and points the camera.
##
## Scene contract (see tools/build_campus_scene.gd, tools/build_interiors.gd):
##   Markers/arrive_<key>   spawn points (Game.arrival picks one)
##   Markers/spot_<id>      where NPCs stand and activities happen
##   Markers/door_<place>   walk here and press ENTER/EXIT to travel
##   Actors                 parent for the player and NPCs
##   Sun, WorldEnvironment  optional; tinted per period on the quad

const PlayerScene: PackedScene = preload("res://scenes/world3d/player3d.tscn")
const NpcScene: PackedScene = preload("res://scenes/world3d/npc3d.tscn")
const GameUIScript = preload("res://scripts/ui/game_ui.gd")
const ShotMinigameScript = preload("res://scripts/minigame/shot_minigame.gd")

const INTERACT_RADIUS: float = 2.1
const DOOR_RADIUS: float = 2.3

@export var location_id: String = "campus"
@export var cam_pitch: float = -40.0
@export var cam_yaw: float = 20.0
@export var cam_distance: float = 14.0
@export var cam_fov: float = 38.0
@export var look_ahead: Vector3 = Vector3(0, 0, -1.2)
## The camera rig never leaves this XZ rectangle, so interiors stay framed.
@export var cam_bounds: Rect2 = Rect2(-100, -100, 200, 200)
## Interiors get softer, closer framing for conversations.
@export var talk_distance: float = 8.5
@export var apply_period_lighting: bool = false

var player: CharacterBody3D
var ui: CanvasLayer
var npcs: Dictionary = {}  # npc_id -> node
var busy: bool = false

var _rig: Node3D
var _arm: Node3D
var _camera: Camera3D
var _cam_tween: Tween
var _interactables: Array = []
var _current: Dictionary = {}
var _beacon: Node3D
var _beacon_time: float = 0.0
var _markers: Node3D


func _ready() -> void:
	Game.location = location_id
	_markers = get_node_or_null("Markers")
	ui = CanvasLayer.new()
	ui.set_script(GameUIScript)
	add_child(ui)
	ui.action_pressed.connect(_interact)
	ui.card.choice_made.connect(_on_choice_made)
	_spawn_player()
	_build_camera()
	_build_beacon()
	_populate()
	if apply_period_lighting:
		_apply_lighting()
	ui.refresh()
	if not Game.in_game:
		# Opened directly in the editor: give it a usable state.
		Game.in_game = true
	var period_line: String = "%s · %s" % [TimeSystem.weekday_name(), TimeSystem.period_name()]
	ui.toast(Game.LOCATION_NAMES.get(location_id, "") + "  —  " + period_line)


func _process(delta: float) -> void:
	player.external_input = ui.joystick.output
	var modal: bool = ui.is_modal_open() or busy
	player.control_locked = modal
	if not modal:
		_follow_camera(delta)
		_update_current()
	_update_beacon(delta)
	if Input.is_action_just_pressed("interact"):
		if ui.card.is_open():
			ui.card.advance()
		elif ui.recap_open():
			ui._close_recap()
		elif not modal:
			_interact()


# =============================================================================
# Setup
# =============================================================================

func _spawn_player() -> void:
	var look: Dictionary = ContentDB.get_look(GameState.look_id)
	player = PlayerScene.instantiate()
	player.name = "Player"
	player.model_key = str(look.get("model", "male_casual"))
	player.skin_tone = str(look.get("skin", "brown"))
	player.shirt_color = Color(str(look.get("shirt", "#ebb84d")))
	player.pants_color = Color(str(look.get("pants", "#29385f")))
	player.hair_color = Color(str(look.get("hair", "#1a1412")))
	var arrive: Marker3D = _marker("arrive_" + Game.arrival)
	if arrive == null:
		arrive = _first_marker("arrive_")
	$Actors.add_child(player)
	if arrive != null:
		player.global_position = arrive.global_position + Vector3(0, 0.05, 0)
		player.face_direction(-arrive.global_transform.basis.z)


func _build_camera() -> void:
	_rig = Node3D.new()
	_rig.name = "CameraRig"
	add_child(_rig)
	_arm = Node3D.new()
	_arm.rotation_degrees = Vector3(cam_pitch, cam_yaw, 0)
	_rig.add_child(_arm)
	_camera = Camera3D.new()
	_camera.fov = cam_fov
	_camera.position.z = cam_distance
	_arm.add_child(_camera)
	_camera.make_current()
	_rig.global_position = _clamp_rig(player.global_position + look_ahead)


func _follow_camera(delta: float) -> void:
	if _cam_tween != null and _cam_tween.is_running():
		return
	var target: Vector3 = _clamp_rig(player.global_position + look_ahead)
	_rig.global_position = _rig.global_position.lerp(target, minf(1.0, 6.0 * delta))


func _clamp_rig(p: Vector3) -> Vector3:
	return Vector3(
		clampf(p.x, cam_bounds.position.x, cam_bounds.end.x), p.y,
		clampf(p.z, cam_bounds.position.y, cam_bounds.end.y)
	)


## (Re)places this period's NPCs and rebuilds the interactable list.
func _populate() -> void:
	for node: Node in npcs.values():
		node.queue_free()
	npcs.clear()
	_interactables.clear()
	var npc_data: Dictionary = ContentDB.get_npcs()
	for entry: Dictionary in Game.npcs_at(location_id):
		var marker: Marker3D = _marker("spot_" + str(entry["spot"]))
		if marker == null:
			push_warning("No marker spot_%s in %s" % [entry["spot"], location_id])
			continue
		var info: Dictionary = npc_data[entry["npc"]]
		var npc: Node3D = NpcScene.instantiate()
		npc.name = "NPC_" + str(entry["npc"])
		npc.npc_name = str(info["name"])
		npc.model_key = str(info["model"])
		npc.skin_tone = str(info["skin"])
		npc.shirt_color = Color(str(info["shirt"]))
		npc.pants_color = Color(str(info["pants"]))
		npc.hair_color = Color(str(info["hair"]))
		$Actors.add_child(npc)
		npc.global_position = marker.global_position
		npc.face_direction(-marker.global_transform.basis.z)
		npcs[entry["npc"]] = npc
		var event: Dictionary = entry["event"]
		npc.set_story_pending(not event.is_empty() and not Game.is_event_done(event))
		_interactables.append({
			"kind": "npc", "node": npc, "radius": INTERACT_RADIUS,
			"label": "TALK", "npc": entry["npc"], "entry": entry,
		})
	for spot: Dictionary in Game.spots_at(location_id):
		var marker: Marker3D = _marker("spot_" + str(spot["spot"]))
		if marker == null:
			push_warning("No marker spot_%s in %s" % [spot["spot"], location_id])
			continue
		_interactables.append({
			"kind": "spot", "node": marker, "radius": INTERACT_RADIUS,
			"label": str(spot["prompt"]), "spot": spot,
		})
	if _markers != null:
		for marker in _markers.get_children():
			if marker.name.begins_with("door_"):
				var target: String = str(marker.name).trim_prefix("door_")
				_interactables.append({
					"kind": "door", "node": marker, "radius": DOOR_RADIUS,
					"label": "EXIT" if target == "campus" else "ENTER", "target": target,
				})
	_current = {}


# =============================================================================
# Interaction
# =============================================================================

func _update_current() -> void:
	var best: Dictionary = {}
	var best_dist: float = INF
	for item: Dictionary in _interactables:
		var node: Node3D = item["node"]
		if not is_instance_valid(node):
			continue
		var d: float = Vector2(node.global_position.x - player.global_position.x,
			node.global_position.z - player.global_position.z).length()
		if d < float(item["radius"]) and d < best_dist:
			best = item
			best_dist = d
	if best != _current:
		if _current.get("kind", "") == "npc" and is_instance_valid(_current["node"]):
			_current["node"].set_player_near(false)
		_current = best
		if _current.get("kind", "") == "npc":
			_current["node"].set_player_near(true)
	ui.set_action(_action_label(_current))


func _action_label(item: Dictionary) -> String:
	match item.get("kind", ""):
		"npc", "spot":
			return item["label"]
		"door":
			return item["label"]
	return ""


## Name of what the action button would do — used by tests and the hint.
func current_target() -> Dictionary:
	return _current


func _interact() -> void:
	if busy or _current.is_empty() or ui.is_modal_open() or Game.is_changing_scene():
		return
	match _current["kind"]:
		"npc":
			_talk_to(_current)
		"spot":
			var spot: Dictionary = _current["spot"]
			_play_ui("res://assets/audio/ui_open.ogg")
			ui.card.open_activity(str(spot["title"]), str(spot.get("text", "")),
				Game.available_choices(spot["choices"]), Game.choice_block_reason)
			_active_beat = str(spot["id"])
		"door":
			_play_ui("res://assets/audio/ui_confirm.ogg")
			busy = true
			Game.travel(str(_current["target"]))


var _active_beat: String = ""
var _active_npc: Node3D = null


func _talk_to(item: Dictionary) -> void:
	var entry: Dictionary = item["entry"]
	var npc: Node3D = item["node"]
	var info: Dictionary = ContentDB.get_npcs()[entry["npc"]]
	var event: Dictionary = entry["event"]
	_active_npc = npc
	npc.face_toward(player.global_position)
	player.face_toward(npc.global_position)
	_play_ui("res://assets/audio/ui_open.ogg")
	if not event.is_empty() and not Game.is_event_done(event):
		_active_beat = str(event["id"])
		ui.card.open_conversation(str(entry["npc"]), str(info["name"]), str(info.get("role", "")),
			event["lines"], Game.available_choices(event["choices"]), Game.choice_block_reason)
	else:
		_active_beat = ""
		var line: String
		if not event.is_empty():
			line = str(event.get("repeat_line", "..."))
		else:
			var lines: Array = entry["lines"]
			line = str(lines[(TimeSystem.day * 4 + TimeSystem.period) % lines.size()])
		ui.card.open_conversation(str(entry["npc"]), str(info["name"]), str(info.get("role", "")),
			[line], [], Game.choice_block_reason)
	_move_camera_to_conversation(npc)
	await ui.card.finished
	_restore_camera()


func _on_choice_made(choice: Dictionary) -> void:
	var beat: String = _active_beat
	if choice.get("minigame", "") == "tryout":
		await _run_tryout()
		return
	if beat == "spectator_day":
		Game.apply_choice(beat, choice)
		Game.finish_as_spectator()
		return
	var bonus: Dictionary = {}
	var bonus_text: String = ""
	if choice.has("minigame"):
		ui.card.visible = false
		var kind: String = str(choice["minigame"])
		var result: Dictionary = await run_minigame(kind)
		var extra: Dictionary = Game.minigame_bonus(kind, result)
		bonus = extra["effects"]
		bonus_text = extra["text"]
	var outcome: Dictionary = Game.apply_choice(beat, choice, bonus, bonus_text)
	if not choice.has("minigame"):
		_play_ui("res://assets/audio/ui_confirm.ogg")
	# Story markers update immediately (e.g. the "!" over someone you just answered).
	for item: Dictionary in _interactables:
		if item["kind"] == "npc" and not (item["entry"]["event"] as Dictionary).is_empty():
			item["node"].set_story_pending(not Game.is_event_done(item["entry"]["event"]))
	ui.card.show_result(outcome["reaction"], outcome["applied"])
	await ui.card.finished
	if int(outcome["duration"]) > 0:
		await _pass_time(int(outcome["duration"]))


func _pass_time(blocks: int) -> void:
	busy = true
	var rolled: bool = Game.spend_time(blocks)
	if rolled:
		ui.show_recap(Game.pending_recap_day)
		await ui.recap_closed
		Game.start_new_day()
		return
	await ui.show_banner(TimeSystem.period_name().to_upper(),
		"%s · Day %d" % [TimeSystem.weekday_name(), TimeSystem.day], 1.1)
	if apply_period_lighting:
		_apply_lighting()
	_populate()
	ui.refresh()
	busy = false


## Interiors with a court override nothing — the minigame finds its hoop and
## shooting spots through markers (Markers/hoop, Markers/shot_*).
func run_minigame(kind: String) -> Dictionary:
	busy = true
	var game: Node = Node.new()
	game.set_script(ShotMinigameScript)
	add_child(game)
	var result: Dictionary = await game.run(self, kind)
	game.queue_free()
	busy = false
	return result


func _run_tryout() -> void:
	ui.card.visible = false
	var result: Dictionary = await run_minigame("tryout")
	busy = true
	Game.apply_choice("tryout_day", {"id": "start_tryout", "tags": ["grind"], "effects": {}})
	Game.finish_tryout(result)


# =============================================================================
# Objective beacon
# =============================================================================

func _build_beacon() -> void:
	_beacon = Node3D.new()
	_beacon.name = "Beacon"
	add_child(_beacon)
	var arrow: MeshInstance3D = MeshInstance3D.new()
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.28
	cone.bottom_radius = 0.0
	cone.height = 0.5
	cone.radial_segments = 4
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = UIKit.GOLD
	mat.emission_enabled = true
	mat.emission = UIKit.GOLD
	mat.emission_energy_multiplier = 0.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.render_priority = 8
	cone.material = mat
	arrow.mesh = cone
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon.add_child(arrow)
	_beacon.visible = false


func _update_beacon(delta: float) -> void:
	_beacon_time += delta
	var target: Node3D = beacon_target()
	_beacon.visible = target != null and not ui.is_modal_open()
	if target != null:
		var height: float = 2.95 if target.has_method("set_story_pending") else 2.2
		_beacon.global_position = target.global_position + Vector3(0, height + sin(_beacon_time * 3.2) * 0.12, 0)
		_beacon.rotation.y += delta * 1.8


## Where the objective arrow points in this location, or null.
func beacon_target() -> Node3D:
	var objective: Dictionary = Game.objective()
	var where: String = str(objective.get("location", ""))
	if where == "":
		return null
	if where != location_id:
		# Point at the way out toward it: a building door on the quad, the exit inside.
		var door: Marker3D = _marker("door_" + where) if location_id == "campus" else _marker("door_campus")
		return door
	var spot: String = str(objective.get("spot", ""))
	for entry: Dictionary in Game.npcs_at(location_id):
		if entry["spot"] == spot and npcs.has(entry["npc"]):
			return npcs[entry["npc"]]
	return _marker("spot_" + spot)


# =============================================================================
# Camera moves
# =============================================================================

func _move_camera_to_conversation(npc: Node3D) -> void:
	var between: Vector3 = npc.global_position - player.global_position
	var perp: Vector2 = Vector2(between.z, -between.x)
	var yaw_a: float = rad_to_deg(atan2(perp.x, perp.y))
	var yaw_b: float = rad_to_deg(atan2(-perp.x, -perp.y))
	var chosen: float = yaw_a
	if absf(angle_difference(deg_to_rad(cam_yaw), deg_to_rad(yaw_b))) \
			< absf(angle_difference(deg_to_rad(cam_yaw), deg_to_rad(yaw_a))):
		chosen = yaw_b
	# Keep interior walls out of frame: never swing more than 50° off the set angle.
	chosen = cam_yaw + clampf(angle_difference(deg_to_rad(cam_yaw), deg_to_rad(chosen)) * 180.0 / PI, -50.0, 50.0)
	var midpoint: Vector3 = (player.global_position + npc.global_position) / 2.0
	_tween_camera(midpoint + Vector3(0, 1.0, 0), Vector3(cam_pitch + 8.0, chosen, 0), talk_distance)


func _restore_camera() -> void:
	_tween_camera(_clamp_rig(player.global_position + look_ahead),
		Vector3(cam_pitch, cam_yaw, 0), cam_distance)


func _tween_camera(target: Vector3, arm_rotation: Vector3, distance: float, seconds: float = 0.6) -> void:
	if _cam_tween != null:
		_cam_tween.kill()
	_cam_tween = create_tween().set_parallel()
	_cam_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(_rig, "global_position", target, seconds)
	_cam_tween.tween_property(_arm, "rotation_degrees", arm_rotation, seconds)
	_cam_tween.tween_property(_camera, "position:z", distance, seconds)


## Used by the minigame to frame the shot.
func frame_camera(target: Vector3, arm_rotation: Vector3, distance: float, seconds: float = 0.6) -> void:
	_tween_camera(target, arm_rotation, distance, seconds)


func restore_camera() -> void:
	_restore_camera()


# =============================================================================
# Period lighting (quad only)
# =============================================================================

func _apply_lighting() -> void:
	var sun: DirectionalLight3D = get_node_or_null("Sun")
	var world: WorldEnvironment = get_node_or_null("WorldEnvironment")
	if sun == null or world == null:
		return
	var sky: ProceduralSkyMaterial = world.environment.sky.sky_material as ProceduralSkyMaterial
	match TimeSystem.period:
		TimeSystem.Period.MORNING:
			sun.light_color = Color(1.0, 0.95, 0.88)
			sun.light_energy = 1.05
			sun.rotation_degrees = Vector3(-40, -60, 0)
			world.environment.ambient_light_energy = 1.0
			sky.sky_top_color = Color(0.42, 0.62, 0.84)
			sky.sky_horizon_color = Color(0.86, 0.86, 0.8)
		TimeSystem.Period.AFTERNOON:
			sun.light_color = Color(1.0, 0.93, 0.82)
			sun.light_energy = 1.1
			sun.rotation_degrees = Vector3(-52, -38, 0)
			world.environment.ambient_light_energy = 1.05
			sky.sky_top_color = Color(0.4, 0.58, 0.78)
			sky.sky_horizon_color = Color(0.88, 0.82, 0.7)
		TimeSystem.Period.EVENING:
			sun.light_color = Color(1.0, 0.7, 0.45)
			sun.light_energy = 0.95
			sun.rotation_degrees = Vector3(-18, -20, 0)
			world.environment.ambient_light_energy = 0.8
			sky.sky_top_color = Color(0.32, 0.36, 0.6)
			sky.sky_horizon_color = Color(0.98, 0.62, 0.42)
		TimeSystem.Period.NIGHT:
			sun.light_color = Color(0.5, 0.6, 0.95)
			sun.light_energy = 0.22
			sun.rotation_degrees = Vector3(-50, 30, 0)
			world.environment.ambient_light_energy = 0.22
			sky.sky_top_color = Color(0.04, 0.06, 0.14)
			sky.sky_horizon_color = Color(0.16, 0.18, 0.3)
	var night: bool = TimeSystem.period == TimeSystem.Period.NIGHT
	sky.ground_horizon_color = Color(0.14, 0.15, 0.22) if night else Color(0.84, 0.79, 0.67)
	sky.ground_bottom_color = Color(0.05, 0.06, 0.08) if night else Color(0.32, 0.36, 0.31)
	for lamp: Node in find_children("LampLight*", "OmniLight3D", true, false):
		(lamp as OmniLight3D).visible = TimeSystem.period >= TimeSystem.Period.EVENING


# =============================================================================
# Helpers
# =============================================================================

func _marker(marker_name: String) -> Marker3D:
	if _markers == null:
		return null
	return _markers.get_node_or_null(marker_name) as Marker3D


func _first_marker(prefix: String) -> Marker3D:
	if _markers == null:
		return null
	for child in _markers.get_children():
		if child.name.begins_with(prefix):
			return child
	return null


func _play_ui(path: String) -> void:
	var sound: AudioStreamPlayer = get_node_or_null("UISound")
	if sound == null:
		sound = AudioStreamPlayer.new()
		sound.name = "UISound"
		sound.volume_db = -6.0
		add_child(sound)
	sound.stream = load(path)
	sound.play()
