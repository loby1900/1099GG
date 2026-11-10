extends RigidBody3D
## Generic drivable car. One scene (Car.tscn) is shared by every vehicle in
## the game: set `car_type` (or let GameData.selected_car drive it through
## SelectCar.gd) and this script loads the right model, wheels, engine
## sound and top-speed table for that car at runtime. This replaces the old
## approach of baking a separate scene per car/map combination.

@onready var gear_label: Label = $CarInfo/MarginContainer/VBoxContainer/Gear
@onready var speed_label: Label = $CarInfo/MarginContainer/VBoxContainer/Speed
@onready var needle: Sprite2D = $CarInfo/MarginContainer/Sprite2D2
@onready var engine_sound: AudioStreamPlayer = $EngineSound
@onready var body_collision: CollisionShape3D = $BodyCollision
@onready var model_root: Node3D = $Model
@onready var wheels_root: Node3D = $Wheels
@onready var fl_wheel: RayCast3D = $Wheels/FL_Wheel
@onready var fr_wheel: RayCast3D = $Wheels/FR_Wheel
@onready var rl_wheel: RayCast3D = $Wheels/RL_Wheel
@onready var rr_wheel: RayCast3D = $Wheels/RR_Wheel
@onready var tail_light_l: OmniLight3D = $Lights/TailLightL
@onready var tail_light_r: OmniLight3D = $Lights/TailLightR

const TAIL_LIGHT_IDLE_ENERGY := 0.4
const TAIL_LIGHT_BRAKE_ENERGY := 3.2

const DEFAULT_CAR_TYPE := "Porsche"

const CAR_MODELS := {
	"Porsche": "res://cars/porsche.glb",
	"Dodge": "res://cars/Challenger.glb",
	"Supra": "res://cars/supra2.glb",
	"RX7": "res://cars/rx72.glb",
	"Mercedes": "res://cars/mercedes2.glb",
	"EVO": "res://cars/evo2.glb",
	"NSX": "res://cars/nsx2.glb",
	"F1": "res://cars/f12.glb",
	"BMW330i": "res://cars/bmw330i.glb",
	"BMWM4GT3": "res://cars/bmw_m4_gt3.glb",
}

const CAR_SOUNDS := {
	"Porsche": "res://SFX/porsche.wav",
	"Dodge": "res://SFX/Dodge.wav",
	"Supra": "res://SFX/Supra.wav",
	"RX7": "res://SFX/RX7.wav",
	"Mercedes": "res://SFX/Mercedes.wav",
	"EVO": "res://SFX/EVO.wav",
	"NSX": "res://SFX/nsx.wav",
	"F1": "res://SFX/F1.wav",
	"BMW330i": "res://SFX/BMW330i.wav",
	"BMWM4GT3": "res://SFX/BMWM4GT3.wav",
}

# Collision box: measured from each model's combined mesh AABB, shrunk a
# little so it sits just inside the bodywork instead of the outermost tips
# (mirrors, splitters) of the visual mesh.
const CAR_COLLISION := {
	"Porsche": {"size": Vector3(1.01, 0.62, 2.40), "center_y": 0.48},
	"Dodge": {"size": Vector3(1.19, 0.60, 2.84), "center_y": 0.51},
	"Supra": {"size": Vector3(1.11, 0.58, 2.71), "center_y": 0.50},
	"RX7": {"size": Vector3(1.06, 0.64, 2.64), "center_y": 0.48},
	"Mercedes": {"size": Vector3(1.10, 0.71, 2.81), "center_y": 0.53},
	"EVO": {"size": Vector3(1.10, 0.71, 2.72), "center_y": 0.57},
	"NSX": {"size": Vector3(1.10, 0.58, 2.71), "center_y": 0.50},
	"F1": {"size": Vector3(1.31, 0.50, 2.88), "center_y": 0.26},
	# Measured from the real glTF (Sketchfab, meters, before the import-scale
	# fix below) and scaled down to match this roster's established ~0.58x
	# "game scale" (every other car here sits at roughly half real-world size).
	"BMW330i": {"size": Vector3(1.14, 0.70, 2.60), "center_y": 0.69},
	"BMWM4GT3": {"size": Vector3(1.13, 0.75, 2.77), "center_y": 0.63},
}

