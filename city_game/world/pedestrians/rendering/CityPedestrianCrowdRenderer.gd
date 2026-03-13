extends Node3D

const CityPedestrianCrowdBatch := preload("res://city_game/world/pedestrians/rendering/CityPedestrianCrowdBatch.gd")
const CityPedestrianVisualInstance := preload("res://city_game/world/pedestrians/rendering/CityPedestrianVisualInstance.gd")
const CityPedestrianReactiveAgent := preload("res://city_game/world/pedestrians/simulation/CityPedestrianReactiveAgent.gd")

const DEATH_VISUAL_DURATION_SEC := 3.0

var _chunk_center := Vector3.ZERO
var _pedestrian_batch: CityPedestrianCrowdBatch = null
var _tier2_root: Node3D = null
var _tier2_agents: Dictionary = {}
var _tier3_root: Node3D = null
var _tier3_agents: Dictionary = {}
var _death_root: Node3D = null
var _death_visuals: Array[Dictionary] = []
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

func setup(chunk_data: Dictionary) -> void:
	_chunk_center = chunk_data.get("chunk_center", Vector3.ZERO)
	_ensure_nodes()
	var initial_snapshot: Dictionary = chunk_data.get("pedestrian_chunk_snapshot", {})
	if not initial_snapshot.is_empty():
		apply_chunk_snapshot(initial_snapshot)

func apply_chunk_snapshot(snapshot: Dictionary) -> int:
	_ensure_nodes()
	var normalized_snapshot := _normalize_snapshot(snapshot)
	_last_snapshot = normalized_snapshot
	var tier1_states: Array = normalized_snapshot.get("tier1_states", [])
	_last_tier1_transform_write_count = _pedestrian_batch.configure_from_states(tier1_states, _chunk_center)
	_sync_tier2_agents(normalized_snapshot.get("tier2_states", []))
	_sync_tier3_agents(normalized_snapshot.get("tier3_states", []))
	return _last_tier1_transform_write_count

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
		"tier1_transform_write_count": _last_tier1_transform_write_count,
	}

func spawn_pedestrian_death_visual(event: Dictionary) -> void:
	_ensure_nodes()
	var death_visual := CityPedestrianVisualInstance.new()
	death_visual.name = "%s_dead_%d" % [
		str(event.get("pedestrian_id", "pedestrian")).replace(":", "_"),
		Time.get_ticks_usec(),
	]
	_death_root.add_child(death_visual)
	death_visual.apply_state(_build_death_visual_state(event), _chunk_center)
	var remaining_sec := float(event.get("duration_sec", DEATH_VISUAL_DURATION_SEC))
	death_visual.set_meta("death_event", event.duplicate(true))
	death_visual.set_meta("death_remaining_sec", remaining_sec)
	_death_visuals.append({
		"event": event.duplicate(true),
		"node": death_visual,
		"remaining_sec": remaining_sec,
	})

func drain_death_visuals(target_parent: Node3D) -> Array[Dictionary]:
	var transferred_records: Array[Dictionary] = []
	if target_parent == null:
		return transferred_records
	var remaining_sec_by_node: Dictionary = {}
	var event_by_node: Dictionary = {}
	for visual_record_variant in _death_visuals:
		var visual_record: Dictionary = visual_record_variant
		var source_node := visual_record.get("node") as Node3D
		if source_node == null or not is_instance_valid(source_node):
			continue
		remaining_sec_by_node[source_node] = float(visual_record.get("remaining_sec", DEATH_VISUAL_DURATION_SEC))
		event_by_node[source_node] = (visual_record.get("event", {}) as Dictionary).duplicate(true)
	if _death_root == null:
		_death_visuals.clear()
		return transferred_records
	for child in _death_root.get_children():
		var source_node := child as Node3D
		if source_node == null or not is_instance_valid(source_node):
			continue
		var event: Dictionary = {}
		if source_node.has_meta("death_event"):
			event = (source_node.get_meta("death_event", {}) as Dictionary).duplicate(true)
		elif event_by_node.has(source_node):
			event = (event_by_node[source_node] as Dictionary).duplicate(true)
		var remaining_sec := float(source_node.get_meta("death_remaining_sec", remaining_sec_by_node.get(source_node, DEATH_VISUAL_DURATION_SEC)))
		var migrated_node: Node3D = null
		if not event.is_empty():
			var death_visual := CityPedestrianVisualInstance.new()
			death_visual.name = "%s_migrated_%d" % [
				str(event.get("pedestrian_id", "pedestrian")).replace(":", "_"),
				Time.get_ticks_usec(),
			]
			target_parent.add_child(death_visual)
			death_visual.apply_state(_build_death_visual_state(event), Vector3.ZERO)
			migrated_node = death_visual
		elif source_node != null and is_instance_valid(source_node):
			source_node.reparent(target_parent, true)
			migrated_node = source_node
		if source_node != null and is_instance_valid(source_node) and source_node != migrated_node:
			source_node.queue_free()
		if migrated_node == null or not is_instance_valid(migrated_node):
			continue
		transferred_records.append({
			"node": migrated_node,
			"remaining_sec": remaining_sec,
		})
	_death_visuals.clear()
	return transferred_records

