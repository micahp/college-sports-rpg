extends Node
## Timing-based shooting minigame. A marker sweeps a vertical meter; release
## inside the gold zone to make the shot. Zone width comes from basketball
## skill, sweep speed from athleticism and energy (Game.meter_tuning), and
## each mode (shootaround, showcase, tryout) has its own rounds.
##
## Needs in the host location: Markers/hoop (rim center) and Markers/shot_1..3.
## Returns { makes, perfects, shots }.

signal _released

## Tests set this: shots release automatically at the given quality
## ("perfect", "good", "miss") without waiting for input.
static var auto_quality: String = ""

const PERFECT_FRACTION: float = 0.35
const NEAR_FRACTION: float = 1.6

var _loc: Node3D
var _layer: CanvasLayer
var _meter: Control
var _title: Label
var _counter: Label
var _flash: Label
var _shoot_button: Button
var _position: float = 0.0
var _direction: float = 1.0
var _speed: float = 1.0
var _zone_center: float = 0.7
var _zone_width: float = 0.15
var _sweeping: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _ball: MeshInstance3D


func run(loc: Node3D, kind: String) -> Dictionary:
	_loc = loc
	_loc.ui.visible = false
	_rng.randomize()
	_build_ui()
	_build_ball()
	var hoop: Vector3 = _marker_pos("hoop", Vector3(0, 3.05, -8))
	var spots: Array[Vector3] = []
	for i in range(1, 4):
		spots.append(_marker_pos("shot_%d" % i, hoop + Vector3((i - 2) * 2.5, -3.05, 5.0)))
	var tuning: Dictionary = Game.meter_tuning()
	var rounds: Array = Game.minigame_rounds(kind)
	var total_shots: int = 0
	for r: Dictionary in rounds:
		total_shots += int(r["shots"])
	var makes: int = 0
	var perfects: int = 0
	var taken: int = 0
	for round_index in rounds.size():
		var r: Dictionary = rounds[round_index]
		_title.text = str(r["name"])
		var spot: Vector3 = spots[round_index % spots.size()]
		if kind == "tryout" and round_index == 2:
			# Free throws come from the line, straight on.
			spot = _marker_pos("shot_ft", Vector3(hoop.x, 0, hoop.z + 4.3))
		_place_player(spot, hoop)
		await _wait(0.5)
		for shot in int(r["shots"]):
			_counter.text = "Shot %d / %d     Makes %d" % [taken + 1, total_shots, makes]
			_speed = float(tuning["speed"]) * float(r["speed"])
			_zone_width = clampf(float(tuning["zone"]) * float(r["zone"]), 0.05, 0.4)
			_zone_center = _rng.randf_range(0.5 + _zone_width / 2.0, 0.92 - _zone_width / 2.0)
			_position = 0.0
			_direction = 1.0
			_shoot_button.visible = true
			_sweeping = true
			if auto_quality != "":
				get_tree().create_timer(0.15).timeout.connect(_auto_release)
			await _released
			_sweeping = false
			_shoot_button.visible = false
			var quality: String = _grade(_position)
			var made: bool = _roll_make(quality)
			taken += 1
			if made:
				makes += 1
			if made and quality == "perfect":
				perfects += 1
			await _animate_shot(hoop, made)
			_flash_result(quality, made)
			_counter.text = "Shot %d / %d     Makes %d" % [taken, total_shots, makes]
			await _wait(0.55)
	_meter.visible = false
	_title.text = "%d of %d" % [makes, total_shots]
	_flash.text = "That's the set."
	_flash.modulate.a = 1.0
	await _wait(1.2)
	_layer.queue_free()
	_ball.queue_free()
	_loc.ui.visible = true
	_loc.restore_camera()
	return {"makes": makes, "perfects": perfects, "shots": total_shots}


func _process(delta: float) -> void:
	if _sweeping:
		_position += _direction * _speed * delta
		if _position >= 1.0:
			_position = 1.0
			_direction = -1.0
		elif _position <= 0.0:
			_position = 0.0
			_direction = 1.0
		_meter.queue_redraw()
	if _sweeping and Input.is_action_just_pressed("interact"):
		_release()


func _release() -> void:
	if _sweeping:
		_sweeping = false
		_released.emit()


