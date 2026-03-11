extends RefCounted

static func build_chunk_occluder(chunk_size_m: float) -> OccluderInstance3D:
	var occluder_instance := OccluderInstance3D.new()
	occluder_instance.name = "ChunkOccluder"
	occluder_instance.position = Vector3(0.0, 14.0, 0.0)

	var box_occluder := BoxOccluder3D.new()
	box_occluder.size = Vector3(chunk_size_m * 0.8, 28.0, chunk_size_m * 0.8)
	occluder_instance.occluder = box_occluder
	return occluder_instance

