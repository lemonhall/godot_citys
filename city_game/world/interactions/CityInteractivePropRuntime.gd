extends Node

const GROUP_NAME := "city_interactable_prop"
const DEFAULT_KICK_PROMPT_TEXT := "按 E 踢球"
const DEFAULT_INTERACTION_PROMPT_TEXT := "按 E 交互"

var _player: Node3D = null
var _active_node: Node3D = null
var _active_contract: Dictionary = {}
var _state: Dictionary = _build_hidden_state()

func setup(player_node: Node3D) -> void:
	_player = player_node

func refresh(blocked: bool = false) -> Dictionary:
	if blocked or _player == null or not is_instance_valid(_player):
		_clear_state()
		return get_state()
	var tree := get_tree()
	if tree == null:
		_clear_state()
		return get_state()
	var nearest_distance := INF
	var nearest_contract: Dictionary = {}
	var nearest_node: Node3D = null
	for node_variant in tree.get_nodes_in_group(GROUP_NAME):
		var actor := node_variant as Node3D
		if actor == null or not is_instance_valid(actor) or not actor.has_method("get_interaction_contract"):
			continue
		var contract: Dictionary = actor.get_interaction_contract()
		var prop_id := str(contract.get("prop_id", ""))
		var interaction_kind := str(contract.get("interaction_kind", ""))
		var radius_m := float(contract.get("interaction_radius_m", 0.0))
		if prop_id == "" or interaction_kind == "" or radius_m <= 0.0:
			continue
		var planar_distance := _resolve_planar_distance_m(actor.global_position)
		if planar_distance > radius_m:
			continue
		if planar_distance >= nearest_distance:
			continue
		nearest_distance = planar_distance
		nearest_contract = contract.duplicate(true)
		nearest_node = actor
	if nearest_contract.is_empty() or nearest_node == null:
		_clear_state()
		return get_state()
	_active_node = nearest_node
	_active_contract = nearest_contract.duplicate(true)
	_state = {
		"visible": true,
		"owner_kind": "interactive_prop",
		"prop_id": str(nearest_contract.get("prop_id", "")),
		"display_name": str(nearest_contract.get("display_name", "")),
		"interaction_kind": str(nearest_contract.get("interaction_kind", "")),
		"prompt_text": _resolve_prompt_text(nearest_contract),
		"distance_m": snappedf(nearest_distance, 0.01),
	}
	return get_state()

func get_state() -> Dictionary:
	return _state.duplicate(true)

func get_active_contract() -> Dictionary:
	return _active_contract.duplicate(true)

func has_active_candidate() -> bool:
	return bool(_state.get("visible", false)) and not _active_contract.is_empty()

func trigger_active_interaction(player_node: Node3D = null) -> Dictionary:
	if _active_node == null or not is_instance_valid(_active_node):
		return {
			"success": false,
			"error": "missing_active_prop",
		}
	if not _active_node.has_method("apply_player_interaction"):
		return {
			"success": false,
			"error": "missing_apply_player_interaction",
			"prop_id": str(_active_contract.get("prop_id", "")),
		}
	var resolved_player := player_node
	if resolved_player == null:
		resolved_player = _player
	if resolved_player == null or not is_instance_valid(resolved_player):
		return {
			"success": false,
			"error": "missing_player",
			"prop_id": str(_active_contract.get("prop_id", "")),
		}
	var interaction_result: Variant = _active_node.apply_player_interaction(resolved_player, _active_contract.duplicate(true))
	if not (interaction_result is Dictionary):
		return {
			"success": false,
			"error": "invalid_interaction_result",
			"prop_id": str(_active_contract.get("prop_id", "")),
		}
	var result: Dictionary = interaction_result
	if not result.has("prop_id"):
		result["prop_id"] = str(_active_contract.get("prop_id", ""))
	if not result.has("interaction_kind"):
		result["interaction_kind"] = str(_active_contract.get("interaction_kind", ""))
	return result

func _clear_state() -> void:
	_active_node = null
	_active_contract.clear()
	_state = _build_hidden_state()

func _build_hidden_state() -> Dictionary:
	return {
		"visible": false,
		"owner_kind": "",
		"prop_id": "",
		"display_name": "",
		"interaction_kind": "",
		"prompt_text": "",
		"distance_m": 0.0,
	}

func _resolve_prompt_text(contract: Dictionary) -> String:
	var prompt_text := str(contract.get("prompt_text", "")).strip_edges()
	if prompt_text != "":
		return prompt_text
	if str(contract.get("interaction_kind", "")) == "kick":
		return DEFAULT_KICK_PROMPT_TEXT
	return DEFAULT_INTERACTION_PROMPT_TEXT

func _resolve_planar_distance_m(target_world_position: Vector3) -> float:
	var player_position := _player.global_position
	return Vector2(player_position.x - target_world_position.x, player_position.z - target_world_position.z).length()
