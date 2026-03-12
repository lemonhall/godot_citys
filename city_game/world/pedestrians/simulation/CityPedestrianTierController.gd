extends RefCounted

const CityPedestrianArchetypeCatalog := preload("res://city_game/world/pedestrians/rendering/CityPedestrianArchetypeCatalog.gd")
const CityPedestrianState := preload("res://city_game/world/pedestrians/simulation/CityPedestrianState.gd")
const CityTerrainSampler := preload("res://city_game/world/rendering/CityTerrainSampler.gd")

const DEFAULT_PRESET := "lite"
const DEFAULT_TIER_1_BUDGET := 768
const DEFAULT_TIER_2_BUDGET := 96
const DEFAULT_TIER_2_RADIUS_M := 110.0

var _config = null
var _pedestrian_query = null
var _lane_graph = null
var _world_seed := 0
var _archetype_catalog := CityPedestrianArchetypeCatalog.new()
var _states_by_id: Dictionary = {}
var _chunk_state_ids: Dictionary = {}
var _budget_contract := {
	"preset": DEFAULT_PRESET,
	"tier1_budget": DEFAULT_TIER_1_BUDGET,
	"tier2_budget": DEFAULT_TIER_2_BUDGET,
	"tier2_radius_m": DEFAULT_TIER_2_RADIUS_M,
}
var _global_snapshot: Dictionary = {}
var _chunk_snapshots: Dictionary = {}

func setup(config, world_data: Dictionary) -> void:
	_config = config
	_pedestrian_query = world_data.get("pedestrian_query")
	_lane_graph = _pedestrian_query.get_lane_graph() if _pedestrian_query != null and _pedestrian_query.has_method("get_lane_graph") else null
	_world_seed = int(config.base_seed) if config != null else 0
	_states_by_id.clear()
	_chunk_state_ids.clear()
	_chunk_snapshots.clear()
	_global_snapshot.clear()

func get_budget_contract() -> Dictionary:
	return _budget_contract.duplicate(true)

func update_active_chunks(active_chunk_entries: Array, player_position: Vector3, delta: float = 0.0) -> Dictionary:
	var active_states: Array = []
	var active_chunk_ids: Array[String] = []
	for entry_variant in active_chunk_entries:
		var entry: Dictionary = entry_variant
		var chunk_key: Vector2i = entry.get("chunk_key", Vector2i.ZERO)
		var chunk_id := str(entry.get("chunk_id", ""))
		active_chunk_ids.append(chunk_id)
		active_states.append_array(_ensure_chunk_states(chunk_key))

	if delta > 0.0:
		for state_variant in active_states:
			var state: CityPedestrianState = state_variant
			state.step(delta)
			_ground_state(state)

	var ranked_states: Array[Dictionary] = []
	for state_variant in active_states:
		var state: CityPedestrianState = state_variant
		ranked_states.append({
			"pedestrian_id": state.pedestrian_id,
			"distance_m": player_position.distance_to(state.world_position),
		})
	ranked_states.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance_m", 0.0)) < float(b.get("distance_m", 0.0))
	)

	var tier2_budget := int(_budget_contract.get("tier2_budget", DEFAULT_TIER_2_BUDGET))
	var tier1_budget := int(_budget_contract.get("tier1_budget", DEFAULT_TIER_1_BUDGET))
	var tier2_radius_m := float(_budget_contract.get("tier2_radius_m", DEFAULT_TIER_2_RADIUS_M))
	var tier1_states: Array[Dictionary] = []
	var tier2_states: Array[Dictionary] = []
	var tier1_count := 0
	var tier2_count := 0
	var tier0_count := 0
	for ranked_state_variant in ranked_states:
		var ranked_state: Dictionary = ranked_state_variant
		var state: CityPedestrianState = _states_by_id.get(str(ranked_state.get("pedestrian_id", "")))
		if state == null:
			continue
		var distance_m := float(ranked_state.get("distance_m", 0.0))
		if distance_m <= tier2_radius_m and tier2_count < tier2_budget:
			state.set_tier(CityPedestrianState.TIER_2)
			tier2_count += 1
			tier2_states.append(state.to_snapshot())
		elif tier1_count < tier1_budget:
			state.set_tier(CityPedestrianState.TIER_1)
			tier1_count += 1
			tier1_states.append(state.to_snapshot())
		else:
			state.set_tier(CityPedestrianState.TIER_0)
			tier0_count += 1

	_chunk_snapshots.clear()
	for chunk_id in active_chunk_ids:
		var chunk_state_ids: Array[String] = _chunk_state_ids.get(chunk_id, [])
		var chunk_tier1_states: Array[Dictionary] = []
		var chunk_tier2_states: Array[Dictionary] = []
		var chunk_tier0_count := 0
		for pedestrian_id in chunk_state_ids:
			var state: CityPedestrianState = _states_by_id.get(str(pedestrian_id))
			if state == null:
				continue
			match state.tier:
				CityPedestrianState.TIER_1:
					chunk_tier1_states.append(state.to_snapshot())
				CityPedestrianState.TIER_2:
					chunk_tier2_states.append(state.to_snapshot())
				_:
					chunk_tier0_count += 1
		_chunk_snapshots[chunk_id] = {
			"chunk_id": chunk_id,
			"tier0_count": chunk_tier0_count,
			"tier1_count": chunk_tier1_states.size(),
			"tier2_count": chunk_tier2_states.size(),
			"tier1_states": chunk_tier1_states,
			"tier2_states": chunk_tier2_states,
		}

	_global_snapshot = {
		"preset": str(_budget_contract.get("preset", DEFAULT_PRESET)),
		"active_chunk_count": active_chunk_ids.size(),
		"active_state_count": active_states.size(),
		"tier0_count": tier0_count,
		"tier1_count": tier1_count,
		"tier2_count": tier2_count,
		"tier1_budget": tier1_budget,
		"tier2_budget": tier2_budget,
		"tier2_radius_m": tier2_radius_m,
		"tier1_states": tier1_states,
		"tier2_states": tier2_states,
	}
	return _global_snapshot.duplicate(true)

