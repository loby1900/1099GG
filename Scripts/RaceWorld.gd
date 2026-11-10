extends Node3D
## Generic race-map bootstrapper. Every map scene (world.tscn, world_2.tscn,
## world_3.tscn, world_4.tscn) uses this same script and just supplies
## different @export values (waypoints, colors, scenery theme) - the sky,
## ground, road, guardrails, checkpoints, scenery, car and camera are all
## built here at runtime instead of being hand-placed per map.
##
## This replaces the old approach of hand-authoring a full node tree (and a
## separate baked scene per car/map combination) for every track.

enum SceneryTheme { FOREST, DESERT, CANYON, NIGHT, NONE }

@export_group("Identity")
@export var map_id: String = ""  # "" = no lap timer (freeroam map)

@export_group("Track")
@export var waypoints: Array[Vector3] = []
@export var track_width: float = 11.0
@export var road_color: Color = Color(0.16, 0.16, 0.18)

@export_group("Environment")
@export var scenery_theme: SceneryTheme = SceneryTheme.FOREST
@export var sky_top_color: Color = Color(0.3, 0.55, 0.95)
@export var sky_horizon_color: Color = Color(0.75, 0.82, 0.9)
@export var ground_color: Color = Color(0.2, 0.45, 0.18)
@export var ground_half_extents: Vector2 = Vector2(140, 140)
@export var sun_energy: float = 1.1
@export var sun_color: Color = Color(1.0, 0.97, 0.9)
@export var sun_basis_degrees: Vector3 = Vector3(-50, -30, 0)
@export var fog_color: Color = Color(0.7, 0.78, 0.85)
@export var fog_density: float = 0.0015

var _car: Node = null
var _track_path: Array = []


func _ready() -> void:
	_setup_environment()
	_setup_ground()
	var track_data = _setup_track()
	_setup_scenery(track_data["path"])
	_setup_car(track_data["spawn_transform"])
	_setup_checkpoints(track_data["checkpoints"])


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY

	var sky_shader: Shader = load("res://Shaders/sky.gdshader")
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = sky_shader
	sky_mat.set_shader_parameter("skyColor", sky_top_color)
	sky_mat.set_shader_parameter("horizonColor", sky_horizon_color)
	# Ground tone the new sky shader fades to when a steep camera angle
	# peeks below the horizon line, so it blends with this map's own
	# ground_color instead of repeating the sky gradient upside down.
	sky_mat.set_shader_parameter("groundColor", ground_color.lerp(Color.BLACK, 0.25))

	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.fog_enabled = true
	env.fog_light_color = fog_color
	env.fog_density = fog_density
	env.fog_sun_scatter = 0.08  # faint hazy brightening toward the sun -- cheap, renderer-agnostic
	# fog_sky_affect defaults to 1.0, which -- verified in-engine -- paints the
	# *entire* sky dome toward fog_color, flattening the new gradient/sun disk
	# into a near-solid pale wash regardless of the sky shader underneath.
	# Ground-level distance haze is still what fog_density/fog_color are for;
	# the sky itself should stay untouched by it.
	env.fog_sky_affect = 0.0

	# Filmic color response instead of the default hard-clipping Linear
	# tonemap, plus a light glow/bloom pass -- both run fine on the Mobile
	# renderer (unlike SSAO/SSR/SDFGI, which it doesn't support at all).
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.04

	# Deliberately subtle: this is a large-area sky dome plus bright metal
	# specular highlights, not a handful of small point-lights, so a strong
	# multi-level glow here washes a big fraction of the screen to white
	# (verified -- an earlier, stronger pass did exactly that). Threshold
	# stays safely above the sky gradient's own peak (<1.0 per channel) so
	# only the sun disk, chrome specular and the night map's lamp bulbs
	# actually bloom.
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(2, 0.15)
	env.set_glow_level(3, 0.25)
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.15

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.light_energy = sun_energy
	sun.light_color = sun_color
	sun.rotation_degrees = sun_basis_degrees
	sun.shadow_enabled = true
	# Soften shadow edges and push the bias out a touch so the (fairly low
	# triangle-count) car and prop meshes don't self-shadow/acne at
	# distance -- shadow_enabled alone leaves Godot's hard-edged defaults.
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 140.0
	add_child(sun)


func _setup_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"

	var shape := BoxShape3D.new()
	shape.size = Vector3(ground_half_extents.x * 2.0, 2.0, ground_half_extents.y * 2.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0, -1.0, 0)
	body.add_child(collision)

	var mesh := BoxMesh.new()
	mesh.size = shape.size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ground_color
	mat.roughness = 1.0
	mesh.material = mat

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = Vector3(0, -1.0, 0)
	body.add_child(mi)

	add_child(body)


func _setup_track() -> Dictionary:
	if waypoints.size() < 3:
		push_warning("RaceWorld: fewer than 3 waypoints, skipping track generation")
		return {"path": [], "checkpoints": [], "spawn_transform": Transform3D()}

	var data = TrackBuilder.build(waypoints, track_width, road_color)
	var road: MeshInstance3D = data["road"]
	road.position.y = 0.03
	add_child(road)
	add_child(data["rails"])

	_track_path = data["path"]
	return data


