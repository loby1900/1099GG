extends Control
## Driving HUD. Shows the steering-wheel / gas / brake indicators on every
## platform, and additionally shows the touch driving controls (steering
## joystick, pedals, gear and pause buttons) on phones/tablets or whenever
## force_touch_controls is turned on for testing on desktop.

@export var force_touch_controls: bool = false

@onready var touch_controls: Control = $TouchControls
@onready var wheel_indicator: TextureRect = $Dash/WheelIndicator
@onready var gas_bar: ProgressBar = $Dash/GasBar
@onready var brake_bar: ProgressBar = $Dash/BrakeBar
@onready var pause_button: TouchScreenButton = $TouchControls/PauseAnchor/PauseButton
@onready var steer_joystick: Control = $TouchControls/SteerJoystick
@onready var steer_dpad: Control = $TouchControls/SteerDPad


func _ready() -> void:
	touch_controls.visible = force_touch_controls or TouchInputRouter.wants_touch_controls()
	pause_button.pressed.connect(_on_pause_pressed)
	_apply_control_scheme()


## Shows whichever steering control (analog wheel/joystick or digital
## arrow D-pad) the player picked in Options -> Controls. Both drive the
## same ui_left/ui_right actions, so nothing else needs to change.
func _apply_control_scheme() -> void:
	var use_dpad: bool = GameData.control_scheme == "dpad"
	steer_joystick.visible = not use_dpad
	steer_dpad.visible = use_dpad


func _process(_delta: float) -> void:
	var steer: float = Input.get_axis("ui_right", "ui_left")
	wheel_indicator.rotation_degrees = -steer * 35.0
	gas_bar.value = Input.get_action_strength("ui_up") * 100.0
	brake_bar.value = Input.get_action_strength("ui_down") * 100.0


func _on_pause_pressed() -> void:
	var menus := get_tree().get_nodes_in_group("pause_menu")
	if menus.size() > 0:
		menus[0].toggle_pause()