# Half-track-width / half-wheelbase used to place the 4 wheel RayCasts,
# proportional to each car's own footprint so wheels roughly line up with
# the fenders despite every car sharing the same generic rim meshes.
const CAR_WHEEL_LAYOUT := {
	"Porsche": {"half_width": 0.46, "half_axle": 0.52},
	"Dodge": {"half_width": 0.54, "half_axle": 0.62},
	"Supra": {"half_width": 0.51, "half_axle": 0.59},
	"RX7": {"half_width": 0.48, "half_axle": 0.57},
	"Mercedes": {"half_width": 0.50, "half_axle": 0.61},
	"EVO": {"half_width": 0.50, "half_axle": 0.59},
	"NSX": {"half_width": 0.50, "half_axle": 0.59},
	"F1": {"half_width": 0.68, "half_axle": 0.62},
	"BMW330i": {"half_width": 0.45, "half_axle": 0.83},
	"BMWM4GT3": {"half_width": 0.49, "half_axle": 0.84},
}

# The two BMW models are raw Sketchfab downloads: real-world meters at a
# 100x-too-small export scale, with their own wheels baked into the mesh
# (hidden below so the shared generic rim system in WHEEL_MESHES can drive
# and steer instead) and an origin centered on neither the wheelbase nor
# this project's established car scale. CAR_MODEL_FIXUP corrects all three
# (scale, recentering, ride height) for just these two; every other car
# keeps the identity transform it already had.
const CAR_MODEL_FIXUP := {
	"BMW330i": {
		"scale": 58.0,
		# Y measured directly in-engine: with the old +0.215 the baked (hidden)
		# wheel's own ground-contact point sat at world Y=0.4228 while the
		# live generic wheel sits at Y~0.0003 on flat ground -- the model was
		# floating ~42cm above its wheels. +0.215 was double-counting the
		# ride height RigidBody already applies via its own world position;
		# this value instead zeroes that out so the fender sits where the
		# baked wheel (and hence the generic wheel inside it) actually is.
		"offset": Vector3(0, -0.2074, -0.074),
		"rotation_y_deg": 0.0,
		"hide_node": "SK_Tyre_101_001",  # Godot's glTF importer swaps "." for "_" in node names.
	},
	"BMWM4GT3": {
		"scale": 58.0,
		"offset": Vector3(0, -0.2010, -0.068),
		"rotation_y_deg": 0.0,
		"hide_node": "Wheel1A_3D_00",
	},
}

const WHEEL_MESHES := {
	"front_left": "res://trying/FL.glb",
	"front_right": "res://trying/FR.glb",
	"rear_left": "res://trying/RL.glb",
	"rear_right": "res://trying/RR.glb",
}
const F1_WHEEL_MESHES := {
	"front_left": "res://trying/F1L.glb",
	"front_right": "res://trying/F1R.glb",
	"rear_left": "res://trying/F1L.glb",
	"rear_right": "res://trying/F1R.glb",
}

@export var car_type: String = DEFAULT_CAR_TYPE:
	set(value):
		car_type = value
		if is_inside_tree():
			_apply_car_type()

@export var suspension_rest_dist: float = 0.6
@export var spring_strength: float = 12
@export var spring_damper: float = 6.0
@export var wheel_radius: float = 0.22

@export var debug: bool = false
@export var engine_power: float = 6
@export var brake_force: float = 14.0

var accel_input

@export var steering_angle: float = 25
@export var front_tire_grip: float = 4
@export var rear_tire_grip: float = 1.8

var air_density: float = 1.225  # kg/m^3
@export var frontal_area: float = 2.2  # m^2
@export var rolling_resistance_factor: float = 0.015


var current_rpm: float = 0
var current_gear: int = 1
var max_rpm: float = 7000
var gear_ratios: Array = [0, -0.8, 1, 1.1, 1.3, 1.5, 1.5]
var max_speeds_per_gear: Array = [0, -10, 48, 72, 103, 132, 158]