func get_global_snapshot() -> Dictionary:
	return _global_snapshot.duplicate(true)

func get_chunk_snapshot(chunk_id: String) -> Dictionary:
	if not _chunk_snapshots.has(chunk_id):
		return {
			"chunk_id": chunk_id,
			"tier0_count": 0,
			"tier1_count": 0,
			"tier2_count": 0,
			"tier1_states": [],
			"tier2_states": [],
		}
	return (_chunk_snapshots[chunk_id] as Dictionary).duplicate(true)

func get_state_snapshot(pedestrian_id: String) -> Dictionary:
	var state: CityPedestrianState = _states_by_id.get(pedestrian_id)
	if state == null:
		return {}
	return state.to_snapshot()

func _ensure_chunk_states(chunk_key: Vector2i) -> Array:
	var chunk_id: String = str(_config.format_chunk_id(chunk_key))
	if not _chunk_state_ids.has(chunk_id):
		var chunk_query: Dictionary = _pedestrian_query.get_pedestrian_query_for_chunk(chunk_key)
		var chunk_state_ids: Array[String] = []
		for spawn_slot_variant in chunk_query.get("spawn_slots", []):
			var spawn_slot: Dictionary = spawn_slot_variant
			var state: CityPedestrianState = _build_state(chunk_id, spawn_slot)
			_states_by_id[state.pedestrian_id] = state
			chunk_state_ids.append(state.pedestrian_id)
		_chunk_state_ids[chunk_id] = chunk_state_ids
	var states: Array = []
	var state_ids: Array[String] = _chunk_state_ids.get(chunk_id, [])
	for pedestrian_id in state_ids:
		var state: CityPedestrianState = _states_by_id.get(str(pedestrian_id))
		if state != null:
			states.append(state)
	return states

func _build_state(chunk_id: String, spawn_slot: Dictionary) -> CityPedestrianState:
	var descriptor: Dictionary = _archetype_catalog.build_descriptor(spawn_slot)
	var lane: Dictionary = _lane_graph.get_lane_by_id(str(spawn_slot.get("lane_ref_id", ""))) if _lane_graph != null else {}
	var state: CityPedestrianState = CityPedestrianState.new()
	var lane_points: Array = lane.get("points", [])
	state.setup({
		"pedestrian_id": "ped:%s" % str(spawn_slot.get("spawn_slot_id", "")),
		"chunk_id": chunk_id,
		"spawn_slot_id": str(spawn_slot.get("spawn_slot_id", "")),
		"lane_ref_id": str(spawn_slot.get("lane_ref_id", "")),
		"route_signature": "%s|%s|%s" % [
			str(spawn_slot.get("lane_ref_id", "")),
			str(spawn_slot.get("side", "")),
			str(spawn_slot.get("road_class", "")),
		],
		"archetype_id": str(descriptor.get("archetype_id", "resident")),
		"archetype_signature": str(descriptor.get("archetype_signature", "resident:v0")),
		"seed": int(spawn_slot.get("seed", 0)),
		"height_m": float(descriptor.get("height_m", 1.75)),
		"radius_m": float(descriptor.get("radius_m", 0.28)),
		"speed_mps": float(descriptor.get("speed_mps", 1.25)),
		"stride_phase": float(descriptor.get("stride_phase", 0.0)),
		"route_progress": fposmod(float(posmod(int(spawn_slot.get("seed", 0)), 997)) / 997.0, 1.0),
		"world_position": spawn_slot.get("world_position", Vector3.ZERO),
		"lane_points": lane_points,
		"lane_length_m": float(lane.get("path_length_m", 0.0)),
		"tint": descriptor.get("tint", Color(0.7, 0.74, 0.78, 1.0)),
	})
	_ground_state(state)
	return state

func _ground_state(state: CityPedestrianState) -> void:
	state.apply_ground_height(CityTerrainSampler.sample_height(state.world_position.x, state.world_position.z, _world_seed))
