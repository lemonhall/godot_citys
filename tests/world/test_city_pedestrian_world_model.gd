extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config_script := load("res://city_game/world/model/CityWorldConfig.gd")
	if config_script == null:
		T.fail_and_quit(self, "Missing res://city_game/world/model/CityWorldConfig.gd")
		return

	var generator_script := load("res://city_game/world/generation/CityWorldGenerator.gd")
	if generator_script == null:
		T.fail_and_quit(self, "Missing res://city_game/world/generation/CityWorldGenerator.gd")
		return

	var config = config_script.new()
	var generator = generator_script.new()
	var world_a: Dictionary = generator.generate_world(config)
	var world_b: Dictionary = generator.generate_world(config)

	if not T.require_true(self, world_a.has("pedestrian_query"), "World data must include pedestrian_query"):
		return

	var pedestrian_query = world_a["pedestrian_query"]
	if not T.require_true(self, pedestrian_query.has_method("get_pedestrian_query_for_chunk"), "pedestrian_query must expose get_pedestrian_query_for_chunk()"):
		return
	if not T.require_true(self, pedestrian_query.has_method("get_world_stats"), "pedestrian_query must expose get_world_stats()"):
		return
	if not T.require_true(self, pedestrian_query.has_method("get_profile_snapshot"), "pedestrian_query must expose get_profile_snapshot()"):
		return

	var chunk_grid: Vector2i = config.get_chunk_grid_size()
	var center_chunk := Vector2i(
		int(floor(float(chunk_grid.x) * 0.5)),
		int(floor(float(chunk_grid.y) * 0.5))
	)
	var center_query_a: Dictionary = pedestrian_query.get_pedestrian_query_for_chunk(center_chunk)
	var center_query_b: Dictionary = (world_b["pedestrian_query"] as Object).call("get_pedestrian_query_for_chunk", center_chunk)

	if not T.require_true(self, center_query_a.get("chunk_id", "") == config.format_chunk_id(center_chunk), "Chunk query must preserve deterministic chunk_id"):
		return
	if not T.require_true(self, str(center_query_a.get("lane_page_id", "")).length() > 0, "Chunk query must expose a stable lane_page_id placeholder"):
		return
	if not T.require_true(self, int(center_query_a.get("spawn_capacity", 0)) > 0, "Center chunk query must expose non-zero spawn_capacity"):
		return
	var spawn_slots: Array = center_query_a.get("spawn_slots", [])
	if not T.require_true(self, not spawn_slots.is_empty(), "Center chunk query must expose deterministic spawn_slots"):
		return
	var first_slot: Dictionary = spawn_slots[0]
	if not T.require_true(self, str(first_slot.get("spawn_slot_id", "")).length() > 0, "spawn_slot must expose spawn_slot_id"):
		return
	if not T.require_true(self, str(first_slot.get("lane_ref_id", "")).length() > 0, "spawn_slot must expose lane_ref_id"):
		return
	if not T.require_true(self, str(first_slot.get("road_id", "")).length() > 0, "spawn_slot must expose road_id"):
		return
	if not T.require_true(self, str(first_slot.get("road_class", "")).length() > 0, "spawn_slot must expose road_class"):
		return
	if not T.require_true(self, center_query_a.get("roster_signature", "") == center_query_b.get("roster_signature", ""), "Chunk roster signature must be deterministic across runs"):
		return

	var world_stats: Dictionary = pedestrian_query.get_world_stats()
	if not T.require_true(self, int(world_stats.get("district_profile_count", 0)) == 4900, "world_stats must report all district profiles"):
		return
	if not T.require_true(self, int(world_stats.get("road_class_count", 0)) >= 4, "world_stats must report multiple road classes"):
		return
	if not T.require_true(self, int(world_a.get("generation_profile", {}).get("pedestrian_world_usec", 0)) > 0, "generation_profile must expose pedestrian_world_usec"):
		return

	T.pass_and_quit(self)
