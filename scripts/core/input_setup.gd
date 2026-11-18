extends Node
## Registers input actions in code so project.godot never carries fragile
## serialized InputEventKey blocks. Autoloaded before any gameplay scene.
## Every action has keyboard and gamepad bindings; gameplay code reads
## actions only, never raw keys. Gamepad layout follows the NBA 2K defaults
## (X/Square shoot, A/Cross pass, LB/L1 pick, RT/R2 sprint).


func _ready() -> void:
	# Keyboard movement stays keyboard-only so a controller (or a device the
	# browser reports as one) can never cancel or override the keys.
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("move_up", [KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	_add_action("pad_left", [], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_add_action("pad_right", [], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_add_action("pad_up", [], [JOY_BUTTON_DPAD_UP], JOY_AXIS_LEFT_Y, -1.0)
	_add_action("pad_down", [], [JOY_BUTTON_DPAD_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_add_action("interact", [KEY_E, KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A])
	_add_action("shoot", [KEY_SPACE, KEY_E, KEY_ENTER], [JOY_BUTTON_X])
	_add_action("pass", [KEY_F, KEY_Q], [JOY_BUTTON_A])
	_add_action("pick", [KEY_C, KEY_R], [JOY_BUTTON_LEFT_SHOULDER])
	_add_action("sprint", [KEY_SHIFT], [], JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])


func _add_action(action: String, keys: Array, buttons: Array = [], axis: int = -1, axis_value: float = 0.0) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	for key: Key in keys:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
	for button: JoyButton in buttons:
		var jb: InputEventJoypadButton = InputEventJoypadButton.new()
		jb.device = -1  # any controller
		jb.button_index = button
		InputMap.action_add_event(action, jb)
	if axis >= 0:
		var jm: InputEventJoypadMotion = InputEventJoypadMotion.new()
		jm.device = -1
		jm.axis = axis as JoyAxis
		jm.axis_value = axis_value
		InputMap.action_add_event(action, jm)
