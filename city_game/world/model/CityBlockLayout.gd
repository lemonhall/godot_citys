extends RefCounted

const BLOCKS_PER_CHUNK := 4
const PARCELS_PER_BLOCK := 4

var _config = null

func setup(config) -> void:
	_config = config

func get_block_count() -> int:
	if _config == null:
		return 0
	return _config.get_chunk_count() * BLOCKS_PER_CHUNK

func get_parcel_count() -> int:
	return get_block_count() * PARCELS_PER_BLOCK

func get_block_ids(limit: int = 16) -> Array[String]:
	var ids: Array[String] = []
	if _config == null or limit <= 0:
		return ids
	var chunk_grid: Vector2i = _config.get_chunk_grid_size()
	for x in range(chunk_grid.x):
		for y in range(chunk_grid.y):
			for local_index in range(BLOCKS_PER_CHUNK):
				ids.append("%s_block_%d" % [_config.format_chunk_id(Vector2i(x, y)), local_index])
				if ids.size() >= limit:
					return ids
	return ids

func get_first_block_id() -> String:
	if _config == null:
		return ""
	return "%s_block_0" % _config.format_chunk_id(Vector2i.ZERO)

func get_blocks_for_chunk(chunk_key: Vector2i) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	if _config == null:
		return blocks

	var chunk_id: String = _config.format_chunk_id(chunk_key)
	var district_key: Vector2i = _chunk_to_district_key(chunk_key)
	for local_index in range(BLOCKS_PER_CHUNK):
		blocks.append({
			"block_id": "%s_block_%d" % [chunk_id, local_index],
			"block_local_index": local_index,
			"chunk_id": chunk_id,
			"chunk_key": chunk_key,
			"district_id": _config.format_district_id(district_key),
			"seed": _config.derive_seed("block", chunk_key, local_index),
		})
	return blocks

func get_parcels_for_block(block_data: Dictionary) -> Array[Dictionary]:
	var parcels: Array[Dictionary] = []
	if _config == null:
		return parcels

	var block_id: String = str(block_data.get("block_id", ""))
	var chunk_key: Vector2i = block_data.get("chunk_key", Vector2i.ZERO)
	var local_index := int(block_data.get("block_local_index", 0))
	for parcel_index in range(PARCELS_PER_BLOCK):
		parcels.append({
			"parcel_id": "%s_parcel_%d" % [block_id, parcel_index],
			"block_id": block_id,
			"chunk_id": str(block_data.get("chunk_id", "")),
			"seed": _config.derive_seed("parcel", chunk_key, local_index * 10 + parcel_index),
		})
	return parcels

func _chunk_to_district_key(chunk_key: Vector2i) -> Vector2i:
	var district_grid: Vector2i = _config.get_district_grid_size()
	var chunk_grid: Vector2i = _config.get_chunk_grid_size()
	var district_x: int = mini(int(floor(float(chunk_key.x) * float(district_grid.x) / float(chunk_grid.x))), district_grid.x - 1)
	var district_y: int = mini(int(floor(float(chunk_key.y) * float(district_grid.y) / float(chunk_grid.y))), district_grid.y - 1)
	return Vector2i(district_x, district_y)