func _setup_scenery(path: Array) -> void:
	if scenery_theme == SceneryTheme.NONE:
		return

	match scenery_theme:
		SceneryTheme.FOREST:
			_add_scatter(PropScatter.PropType.TREE, 140, path, 9.0, 1)
			_add_scatter(PropScatter.PropType.ROCK, 30, path, 8.0, 2)
		SceneryTheme.DESERT:
			_add_scatter(PropScatter.PropType.CACTUS, 70, path, 8.0, 3)
			_add_scatter(PropScatter.PropType.ROCK, 50, path, 8.0, 4)
		SceneryTheme.CANYON:
			_add_scatter(PropScatter.PropType.ROCK, 90, path, 7.0, 5)
		SceneryTheme.NIGHT:
			_add_scatter(PropScatter.PropType.ROCK, 40, path, 8.0, 6)
			_setup_night_lighting(path)


func _setup_night_lighting(path: Array) -> void:
	## Lines the track with alternating lamp posts so the night map isn't
	## pitch black outside the headlight cone - a plain MultiMesh can't carry
	## a light per instance, so these are placed as real (sparse) nodes.
	if path.is_empty():
		return
	var spacing := 22.0
	var traveled := 0.0
	var last_pos: Vector3 = path[0]
	var side := 1.0
	for i in range(1, path.size()):
		var pos: Vector3 = path[i]
		traveled += last_pos.distance_to(pos)
		last_pos = pos
		if traveled >= spacing:
			traveled = 0.0
			side *= -1.0
			var dir: Vector3 = (pos - path[max(i - 2, 0)]).normalized()
			var normal := Vector3(-dir.z, 0, dir.x)
			var lamp_pos := pos + normal * (track_width * 0.5 + 2.2) * side
			_add_lamp_post(lamp_pos)


func _add_lamp_post(pos: Vector3) -> void:
	var lamp := Node3D.new()
	lamp.position = pos

	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.07
	pole_mesh.bottom_radius = 0.09
	pole_mesh.height = 4.0
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.08, 0.08, 0.1)
	pole_mesh.material = pole_mat
	pole.mesh = pole_mesh
	pole.position.y = 2.0
	lamp.add_child(pole)

	var bulb := MeshInstance3D.new()
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.22
	bulb_mesh.height = 0.44
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.albedo_color = Color(1.0, 0.92, 0.7)
	bulb_mat.emission_enabled = true
	bulb_mat.emission = Color(1.0, 0.85, 0.55)
	bulb_mat.emission_energy_multiplier = 3.0
	bulb_mesh.material = bulb_mat
	bulb.mesh = bulb_mesh
	bulb.position.y = 4.05
	lamp.add_child(bulb)

	var light := OmniLight3D.new()
	light.position.y = 4.0
	light.light_color = Color(1.0, 0.88, 0.65)
	light.light_energy = 2.2
	light.omni_range = 14.0
	light.shadow_enabled = false
	lamp.add_child(light)

	add_child(lamp)


func _add_scatter(prop_type: int, count: int, path: Array, keep_out: float, seed_value: int) -> void:
	var scatter := PropScatter.new()
	scatter.prop_type = prop_type
	scatter.area_half_extents = ground_half_extents * 0.9
	scatter.count = count
	scatter.track_path = path
	scatter.keep_out_radius = keep_out
	scatter.rng_seed = seed_value
	add_child(scatter)


func _setup_car(spawn_transform: Transform3D) -> void:
	var car_scene: PackedScene = load("res://Scenes/Car.tscn")
	_car = car_scene.instantiate()
	_car.name = "Car"
	_car.car_type = GameData.selected_car if GameData.selected_car != "" else "Porsche"
	add_child(_car)
	_car.global_transform = spawn_transform

	var pivot_scene: PackedScene = load("res://Scenes/pivot.tscn")
	var pivot = pivot_scene.instantiate()
	# The car's engine drives it toward local -Z (see wheel.gd's
	# acceleration()), so "behind the car" for a chase camera is +Z, not -Z.
	pivot.position = Vector3(0, 2.6, 6.2)
	_car.add_child(pivot)


func _setup_checkpoints(checkpoints: Array) -> void:
	if checkpoints.is_empty():
		return
	for area in checkpoints:
		add_child(area)

	if map_id == "":
		return  # Freeroam map: no lap timer.

	var lap_timer = get_node_or_null("LapTimer")
	if lap_timer == null:
		push_warning("RaceWorld: map_id set but no LapTimer child found")
		return
	lap_timer.map_id = map_id

	checkpoints[0].body_entered.connect(lap_timer._on_checkpoint_sector_1_body_entered)
	checkpoints[1].body_entered.connect(lap_timer._on_checkpoint_sector_2_body_entered)
	checkpoints[2].body_entered.connect(lap_timer._on_checkpoint_sector_3_body_entered)