var shift_up_rpm: float = 2000
var shift_down_rpm: float = 0
var steering_input

var in_neutral: bool = true
var in_reverse: bool = false

# Top speed per gear, by car type.
var car_max_speeds = {
	"Porsche": [0, -20, 45, 75, 110, 145, 185],  # Porsche 911
	"Dodge": [0, -20, 40, 65, 95, 125, 165],     # Dodge Challenger
	"Supra": [0, -20, 50, 80, 115, 150, 180],    # Toyota Supra MK4
	"RX7": [0, -20, 48, 78, 110, 140, 170],      # Mazda RX7 Spirit R
	"Mercedes": [0, -20, 47, 75, 105, 135, 165], # Mercedes 190Evo2
	"EVO": [0, -20, 45, 70, 100, 130, 160],      # Mitsubishi Lancer Evo
	"NSX": [0, -20, 46, 73, 105, 140, 175],      # Honda NSX
	"F1": [0, -30, 100, 150, 200, 250, 300],     # Formula car
	"BMW330i": [0, -20, 48, 78, 112, 148, 182],  # BMW 330i xDrive
	"BMWM4GT3": [0, -25, 70, 120, 170, 220, 270], # BMW M4 GT3 EVO (race car)
}

var idle_rpm: float = 1000  # Idle RPM
var rpm_increase_factor: float = 100


func _ready():
	_apply_car_type()


func _apply_car_type() -> void:
	if not is_node_ready():
		await ready

	var resolved_type := car_type
	if not CAR_MODELS.has(resolved_type):
		push_warning("Unknown car type '%s', falling back to %s" % [car_type, DEFAULT_CAR_TYPE])
		resolved_type = DEFAULT_CAR_TYPE

	max_speeds_per_gear = car_max_speeds.get(resolved_type, max_speeds_per_gear)

	_load_model(resolved_type)
	_build_collision(resolved_type)
	_build_wheels(resolved_type)
	_load_engine_sound(resolved_type)


func _load_model(resolved_type: String) -> void:
	for child in model_root.get_children():
		child.queue_free()
	var packed: PackedScene = load(CAR_MODELS[resolved_type])
	if not packed:
		return
	var instance: Node3D = packed.instantiate()
	model_root.add_child(instance)

	var fixup = CAR_MODEL_FIXUP.get(resolved_type)
	if fixup == null:
		return

	instance.scale = Vector3.ONE * fixup["scale"]
	instance.position = fixup["offset"]
	instance.rotation_degrees.y = fixup["rotation_y_deg"]

	var baked_wheels := _find_descendant_by_name(instance, fixup["hide_node"])
	if baked_wheels:
		baked_wheels.visible = false
	else:
		push_warning("CAR_MODEL_FIXUP: '%s' not found in %s, baked-in wheels may double up with the generic rims" % [fixup["hide_node"], resolved_type])


func _find_descendant_by_name(node: Node, target_name: String) -> Node:
	for child in node.get_children():
		if child.name == target_name:
			return child
		var found := _find_descendant_by_name(child, target_name)
		if found:
			return found
	return null


func _build_collision(resolved_type: String) -> void:
	var data = CAR_COLLISION.get(resolved_type, CAR_COLLISION[DEFAULT_CAR_TYPE])
	var shape := BoxShape3D.new()
	shape.size = data["size"]
	body_collision.shape = shape
	body_collision.position = Vector3(0, data["center_y"], 0)


func _build_wheels(resolved_type: String) -> void:
	var layout = CAR_WHEEL_LAYOUT.get(resolved_type, CAR_WHEEL_LAYOUT[DEFAULT_CAR_TYPE])
	var meshes = F1_WHEEL_MESHES if resolved_type == "F1" else WHEEL_MESHES
	var hw: float = layout["half_width"]
	var ha: float = layout["half_axle"]

	_place_wheel(fl_wheel, Vector3(-hw, 0.4, ha), meshes["front_left"])
	_place_wheel(fr_wheel, Vector3(hw, 0.4, ha), meshes["front_right"])
	_place_wheel(rl_wheel, Vector3(-hw, 0.4, -ha), meshes["rear_left"])
	_place_wheel(rr_wheel, Vector3(hw, 0.4, -ha), meshes["rear_right"])


