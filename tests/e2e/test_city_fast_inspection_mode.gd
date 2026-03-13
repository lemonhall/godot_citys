extends SceneTree

const T := preload("res://tests/_test_util.gd")
const SEARCH_POSITIONS := [
	Vector3(2048.0, 2.0, 26.0),
	Vector3.ZERO,
	Vector3(768.0, 2.0, 26.0),
	Vector3(-600.0, 2.0, 26.0),
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for fast inspection mode")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("set_control_mode"), "CityPrototype must expose set_control_mode()"):
		return
	if not T.require_true(self, world.has_method("get_control_mode"), "CityPrototype must expose get_control_mode()"):
		return
	if not T.require_true(self, world.has_method("get_pedestrian_runtime_snapshot"), "CityPrototype must expose get_pedestrian_runtime_snapshot()"):
		return

	var player = world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "CityPrototype must keep Player for fast inspection mode"):
		return
	if not T.require_true(self, player.has_method("get_speed_profile"), "PlayerController must expose get_speed_profile()"):
		return
	if not T.require_true(self, player.has_method("get_walk_speed_mps"), "PlayerController must expose get_walk_speed_mps()"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "PlayerController must support teleport_to_world_position()"):
		return
	if not T.require_true(self, world.get_node_or_null("InspectionCar") == null, "CityPrototype must not include InspectionCar once fast inspection mode replaces it"):
		return

	world.set_control_mode("inspection")
	if not T.require_true(self, world.get_control_mode() == "inspection", "CityPrototype must switch into inspection control mode"):
		return
	if not T.require_true(self, player.get_speed_profile() == "inspection", "PlayerController must switch into inspection speed profile"):
		return
	if not T.require_true(self, float(player.get_walk_speed_mps()) >= 80.0, "Inspection speed profile must provide fast traversal speed"):
		return

	var target_position := Vector3(2048.0, 2.0, 26.0)
	player.teleport_to_world_position(target_position)
	world.update_streaming_for_position(target_position)
	await process_frame

	var report: Dictionary = world.build_runtime_report(player.global_position)
	if not T.require_true(self, str(report.get("control_mode", "")) == "inspection", "Runtime report must expose inspection control mode"):
		return

	var snapshot: Dictionary = world.get_streaming_snapshot()
	if not T.require_true(self, str(snapshot.get("current_chunk_id", "")) != "", "Inspection mode must still report current_chunk_id"):
		return
	if not T.require_true(self, int(snapshot.get("active_chunk_count", 0)) <= 25, "Inspection mode must preserve chunk streaming guardrails"):
		return

	var candidate := await _find_candidate(world, player)
	if not T.require_true(self, not candidate.is_empty(), "Inspection mode E2E needs a nearby pedestrian candidate to validate non-threatening runtime reactions"):
		return
	var pedestrian_id := str(candidate.get("pedestrian_id", ""))
	var candidate_position: Vector3 = candidate.get("world_position", Vector3.ZERO)
	player.teleport_to_world_position(candidate_position + Vector3(0.8, 0.0, 0.8))
	for _frame_index in range(3):
		world.update_streaming_for_position(player.global_position, 0.12)
		await process_frame
	var reaction_snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
	var inspection_state := _find_state(reaction_snapshot, pedestrian_id)
	print("CITY_FAST_INSPECTION_MODE_REACTION %s" % JSON.stringify(inspection_state))
	if not T.require_true(self, not inspection_state.is_empty(), "Inspection mode runtime reaction must keep the nearby pedestrian resident in the snapshot"):
		return
	if not T.require_true(self, str(inspection_state.get("reaction_state", "")) == "yield", "Inspection mode runtime approach must stay non-threatening and resolve to yield instead of panic/flee"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _find_candidate(world, player) -> Dictionary:
	for search_position in SEARCH_POSITIONS:
		player.teleport_to_world_position(search_position)
		world.update_streaming_for_position(search_position, 0.25)
		await process_frame
		var snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
		for tier_key in ["tier2_states", "tier1_states"]:
			for state_variant in snapshot.get(tier_key, []):
				var state: Dictionary = state_variant
				if str(state.get("life_state", "alive")) != "alive":
					continue
				if str(state.get("reaction_state", "none")) != "none":
					continue
				return state
	return {}

func _find_state(snapshot: Dictionary, pedestrian_id: String) -> Dictionary:
	for tier_key in ["tier3_states", "tier2_states", "tier1_states"]:
		for state_variant in snapshot.get(tier_key, []):
			var state: Dictionary = state_variant
			if str(state.get("pedestrian_id", "")) == pedestrian_id:
				return state
	return {}
