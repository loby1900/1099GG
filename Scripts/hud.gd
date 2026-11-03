extends Control

# Optional dashboard widgets already used by the desktop HUD.
@onready var steering_wheel: CanvasItem = get_node_or_null("Wheel") as CanvasItem
@onready var gas_pedal: Range = get_node_or_null("Gas") as Range
@onready var brake_pedal: Range = get_node_or_null("Brakes") as Range

@export var force_mobile_controls: bool = false

const STEER_ACTION_LEFT := "ui_left"
const STEER_ACTION_RIGHT := "ui_right"
const ACCELERATE_ACTION := "ui_up"
const BRAKE_ACTION := "ui_down"
const GEAR_UP_ACTION := "shift_up"
const GEAR_DOWN_ACTION := "shift_down"

var _touch_controls_active := false
var _touch_roles: Dictionary = {}
var _action_holders: Dictionary = {}
var _steering_strength := 0.0
var _joystick_center := Vector2.ZERO
var _joystick_radius := 0.0
var _accelerate_center := Vector2.ZERO
var _brake_center := Vector2.ZERO
var _gear_up_center := Vector2.ZERO
var _gear_down_center := Vector2.ZERO
var _button_radius := 0.0


func _ready() -> void:
	_touch_controls_active = force_mobile_controls or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	if _touch_controls_active:
		set_process_input(true)
		queue_redraw()


func _process(_delta: float) -> void:
	if steering_wheel != null:
		var steering_input := Input.get_action_strength(STEER_ACTION_RIGHT) - Input.get_action_strength(STEER_ACTION_LEFT)
		steering_wheel.rotation_degrees = steering_input * 160.0
	if gas_pedal != null:
		gas_pedal.value = Input.get_action_strength(ACCELERATE_ACTION)
	if brake_pedal != null:
		brake_pedal.value = Input.get_action_strength(BRAKE_ACTION)


func _input(event: InputEvent) -> void:
	if not _touch_controls_active:
		return

	if event is InputEventScreenTouch:
		var touch := make_input_local(event) as InputEventScreenTouch
		if touch.pressed:
			_begin_touch(touch.index, touch.position)
		else:
			_end_touch(touch.index)
	elif event is InputEventScreenDrag:
		var drag := make_input_local(event) as InputEventScreenDrag
		if _touch_roles.get(drag.index, "") == "steer":
			_update_steering(drag.position)


func _layout_controls() -> void:
	var viewport_size := get_viewport_rect().size
	var control_size := size
	if control_size.x <= 0.0 or control_size.y <= 0.0:
		control_size = viewport_size
	var canvas_size := Vector2(min(control_size.x, viewport_size.x), min(control_size.y, viewport_size.y))
	var short_side := min(canvas_size.x, canvas_size.y)
	_joystick_center = Vector2(canvas_size.x * 0.17, canvas_size.y * 0.78)
	_joystick_radius = clampf(short_side * 0.115, 58.0, 112.0)
	_button_radius = clampf(short_side * 0.075, 44.0, 76.0)
	_accelerate_center = Vector2(canvas_size.x * 0.86, canvas_size.y * 0.73)
	_brake_center = Vector2(canvas_size.x * 0.86, canvas_size.y * 0.90)
	_gear_up_center = Vector2(canvas_size.x * 0.70, canvas_size.y * 0.72)
	_gear_down_center = Vector2(canvas_size.x * 0.70, canvas_size.y * 0.89)


func _begin_touch(index: int, position: Vector2) -> void:
	_layout_controls()
	if position.distance_to(_joystick_center) <= _joystick_radius * 1.45:
		_touch_roles[index] = "steer"
		_update_steering(position)
	elif position.distance_to(_accelerate_center) <= _button_radius * 1.35:
		_touch_roles[index] = ACCELERATE_ACTION
		_hold_action(ACCELERATE_ACTION)
	elif position.distance_to(_brake_center) <= _button_radius * 1.35:
		_touch_roles[index] = BRAKE_ACTION
		_hold_action(BRAKE_ACTION)
	elif position.distance_to(_gear_up_center) <= _button_radius * 0.72:
		_touch_roles[index] = GEAR_UP_ACTION
		_hold_action(GEAR_UP_ACTION)
	elif position.distance_to(_gear_down_center) <= _button_radius * 0.72:
		_touch_roles[index] = GEAR_DOWN_ACTION
		_hold_action(GEAR_DOWN_ACTION)
	queue_redraw()


func _end_touch(index: int) -> void:
	if not _touch_roles.has(index):
		return
	var role: String = _touch_roles[index]
	_touch_roles.erase(index)
	if role == "steer":
		_update_steering(Vector2.ZERO, true)
	else:
		_release_action(role)
	queue_redraw()


func _update_steering(position: Vector2, reset: bool = false) -> void:
	var previous := _steering_strength
	if reset:
		_steering_strength = 0.0
	else:
		var offset := position - _joystick_center
		_steering_strength = clampf(offset.x / _joystick_radius, -1.0, 1.0)
		if absf(_steering_strength) < 0.12:
			_steering_strength = 0.0

	if signf(previous) != signf(_steering_strength):
		Input.action_release(STEER_ACTION_LEFT)
		Input.action_release(STEER_ACTION_RIGHT)
	if _steering_strength < 0.0:
		Input.action_press(STEER_ACTION_LEFT, absf(_steering_strength))
		Input.action_release(STEER_ACTION_RIGHT)
	elif _steering_strength > 0.0:
		Input.action_press(STEER_ACTION_RIGHT, _steering_strength)
		Input.action_release(STEER_ACTION_LEFT)
	else:
		Input.action_release(STEER_ACTION_LEFT)
		Input.action_release(STEER_ACTION_RIGHT)
	queue_redraw()


func _hold_action(action: String) -> void:
	var holders: int = int(_action_holders.get(action, 0))
	_action_holders[action] = holders + 1
	if holders == 0:
		Input.action_press(action)


func _release_action(action: String) -> void:
	var holders: int = int(_action_holders.get(action, 0))
	if holders <= 1:
		_action_holders.erase(action)
		Input.action_release(action)
	else:
		_action_holders[action] = holders - 1


func _draw() -> void:
	if not _touch_controls_active:
		return
	_layout_controls()
	_draw_pad(_joystick_center, _joystick_radius, "STEER", Color(0.16, 0.48, 0.82, 0.52))
	var knob := _joystick_center + Vector2(_steering_strength * _joystick_radius * 0.58, 0.0)
	_draw_pad(knob, _joystick_radius * 0.40, "", Color(0.72, 0.84, 0.98, 0.72))
	_draw_pad(_accelerate_center, _button_radius, "GAS", Color(0.16, 0.68, 0.34, 0.66))
	_draw_pad(_brake_center, _button_radius, "BRAKE", Color(0.82, 0.22, 0.20, 0.66))
	_draw_pad(_gear_up_center, _button_radius * 0.66, "+", Color(0.94, 0.64, 0.16, 0.68))
	_draw_pad(_gear_down_center, _button_radius * 0.66, "-", Color(0.94, 0.64, 0.16, 0.68))


func _draw_pad(center: Vector2, radius: float, label: String, color: Color) -> void:
	draw_circle(center, radius, color)
	draw_arc(center, radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.8), 3.0, true)
	if not label.is_empty():
		var font := ThemeDB.fallback_font
		var font_size := maxi(16, int(radius * 0.34))
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, center + Vector2(-text_size.x * 0.5, font_size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
