extends Node3D

const GROUP_NAME := "city_interactable_npc"

@export var actor_id := ""
@export var display_name := ""
@export var interaction_kind := ""
@export var interaction_radius_m := 5.0
@export var dialogue_id := ""
@export_multiline var opening_line := ""

func _ready() -> void:
	_sync_group_membership()

func get_interaction_contract() -> Dictionary:
	var resolved_actor_id := actor_id.strip_edges()
	var resolved_display_name := display_name.strip_edges()
	var resolved_kind := interaction_kind.strip_edges()
	var resolved_dialogue_id := dialogue_id.strip_edges()
	var resolved_opening_line := opening_line.strip_edges()
	if resolved_actor_id == "" and has_meta("city_service_actor_id"):
		resolved_actor_id = str(get_meta("city_service_actor_id", "")).strip_edges()
	if resolved_display_name == "":
		resolved_display_name = str(get_meta("city_service_actor_role", "")).strip_edges()
	return {
		"actor_id": resolved_actor_id,
		"display_name": resolved_display_name,
		"interaction_kind": resolved_kind,
		"interaction_radius_m": maxf(interaction_radius_m, 0.0),
		"dialogue_id": resolved_dialogue_id,
		"opening_line": resolved_opening_line,
	}

func is_interactable_npc_enabled() -> bool:
	var contract := get_interaction_contract()
	return str(contract.get("actor_id", "")) != "" \
		and str(contract.get("interaction_kind", "")) != "" \
		and float(contract.get("interaction_radius_m", 0.0)) > 0.0

func _sync_group_membership() -> void:
	if not is_inside_tree():
		return
	if is_in_group(GROUP_NAME):
		return
	if is_interactable_npc_enabled():
		add_to_group(GROUP_NAME)
		return
