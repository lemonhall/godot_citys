extends Node

const CityInteractableNpc := preload("res://city_game/world/interactions/CityInteractableNpc.gd")
const PROMPT_TEXT := "可以按下 E 键交互"

var _player: Node3D = null
var _dialogue_runtime = null
var _active_contract: Dictionary = {}
var _state: Dictionary = _build_hidden_state()

func setup(player_node: Node3D, dialogue_runtime) -> void:
	_player = player_node
	_dialogue_runtime = dialogue_runtime

func refresh(blocked: bool = false) -> Dictionary:
	if blocked or _player == null or not is_instance_valid(_player) or _is_dialogue_active():
		_clear_state()
		return get_state()
	var tree := get_tree()
	if tree == null:
		_clear_state()
		return get_state()
	var nearest_distance := INF
	var nearest_contract: Dictionary = {}
	for node_variant in tree.get_nodes_in_group(CityInteractableNpc.GROUP_NAME):
		var actor := node_variant as Node3D
		if actor == null or not is_instance_valid(actor) or not actor.has_method("get_interaction_contract"):
			continue
		var contract: Dictionary = actor.get_interaction_contract()
		var actor_id := str(contract.get("actor_id", ""))
		var interaction_kind := str(contract.get("interaction_kind", ""))
		var radius_m := float(contract.get("interaction_radius_m", 0.0))
		if actor_id == "" or interaction_kind == "" or radius_m <= 0.0:
			continue
		var planar_distance := _resolve_planar_distance_m(actor.global_position)
		if planar_distance > radius_m:
			continue
		if planar_distance >= nearest_distance:
			continue
		nearest_distance = planar_distance
		nearest_contract = contract.duplicate(true)
	if nearest_contract.is_empty():
		_clear_state()
		return get_state()
	_active_contract = nearest_contract.duplicate(true)
	_state = {
		"visible": true,
		"actor_id": str(nearest_contract.get("actor_id", "")),
		"display_name": str(nearest_contract.get("display_name", "")),
		"prompt_text": PROMPT_TEXT,
		"distance_m": snappedf(nearest_distance, 0.01),
	}
	return get_state()

func get_state() -> Dictionary:
	return _state.duplicate(true)

func get_active_contract() -> Dictionary:
	return _active_contract.duplicate(true)

func has_active_candidate() -> bool:
	return bool(_state.get("visible", false)) and not _active_contract.is_empty()

func _clear_state() -> void:
	_active_contract.clear()
	_state = _build_hidden_state()

func _build_hidden_state() -> Dictionary:
	return {
		"visible": false,
		"actor_id": "",
		"display_name": "",
		"prompt_text": "",
		"distance_m": 0.0,
	}

func _resolve_planar_distance_m(target_world_position: Vector3) -> float:
	var player_position := _player.global_position
	return Vector2(player_position.x - target_world_position.x, player_position.z - target_world_position.z).length()

func _is_dialogue_active() -> bool:
	return _dialogue_runtime != null and _dialogue_runtime.has_method("is_active") and bool(_dialogue_runtime.is_active())

