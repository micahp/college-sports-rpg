extends CanvasLayer
## Court pause menu. Uses the engine's pause (SceneTree.paused): this layer
## runs while paused (process_mode = Always in the scene), the game under
## it stops. Layout lives in pause_menu.tscn; this script only wires it.

@onready var _pause_button: Button = $PauseButton
@onready var _menu: PanelContainer = $Menu
@onready var _controls: PanelContainer = $Controls


func _ready() -> void:
	for panel: PanelContainer in [_menu, _controls]:
		panel.add_theme_stylebox_override("panel", UIKit.panel_style(0.96))
	_pause_button.pressed.connect(_toggle)
	$Menu/Col/Resume.pressed.connect(_toggle)
	$Menu/Col/ControlsButton.pressed.connect(_show.bind(false, true))
	$Controls/Col/Back.pressed.connect(_show.bind(true, false))
	_show(false, false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	var paused: bool = not get_tree().paused
	get_tree().paused = paused
	_show(paused, false)


func _show(menu: bool, controls: bool) -> void:
	_menu.visible = menu
	_controls.visible = controls


func _exit_tree() -> void:
	get_tree().paused = false
