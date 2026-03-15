extends RefCounted

const CityAddressGrammar := preload("res://city_game/world/model/CityAddressGrammar.gd")
const CityPlaceIndex := preload("res://city_game/world/model/CityPlaceIndex.gd")

const SOURCE_VERSION := CityPlaceIndex.SOURCE_VERSION
const LANDMARK_TARGET_COUNT := 4096
const ROUTABLE_SEARCH_RADIUS_OPTIONS := [128.0, 256.0, 512.0, 1024.0, 2048.0, 4096.0]

func build_index(config, road_graph, block_layout, street_cluster_catalog, name_candidate_catalog: Dictionary, vehicle_query) -> CityPlaceIndex:
	var entries: Array[Dictionary] = []
	var debug_sample_queries := {
		"road": "",
		"intersection": "",
		"landmark": "",
		"address": "",
	}

	var road_result := _build_road_entries(road_graph, street_cluster_catalog, vehicle_query)
	entries.append_array(road_result.get("entries", []))
	debug_sample_queries["road"] = str(road_result.get("sample_query", ""))

	var intersection_result := _build_intersection_entries(config, road_graph, street_cluster_catalog, vehicle_query)
	entries.append_array(intersection_result.get("entries", []))
	debug_sample_queries["intersection"] = str(intersection_result.get("sample_query", ""))

	var landmark_result := _build_landmark_entries(block_layout, name_candidate_catalog, vehicle_query)
	entries.append_array(landmark_result.get("entries", []))
	debug_sample_queries["landmark"] = str(landmark_result.get("sample_query", ""))

	debug_sample_queries["address"] = _build_debug_address_query(block_layout, road_graph, street_cluster_catalog, vehicle_query)

	var place_index := CityPlaceIndex.new()
	place_index.setup(entries, debug_sample_queries, {}, SOURCE_VERSION)
	return place_index

static func resolve_address_target_data(block_layout, road_graph, street_cluster_catalog, vehicle_query, block_serial_index: int, parcel_local_index: int, frontage_slot_index: int = 0) -> Dictionary:
	if block_layout == null:
		return {}
	var block_data: Dictionary = block_layout.get_block_data_by_serial_index(block_serial_index)
	if block_data.is_empty():
		return {}
	var parcel_data: Dictionary = block_layout.get_parcel_for_block(block_data, parcel_local_index)
	if parcel_data.is_empty():
		return {}
	var frontage_slots: Array = block_layout.get_frontage_slots_for_parcel(block_data, parcel_data)
	if frontage_slot_index < 0 or frontage_slot_index >= frontage_slots.size():
		return {}
	var slot_data: Dictionary = frontage_slots[frontage_slot_index]
	var canonical_road_name := resolve_canonical_road_name_for_parcel(road_graph, street_cluster_catalog, block_data, parcel_data)
	if canonical_road_name == "":
		return {}
	var grammar := CityAddressGrammar.new()
	var address_record := grammar.build_address_record(
		block_data,
		parcel_data,
		frontage_slot_index,
		canonical_road_name,
		str(parcel_data.get("frontage_side", ""))
	)
	var world_anchor_2d: Vector2 = slot_data.get("world_anchor", parcel_data.get("center_2d", block_data.get("center_2d", Vector2.ZERO)))
	var world_anchor := Vector3(world_anchor_2d.x, 0.0, world_anchor_2d.y)
	return {
		"block_data": block_data.duplicate(true),
		"parcel_data": parcel_data.duplicate(true),
		"slot_data": slot_data.duplicate(true),
		"canonical_road_name": canonical_road_name,
		"address_record": address_record.duplicate(true),
		"world_anchor": world_anchor,
		"routable_anchor": snap_world_anchor_to_driving_lane(vehicle_query, world_anchor),
	}

