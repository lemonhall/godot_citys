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
	streamer.update_for_world_position(Vector3.ZERO)

	var controller = CityPedestrianTierController.new()
	controller.setup(config, world_data)

	if not T.require_true(self, controller.has_method("get_budget_contract"), "Tier controller must expose get_budget_contract()"):
		return
	if not T.require_true(self, controller.has_method("update_active_chunks"), "Tier controller must expose update_active_chunks()"):
		return
	if not T.require_true(self, controller.has_method("get_global_snapshot"), "Tier controller must expose get_global_snapshot()"):
		return

	var budget_contract: Dictionary = controller.get_budget_contract()
	if not T.require_true(self, str(budget_contract.get("preset", "")) == "lite", "Default pedestrian budget preset must be lite"):
		return
	if not T.require_true(self, int(budget_contract.get("tier1_budget", 0)) > 0, "Tier 1 budget must be greater than zero"):
		return
	if not T.require_true(self, int(budget_contract.get("tier1_budget", 0)) <= 768, "Tier 1 budget must stay at or below the lite cap of 768"):
		return
	if not T.require_true(self, int(budget_contract.get("tier2_budget", 0)) > 0, "Tier 2 budget must be greater than zero"):
		return
	if not T.require_true(self, int(budget_contract.get("tier2_budget", 0)) <= 96, "Tier 2 budget must stay at or below the lite cap of 96"):
		return

	controller.update_active_chunks(streamer.get_active_chunk_entries(), Vector3.ZERO, 0.25)
	var snapshot: Dictionary = controller.get_global_snapshot()
	print("CITY_PEDESTRIAN_LOD_CONTRACT %s" % JSON.stringify(snapshot))

	if not T.require_true(self, int(snapshot.get("active_state_count", 0)) > 0, "Tier controller must activate at least one pedestrian state for the center window"):
		return
	if not T.require_true(self, int(snapshot.get("tier1_count", 0)) <= int(budget_contract.get("tier1_budget", 0)), "Tier 1 visible state count must stay within budget"):
		return
	if not T.require_true(self, int(snapshot.get("tier2_count", 0)) <= int(budget_contract.get("tier2_budget", 0)), "Tier 2 visible state count must stay within budget"):
		return
	if not T.require_true(self, int(snapshot.get("tier0_count", 0)) + int(snapshot.get("tier1_count", 0)) + int(snapshot.get("tier2_count", 0)) == int(snapshot.get("active_state_count", 0)), "Tier 0-2 counts must partition the active pedestrian set"):
		return

	T.pass_and_quit(self)
