extends RefCounted

const CHUNKS_PER_PAGE := 4

func build_chunk_contract(chunk_key: Vector2i, chunk_size_m: float, chunks_per_page: int = CHUNKS_PER_PAGE) -> Dictionary:
	var safe_chunks_per_page := maxi(chunks_per_page, 1)
	var page_key := Vector2i(
		int(floor(float(chunk_key.x) / float(safe_chunks_per_page))),
		int(floor(float(chunk_key.y) / float(safe_chunks_per_page)))
	)
	var local_chunk_x := int(posmod(chunk_key.x, safe_chunks_per_page))
	var local_chunk_y := int(posmod(chunk_key.y, safe_chunks_per_page))
	var uv_tile_size := 1.0 / float(safe_chunks_per_page)
	return {
		"page_key": page_key,
		"chunks_per_page": safe_chunks_per_page,
		"page_world_size_m": float(safe_chunks_per_page) * chunk_size_m,
		"page_origin_chunk_key": page_key * safe_chunks_per_page,
		"page_resolution": safe_chunks_per_page,
		"chunk_slot": Vector2i(local_chunk_x, local_chunk_y),
		"chunk_offset_m": Vector2(float(local_chunk_x) * chunk_size_m, float(local_chunk_y) * chunk_size_m),
		"uv_rect": Rect2(
			Vector2(float(local_chunk_x) * uv_tile_size, float(local_chunk_y) * uv_tile_size),
			Vector2.ONE * uv_tile_size
		),
	}

func get_page_chunk_keys(page_key: Vector2i, chunks_per_page: int = CHUNKS_PER_PAGE) -> Array[Vector2i]:
	var safe_chunks_per_page := maxi(chunks_per_page, 1)
	var page_origin_chunk_key := page_key * safe_chunks_per_page
	var chunk_keys: Array[Vector2i] = []
	for local_y in range(safe_chunks_per_page):
		for local_x in range(safe_chunks_per_page):
			chunk_keys.append(page_origin_chunk_key + Vector2i(local_x, local_y))
	return chunk_keys
