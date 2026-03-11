extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")

const TERRAIN_PAGE_PROVIDER_PATH := "res://city_game/world/rendering/CityTerrainPageProvider.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var provider_script := load(TERRAIN_PAGE_PROVIDER_PATH)
	if not T.require_true(self, provider_script != null, "Terrain page provider script must exist for v5 M2"):
		return

	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var provider = provider_script.new()
	provider.setup(config, world_data)

	var chunk_a := _build_chunk_payload(config, world_data, Vector2i(136, 136))
	var chunk_b := _build_chunk_payload(config, world_data, Vector2i(137, 136))
	var binding_a: Dictionary = provider.resolve_chunk_sample_binding(chunk_a, 12)
	var binding_b: Dictionary = provider.resolve_chunk_sample_binding(chunk_b, 12)

	if not T.require_true(self, binding_a.get("page_key", Vector2i.ZERO) == binding_b.get("page_key", Vector2i.ZERO), "Adjacent chunks must share one terrain page key at runtime"):
		return
	if not T.require_true(self, int(provider.get_runtime_page_count()) == 1, "Resolving two adjacent chunks in the same page must build exactly one runtime terrain page"):
		return
	if not T.require_true(self, not bool(binding_a.get("runtime_hit", true)), "First terrain page binding must be a runtime miss that builds the page bundle"):
		return
	if not T.require_true(self, bool(binding_b.get("runtime_hit", false)), "Second adjacent terrain page binding must hit the existing runtime page bundle"):
		return

	T.pass_and_quit(self)

func _build_chunk_payload(config: CityWorldConfig, world_data: Dictionary, chunk_key: Vector2i) -> Dictionary:
	var bounds: Rect2 = config.get_world_bounds()
	var chunk_center := Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * float(config.chunk_size_m),
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * float(config.chunk_size_m)
	)
	return {
		"chunk_id": config.format_chunk_id(chunk_key),
		"chunk_key": chunk_key,
		"chunk_center": chunk_center,
		"chunk_size_m": float(config.chunk_size_m),
		"chunk_seed": config.derive_seed("render_chunk", chunk_key),
		"world_seed": int(config.base_seed),
		"road_graph": world_data.get("road_graph"),
	}
