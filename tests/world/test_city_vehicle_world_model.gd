extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var generator := CityWorldGenerator.new()
	var world_a: Dictionary = generator.generate_world(config)
	var world_b: Dictionary = generator.generate_world(config)

	if not T.require_true(self, world_a.has("vehicle_query"), "World data must include vehicle_query"):
		return

	var vehicle_query = world_a["vehicle_query"]
	if not T.require_true(self, vehicle_query.has_method("get_vehicle_query_for_chunk"), "vehicle_query must expose get_vehicle_query_for_chunk()"):
		return
	if not T.require_true(self, vehicle_query.has_method("get_world_stats"), "vehicle_query must expose get_world_stats()"):
		return
	if not T.require_true(self, vehicle_query.has_method("get_profile_snapshot"), "vehicle_query must expose get_profile_snapshot()"):
		return
	if not T.require_true(self, vehicle_query.has_method("get_lane_graph"), "vehicle_query must expose get_lane_graph()"):
		return
	if not T.require_true(self, vehicle_query.has_method("get_density_for_district_class"), "vehicle_query must expose get_density_for_district_class()"):
		return
	if not T.require_true(self, vehicle_query.has_method("get_density_for_road_class"), "vehicle_query must expose get_density_for_road_class()"):
		return
	if not T.require_true(self, vehicle_query.has_method("get_min_headway_for_road_class"), "vehicle_query must expose get_min_headway_for_road_class()"):
		return

	var center_chunk := _center_chunk(config)
	var center_query_a: Dictionary = vehicle_query.get_vehicle_query_for_chunk(center_chunk)
	var center_query_b: Dictionary = (world_b["vehicle_query"] as Object).call("get_vehicle_query_for_chunk", center_chunk)

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
	if not T.require_true(self, str(first_slot.get("direction", "")).length() > 0, "spawn_slot must expose direction"):
		return
	if not T.require_true(self, absf(float(first_slot.get("heading_deg", INF))) < 360.1, "spawn_slot must expose heading_deg"):
		return
	if not T.require_true(self, float(first_slot.get("distance_along_lane_m", -1.0)) >= 0.0, "spawn_slot must expose distance_along_lane_m"):
		return
	if not T.require_true(self, center_query_a.get("roster_signature", "") == center_query_b.get("roster_signature", ""), "Chunk roster signature must be deterministic across runs"):
		return

	var expressway_density := float(vehicle_query.get_density_for_road_class("expressway_elevated"))
	var arterial_density := float(vehicle_query.get_density_for_road_class("arterial"))
	var local_density := float(vehicle_query.get_density_for_road_class("local"))
	var service_density := float(vehicle_query.get_density_for_road_class("service"))
	if not T.require_true(self, expressway_density >= arterial_density and arterial_density >= local_density and local_density >= service_density, "Road class density ordering must remain deterministic and descending from expressway to service"):
		return

	var world_stats: Dictionary = vehicle_query.get_world_stats()
	if not T.require_true(self, int(world_stats.get("district_profile_count", 0)) == 4900, "world_stats must report all district profiles"):
		return
	if not T.require_true(self, int(world_stats.get("road_class_count", 0)) >= 6, "world_stats must report all configured road classes"):
		return
	if not T.require_true(self, int(world_stats.get("lane_count", 0)) > 0, "world_stats must report non-zero lane_count"):
		return
	if not T.require_true(self, int(world_stats.get("intersection_turn_contract_count", 0)) > 0, "world_stats must report non-zero intersection_turn_contract_count"):
		return
	if not T.require_true(self, int(world_a.get("generation_profile", {}).get("vehicle_world_usec", 0)) > 0, "generation_profile must expose vehicle_world_usec"):
		return

	T.pass_and_quit(self)

func _center_chunk(config: CityWorldConfig) -> Vector2i:
	var chunk_grid: Vector2i = config.get_chunk_grid_size()
	return Vector2i(
		int(floor(float(chunk_grid.x) * 0.5)),
		int(floor(float(chunk_grid.y) * 0.5))
	)
