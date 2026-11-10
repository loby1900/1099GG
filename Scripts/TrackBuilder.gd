class_name TrackBuilder
extends RefCounted
## Builds a closed-loop race track from a handful of hand-placed waypoints:
## a smooth (Catmull-Rom) visual road ribbon, guardrail colliders along
## both edges so the car can't just drive off into the scenery, and three
## evenly-spaced checkpoint trigger volumes for lap timing.
##
## This is a plain RefCounted helper (not a node) so any map script can
## call TrackBuilder.build(...) and get back the pieces to add to its own
## tree, instead of duplicating this math in every map.

const SUBDIVISIONS_PER_SEGMENT := 10
const RAIL_HEIGHT := 0.7
const RAIL_THICKNESS := 0.4
const SEGMENTS_PER_RAIL_COLLIDER := 5


static func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 = t * t
	var t3 = t2 * t
	return 0.5 * (
		(2.0 * p1) +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


## Returns a smooth, closed list of points running through all waypoints.
static func smooth_path(waypoints: Array) -> Array:
	var n = waypoints.size()
	var out: Array = []
	for i in range(n):
		var p0 = waypoints[(i - 1 + n) % n]
		var p1 = waypoints[i]
		var p2 = waypoints[(i + 1) % n]
		var p3 = waypoints[(i + 2) % n]
		for s in range(SUBDIVISIONS_PER_SEGMENT):
			var t = float(s) / float(SUBDIVISIONS_PER_SEGMENT)
			out.append(_catmull_rom(p0, p1, p2, p3, t))
	return out


## Builds everything and returns a Dictionary:
## {"road": MeshInstance3D, "rails": StaticBody3D, "checkpoints": [Area3D,Area3D,Area3D],
##  "spawn_transform": Transform3D, "path": Array[Vector3]}
static func build(waypoints: Array, width: float, road_color: Color) -> Dictionary:
	var path = smooth_path(waypoints)
	var road = _build_road_mesh(path, width, road_color)
	var rails = _build_rails(path, width)
	var checkpoints = _build_checkpoints(path, width)
	var spawn_transform = _spawn_transform_at(path, 0)
	return {
		"road": road,
		"rails": rails,
		"checkpoints": checkpoints,
		"spawn_transform": spawn_transform,
		"path": path,
	}


static func _forward_at(path: Array, i: int) -> Vector3:
	var n = path.size()
	var a = path[i]
	var b = path[(i + 1) % n]
	return (b - a).normalized()


static func _build_road_mesh(path: Array, width: float, color: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var n = path.size()
	var lefts: Array = []
	for i in range(n):
		var fwd = _forward_at(path, i)
		var side = fwd.cross(Vector3.UP).normalized()
		lefts.append(side)

	for i in range(n):
		var next_i = (i + 1) % n
		var p_a = path[i]
		var p_b = path[next_i]
		var side_a = lefts[i]
		var side_b = lefts[next_i]

		var a_l = p_a - side_a * width * 0.5
		var a_r = p_a + side_a * width * 0.5
		var b_l = p_b - side_b * width * 0.5
		var b_r = p_b + side_b * width * 0.5

		st.set_color(color)
		st.set_uv(Vector2(0, float(i)))
		st.add_vertex(a_l)
		st.set_uv(Vector2(1, float(i)))
		st.add_vertex(a_r)
		st.set_uv(Vector2(1, float(i + 1)))
		st.add_vertex(b_r)

		st.set_uv(Vector2(0, float(i)))
		st.add_vertex(a_l)
		st.set_uv(Vector2(1, float(i + 1)))
		st.add_vertex(b_r)
		st.set_uv(Vector2(0, float(i + 1)))
		st.add_vertex(b_l)

	st.generate_normals()
	st.generate_tangents()

	var mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mat.vertex_color_use_as_albedo = false
	# The ribbon's winding isn't guaranteed to face up for every segment
	# (it depends on the turn direction), so disable culling rather than
	# risk the road vanishing on some corners.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)

	var mi := MeshInstance3D.new()
	mi.name = "RoadMesh"
	mi.mesh = mesh
	return mi


static func _build_rails(path: Array, width: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Guardrails"

	var n = path.size()
	var i = 0
	while i < n:
		var j = min(i + SEGMENTS_PER_RAIL_COLLIDER, n)
		_add_rail_segment(body, path, i, j, width, 1.0)
		_add_rail_segment(body, path, i, j, width, -1.0)
		i += SEGMENTS_PER_RAIL_COLLIDER
	return body


static func _add_rail_segment(body: StaticBody3D, path: Array, i: int, j: int, width: float, side_sign: float) -> void:
	var n = path.size()
	var start = path[i]
	var end = path[j % n]
	var fwd = _forward_at(path, i)
	var side = fwd.cross(Vector3.UP).normalized()

	var start_edge = start + side * side_sign * width * 0.5
	var end_edge = end + side * side_sign * width * 0.5
	var mid = (start_edge + end_edge) * 0.5
	var length = start_edge.distance_to(end_edge)
	if length < 0.01:
		return

	var shape := BoxShape3D.new()
	shape.size = Vector3(RAIL_THICKNESS, RAIL_HEIGHT, length + 0.5)

	var collision := CollisionShape3D.new()
	collision.shape = shape

	var forward_dir = (end_edge - start_edge).normalized()
	var basis = Basis.looking_at(forward_dir, Vector3.UP)
	collision.transform = Transform3D(basis, mid + Vector3(0, RAIL_HEIGHT * 0.5, 0))

	body.add_child(collision)


static func _spawn_transform_at(path: Array, i: int) -> Transform3D:
	var fwd = _forward_at(path, i)
	var basis = Basis.looking_at(fwd, Vector3.UP)
	# Just above the suspension's natural resting height (~0.22) so the car
	# settles onto its wheels in a frame or two instead of free-falling and
	# slamming down with enough impact velocity to set off a bounce.
	return Transform3D(basis, path[i] + Vector3(0, 0.3, 0))


static func _build_checkpoints(path: Array, width: float) -> Array:
	var n = path.size()
	var fractions = [0.0, 1.0 / 3.0, 2.0 / 3.0]
	var names = ["CheckpointSector1", "CheckpointSector2", "CheckpointSector3"]
	var areas: Array = []
	for k in range(3):
		var i = int(round(fractions[k] * n)) % n
		var fwd = _forward_at(path, i)
		var basis = Basis.looking_at(fwd, Vector3.UP)

		var area := Area3D.new()
		area.name = names[k]

		var shape := BoxShape3D.new()
		shape.size = Vector3(width, 4.0, 1.0)
		var collision := CollisionShape3D.new()
		collision.shape = shape

		area.add_child(collision)
		area.transform = Transform3D(basis, path[i] + Vector3(0, 2.0, 0))
		areas.append(area)
	return areas
