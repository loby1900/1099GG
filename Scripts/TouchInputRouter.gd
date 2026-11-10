extends Node
## Autoload singleton.
##
## Coordinates touch input between the on-screen driving HUD (joystick,
## pedals, gear/pause buttons) and the free camera-orbit drag in Pivot.gd.
## A touch "claimed" here (because it landed on a HUD control) must not also
## be interpreted as a camera-drag gesture, and vice versa.

var _claimed_touches: Dictionary = {}


func claim(index: int) -> void:
	_claimed_touches[index] = true


func release(index: int) -> void:
	_claimed_touches.erase(index)


func is_claimed(index: int) -> bool:
	return _claimed_touches.has(index)


## True on devices that should default to showing the touch driving HUD.
static func wants_touch_controls() -> bool:
	if DisplayServer.is_touchscreen_available():
		return true
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
