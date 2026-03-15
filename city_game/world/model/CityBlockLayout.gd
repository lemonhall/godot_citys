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

func get_block_data_by_serial_index(block_serial_index: int) -> Dictionary:
	if _config == null or block_serial_index < 0 or block_serial_index >= get_block_count():
		return {}
	var chunk_grid: Vector2i = _config.get_chunk_grid_size()
	var chunk_flat_index := int(floor(float(block_serial_index) / float(BLOCKS_PER_CHUNK)))
	var local_index := posmod(block_serial_index, BLOCKS_PER_CHUNK)
	var chunk_x := int(floor(float(chunk_flat_index) / float(chunk_grid.y)))
	var chunk_y := posmod(chunk_flat_index, chunk_grid.y)
	var blocks := get_blocks_for_chunk(Vector2i(chunk_x, chunk_y))
	if local_index < 0 or local_index >= blocks.size():
		return {}
	return (blocks[local_index] as Dictionary).duplicate(true)

func get_blocks_for_chunk(chunk_key: Vector2i) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	if _config == null:
		return blocks

	var chunk_id: String = _config.format_chunk_id(chunk_key)
	var district_key: Vector2i = _chunk_to_district_key(chunk_key)
	var chunk_rect := _build_chunk_rect(chunk_key)
	var block_size_m := float(_config.chunk_size_m) * 0.5
	for local_index in range(BLOCKS_PER_CHUNK):
		var block_row := int(floor(float(local_index) / 2.0))
		var block_col := local_index % 2
		var block_origin := chunk_rect.position + Vector2(float(block_col) * block_size_m, float(block_row) * block_size_m)
		blocks.append({
			"block_id": "%s_block_%d" % [chunk_id, local_index],
			"block_local_index": local_index,
			"block_serial_index": _resolve_block_serial_index(chunk_key, local_index),
			"chunk_id": chunk_id,
			"chunk_key": chunk_key,
			"district_id": _config.format_district_id(district_key),
			"seed": _config.derive_seed("block", chunk_key, local_index),
			"world_rect": Rect2(block_origin, Vector2.ONE * block_size_m),
			"center_2d": block_origin + Vector2.ONE * block_size_m * 0.5,
		})
	return blocks

func get_parcels_for_block(block_data: Dictionary) -> Array[Dictionary]:
	var parcels: Array[Dictionary] = []
	if _config == null:
		return parcels

	var block_id: String = str(block_data.get("block_id", ""))
	var chunk_key: Vector2i = block_data.get("chunk_key", Vector2i.ZERO)
	var local_index := int(block_data.get("block_local_index", 0))
	var block_rect: Rect2 = block_data.get("world_rect", Rect2())
	var block_center: Vector2 = block_data.get("center_2d", block_rect.position + block_rect.size * 0.5)
	var inset_m := minf(block_rect.size.x, block_rect.size.y) * 0.28
	var parcel_offsets := [
		Vector2(0.0, -inset_m),
		Vector2(inset_m, 0.0),
		Vector2(0.0, inset_m),
		Vector2(-inset_m, 0.0),
	]
	var frontage_sides := ["north", "east", "south", "west"]
	for parcel_index in range(PARCELS_PER_BLOCK):
		parcels.append({
			"parcel_id": "%s_parcel_%d" % [block_id, parcel_index],
			"parcel_local_index": parcel_index,
			"block_id": block_id,
			"chunk_id": str(block_data.get("chunk_id", "")),
			"seed": _config.derive_seed("parcel", chunk_key, local_index * 10 + parcel_index),
			"center_2d": block_center + parcel_offsets[parcel_index],
			"frontage_side": frontage_sides[parcel_index],
			"frontage_slot_count": 1,
		})
	return parcels

func get_parcel_for_block(block_data: Dictionary, parcel_local_index: int) -> Dictionary:
	var parcels := get_parcels_for_block(block_data)
	if parcel_local_index < 0 or parcel_local_index >= parcels.size():
		return {}
	return (parcels[parcel_local_index] as Dictionary).duplicate(true)

func get_frontage_slots_for_parcel(block_data: Dictionary, parcel_data: Dictionary) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	var center_2d: Vector2 = parcel_data.get("center_2d", block_data.get("center_2d", Vector2.ZERO))
	slots.append({
		"frontage_slot_index": 0,
		"parcel_id": str(parcel_data.get("parcel_id", "")),
		"frontage_side": str(parcel_data.get("frontage_side", "north")),
		"world_anchor": center_2d,
	})
	return slots

func _chunk_to_district_key(chunk_key: Vector2i) -> Vector2i:
	var district_grid: Vector2i = _config.get_district_grid_size()
	var chunk_grid: Vector2i = _config.get_chunk_grid_size()
	var district_x: int = mini(int(floor(float(chunk_key.x) * float(district_grid.x) / float(chunk_grid.x))), district_grid.x - 1)
	var district_y: int = mini(int(floor(float(chunk_key.y) * float(district_grid.y) / float(chunk_grid.y))), district_grid.y - 1)
	return Vector2i(district_x, district_y)

func _build_chunk_rect(chunk_key: Vector2i) -> Rect2:
	var bounds: Rect2 = _config.get_world_bounds()
	var chunk_size := float(_config.chunk_size_m)
	var chunk_origin := Vector2(
		bounds.position.x + float(chunk_key.x) * chunk_size,
		bounds.position.y + float(chunk_key.y) * chunk_size
	)
	return Rect2(chunk_origin, Vector2.ONE * chunk_size)

func _resolve_block_serial_index(chunk_key: Vector2i, local_index: int) -> int:
	var chunk_grid: Vector2i = _config.get_chunk_grid_size()
	return (chunk_key.x * chunk_grid.y + chunk_key.y) * BLOCKS_PER_CHUNK + local_index