static func resolve_canonical_road_name_for_parcel(road_graph, street_cluster_catalog, block_data: Dictionary, parcel_data: Dictionary) -> String:
	if road_graph == null or street_cluster_catalog == null:
		return ""
	var block_rect: Rect2 = block_data.get("world_rect", Rect2())
	var center_2d: Vector2 = parcel_data.get("center_2d", block_data.get("center_2d", Vector2.ZERO))
	var search_margin := maxf(block_rect.size.x, block_rect.size.y) * 1.15 + 128.0
	var search_rect := block_rect.grow(search_margin)
	var preferred_orientation := _preferred_orientation_for_frontage(str(parcel_data.get("frontage_side", "")))
	var best_name := ""
	var best_score := INF
	for edge_variant in road_graph.get_edges_intersecting_rect(search_rect):
		var edge: Dictionary = edge_variant
		var edge_id := str(edge.get("edge_id", edge.get("road_id", "")))
		var canonical_name := str(street_cluster_catalog.get_edge_canonical_name(edge_id))
		if canonical_name == "":
			continue
		var points: Array = edge.get("points", [])
		var distance_m := _distance_point_to_polyline_2d(center_2d, points)
		var orientation_bucket := _orientation_bucket_from_points(points)
		var road_class := str(edge.get("class", "secondary"))
		var score := distance_m + _road_class_penalty(road_class)
		if orientation_bucket == preferred_orientation:
			score -= 18.0
		if block_rect.intersects(edge.get("bounds", Rect2()).grow(24.0)):
			score -= 8.0
		if score < best_score:
			best_score = score
			best_name = canonical_name
	return best_name

static func snap_world_anchor_to_driving_lane(vehicle_query, world_position: Vector3) -> Vector3:
	if vehicle_query == null or not vehicle_query.has_method("get_lane_graph"):
		return world_position
	var lane_graph = vehicle_query.get_lane_graph()
	if lane_graph == null or not lane_graph.has_method("get_lanes_intersecting_rect"):
		return world_position
	var point_2d := Vector2(world_position.x, world_position.z)
	var best_point := world_position
	var best_distance := INF
	for radius_variant in ROUTABLE_SEARCH_RADIUS_OPTIONS:
		var radius := float(radius_variant)
		var search_rect := Rect2(point_2d - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
		var lanes: Array = lane_graph.get_lanes_intersecting_rect(search_rect, ["driving"])
		if lanes.is_empty():
			continue
		for lane_variant in lanes:
			var lane: Dictionary = lane_variant
			var closest := _closest_point_on_polyline_3d(world_position, lane.get("points", []))
			var distance_m := float(closest.get("distance_m", INF))
			if distance_m < best_distance:
				best_distance = distance_m
				best_point = closest.get("world_point", world_position)
		if best_distance <= radius * 0.75:
			break
	return best_point

static func tokenize_string(value: String) -> Array[String]:
	var normalized := CityAddressGrammar.new().normalize_name(value)
	var tokens: Array[String] = []
	for token in normalized.split(" ", false):
		if token != "":
			tokens.append(token)
	return tokens

func _build_road_entries(road_graph, street_cluster_catalog, vehicle_query) -> Dictionary:
	var entries: Array[Dictionary] = []
	var sample_query := ""
	var clusters: Array = street_cluster_catalog.get_clusters()
	clusters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("street_cluster_id", "")) < str(b.get("street_cluster_id", ""))
	)
	for cluster_variant in clusters:
		var cluster: Dictionary = cluster_variant
		var cluster_id := str(cluster.get("street_cluster_id", ""))
		var canonical_name := str(cluster.get("canonical_name", ""))
		if cluster_id == "" or canonical_name == "":
			continue
		var representative_anchor_2d: Vector2 = cluster.get("representative_anchor", Vector2.ZERO)
		var world_anchor := Vector3(representative_anchor_2d.x, 0.0, representative_anchor_2d.y)
		var district_id := ""
		var edge_ids: Array = cluster.get("edge_ids", [])
		if not edge_ids.is_empty():
			var representative_edge: Dictionary = road_graph.get_edge_by_id(str(edge_ids[0]))
			district_id = str(representative_edge.get("from", ""))
		entries.append({
			"place_id": "road:%s" % cluster_id,
			"place_type": "road",
			"display_name": canonical_name,
			"normalized_name": str(cluster.get("normalized_name", "")),
			"world_anchor": world_anchor,
			"routable_anchor": snap_world_anchor_to_driving_lane(vehicle_query, world_anchor),
			"district_id": district_id,
			"search_tokens": tokenize_string(canonical_name),
			"source_version": SOURCE_VERSION,
		})
		if sample_query == "":
			sample_query = canonical_name
	return {
		"entries": entries,
		"sample_query": sample_query,
	}

