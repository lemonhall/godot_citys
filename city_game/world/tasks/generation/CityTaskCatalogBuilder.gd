extends RefCounted

const CityAddressGrammar := preload("res://city_game/world/model/CityAddressGrammar.gd")
const CityChunkKey := preload("res://city_game/world/streaming/CityChunkKey.gd")
const CityPlaceIndexBuilder := preload("res://city_game/world/generation/CityPlaceIndexBuilder.gd")
const CityResolvedTarget := preload("res://city_game/world/model/CityResolvedTarget.gd")

const FALLBACK_NAME_POOL := [
	"Aster",
	"Briar",
	"Cedar",
	"Dawn",
	"Ember",
	"Fable",
	"Grove",
	"Harbor",
]

const SAMPLE_TASK_BLUEPRINTS := [
	{
		"task_id": "task_courier_pickup",
		"title": "Courier Pickup",
		"icon_id": "task_delivery",
		"start_target": Vector2(-768.0, -512.0),
		"objective_target": Vector2(1664.0, 640.0),
	},
	{
		"task_id": "task_cross_town_run",
		"title": "Cross-Town Run",
		"icon_id": "task_drive",
		"start_target": Vector2(448.0, -1856.0),
		"objective_target": Vector2(-2176.0, 1216.0),
	},
	{
		"task_id": "task_harbor_lookup",
		"title": "Harbor Lookup",
		"icon_id": "task_search",
		"start_target": Vector2(2048.0, 1856.0),
		"objective_target": Vector2(-1280.0, -1664.0),
	},
]

func build(config, block_layout, vehicle_query, name_candidate_catalog: Dictionary = {}) -> Dictionary:
	var definitions: Array[Dictionary] = []
	var slots: Array[Dictionary] = []
	var used_candidate_ids: Dictionary = {}
	var name_pool := _resolve_name_pool(name_candidate_catalog)
	for task_index in range(SAMPLE_TASK_BLUEPRINTS.size()):
		var blueprint: Dictionary = SAMPLE_TASK_BLUEPRINTS[task_index]
		var built := _build_task(config, block_layout, vehicle_query, name_pool, blueprint, task_index, used_candidate_ids)
		if built.is_empty():
			continue
		definitions.append(built.get("definition", {}))
		slots.append_array(built.get("slots", []))
	return {
		"definitions": definitions,
		"slots": slots,
	}

func _build_task(config, block_layout, vehicle_query, name_pool: Array, blueprint: Dictionary, task_index: int, used_candidate_ids: Dictionary) -> Dictionary:
	var task_id := str(blueprint.get("task_id", ""))
	if task_id == "":
		return {}
	var start_location_name := _build_location_name(name_pool, task_index * 2, ["Plaza", "Yard", "Square", "Depot"])
	var objective_location_name := _build_location_name(name_pool, task_index * 2 + 1, ["Tower", "Terminal", "Arcade", "Exchange"])
	var start_slot := _build_slot(
		config,
		block_layout,
		vehicle_query,
		task_id,
		"start",
		blueprint.get("start_target", Vector2.ZERO),
		start_location_name,
		"task_available_start",
		18.0,
		used_candidate_ids
	)
	var objective_slot := _build_slot(
		config,
		block_layout,
		vehicle_query,
		task_id,
		"objective",
		blueprint.get("objective_target", Vector2.ZERO),
		objective_location_name,
		"task_active_objective",
		14.0,
		used_candidate_ids
	)
	if start_slot.is_empty() or objective_slot.is_empty():
		return {}
	var definition := {
		"task_id": task_id,
		"title": str(blueprint.get("title", task_id)),
		"summary": "Enter the start ring near %s, then reach %s." % [start_location_name, objective_location_name],
		"icon_id": str(blueprint.get("icon_id", "task")),
		"initial_status": "available",
		"start_slot": str(start_slot.get("slot_id", "")),
		"objective_slots": [str(objective_slot.get("slot_id", ""))],
		"auto_track_on_start": true,
	}
	return {
		"definition": definition,
		"slots": [start_slot, objective_slot],
	}