func _place_wheel(raycast: RayCast3D, local_pos: Vector3, mesh_path: String) -> void:
	raycast.position = local_pos
	raycast.target_position = Vector3(0, -(suspension_rest_dist + wheel_radius + 0.3), 0)
	for child in raycast.get_children():
		child.queue_free()
	var packed: PackedScene = load(mesh_path)
	if packed:
		raycast.add_child(packed.instantiate())


func _load_engine_sound(resolved_type: String) -> void:
	var sound_path: String = CAR_SOUNDS.get(resolved_type, CAR_SOUNDS[DEFAULT_CAR_TYPE])
	if ResourceLoader.exists(sound_path):
		engine_sound.stream = load(sound_path)
	engine_sound.play()


func _physics_process(delta):
	handle_input()

	accel_input = Input.get_action_strength("ui_up")
	var brake_input: float = Input.get_action_strength("ui_down")
	steering_input = Input.get_axis("ui_right", "ui_left")
	var steering_rotation = steering_input * steering_angle

	if in_reverse and accel_input > 0:
		accel_input = -1 * accel_input
	elif current_gear > 0 and accel_input < 0:
		# When in any forward gear and the acceleration input is negative (e.g., the player is trying to reverse), ignore this input.
		accel_input = 0

	if brake_input > 0.0 and linear_velocity.length() > 0.05:
		apply_central_force(-linear_velocity.normalized() * brake_input * brake_force)

	# Brake lights: dim running-light glow normally, bright red the instant
	# the brake is pressed -- same idle/brake split real tail lights use.
	var tail_energy: float = TAIL_LIGHT_BRAKE_ENERGY if brake_input > 0.0 else TAIL_LIGHT_IDLE_ENERGY
	tail_light_l.light_energy = tail_energy
	tail_light_r.light_energy = tail_energy

	if steering_rotation != 0:
		# Apply steering rotation
		var angle = clamp(fl_wheel.rotation.y + steering_rotation, -steering_angle, steering_angle)
		var new_rotation = angle * delta

		fl_wheel.rotation.y = lerp(fl_wheel.rotation.y, new_rotation, 0.3)
		fr_wheel.rotation.y = lerp(fr_wheel.rotation.y, new_rotation, 0.3)

		adjust_rear_grip_dynamically(steering_input, accel_input)
	else:
		fl_wheel.rotation.y = move_toward(fl_wheel.rotation.y, 0.0, 0.2)
		fr_wheel.rotation.y = move_toward(fr_wheel.rotation.y, 0.0, 0.2)
		restore_rear_grip(delta)

	var speed_kmh = linear_velocity.length() * 3.6

	# Prevent acceleration if the maximum speed for the current gear is reached
	if speed_kmh >= max_speeds_per_gear[current_gear]:
		accel_input = min(accel_input, 0)  # Allow deceleration or maintaining speed, but not acceleration
	update_rpm(delta)
	update_needle()
	update_engine_sound()
	speed_label.text = "Speed: %d km/h" % int(speed_kmh)
	# Convert gear to a string that makes sense (e.g., R for reverse, N for neutral)
	var gear_text = "N" if in_neutral else ("R" if in_reverse else str(current_gear - 1))
	gear_label.text = "Gear: %s" % gear_text


func update_needle():
	# Normalize the RPM value to a 0-1 range where 0 is 1000 RPM and 1 is 7000 RPM
	var rpm_normalized = (current_rpm - 1000) / (7000 - 1000)
	# Calculate the needle's angle within the range (from 33 degrees to 230 degrees)
	var needle_angle = lerp(33, 230, rpm_normalized)
	needle.rotation_degrees = needle_angle


