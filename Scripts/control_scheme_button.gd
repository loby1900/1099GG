extends Control
## Lets the player pick the on-screen steering control: the analog
## steering-wheel/joystick, or classic arcade-style left/right arrow
## buttons. Persistence lives centrally in GameData (so hud.gd can read the
## saved choice on its very first _ready(), even if this menu is never
## visited this run) -- this row just reflects and changes it.

@onready var option_button: OptionButton = $HBoxContainer/OptionButton

const SCHEME_OPTIONS := ["Steering Wheel", "Arrows (D-Pad)"]
const SCHEME_KEYS := ["wheel", "dpad"]


func _ready() -> void:
	for label in SCHEME_OPTIONS:
		option_button.add_item(label)
	var index: int = SCHEME_KEYS.find(GameData.control_scheme)
	option_button.selected = max(index, 0)
	option_button.item_selected.connect(_on_selected)


func _on_selected(index: int) -> void:
	if index >= 0 and index < SCHEME_KEYS.size():
		GameData.set_control_scheme(SCHEME_KEYS[index])
