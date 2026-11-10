extends Control
## On-screen analog steering stick. Fixed position (doesn't "float" to where
## the finger lands) so it's always where the driver expects it. Drives the
## existing ui_left / ui_right actions, exactly as the keyboard does, so
## car.gd needs no special-casing for touch.

@export var max_radius: float = 90.0
@export var deadzone: float = 0.08
@export var return_speed: float = 14.0

var _active: bool = false
var _pointer_id: int = -2  # -1 = mouse, >= 0 = a real touch index, -2 = none
var _knob_offset: Vector2 = Vector2.ZERO
var _center: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_center = size / 2.0
	resized.connect(func(): _center = size / 2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_try_start(event.index, event.position)
		elif event.index == _pointer_id:
			_stop()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == _pointer_id:
			_update_knob(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_start(-1, event.position)
		elif _pointer_id == -1:
			_stop()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _pointer_id == -1:
			_update_knob(event.position)
		get_viewport().set_input_as_handled()


func _try_start(id: int, local_pos: Vector2) -> void:
	if _active:
		return
	_active = true
	_pointer_id = id
	if id >= 0:
		TouchInputRouter.claim(id)
	_update_knob(local_pos)


func _stop() -> void:
	if _pointer_id >= 0:
		TouchInputRouter.release(_pointer_id)
	_active = false
	_pointer_id = -2
	Input.action_release("ui_left")
	Input.action_release("ui_right")


func _update_knob(local_pos: Vector2) -> void:
	var offset: Vector2 = local_pos - _center
	if offset.length() > max_radius:
		offset = offset.normalized() * max_radius
	_knob_offset = offset
	_apply_steering()


func _apply_steering() -> void:
	var x: float = _knob_offset.x / max_radius
	if absf(x) < deadzone:
		Input.action_release("ui_left")
		Input.action_release("ui_right")
	elif x < 0.0:
		Input.action_press("ui_left", clampf(-x, 0.0, 1.0))
		Input.action_release("ui_right")
	else:
		Input.action_press("ui_right", clampf(x, 0.0, 1.0))
		Input.action_release("ui_left")


func _process(delta: float) -> void:
	if not _active:
		_knob_offset = _knob_offset.move_toward(Vector2.ZERO, max_radius * return_speed * delta / 10.0)
	queue_redraw()


func _draw() -> void:
	var base_color := Color(0.33, 0.78, 1.0, 0.22 if not _active else 0.34)
	draw_circle(_center, max_radius, base_color)
	draw_arc(_center, max_radius, 0, TAU, 48, Color(1, 1, 1, 0.5), 3.0, true)
	var knob_pos: Vector2 = _center + _knob_offset
	draw_circle(knob_pos, max_radius * 0.42, Color(0.9, 0.95, 1.0, 0.85))
	draw_arc(knob_pos, max_radius * 0.42, 0, TAU, 32, Color(0.2, 0.5, 0.65, 0.9), 2.0, true)
