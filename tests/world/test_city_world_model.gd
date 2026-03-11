extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var script := load("res://city_game/world/model/CityWorldConfig.gd")
	if script == null:
		T.fail_and_quit(self, "Missing res://city_game/world/model/CityWorldConfig.gd")
		return

	var config = script.new()
	if not T.require_true(self, config != null, "CityWorldConfig must instantiate"):
		return
	if not T.require_true(self, config.world_width_m == 70000, "world_width_m must equal 70000"):
		return
	if not T.require_true(self, config.world_depth_m == 70000, "world_depth_m must equal 70000"):
		return
	if not T.require_true(self, config.chunk_size_m == 256, "chunk_size_m must equal 256"):
		return
	if not T.require_true(self, config.district_size_m == 1000, "district_size_m must equal 1000"):
		return

	var chunk_grid: Vector2i = config.get_chunk_grid_size()
	if not T.require_true(self, chunk_grid == Vector2i(274, 274), "Chunk grid must equal 274 x 274"):
		return
	if not T.require_true(self, config.get_chunk_count() == 75076, "Chunk count must equal 75076"):
		return

	var district_grid: Vector2i = config.get_district_grid_size()
	if not T.require_true(self, district_grid == Vector2i(70, 70), "District grid must equal 70 x 70"):
		return

	var bounds: Rect2 = config.get_world_bounds()
	if not T.require_true(self, bounds.position == Vector2(-35000.0, -35000.0), "World bounds min must equal (-35000, -35000)"):
		return
	if not T.require_true(self, bounds.size == Vector2(70000.0, 70000.0), "World bounds size must equal (70000, 70000)"):
		return

	var seed_a: int = config.derive_seed("district", Vector2i(2, 3), 11)
	var seed_b: int = script.new().derive_seed("district", Vector2i(2, 3), 11)
	if not T.require_true(self, seed_a == seed_b, "derive_seed() must be deterministic"):
		return

	T.pass_and_quit(self)