func _build_intersection_entries(config, road_graph, street_cluster_catalog, vehicle_query) -> Dictionary:
	var grammar := CityAddressGrammar.new()
	var entries: Array[Dictionary] = []
	var sample_query := ""
	var intersections: Array = road_graph.get_intersections_in_rect(config.get_world_bounds())
	intersections.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("intersection_id", "")) < str(b.get("intersection_id", ""))
	)
	for intersection_variant in intersections:
		var intersection: Dictionary = intersection_variant
		var road_names := _collect_intersection_road_names(street_cluster_catalog, intersection)
		if road_names.size() < 2:
			continue
		var display_name := grammar.build_intersection_name(road_names[0], road_names[1])
		var position_2d: Vector2 = intersection.get("position", Vector2.ZERO)
		var world_anchor := Vector3(position_2d.x, 0.0, position_2d.y)
		var search_tokens := tokenize_string(display_name)
		for road_name in road_names:
			for token in tokenize_string(road_name):
				if not search_tokens.has(token):
					search_tokens.append(token)
		entries.append({
			"place_id": "intersection:%s" % str(intersection.get("intersection_id", "")),
			"place_type": "intersection",
			"display_name": display_name,
			"normalized_name": grammar.normalize_name(display_name),
			"world_anchor": world_anchor,
			"routable_anchor": snap_world_anchor_to_driving_lane(vehicle_query, world_anchor),
			"district_id": _resolve_intersection_district_id(road_graph, intersection),
			"search_tokens": search_tokens,
			"source_version": SOURCE_VERSION,
			"road_names": road_names.duplicate(),
		})
		if sample_query == "":
			sample_query = display_name
	return {
		"entries": entries,
		"sample_query": sample_query,
	}

func _build_landmark_entries(block_layout, name_candidate_catalog: Dictionary, vehicle_query) -> Dictionary:
	var entries: Array[Dictionary] = []
	var landmark_names: Array = name_candidate_catalog.get("landmark_proper_name_pool", [])
	if landmark_names.is_empty():
		return {
			"entries": entries,
			"sample_query": "",
		}
	var block_count: int = int(block_layout.get_block_count())
	var block_stride := maxi(int(floor(float(block_count) / float(LANDMARK_TARGET_COUNT))), 1)
	var block_serial_index := int(floor(float(block_stride) * 0.5))
	var landmark_index := 0
	while block_serial_index < block_count and landmark_index < LANDMARK_TARGET_COUNT:
		var block_data: Dictionary = block_layout.get_block_data_by_serial_index(block_serial_index)
		if not block_data.is_empty():
			var parcel_local_index := landmark_index % 4
			var parcel_data: Dictionary = block_layout.get_parcel_for_block(block_data, parcel_local_index)
			if not parcel_data.is_empty():
				var frontage_slots: Array = block_layout.get_frontage_slots_for_parcel(block_data, parcel_data)
				var slot_data: Dictionary = frontage_slots[0] if not frontage_slots.is_empty() else {}
				var world_anchor_2d: Vector2 = slot_data.get("world_anchor", parcel_data.get("center_2d", block_data.get("center_2d", Vector2.ZERO)))
				var world_anchor := Vector3(world_anchor_2d.x, 0.0, world_anchor_2d.y)
				var display_name := str(landmark_names[landmark_index % landmark_names.size()])
				entries.append({
					"place_id": "landmark:%s" % str(parcel_data.get("parcel_id", block_data.get("block_id", ""))),
					"place_type": "landmark",
					"display_name": display_name,
					"normalized_name": CityAddressGrammar.new().normalize_name(display_name),
					"world_anchor": world_anchor,
					"routable_anchor": snap_world_anchor_to_driving_lane(vehicle_query, world_anchor),
					"district_id": str(block_data.get("district_id", "")),
					"search_tokens": tokenize_string(display_name),
					"source_version": SOURCE_VERSION,
					"block_id": str(block_data.get("block_id", "")),
					"parcel_id": str(parcel_data.get("parcel_id", "")),
				})
			landmark_index += 1
		block_serial_index += block_stride
	var sample_query := ""
	var best_sample_score := INF
	for entry_variant in entries:
		var entry: Dictionary = entry_variant
		var world_anchor: Vector3 = entry.get("world_anchor", Vector3.ZERO)
		var sample_score := world_anchor.x * world_anchor.x + world_anchor.z * world_anchor.z
		if sample_score < best_sample_score:
			best_sample_score = sample_score
			sample_query = str(entry.get("display_name", ""))
	return {
		"entries": entries,
		"sample_query": sample_query,
	}

