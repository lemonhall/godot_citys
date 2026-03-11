extends RefCounted

const DEFAULT_BASE_SEED := 424242

var base_seed: int
var world_width_m := 70000
var world_depth_m := 70000
var chunk_size_m := 256
var district_size_m := 1000

func _init(initial_seed: int = DEFAULT_BASE_SEED) -> void:
	base_seed = initial_seed

func get_world_bounds() -> Rect2:
	return Rect2(
		Vector2(-world_width_m * 0.5, -world_depth_m * 0.5),
		Vector2(world_width_m, world_depth_m)
	)

func get_chunk_grid_size() -> Vector2i:
	return Vector2i(
		int(ceil(world_width_m / float(chunk_size_m))),
		int(ceil(world_depth_m / float(chunk_size_m)))
	)

func get_chunk_count() -> int:
	var chunk_grid := get_chunk_grid_size()
	return chunk_grid.x * chunk_grid.y

func get_district_grid_size() -> Vector2i:
	return Vector2i(
		int(ceil(world_width_m / float(district_size_m))),
		int(ceil(world_depth_m / float(district_size_m)))
	)

func format_chunk_id(chunk_key: Vector2i) -> String:
	var width := _grid_index_width(get_chunk_grid_size())
	return "chunk_%s_%s" % [_pad_index(chunk_key.x, width), _pad_index(chunk_key.y, width)]

func format_district_id(district_key: Vector2i) -> String:
	var width := _grid_index_width(get_district_grid_size())
	return "district_%s_%s" % [_pad_index(district_key.x, width), _pad_index(district_key.y, width)]

func derive_seed(scope_name: String, coords: Vector2i = Vector2i.ZERO, salt: int = 0) -> int:
	var hash_value := base_seed & 0x7fffffff
	for byte_value in scope_name.to_utf8_buffer():
		hash_value = int((hash_value * 33 + int(byte_value) + 17) & 0x7fffffff)
	hash_value = int((hash_value + coords.x * 92837111 + coords.y * 689287499 + salt * 283923481) & 0x7fffffff)
	hash_value = int((hash_value * 1103515245 + 12345) & 0x7fffffff)
	return hash_value

func _grid_index_width(grid_size: Vector2i) -> int:
	return maxi(str(grid_size.x - 1).length(), str(grid_size.y - 1).length())

func _pad_index(value: int, width: int) -> String:
	var text := str(value)
	while text.length() < width:
		text = "0" + text
	return text
