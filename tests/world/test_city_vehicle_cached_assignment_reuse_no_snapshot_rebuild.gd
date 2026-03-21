extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")

const CONTROLLER_PATH := "res://city_game/world/vehicles/simulation/CityVehicleTierController.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var controller_script := load(CONTROLLER_PATH)
	if not T.require_true(self, controller_script != null, "Vehicle tier controller script must exist for cached-assignment reuse validation"):
		return

	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var streamer := CityChunkStreamer.new(config, world_data)
	var controller = controller_script.new()
	controller.setup(config, world_data)

	if not T.require_true(self, controller.has_method("get_runtime_snapshot"), "Vehicle tier controller must expose get_runtime_snapshot() for cached-assignment reuse validation"):
		return
	if not T.require_true(self, controller.has_method("get_chunk_snapshot_ref"), "Vehicle tier controller must expose get_chunk_snapshot_ref() for cached-assignment reuse validation"):
		return

	var origin := Vector3.ZERO
	streamer.update_for_world_position(origin)
	var active_chunk_entries: Array = streamer.get_active_chunk_entries()
	controller.update_active_chunks(active_chunk_entries, origin, 0.05)

	var first_runtime_snapshot: Dictionary = controller.get_runtime_snapshot()
	var tracked_chunk_id := _pick_visible_chunk_id(first_runtime_snapshot)
	if not T.require_true(self, tracked_chunk_id != "", "Cached-assignment reuse validation requires at least one visible vehicle chunk"):
		return

	controller.update_active_chunks(active_chunk_entries, origin, 0.05)
	var second_runtime_snapshot: Dictionary = controller.get_runtime_snapshot()
	var second_profile_stats: Dictionary = second_runtime_snapshot.get("profile_stats", {})
	var tracked_chunk_snapshot: Dictionary = controller.get_chunk_snapshot_ref(tracked_chunk_id)

	if not T.require_true(self, int(second_profile_stats.get("traffic_snapshot_rebuild_usec", -1)) == 0, "Vehicle cached-assignment reuse must not rebuild whole chunk snapshots when only vehicle motion changes inside the same chunk window"):
		return
	if not T.require_true(self, bool(tracked_chunk_snapshot.get("dirty", false)), "Vehicle cached-assignment reuse must still mark stepped visible chunks dirty for renderer commit"):
		return

	print("CITY_VEHICLE_CACHED_ASSIGNMENT_REUSE %s" % JSON.stringify({
		"chunk_id": tracked_chunk_id,
		"traffic_snapshot_rebuild_usec": int(second_profile_stats.get("traffic_snapshot_rebuild_usec", -1)),
		"dirty": bool(tracked_chunk_snapshot.get("dirty", false)),
	}))

	T.pass_and_quit(self)

func _pick_visible_chunk_id(runtime_snapshot: Dictionary) -> String:
	for tier_key in ["tier2_states", "tier1_states", "tier3_states"]:
		for state_variant in runtime_snapshot.get(tier_key, []):
			var state: Dictionary = state_variant
			var chunk_id := str(state.get("chunk_id", ""))
			if chunk_id != "":
				return chunk_id
	return ""
