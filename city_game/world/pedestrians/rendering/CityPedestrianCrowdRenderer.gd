extends Node3D

const CityPedestrianCrowdBatch := preload("res://city_game/world/pedestrians/rendering/CityPedestrianCrowdBatch.gd")
const CityPedestrianReactiveAgent := preload("res://city_game/world/pedestrians/simulation/CityPedestrianReactiveAgent.gd")

var _chunk_center := Vector3.ZERO
var _pedestrian_batch: CityPedestrianCrowdBatch = null
var _tier2_root: Node3D = null
var _tier2_agents: Dictionary = {}
var _tier3_root: Node3D = null
var _tier3_agents: Dictionary = {}
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

func setup(chunk_data: Dictionary) -> void:
	_chunk_center = chunk_data.get("chunk_center", Vector3.ZERO)
	_ensure_nodes()
	apply_chunk_snapshot(chunk_data.get("pedestrian_chunk_snapshot", {}))

func apply_chunk_snapshot(snapshot: Dictionary) -> void:
	_ensure_nodes()
	var normalized_snapshot := _normalize_snapshot(snapshot)
	_last_snapshot = normalized_snapshot
	var tier1_states: Array = normalized_snapshot.get("tier1_states", [])
	_pedestrian_batch.configure_from_states(tier1_states, _chunk_center)
	_sync_tier2_agents(normalized_snapshot.get("tier2_states", []))
	_sync_tier3_agents(normalized_snapshot.get("tier3_states", []))

func get_batch() -> MultiMeshInstance3D:
	_ensure_nodes()
	return _pedestrian_batch

func get_crowd_stats() -> Dictionary:
	return {
		"tier0_count": int(_last_snapshot.get("tier0_count", 0)),
		"tier1_count": int(_last_snapshot.get("tier1_count", 0)),
		"tier2_count": int(_last_snapshot.get("tier2_count", 0)),
		"tier3_count": int(_last_snapshot.get("tier3_count", 0)),
		"tier1_instance_count": _pedestrian_batch.multimesh.instance_count if _pedestrian_batch != null and _pedestrian_batch.multimesh != null else 0,
	}

func _ensure_nodes() -> void:
	if _pedestrian_batch == null:
		_pedestrian_batch = CityPedestrianCrowdBatch.new()
		add_child(_pedestrian_batch)
	if _tier2_root == null:
		_tier2_root = Node3D.new()
		_tier2_root.name = "Tier2Agents"
		add_child(_tier2_root)
	if _tier3_root == null:
		_tier3_root = Node3D.new()
		_tier3_root.name = "Tier3Agents"
		add_child(_tier3_root)

func _sync_tier2_agents(states: Array) -> void:
	var keep_ids: Dictionary = {}
	for state_variant in states:
		var state: Dictionary = state_variant
		var pedestrian_id := str(state.get("pedestrian_id", ""))
		keep_ids[pedestrian_id] = true
		var agent_root: Node3D = _tier2_agents.get(pedestrian_id)
		if agent_root == null:
			agent_root = _build_tier2_agent(pedestrian_id)
			_tier2_agents[pedestrian_id] = agent_root
			_tier2_root.add_child(agent_root)
		_apply_state_to_agent(agent_root, state)
	for pedestrian_id in _tier2_agents.keys():
		if keep_ids.has(str(pedestrian_id)):
			continue
		var agent_root: Node3D = _tier2_agents[pedestrian_id]
		if agent_root != null and is_instance_valid(agent_root):
			agent_root.queue_free()
		_tier2_agents.erase(pedestrian_id)

func _sync_tier3_agents(states: Array) -> void:
	var keep_ids: Dictionary = {}
	for state_variant in states:
		var state: Dictionary = state_variant
		var pedestrian_id := str(state.get("pedestrian_id", ""))
		keep_ids[pedestrian_id] = true
		var agent_root: CityPedestrianReactiveAgent = _tier3_agents.get(pedestrian_id)
		if agent_root == null:
			agent_root = CityPedestrianReactiveAgent.new()
			agent_root.name = pedestrian_id.replace(":", "_")
			_tier3_agents[pedestrian_id] = agent_root
			_tier3_root.add_child(agent_root)
		agent_root.apply_state(state, _chunk_center)
	for pedestrian_id in _tier3_agents.keys():
		if keep_ids.has(str(pedestrian_id)):
			continue
		var agent_root: CityPedestrianReactiveAgent = _tier3_agents[pedestrian_id]
		if agent_root != null and is_instance_valid(agent_root):
			agent_root.queue_free()
		_tier3_agents.erase(pedestrian_id)

func _build_tier2_agent(pedestrian_id: String) -> Node3D:
	var root := Node3D.new()
	root.name = pedestrian_id.replace(":", "_")
	var body := MeshInstance3D.new()
	body.name = "Body"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.36, 1.0, 0.3)
	body.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.756863, 0.760784, 0.737255, 1.0)
	material.roughness = 1.0
	body.material_override = material
	root.add_child(body)
	return root

func _apply_state_to_agent(agent_root: Node3D, state: Dictionary) -> void:
	var world_position: Vector3 = state.get("world_position", Vector3.ZERO)
	var local_position := world_position - _chunk_center
	var heading: Vector3 = state.get("heading", Vector3.FORWARD)
	heading.y = 0.0
	if heading.length_squared() <= 0.0001:
		heading = Vector3.FORWARD
	heading = heading.normalized()
	var height_m := float(state.get("height_m", 1.75))
	var radius_m := float(state.get("radius_m", 0.28))
	agent_root.position = Vector3(local_position.x, local_position.y + height_m * 0.5, local_position.z)
	agent_root.rotation.y = atan2(heading.x, heading.z)
	var body := agent_root.get_node_or_null("Body") as MeshInstance3D
	if body != null:
		body.scale = Vector3(radius_m * 2.0, height_m, radius_m * 1.8)

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
