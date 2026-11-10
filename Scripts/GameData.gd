extends Node
## Carries the player's choices between scenes (selected map/car) and the
## persisted gameplay preferences that need to be known as soon as a race
## scene loads, before any options menu is necessarily visited this run.

var selected_map: String = ""
var selected_car: String = ""

## "wheel" = the on-screen steering-wheel/joystick (analog, default).
## "dpad"  = classic arcade-style left/right arrow buttons (digital).
## Both schemes drive the same ui_left / ui_right actions underneath, so
## nothing else in the game needs to know which one is active.
var control_scheme: String = "wheel"

const CONTROL_SETTINGS_FILE := "user://control_settings.cfg"


func _ready() -> void:
	_load_control_scheme()


func set_control_scheme(scheme: String) -> void:
	if scheme != "wheel" and scheme != "dpad":
		return
	control_scheme = scheme
	var config := ConfigFile.new()
	config.set_value("controls", "scheme", scheme)
	config.save(CONTROL_SETTINGS_FILE)


func _load_control_scheme() -> void:
	var config := ConfigFile.new()
	if config.load(CONTROL_SETTINGS_FILE) == OK:
		var scheme = config.get_value("controls", "scheme", "wheel")
		if scheme == "wheel" or scheme == "dpad":
			control_scheme = scheme

