extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityPedestrianTierController := preload("res://city_game/world/pedestrians/simulation/CityPedestrianTierController.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var streamer := CityChunkStreamer.new(config, world_data)
	var controller = CityPedestrianTierController.new()
	controller.setup(config, world_data)

	if not T.require_true(self, controller.has_method("get_budget_contract"), "Tier controller must expose get_budget_contract() for streaming budget validation"):
		return
	if not T.require_true(self, controller.has_method("get_runtime_snapshot"), "Tier controller must expose get_runtime_snapshot() for page cache validation"):
		return

	var pedestrian_query = world_data.get("pedestrian_query")
	var world_stats: Dictionary = pedestrian_query.get_world_stats() if pedestrian_query != null and pedestrian_query.has_method("get_world_stats") else {}
	var max_spawn_slots_per_chunk := int(world_stats.get("max_spawn_slots_per_chunk", 0))
	if not T.require_true(self, max_spawn_slots_per_chunk > 0, "Pedestrian world stats must expose max_spawn_slots_per_chunk"):
		return

	var budget_contract: Dictionary = controller.get_budget_contract()
	if not T.require_true(self, int(budget_contract.get("nearfield_budget", 0)) > 0, "Streaming budget contract must expose positive nearfield_budget"):
		return
	if not T.require_true(self, int(budget_contract.get("tier3_budget", 0)) > 0, "Streaming budget contract must expose positive tier3_budget"):
		return

	var peak_nearfield := 0
	for step in range(9):
		var travel_position := Vector3(-1200.0 + float(step) * 300.0, 0.0, 26.0)
		streamer.update_for_world_position(travel_position)
		controller.update_active_chunks(streamer.get_active_chunk_entries(), travel_position, 0.25)
		var snapshot: Dictionary = controller.get_global_snapshot()
		var nearfield_count := int(snapshot.get("tier2_count", 0)) + int(snapshot.get("tier3_count", 0))
		peak_nearfield = maxi(peak_nearfield, nearfield_count)

		if not T.require_true(self, int(snapshot.get("tier3_count", 0)) <= int(budget_contract.get("tier3_budget", 0)), "Tier 3 pedestrian count must stay within hard budget during chunk travel"):
			return
		if not T.require_true(self, nearfield_count <= int(budget_contract.get("nearfield_budget", 0)), "Tier 2 + Tier 3 pedestrians must stay within nearfield budget during chunk travel"):
			return
		if not T.require_true(self, int(snapshot.get("active_state_count", 0)) <= int(snapshot.get("active_chunk_count", 0)) * max_spawn_slots_per_chunk, "Active pedestrian count must remain bounded by active pages instead of leaking during travel"):
			return

	var runtime_snapshot: Dictionary = controller.get_runtime_snapshot()
	print("CITY_PEDESTRIAN_STREAMING_BUDGET %s" % JSON.stringify(runtime_snapshot))

	if not T.require_true(self, peak_nearfield > 0, "Streaming budget test requires at least one nearfield pedestrian"):
		return
	if not T.require_true(self, int(runtime_snapshot.get("active_page_count", 0)) <= 25, "Pedestrian streaming must stay aligned with the 5x5 active chunk window"):
		return
	if not T.require_true(self, int(runtime_snapshot.get("duplicate_page_load_count", 0)) == 0, "One-way travel must not duplicate pedestrian page loads"):
		return

	T.pass_and_quit(self)