func _auto_release() -> void:
	match auto_quality:
		"perfect":
			_position = _zone_center
		"good":
			_position = _zone_center + _zone_width * 0.45
		_:
			_position = clampf(_zone_center - _zone_width * 2.5, 0.0, 1.0)
	_release()


func _grade(p: float) -> String:
	var half: float = _zone_width / 2.0
	var d: float = absf(p - _zone_center)
	if d <= half * PERFECT_FRACTION:
		return "perfect"
	if d <= half:
		return "good"
	if d <= half * NEAR_FRACTION:
		return "near"
	return "miss"


func _roll_make(quality: String) -> bool:
	if auto_quality != "":
		return quality == "perfect" or quality == "good"
	match quality:
		"perfect":
			return true
		"good":
			return _rng.randf() < 0.9
		"near":
			return _rng.randf() < 0.3
	return _rng.randf() < 0.04


func _flash_result(quality: String, made: bool) -> void:
	var text: String
	if made:
		text = {"perfect": "SWISH!", "good": "Good!", "near": "Rolled in!", "miss": "Lucky bounce!"}[quality]
	else:
		text = {"perfect": "Rimmed out", "good": "In and out", "near": "Just off", "miss": "Brick"}[quality]
	_flash.text = text
	_flash.add_theme_color_override("font_color", UIKit.GOLD if made else UIKit.BAD)
	_flash.modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(_flash, "modulate:a", 0.0, 0.3)


# =============================================================================
# 3D: player placement and the ball
# =============================================================================

func _place_player(spot: Vector3, hoop: Vector3) -> void:
	var player: CharacterBody3D = _loc.player
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(spot.x, player.global_position.y, spot.z)
	player.face_toward(Vector3(hoop.x, player.global_position.y, hoop.z))
	var away: Vector3 = Vector3(spot.x - hoop.x, 0, spot.z - hoop.z).normalized()
	var yaw: float = rad_to_deg(atan2(away.x, away.z))
	var mid: Vector3 = spot.lerp(Vector3(hoop.x, 0, hoop.z), 0.4) + Vector3(0, 1.7, 0)
	_loc.frame_camera(mid, Vector3(-14, yaw + 16.0, 0), 7.2, 0.45)


func _build_ball() -> void:
	_ball = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.42, 0.14)
	mat.roughness = 0.75
	sphere.material = mat
	_ball.mesh = sphere
	_ball.visible = false
	_loc.add_child(_ball)


func _animate_shot(hoop: Vector3, made: bool) -> void:
	var player: CharacterBody3D = _loc.player
	player.play_action("Jump", 1.6)
	var fast: bool = auto_quality != ""
	await _wait(0.05 if fast else 0.28)
	var to_hoop: Vector3 = Vector3(hoop.x, 0, hoop.z) - Vector3(player.global_position.x, 0, player.global_position.z)
	var start: Vector3 = player.global_position + to_hoop.normalized() * 0.3 + Vector3(0, 2.3, 0)
	var end: Vector3 = hoop
	if not made:
		var side: Vector3 = to_hoop.normalized().cross(Vector3.UP) * (0.32 if _rng.randf() < 0.5 else -0.32)
		end = hoop + side + Vector3(0, 0.08, 0)
	var peak: float = maxf(start.y, end.y) + 1.6
	_ball.visible = true
	var flight: float = 0.15 if fast else 0.85
	var tween: Tween = create_tween()
	tween.tween_method(func(t: float) -> void:
		var p: Vector3 = start.lerp(end, t)
		p.y = lerpf(lerpf(start.y, peak, t), lerpf(peak, end.y, t), t)
		_ball.global_position = p, 0.0, 1.0, flight)
	await tween.finished
	var drop: Tween = create_tween()
	if made:
		drop.tween_property(_ball, "global_position", hoop + Vector3(0, -2.9, 0), 0.1 if fast else 0.45)
	else:
		var away: Vector3 = (end - hoop).normalized() * 2.2
		drop.tween_property(_ball, "global_position", end + away + Vector3(0, -2.9, 0), 0.1 if fast else 0.55)
	await drop.finished
	_ball.visible = false