func _build_debug_address_query(block_layout, road_graph, street_cluster_catalog, vehicle_query) -> String:
	var block_count: int = int(block_layout.get_block_count())
	var block_stride := maxi(int(floor(float(block_count) / 2048.0)), 1)
	var center_block_serial := int(floor(float(block_count) * 0.5))
	for search_index in range(0, 2048):
		var signed_offset := search_index / 2
		if search_index % 2 == 1:
			signed_offset = -signed_offset
		var block_serial_index := clampi(center_block_serial + signed_offset * block_stride, 0, block_count - 1)
		for parcel_local_index in range(4):
			var resolved := resolve_address_target_data(
				block_layout,
				road_graph,
				street_cluster_catalog,
				vehicle_query,
				block_serial_index,
				parcel_local_index,
				0
			)
			if resolved.is_empty():
				continue
			var address_record: Dictionary = resolved.get("address_record", {})
			var display_name := str(address_record.get("display_name", ""))
			if display_name != "":
				return display_name
	return ""

func _collect_intersection_road_names(street_cluster_catalog, intersection: Dictionary) -> Array[String]:
	var names: Array[String] = []
	var seen: Dictionary = {}
	for branch_variant in intersection.get("ordered_branches", []):
		var branch: Dictionary = branch_variant
		var road_name := str(street_cluster_catalog.get_edge_canonical_name(str(branch.get("edge_id", ""))))
		if road_name == "" or seen.has(road_name):
			continue
		seen[road_name] = true
		names.append(road_name)
	names.sort()
	return names

func _resolve_intersection_district_id(road_graph, intersection: Dictionary) -> String:
	for branch_variant in intersection.get("ordered_branches", []):
		var branch: Dictionary = branch_variant
		var edge: Dictionary = road_graph.get_edge_by_id(str(branch.get("edge_id", "")))
		if edge.is_empty():
			continue
		return str(edge.get("from", edge.get("to", "")))
	return ""

static func _preferred_orientation_for_frontage(frontage_side: String) -> String:
	match frontage_side.to_lower():
		"east", "west":
			return "vertical"
		"north", "south":
			return "horizontal"
	return "horizontal"

static func _road_class_penalty(road_class: String) -> float:
	match road_class:
		"collector":
			return -6.0
		"secondary":
			return 0.0
		"arterial":
			return 12.0
		"expressway_elevated":
			return 36.0
	return 8.0

static func _orientation_bucket_from_points(points: Array) -> String:
	if points.size() < 2:
		return "horizontal"
	var first := points[0] as Vector2
	var last := points[points.size() - 1] as Vector2
	return "horizontal" if absf(last.x - first.x) >= absf(last.y - first.y) else "vertical"

static func _distance_point_to_polyline_2d(point: Vector2, points: Array) -> float:
	if points.size() < 2:
		return INF
	var best_distance := INF
	for point_index in range(points.size() - 1):
		var a := points[point_index] as Vector2
		var b := points[point_index + 1] as Vector2
		best_distance = minf(best_distance, point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b)))
	return best_distance

static func _closest_point_on_polyline_3d(point: Vector3, polyline: Array) -> Dictionary:
	if polyline.size() < 2:
		return {
			"world_point": point,
			"distance_m": INF,
		}
	var best_distance := INF
	var best_point := point
	for point_index in range(polyline.size() - 1):
		var a := polyline[point_index] as Vector3
		var b := polyline[point_index + 1] as Vector3
		var closest := _closest_point_on_segment_3d(point, a, b)
		var distance_m := point.distance_to(closest)
		if distance_m < best_distance:
			best_distance = distance_m
			best_point = closest
	return {
		"world_point": best_point,
		"distance_m": best_distance,
	}

static func _closest_point_on_segment_3d(point: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var segment := b - a
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return a
	var t := clampf((point - a).dot(segment) / length_squared, 0.0, 1.0)
	return a + segment * t
