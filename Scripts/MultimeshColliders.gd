extends MultiMeshInstance3D
## Generates one static cylinder collider per instance of a MultiMesh, so a
## whole forest of scattered props (trees, rocks, lamp posts...) gets
## collision without hand-placing a StaticBody3D for each one.
##
## Replaces the old hitboxiMultimeshov.gd, which built a shape from a
## default-sized CylinderMesh and then immediately overwrote the collider's
## orientation with `rotation.x/y/z = 25.132` (== 4*TAU, i.e. always resets
## back to identity) right after copying the instance's real basis — so the
## per-instance rotation it computed was always discarded. This version
## just uses each instance's real transform directly, and reuses a single
## shared Shape3D resource instead of building a new one per instance.

@export var collider_radius: float = 0.35
@export var collider_height: float = 4.0
## Shifts the collider up/down relative to the instance origin, for meshes
## whose origin isn't at the base (most trunk/rock meshes are).
@export var collider_vertical_offset: float = 0.0


func _ready() -> void:
	if multimesh == null:
		return

	var shape := CylinderShape3D.new()
	shape.radius = collider_radius
	shape.height = collider_height

	for i in multimesh.instance_count:
		var inst_transform: Transform3D = multimesh.get_instance_transform(i)

		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position.y += collider_vertical_offset

		var body := StaticBody3D.new()
		body.transform = inst_transform
		body.add_child(collision)
		add_child(body)