# =============================================================================
# UI
# =============================================================================

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	var top: VBoxContainer = VBoxContainer.new()
	top.anchor_left = 0.5
	top.anchor_right = 0.5
	top.offset_left = -360
	top.offset_right = 360
	top.offset_top = 22
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	_layer.add_child(top)
	_title = UIKit.label("", 30, UIKit.GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.1))
	_title.add_theme_constant_override("outline_size", 8)
	top.add_child(_title)
	_counter = UIKit.label("", 19)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.1))
	_counter.add_theme_constant_override("outline_size", 6)
	top.add_child(_counter)

	_flash = UIKit.label("", 46, UIKit.GOLD)
	_flash.anchor_left = 0.5
	_flash.anchor_right = 0.5
	_flash.anchor_top = 0.5
	_flash.anchor_bottom = 0.5
	_flash.offset_left = -300
	_flash.offset_right = 300
	_flash.offset_top = -150
	_flash.offset_bottom = -90
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.1))
	_flash.add_theme_constant_override("outline_size", 10)
	_flash.modulate.a = 0.0
	_layer.add_child(_flash)

	_meter = Control.new()
	_meter.anchor_left = 1.0
	_meter.anchor_right = 1.0
	_meter.anchor_top = 0.5
	_meter.anchor_bottom = 0.5
	_meter.offset_left = -300
	_meter.offset_right = -240
	_meter.offset_top = -190
	_meter.offset_bottom = 170
	_meter.draw.connect(_draw_meter)
	_layer.add_child(_meter)

	_shoot_button = UIKit.button("SHOOT", true, 120)
	_shoot_button.name = "ShootButton"
	_shoot_button.anchor_left = 1.0
	_shoot_button.anchor_right = 1.0
	_shoot_button.anchor_top = 1.0
	_shoot_button.anchor_bottom = 1.0
	_shoot_button.offset_left = -190
	_shoot_button.offset_right = -40
	_shoot_button.offset_top = -170
	_shoot_button.offset_bottom = -50
	_shoot_button.add_theme_font_size_override("font_size", 24)
	_shoot_button.button_down.connect(_release)
	_shoot_button.visible = false
	_layer.add_child(_shoot_button)

	if not UIKit.is_touch():
		var hint: Label = UIKit.label("Tap SHOOT or press Space when the marker is in the gold zone", 16, UIKit.TEXT)
		hint.anchor_left = 0.5
		hint.anchor_right = 0.5
		hint.anchor_top = 1.0
		hint.anchor_bottom = 1.0
		hint.offset_left = -360
		hint.offset_right = 360
		hint.offset_top = -46
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		hint.add_theme_constant_override("outline_size", 5)
		_layer.add_child(hint)


func _draw_meter() -> void:
	var size: Vector2 = _meter.size
	var rect: Rect2 = Rect2(Vector2(14, 0), Vector2(size.x - 28, size.y))
	_meter.draw_rect(rect.grow(6), Color(UIKit.NAVY_DEEP, 0.9))
	_meter.draw_rect(rect, Color(1, 1, 1, 0.1))
	# 0 at the bottom, 1 at the top.
	var zone_top: float = rect.end.y - (_zone_center + _zone_width / 2.0) * rect.size.y
	var zone_h: float = _zone_width * rect.size.y
	_meter.draw_rect(Rect2(rect.position.x, zone_top, rect.size.x, zone_h), Color(UIKit.GOLD, 0.55))
	var perfect_h: float = zone_h * PERFECT_FRACTION
	_meter.draw_rect(Rect2(rect.position.x, zone_top + (zone_h - perfect_h) / 2.0, rect.size.x, perfect_h),
		Color(1.0, 0.95, 0.7, 0.95))
	var y: float = rect.end.y - _position * rect.size.y
	_meter.draw_rect(Rect2(0, y - 3, size.x, 6), Color.WHITE)
	_meter.draw_rect(Rect2(0, y - 3, size.x, 6), Color(0, 0, 0, 0.6), false, 1.5)


func _marker_pos(marker_name: String, fallback: Vector3) -> Vector3:
	var marker: Node3D = _loc.get_node_or_null("Markers/" + marker_name)
	return marker.global_position if marker != null else fallback


func _wait(seconds: float) -> void:
	if auto_quality != "":
		seconds = minf(seconds, 0.05)
	await get_tree().create_timer(seconds).timeout
