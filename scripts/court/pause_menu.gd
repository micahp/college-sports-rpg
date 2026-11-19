extends CanvasLayer
const CourtAudio = preload("res://scripts/court/court_audio.gd")
## Court pause menu. Uses the engine's pause (SceneTree.paused): this layer
## runs while paused (process_mode = Always in the scene), the game under
## it stops. Layout lives in pause_menu.tscn; this script only wires it.

@onready var _pause_button: Button = $PauseButton
@onready var _menu: PanelContainer = $Menu
@onready var _controls: PanelContainer = $Controls
@onready var _settings: PanelContainer = $Settings
@onready var _audio_slider: HSlider = $Settings/Col/AudioSlider


func _ready() -> void:
	for panel: PanelContainer in [_menu, _controls]:
		panel.add_theme_stylebox_override("panel", UIKit.panel_style(0.96))
	_pause_button.pressed.connect(_toggle)
	$Menu/Col/Resume.pressed.connect(_toggle)
	$Menu/Col/ControlsButton.pressed.connect(_show.bind(false, true))
	$Controls/Col/Back.pressed.connect(_show.bind(true, false))
	$Menu/Col/SettingsButton.pressed.connect(_show_settings)
	$Settings/Col/Back.pressed.connect(_show.bind(true, false))
	_audio_slider.value = CourtAudio.volume()
	_audio_slider.value_changed.connect(CourtAudio.set_volume)
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
	_settings.visible = false


func _show_settings() -> void:
	_menu.visible = false
	_controls.visible = false
	_settings.visible = true


func _exit_tree() -> void:
	get_tree().paused = false
