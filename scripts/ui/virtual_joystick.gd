extends Control
## On-screen analog stick for touch play. Always visible; mouse drags work too
## because the project emulates touch from mouse. Exposes `output` as a
## unit-clamped Vector2 the campus feeds to the player every frame.

const RADIUS: float = 64.0
const KNOB_RADIUS: float = 27.0

var output: Vector2 = Vector2.ZERO

var _touch_index: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # touches handled in _input


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and _touch_index == -1 and get_global_rect().grow(30).has_point(touch.position):
			_touch_index = touch.index
			_update_output(touch.position)
		elif not touch.pressed and touch.index == _touch_index:
			_touch_index = -1
			output = Vector2.ZERO
			queue_redraw()
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _touch_index:
		_update_output((event as InputEventScreenDrag).position)


func _update_output(screen_position: Vector2) -> void:
	var center: Vector2 = get_global_rect().get_center()
	output = ((screen_position - center) / RADIUS).limit_length(1.0)
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size / 2.0
	draw_circle(center, RADIUS, Color(0.05, 0.08, 0.14, 0.30))
	draw_arc(center, RADIUS, 0.0, TAU, 48, Color(0.92, 0.72, 0.3, 0.35), 2.0)
	draw_circle(center + output * (RADIUS - KNOB_RADIUS * 0.5), KNOB_RADIUS, Color(1, 1, 1, 0.42))
	draw_arc(center + output * (RADIUS - KNOB_RADIUS * 0.5), KNOB_RADIUS, 0.0, TAU, 32,
		Color(0.92, 0.72, 0.3, 0.5), 1.5)
