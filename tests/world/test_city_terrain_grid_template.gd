extends SceneTree

const T := preload("res://tests/_test_util.gd")

const GRID_TEMPLATE_PATH := "res://city_game/world/rendering/CityTerrainGridTemplate.gd"
const CHUNK_SIZE_M := 256.0
const GRID_STEPS := 12

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var template_script := load(GRID_TEMPLATE_PATH)
	if not T.require_true(self, template_script != null, "CityTerrainGridTemplate.gd must exist for shared terrain topology reuse"):
		return

	var template_catalog = template_script.new()
	var template_a: Dictionary = template_catalog.get_template(CHUNK_SIZE_M, GRID_STEPS)
	var template_b: Dictionary = template_catalog.get_template(CHUNK_SIZE_M, GRID_STEPS)
	var local_points_a: PackedVector2Array = template_a.get("local_points", PackedVector2Array())
	var local_points_b: PackedVector2Array = template_b.get("local_points", PackedVector2Array())
	var indices_a: PackedInt32Array = template_a.get("indices", PackedInt32Array())
	var indices_b: PackedInt32Array = template_b.get("indices", PackedInt32Array())

	if not T.require_true(self, int(template_a.get("vertex_count", 0)) == 169, "Terrain grid template must expose a 13x13 unique vertex lattice for 12 steps"):
		return
	if not T.require_true(self, int(template_a.get("index_count", 0)) == 864, "Terrain grid template must expose 864 triangle indices for a 12x12 quad grid"):
		return
	if not T.require_true(self, str(template_a.get("cache_key", "")) == str(template_b.get("cache_key", "")), "Repeated terrain template requests must resolve to the same cache key"):
		return
	if not T.require_true(self, local_points_a == local_points_b, "Repeated terrain template requests must reuse the same local point layout"):
		return
	if not T.require_true(self, indices_a == indices_b, "Repeated terrain template requests must reuse the same index topology"):
		return

	T.pass_and_quit(self)
