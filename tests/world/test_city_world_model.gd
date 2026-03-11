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
	if not T.require_true(self, config.world_width_m == 7000, "world_width_m must equal 7000"):
		return
	if not T.require_true(self, config.world_depth_m == 7000, "world_depth_m must equal 7000"):
		return
	if not T.require_true(self, config.chunk_size_m == 256, "chunk_size_m must equal 256"):
		return
	if not T.require_true(self, config.district_size_m == 1000, "district_size_m must equal 1000"):
		return

	var chunk_grid: Vector2i = config.get_chunk_grid_size()
	if not T.require_true(self, chunk_grid == Vector2i(28, 28), "Chunk grid must equal 28 x 28"):
		return
	if not T.require_true(self, config.get_chunk_count() == 784, "Chunk count must equal 784"):
		return

	var district_grid: Vector2i = config.get_district_grid_size()
	if not T.require_true(self, district_grid == Vector2i(7, 7), "District grid must equal 7 x 7"):
		return

	var bounds: Rect2 = config.get_world_bounds()
	if not T.require_true(self, bounds.position == Vector2(-3500.0, -3500.0), "World bounds min must equal (-3500, -3500)"):
		return
	if not T.require_true(self, bounds.size == Vector2(7000.0, 7000.0), "World bounds size must equal (7000, 7000)"):
		return

	var seed_a: int = config.derive_seed("district", Vector2i(2, 3), 11)
	var seed_b: int = script.new().derive_seed("district", Vector2i(2, 3), 11)
	if not T.require_true(self, seed_a == seed_b, "derive_seed() must be deterministic"):
		return

	T.pass_and_quit(self)

