extends Node3D

const CityVehicleTrafficBatch := preload("res://city_game/world/vehicles/rendering/CityVehicleTrafficBatch.gd")
const CityVehicleVisualCatalog := preload("res://city_game/world/vehicles/rendering/CityVehicleVisualCatalog.gd")
const CityVehicleVisualInstance := preload("res://city_game/world/vehicles/rendering/CityVehicleVisualInstance.gd")

var _chunk_center := Vector3.ZERO
var _vehicle_batch: CityVehicleTrafficBatch = null
var _tier2_root: Node3D = null
var _tier2_agents: Dictionary = {}
var _tier3_root: Node3D = null
var _tier3_agents: Dictionary = {}
var _visual_catalog: CityVehicleVisualCatalog = null
var _last_tier1_transform_write_count := 0
var _last_snapshot := {
	"chunk_id": "",
	"tier0_count": 0,
	"tier1_count": 0,
	"tier2_count": 0,
	"tier3_count": 0,
	"tier1_states": [],
	"tier2_states": [],
	"tier3_states": [],
}

static func prewarm_shared_resources() -> void:
	CityVehicleVisualCatalog.prewarm_shared_resources()
	CityVehicleVisualInstance.prewarm_shared_catalog()
	CityVehicleTrafficBatch.prewarm_shared_proxy_resources()

func setup(chunk_data: Dictionary) -> void:
	_chunk_center = chunk_data.get("chunk_center", Vector3.ZERO)
	var initial_snapshot: Dictionary = chunk_data.get("vehicle_chunk_snapshot", {})
	if not initial_snapshot.is_empty():
		apply_chunk_snapshot(initial_snapshot)

func apply_chunk_snapshot(snapshot: Dictionary) -> int:
	var normalized_snapshot := _normalize_snapshot(snapshot)
	_last_snapshot = normalized_snapshot
	if not _snapshot_has_visible_states(normalized_snapshot) and not _has_runtime_nodes():
		return 0
	_ensure_visual_catalog()
	_ensure_nodes()
	var tier1_states: Array = normalized_snapshot.get("tier1_states", [])
	_last_tier1_transform_write_count = _vehicle_batch.configure_from_states(tier1_states, _chunk_center, _visual_catalog)
	_sync_agents(normalized_snapshot.get("tier2_states", []), _tier2_root, _tier2_agents)
	_sync_agents(normalized_snapshot.get("tier3_states", []), _tier3_root, _tier3_agents)
	return _last_tier1_transform_write_count

func get_batch() -> MultiMeshInstance3D:
	_ensure_nodes()
	return _vehicle_batch

func get_vehicle_stats() -> Dictionary:
	return {
		"tier0_count": int(_last_snapshot.get("tier0_count", 0)),
		"tier1_count": int(_last_snapshot.get("tier1_count", 0)),
		"tier2_count": int(_last_snapshot.get("tier2_count", 0)),
		"tier3_count": int(_last_snapshot.get("tier3_count", 0)),
		"tier1_instance_count": _vehicle_batch.multimesh.instance_count if _vehicle_batch != null and _vehicle_batch.multimesh != null else 0,
		"tier1_transform_write_count": _last_tier1_transform_write_count,
		"tier2_node_count": _tier2_agents.size(),
		"tier3_node_count": _tier3_agents.size(),
	}

func _ensure_nodes() -> void:
	if _vehicle_batch == null:
		_vehicle_batch = CityVehicleTrafficBatch.new()
		add_child(_vehicle_batch)
	if _tier2_root == null:
		_tier2_root = Node3D.new()
		_tier2_root.name = "Tier2Vehicles"
		add_child(_tier2_root)
	if _tier3_root == null:
		_tier3_root = Node3D.new()
		_tier3_root.name = "Tier3Vehicles"
		add_child(_tier3_root)

func _ensure_visual_catalog() -> void:
	if _visual_catalog != null:
		return
	_visual_catalog = CityVehicleVisualCatalog.new()
	CityVehicleVisualInstance.prewarm_shared_catalog()

func _has_runtime_nodes() -> bool:
	return _vehicle_batch != null or _tier2_root != null or _tier3_root != null

func _snapshot_has_visible_states(snapshot: Dictionary) -> bool:
	return not (snapshot.get("tier1_states", []) as Array).is_empty() \
		or not (snapshot.get("tier2_states", []) as Array).is_empty() \
		or not (snapshot.get("tier3_states", []) as Array).is_empty()

func _sync_agents(states: Array, target_root: Node3D, agent_map: Dictionary) -> void:
	var keep_ids: Dictionary = {}
	for state_variant in states:
		var state: Dictionary = state_variant
		var vehicle_id := str(state.get("vehicle_id", ""))
		keep_ids[vehicle_id] = true
		var agent_root: CityVehicleVisualInstance = agent_map.get(vehicle_id)
		if agent_root == null:
			agent_root = CityVehicleVisualInstance.new()
			agent_root.name = vehicle_id.replace(":", "_")
			agent_root.setup(_visual_catalog)
			agent_map[vehicle_id] = agent_root
			target_root.add_child(agent_root)
		agent_root.apply_state(state, _chunk_center)
	for vehicle_id_variant in agent_map.keys():
		var vehicle_id := str(vehicle_id_variant)
		if keep_ids.has(vehicle_id):
			continue
		var agent_root: CityVehicleVisualInstance = agent_map[vehicle_id]
		if agent_root != null and is_instance_valid(agent_root):
			agent_root.queue_free()
		agent_map.erase(vehicle_id)

func _normalize_snapshot(snapshot: Dictionary) -> Dictionary:
	if snapshot.is_empty():
		return {
			"chunk_id": "",
			"tier0_count": 0,
			"tier1_count": 0,
			"tier2_count": 0,
			"tier3_count": 0,
			"tier1_states": [],
			"tier2_states": [],
			"tier3_states": [],
		}
	return {
		"chunk_id": str(snapshot.get("chunk_id", "")),
		"tier0_count": int(snapshot.get("tier0_count", 0)),
		"tier1_count": int(snapshot.get("tier1_count", 0)),
		"tier2_count": int(snapshot.get("tier2_count", 0)),
		"tier3_count": int(snapshot.get("tier3_count", 0)),
		"tier1_states": snapshot.get("tier1_states", []),
		"tier2_states": snapshot.get("tier2_states", []),
		"tier3_states": snapshot.get("tier3_states", []),
	}