func _process(delta: float) -> void:
	if delta <= 0.0 or _death_visuals.is_empty():
		return
	for visual_index in range(_death_visuals.size() - 1, -1, -1):
		var visual_record: Dictionary = _death_visuals[visual_index]
		var remaining_sec := maxf(float(visual_record.get("remaining_sec", 0.0)) - delta, 0.0)
		var visual_node := visual_record.get("node") as Node3D
		if remaining_sec <= 0.0:
			if visual_node != null and is_instance_valid(visual_node):
				visual_node.queue_free()
			_death_visuals.remove_at(visual_index)
			continue
		if visual_node != null and is_instance_valid(visual_node):
			visual_node.set_meta("death_remaining_sec", remaining_sec)
		visual_record["remaining_sec"] = remaining_sec
		_death_visuals[visual_index] = visual_record

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
	if _death_root == null:
		_death_root = Node3D.new()
		_death_root.name = "DeathVisuals"
		add_child(_death_root)

func _sync_tier2_agents(states: Array) -> void:
	var keep_ids: Dictionary = {}
	for state_variant in states:
		var pedestrian_id := _state_pedestrian_id(state_variant)
		keep_ids[pedestrian_id] = true
		var agent_root: Node3D = _tier2_agents.get(pedestrian_id)
		if agent_root == null:
			agent_root = _build_tier2_agent(pedestrian_id)
			_tier2_agents[pedestrian_id] = agent_root
			_tier2_root.add_child(agent_root)
		_apply_state_to_agent(agent_root, state_variant)
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
		var pedestrian_id := _state_pedestrian_id(state_variant)
		keep_ids[pedestrian_id] = true
		var agent_root: CityPedestrianReactiveAgent = _tier3_agents.get(pedestrian_id)
		if agent_root == null:
			agent_root = CityPedestrianReactiveAgent.new()
			agent_root.name = pedestrian_id.replace(":", "_")
			_tier3_agents[pedestrian_id] = agent_root
			_tier3_root.add_child(agent_root)
		agent_root.apply_state(state_variant, _chunk_center)
	for pedestrian_id in _tier3_agents.keys():
		if keep_ids.has(str(pedestrian_id)):
			continue
		var agent_root: CityPedestrianReactiveAgent = _tier3_agents[pedestrian_id]
		if agent_root != null and is_instance_valid(agent_root):
			agent_root.queue_free()
		_tier3_agents.erase(pedestrian_id)

func _build_tier2_agent(pedestrian_id: String) -> Node3D:
	var root := CityPedestrianVisualInstance.new()
	root.name = pedestrian_id.replace(":", "_")
	return root

func _apply_state_to_agent(agent_root: Node3D, state) -> void:
	if agent_root != null and agent_root.has_method("apply_state"):
		agent_root.apply_state(state, _chunk_center)
		return
	var world_position := _state_world_position(state)
	var local_position := world_position - _chunk_center
	agent_root.position = local_position

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

func _state_pedestrian_id(state) -> String:
	if state is Dictionary:
		return str((state as Dictionary).get("pedestrian_id", ""))
	return str(state.pedestrian_id) if state != null else ""

func _state_world_position(state) -> Vector3:
	if state is Dictionary:
		return (state as Dictionary).get("world_position", Vector3.ZERO)
	return state.world_position if state != null else Vector3.ZERO

func _state_heading(state) -> Vector3:
	if state is Dictionary:
		return (state as Dictionary).get("heading", Vector3.FORWARD)
	return state.heading if state != null else Vector3.FORWARD

func _state_height_m(state) -> float:
	if state is Dictionary:
		return float((state as Dictionary).get("height_m", 1.75))
	return float(state.height_m) if state != null else 1.75

func _state_radius_m(state) -> float:
	if state is Dictionary:
		return float((state as Dictionary).get("radius_m", 0.28))
	return float(state.radius_m) if state != null else 0.28

func _build_death_visual_state(event: Dictionary) -> Dictionary:
	return {
		"pedestrian_id": str(event.get("pedestrian_id", "")),
		"world_position": event.get("world_position", Vector3.ZERO),
		"heading": event.get("heading", Vector3.FORWARD),
		"height_m": float(event.get("height_m", 1.75)),
		"radius_m": float(event.get("radius_m", 0.28)),
		"seed": int(event.get("seed", 0)),
		"archetype_id": str(event.get("archetype_id", "resident")),
		"archetype_signature": str(event.get("archetype_signature", "resident:v0")),
		"reaction_state": "none",
		"life_state": "dead",
	}
