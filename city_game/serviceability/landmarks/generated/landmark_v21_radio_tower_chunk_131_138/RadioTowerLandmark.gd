extends Node3D

var _precise_collision_built := false

func _ready() -> void:
	_ensure_precise_collision()

func _ensure_precise_collision() -> void:
	if _precise_collision_built:
		return
	var existing_body := get_node_or_null("PreciseCollision") as StaticBody3D
	if existing_body != null:
		_precise_collision_built = true
		return

	var mesh_instances: Array[MeshInstance3D] = []
	for child in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		mesh_instances.append(mesh_instance)
	if mesh_instances.is_empty():
		return

	# This landmark deliberately uses exact triangle collision so the player can climb the real tower silhouette.
	var collision_body := StaticBody3D.new()
	collision_body.name = "PreciseCollision"
	add_child(collision_body)

	var created_shape_count := 0
	for mesh_instance in mesh_instances:
		var source_faces: PackedVector3Array = mesh_instance.mesh.get_faces()
		if source_faces.is_empty():
			continue
		var transformed_faces := PackedVector3Array()
		transformed_faces.resize(source_faces.size())
		for face_index in range(source_faces.size()):
			transformed_faces[face_index] = to_local(mesh_instance.global_transform * source_faces[face_index])
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(transformed_faces)
		var collision_shape := CollisionShape3D.new()
		collision_shape.name = "%sCollisionShape" % mesh_instance.name
		collision_shape.shape = shape
		collision_body.add_child(collision_shape)
		created_shape_count += 1
	if created_shape_count <= 0:
		collision_body.queue_free()
		return
	_precise_collision_built = true