func update_rpm(delta):
	var wheel_circumference = 2 * PI * wheel_radius
	# Calculate speed_kmh inside this function
	var speed_kmh = linear_velocity.length() * 3.6
	var vehicle_speed = linear_velocity.dot(transform.basis.z.normalized())  # project velocity onto forward direction
	var wheel_rpm = (vehicle_speed / wheel_circumference) * 60  # convert m/s to RPM

	# Use gear ratio to calculate engine RPM based on wheel RPM, accounting for neutral and reverse
	var gear_ratio = gear_ratios[current_gear] if current_gear > 0 else 1
	var engine_rpm = wheel_rpm * gear_ratio

	# If the vehicle is in neutral and the engine RPM is below idle, set it to idle RPM
	if in_neutral and engine_rpm < idle_rpm:
		engine_rpm = idle_rpm

	# Interpolate towards the target RPM based on the current gear and speed
	var target_rpm = engine_rpm
	if current_gear > 0 and current_gear < max_speeds_per_gear.size():
		var max_speed_for_gear = max_speeds_per_gear[current_gear]
		target_rpm = map_range_clamped(speed_kmh, 0, max_speed_for_gear, idle_rpm, max_rpm)

	current_rpm = lerp(current_rpm, target_rpm, rpm_increase_factor * delta)
	current_rpm = clamp(current_rpm, idle_rpm, max_rpm)


func update_engine_sound():
	var rpm_normalized = (current_rpm - idle_rpm) / (max_rpm - idle_rpm)
	engine_sound.pitch_scale = remap(rpm_normalized, 0.0, 1.0, 0.75, 1.5)


func get_torque_at_rpm(rpm):
	var max_torque = 280
	var peak_rpm = 5700
	var torque = max_torque * rpm / peak_rpm
	return clamp(torque, 0, max_torque)


func get_current_speed_limit() -> float:
	if in_reverse:
		return -max_speeds_per_gear[1]
	else:
		return max_speeds_per_gear[abs(current_gear)]


func get_engine_torque(rpm):
	return engine_power


func adjust_rear_grip_dynamically(steering_input, accel_input):
	var oversteer_factor = max(abs(steering_input), abs(accel_input))
	var grip_reduction = 1.0 - (oversteer_factor * 0.1)
	# Smoothly interpolate the rear tire grip towards the reduced grip
	rear_tire_grip = lerp(rear_tire_grip, grip_reduction, 0.1)


func restore_rear_grip(delta):
	# Restore rear tire grip when not steering, at a dynamic rate based on current grip
	var restore_rate = 0.05 + max(0.0, (2.0 - rear_tire_grip) * 2)
	rear_tire_grip = lerp(rear_tire_grip, 2.0, restore_rate * delta)


func shift_up():
	if in_reverse:
		in_reverse = false
		in_neutral = true
		current_gear = 0
	elif in_neutral:
		in_neutral = false
		current_gear = 2  # First gear is at index 2
	elif current_gear < gear_ratios.size() - 1:
		current_gear += 1
	update_gear_label()


func shift_down():
	if current_gear == 2 and linear_velocity.length() * 3.6 < 5:
		in_neutral = true
		current_gear = 0
	elif current_gear > 2:
		current_gear -= 1
	elif in_neutral:
		in_neutral = false
		in_reverse = true
		current_gear = 1  # Reverse gear is at index 1
	update_gear_label()


func update_gear_label():
	if in_neutral:
		gear_label.text = "Gear: N"
	elif in_reverse:
		gear_label.text = "Gear: R"
	else:
		gear_label.text = "Gear: " + str(current_gear - 1)


func handle_input():
	if Input.is_action_just_pressed("shift_up"):
		shift_up()
	elif Input.is_action_just_pressed("shift_down"):
		shift_down()


func map_range_clamped(value, from_min, from_max, to_min, to_max):
	var from_range = from_max - from_min
	var to_range = to_max - to_min
	var scaled_value = (value - from_min) / from_range if from_range else 0
	return clamp(scaled_value * to_range + to_min, to_min, to_max)
