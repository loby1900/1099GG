class_name PropScatter
extends MultiMeshInstance3D
## Scatters a procedural prop (tree / rock / cactus) across a square area,
## skipping anywhere too close to the track centerline, and adds a static
## collider per instance so the car can crash into them.
##
## No external model files are needed - each prop is a tiny hand-built
## mesh out of primitives, which keeps the whole map self-contained.

enum PropType { TREE, ROCK, CACTUS }

@export var prop_type: PropType = PropType.TREE
@export var area_half_extents: Vector2 = Vector2(90, 90)
@export var count: int = 60
@export var track_path: Array = []  # Array[Vector3], the smoothed track centerline
@export var keep_out_radius: float = 9.0
@export var rng_seed: int = 1


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _build_prop_mesh()

	var placed: Array = []
	var attempts = 0
	while placed.size() < count and attempts < count * 20:
		attempts += 1
		var x = rng.randf_range(-area_half_extents.x, area_half_extents.x)
		var z = rng.randf_range(-area_half_extents.y, area_half_extents.y)
		var pos = Vector3(x, 0, z)
		if _too_close_to_track(pos):
			continue
		placed.append(pos)

	multimesh.instance_count = placed.size()

	var collisions := StaticBody3D.new()
	collisions.name = "Colliders"
	var collider_shape = _build_collider_shape()

	for i in range(placed.size()):
		var pos = placed[i]
		var rot = rng.randf_range(0, TAU)
		var scale_variance = rng.randf_range(0.8, 1.3)
		var basis = Basis(Vector3.UP, rot).scaled(Vector3.ONE * scale_variance)
		var xform = Transform3D(basis, pos)
		multimesh.set_instance_transform(i, xform)

		if collider_shape != null:
			var collision := CollisionShape3D.new()
			collision.shape = collider_shape
			collision.transform = xform
			collision.position.y += _collider_vertical_offset() * scale_variance
			collisions.add_child(collision)

	add_child(collisions)


func _too_close_to_track(pos: Vector3) -> bool:
	if track_path.is_empty():
		return false
	# Only check a sparse sample of the path for speed - the track doesn't
	# have corners sharp enough for this to miss a close pass.
	var step = max(1, track_path.size() / 60)
	var i = 0
	while i < track_path.size():
		if pos.distance_to(track_path[i]) < keep_out_radius:
			return true
		i += step
	return false


func _build_collider_shape() -> Shape3D:
	match prop_type:
		PropType.TREE:
			var s := CylinderShape3D.new()
			s.radius = 0.35
			s.height = 2.2
			return s
		PropType.ROCK:
			var s := BoxShape3D.new()
			s.size = Vector3(1.1, 0.9, 1.1)
			return s
		PropType.CACTUS:
			var s := CylinderShape3D.new()
			s.radius = 0.3
			s.height = 2.0
			return s
	return null


func _collider_vertical_offset() -> float:
	match prop_type:
		PropType.TREE:
			return 1.1
		PropType.ROCK:
			return 0.45
		PropType.CACTUS:
			return 1.0
	return 0.0


func _build_prop_mesh() -> Mesh:
	match prop_type:
		PropType.TREE:
			return _build_tree_mesh()
		PropType.ROCK:
			return _build_rock_mesh()
		PropType.CACTUS:
			return _build_cactus_mesh()
	return BoxMesh.new()


func _build_tree_mesh() -> Mesh:
	var multi := ArrayMesh.new()

	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.16
	trunk.bottom_radius = 0.22
	trunk.height = 1.6
	trunk.material = _mat(Color(0.33, 0.22, 0.14))
	_append_surface(multi, trunk, Transform3D(Basis(), Vector3(0, 0.8, 0)))

	var crown_mat = _mat(Color(0.14, 0.42, 0.18))
	for k in range(3):
		var cone := CylinderMesh.new()
		cone.top_radius = 0.02
		cone.bottom_radius = 1.0 - k * 0.22
		cone.height = 1.3
		cone.material = crown_mat
		_append_surface(multi, cone, Transform3D(Basis(), Vector3(0, 1.6 + k * 0.9, 0)))

	return multi


func _build_rock_mesh() -> Mesh:
	var multi := ArrayMesh.new()
	var mat = _mat(Color(0.42, 0.40, 0.38))

	var main := BoxMesh.new()
	main.size = Vector3(1.0, 0.8, 1.1)
	main.material = mat
	_append_surface(multi, main, Transform3D(Basis().rotated(Vector3.UP, 0.4), Vector3(0, 0.4, 0)))

	var bump := BoxMesh.new()
	bump.size = Vector3(0.55, 0.45, 0.5)
	bump.material = mat
	_append_surface(multi, bump, Transform3D(Basis().rotated(Vector3.UP, 1.1), Vector3(0.3, 0.75, -0.15)))

	return multi


func _build_cactus_mesh() -> Mesh:
	var multi := ArrayMesh.new()
	var mat = _mat(Color(0.18, 0.46, 0.24))

	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.22
	trunk.bottom_radius = 0.28
	trunk.height = 2.0
	trunk.material = mat
	_append_surface(multi, trunk, Transform3D(Basis(), Vector3(0, 1.0, 0)))

	var arm := CylinderMesh.new()
	arm.top_radius = 0.14
	arm.bottom_radius = 0.17
	arm.height = 0.9
	arm.material = mat
	_append_surface(multi, arm, Transform3D(Basis().rotated(Vector3.FORWARD, deg_to_rad(80)), Vector3(0.35, 1.3, 0)))

	return multi


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m


func _append_surface(target: ArrayMesh, primitive: PrimitiveMesh, xform: Transform3D) -> void:
	var arrays = primitive.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in range(verts.size()):
		verts[i] = xform * verts[i]
	for i in range(normals.size()):
		normals[i] = xform.basis * normals[i]
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var surf_idx = target.get_surface_count()
	target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	target.surface_set_material(surf_idx, primitive.material)
