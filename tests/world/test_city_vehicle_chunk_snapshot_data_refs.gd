extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityVehicleState := preload("res://city_game/world/vehicles/simulation/CityVehicleState.gd")

const CONTROLLER_PATH := "res://city_game/world/vehicles/simulation/CityVehicleTierController.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var controller_script := load(CONTROLLER_PATH)
	if not T.require_true(self, controller_script != null, "Vehicle tier controller script must exist for chunk snapshot data-ref validation"):
		return

	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var streamer := CityChunkStreamer.new(config, world_data)
	var controller = controller_script.new()
	controller.setup(config, world_data)

	if not T.require_true(self, controller.has_method("get_chunk_snapshot_ref"), "Vehicle tier controller must expose get_chunk_snapshot_ref() for chunk snapshot data-ref validation"):
		return
	if not T.require_true(self, controller.has_method("get_runtime_snapshot"), "Vehicle tier controller must expose get_runtime_snapshot() for chunk snapshot data-ref validation"):
		return

	var origin := Vector3.ZERO
	streamer.update_for_world_position(origin)
	controller.update_active_chunks(streamer.get_active_chunk_entries(), origin, 0.25)

	var runtime_snapshot: Dictionary = controller.get_runtime_snapshot()
	var tier1_states: Array = runtime_snapshot.get("tier1_states", [])
	if not T.require_true(self, not tier1_states.is_empty(), "Chunk snapshot data-ref validation requires at least one Tier 1 vehicle"):
		return
	var first_tier1_state: Dictionary = tier1_states[0]
	var chunk_id := str(first_tier1_state.get("chunk_id", ""))
	if not T.require_true(self, chunk_id != "", "Tier 1 vehicle runtime snapshot must expose chunk_id for chunk snapshot validation"):
		return

	var chunk_snapshot: Dictionary = controller.get_chunk_snapshot_ref(chunk_id)
	var chunk_tier1_states: Array = chunk_snapshot.get("tier1_states", [])
	if not T.require_true(self, not chunk_tier1_states.is_empty(), "Vehicle chunk snapshot must preserve visible Tier 1 states for the selected chunk"):
		return

	var first_chunk_state = chunk_tier1_states[0]
	if not T.require_true(self, first_chunk_state is CityVehicleState, "Vehicle chunk snapshot Tier 1 entries must stay as CityVehicleState refs instead of per-frame render dictionaries"):
		return
	if not T.require_true(self, (first_chunk_state as CityVehicleState).vehicle_id != "", "Vehicle chunk snapshot state refs must keep the live vehicle identity"):
		return

	print("CITY_VEHICLE_CHUNK_SNAPSHOT_DATA_REFS %s" % JSON.stringify({
		"chunk_id": chunk_id,
		"tier1_count": chunk_tier1_states.size(),
		"vehicle_id": (first_chunk_state as CityVehicleState).vehicle_id,
	}))

	T.pass_and_quit(self)