func _build_slot(config, block_layout, vehicle_query, task_id: String, slot_kind: String, target_2d: Vector2, display_name: String, marker_theme: String, trigger_radius_m: float, used_candidate_ids: Dictionary) -> Dictionary:
	var candidate := _pick_block_anchor_near_target(config, block_layout, target_2d, used_candidate_ids)
	var world_anchor: Vector3 = candidate.get("world_anchor", Vector3(target_2d.x, 0.0, target_2d.y))
	var routable_anchor := CityPlaceIndexBuilder.snap_world_anchor_to_driving_lane(vehicle_query, world_anchor)
	var slot_id := "%s:%s" % [task_id, slot_kind]
	var route_target := _build_slot_route_target(slot_id, display_name, world_anchor, routable_anchor, str(candidate.get("district_id", "")))
	return {
		"slot_id": slot_id,
		"task_id": task_id,
		"slot_kind": slot_kind,
		"world_anchor": world_anchor,
		"trigger_radius_m": trigger_radius_m,
		"marker_theme": marker_theme,
		"route_target_override": route_target,
		"display_name": display_name,
		"district_id": str(candidate.get("district_id", "")),
	}

func _pick_block_anchor_near_target(config, block_layout, target_2d: Vector2, used_candidate_ids: Dictionary) -> Dictionary:
	if config == null or block_layout == null:
		return {
			"world_anchor": Vector3(target_2d.x, 0.0, target_2d.y),
			"district_id": "",
		}
	var center_chunk := CityChunkKey.world_to_chunk_key(config, Vector3(target_2d.x, 0.0, target_2d.y))
	for search_radius in range(0, 3):
		var best_candidate := {}
		var best_distance := INF
		for chunk_key in CityChunkKey.get_window_keys(config, center_chunk, search_radius):
			for block_variant in block_layout.get_blocks_for_chunk(chunk_key):
				var block: Dictionary = block_variant
				for parcel_variant in block_layout.get_parcels_for_block(block):
					var parcel: Dictionary = parcel_variant
					var candidate_id := str(parcel.get("parcel_id", ""))
					if candidate_id == "" or used_candidate_ids.has(candidate_id):
						continue
					var frontage_slots: Array = block_layout.get_frontage_slots_for_parcel(block, parcel)
					if frontage_slots.is_empty():
						continue
					var frontage: Dictionary = frontage_slots[0]
					var anchor_2d: Vector2 = frontage.get("world_anchor", parcel.get("center_2d", block.get("center_2d", target_2d)))
					var distance_m := anchor_2d.distance_to(target_2d)
					if distance_m < best_distance:
						best_distance = distance_m
						best_candidate = {
							"candidate_id": candidate_id,
							"world_anchor": Vector3(anchor_2d.x, 0.0, anchor_2d.y),
							"district_id": str(block.get("district_id", "")),
						}
		if not best_candidate.is_empty():
			used_candidate_ids[best_candidate.get("candidate_id", "")] = true
			return best_candidate
	return {
		"world_anchor": Vector3(target_2d.x, 0.0, target_2d.y),
		"district_id": "",
	}

func _build_slot_route_target(slot_id: String, display_name: String, world_anchor: Vector3, routable_anchor: Vector3, district_id: String) -> Dictionary:
	var synthetic_entry := {
		"place_id": "task_slot:%s" % slot_id,
		"place_type": "task_slot",
		"display_name": display_name,
		"normalized_name": CityAddressGrammar.new().normalize_name(display_name),
		"world_anchor": world_anchor,
		"routable_anchor": routable_anchor,
		"district_id": district_id,
		"source_version": "v14-task-slot-1",
	}
	return CityResolvedTarget.build_from_place_entry(
		synthetic_entry,
		"task_slot",
		slot_id,
		world_anchor,
		"task_slot"
	)

func _resolve_name_pool(name_candidate_catalog: Dictionary) -> Array:
	var pool: Array = name_candidate_catalog.get("landmark_proper_name_pool", [])
	if pool.is_empty():
		return FALLBACK_NAME_POOL.duplicate()
	return pool.duplicate()

func _build_location_name(name_pool: Array, name_index: int, suffixes: Array) -> String:
	var base_name := str(name_pool[posmod(name_index, name_pool.size())])
	var suffix := str(suffixes[posmod(name_index, suffixes.size())])
	return "%s %s" % [base_name, suffix]
