extends RefCounted

const CityStreetClusterCatalog := preload("res://city_game/world/model/CityStreetClusterCatalog.gd")
const CityAddressGrammar := preload("res://city_game/world/model/CityAddressGrammar.gd")

const TARGET_CLUSTER_COUNT := 6000
const PRIMARY_STEP_OPTIONS := [220.0, 320.0, 420.0, 520.0, 640.0, 800.0, 960.0]
const SECONDARY_STEP_OPTIONS := [720.0, 1280.0, 1600.0, 2000.0, 2400.0, 2800.0, 3200.0, 4000.0]

func build_catalog(config, road_graph, block_layout, name_candidate_catalog: Dictionary) -> CityStreetClusterCatalog:
	var grouping := _resolve_grouping_parameters(road_graph)
	var clusters_by_key: Dictionary = {}
	var cluster_ids_by_edge: Dictionary = {}

	for edge_variant in road_graph.edges:
		var edge: Dictionary = edge_variant
		var edge_id := str(edge.get("edge_id", edge.get("road_id", "")))
		if edge_id == "":
			continue
		var key := _build_cluster_key(edge, float(grouping.get("primary_step_m", 220.0)), float(grouping.get("secondary_step_m", 720.0)))
		if not clusters_by_key.has(key):
			clusters_by_key[key] = _build_cluster_seed(edge, key)
		var cluster: Dictionary = clusters_by_key[key]
		cluster["edge_ids"].append(edge_id)
		cluster["bounds"] = _merge_bounds(cluster.get("bounds", Rect2()), edge.get("bounds", Rect2()))
		cluster["road_class"] = _merge_cluster_class(str(cluster.get("road_class", "regular")), _class_bucket(str(edge.get("class", "collector"))))
		var edge_length := _edge_length(edge)
		if edge_length > float(cluster.get("longest_edge_length_m", 0.0)):
			cluster["longest_edge_length_m"] = edge_length
			cluster["representative_anchor"] = _edge_midpoint(edge)
		clusters_by_key[key] = cluster
		cluster_ids_by_edge[edge_id] = key

	var road_roots: Array = name_candidate_catalog.get("road_name_root_pool", [])
	var cluster_keys: Array = clusters_by_key.keys()
	cluster_keys.sort()
	var grammar := CityAddressGrammar.new()
	var cluster_payloads: Array[Dictionary] = []
	for cluster_index in range(cluster_keys.size()):
		var cluster_key := str(cluster_keys[cluster_index])
		var cluster: Dictionary = clusters_by_key[cluster_key]
		var road_suffix := _resolve_suffix(str(cluster.get("road_class", "regular")), str(cluster.get("orientation_bucket", "horizontal")))
		var road_root := str(road_roots[cluster_index % max(road_roots.size(), 1)])
		var canonical_name := "%s %s" % [road_root, road_suffix]
		cluster["street_cluster_id"] = "street_cluster_%04d" % cluster_index
		cluster["canonical_name"] = canonical_name
		cluster["normalized_name"] = grammar.normalize_name(canonical_name)
		cluster_payloads.append(cluster)
		for edge_id_variant in cluster.get("edge_ids", []):
			cluster_ids_by_edge[str(edge_id_variant)] = str(cluster.get("street_cluster_id", ""))

	var cluster_catalog := CityStreetClusterCatalog.new()
	cluster_catalog.setup(cluster_payloads, cluster_ids_by_edge, {
		"road_edge_count": int(road_graph.get_edge_count()),
		"intersection_count": int(road_graph.get_intersections_in_rect(config.get_world_bounds()).size()),
		"block_count": int(block_layout.get_block_count()),
		"parcel_count": int(block_layout.get_parcel_count()),
	})
	_annotate_road_graph_edges(road_graph, cluster_catalog)
	return cluster_catalog

func _resolve_grouping_parameters(road_graph) -> Dictionary:
	var best := {
		"primary_step_m": PRIMARY_STEP_OPTIONS[0],
		"secondary_step_m": SECONDARY_STEP_OPTIONS[0],
		"count": 0,
		"delta": INF,
	}
	for primary_step in PRIMARY_STEP_OPTIONS:
		for secondary_step in SECONDARY_STEP_OPTIONS:
			var keys: Dictionary = {}
			for edge_variant in road_graph.edges:
				var edge: Dictionary = edge_variant
				keys[_build_cluster_key(edge, float(primary_step), float(secondary_step))] = true
			var cluster_count := keys.size()
			var delta := absf(float(cluster_count - TARGET_CLUSTER_COUNT))
			var best_count := int(best.get("count", 0))
			var count_in_band := cluster_count >= 5000 and cluster_count <= 7000
			var best_in_band := best_count >= 5000 and best_count <= 7000
			if count_in_band and not best_in_band:
				best = {
					"primary_step_m": primary_step,
					"secondary_step_m": secondary_step,
					"count": cluster_count,
					"delta": delta,
				}
				continue
			if count_in_band == best_in_band and delta < float(best.get("delta", INF)):
				best = {
					"primary_step_m": primary_step,
					"secondary_step_m": secondary_step,
					"count": cluster_count,
					"delta": delta,
				}
	return best

func _build_cluster_key(edge: Dictionary, primary_step_m: float, secondary_step_m: float) -> String:
	var orientation := _orientation_bucket(edge)
	var class_bucket := _class_bucket(str(edge.get("class", "collector")))
	var center := _edge_midpoint(edge)
	var primary_value := 0.0
	var secondary_value := 0.0
	match orientation:
		"horizontal":
			primary_value = center.y
			secondary_value = center.x
		"vertical":
			primary_value = center.x
			secondary_value = center.y
		"diag_pos":
			primary_value = center.y - center.x
			secondary_value = center.x + center.y
		_:
			primary_value = center.y + center.x
			secondary_value = center.x - center.y
	return "%s|%s|%d|%d" % [
		orientation,
		class_bucket,
		_quantize_value(primary_value, primary_step_m),
		_quantize_value(secondary_value, secondary_step_m),
	]

func _build_cluster_seed(edge: Dictionary, cluster_key: String) -> Dictionary:
	return {
		"street_cluster_id": "",
		"cluster_key": cluster_key,
		"orientation_bucket": _orientation_bucket(edge),
		"road_class": _class_bucket(str(edge.get("class", "collector"))),
		"edge_ids": [],
		"representative_anchor": _edge_midpoint(edge),
		"bounds": edge.get("bounds", Rect2()),
		"longest_edge_length_m": _edge_length(edge),
	}

func _annotate_road_graph_edges(road_graph, cluster_catalog: CityStreetClusterCatalog) -> void:
	for edge_variant in road_graph.edges:
		var edge: Dictionary = edge_variant
		var edge_id := str(edge.get("edge_id", edge.get("road_id", "")))
		var cluster: Dictionary = cluster_catalog.get_cluster_for_edge(edge_id)
		if cluster.is_empty():
			continue
		edge["street_cluster_id"] = str(cluster.get("street_cluster_id", ""))
		edge["canonical_road_name"] = str(cluster.get("canonical_name", ""))
		edge["normalized_road_name"] = str(cluster.get("normalized_name", ""))
		edge["display_name"] = str(cluster.get("canonical_name", ""))

func _orientation_bucket(edge: Dictionary) -> String:
	var points: Array = edge.get("points", [])
	if points.size() < 2:
		return "horizontal"
	var start: Vector2 = points[0]
	var finish: Vector2 = points[points.size() - 1]
	var delta := finish - start
	if absf(delta.x) >= absf(delta.y) * 1.7:
		return "horizontal"
	if absf(delta.y) >= absf(delta.x) * 1.7:
		return "vertical"
	if delta.x * delta.y >= 0.0:
		return "diag_pos"
	return "diag_neg"

func _class_bucket(road_class: String) -> String:
	if road_class == "expressway_elevated":
		return "expressway"
	if road_class == "arterial":
		return "arterial"
	return "regular"

func _merge_cluster_class(current_value: String, incoming_value: String) -> String:
	var priorities := {
		"regular": 0,
		"arterial": 1,
		"expressway": 2,
	}
	if int(priorities.get(incoming_value, 0)) > int(priorities.get(current_value, 0)):
		return incoming_value
	return current_value

func _resolve_suffix(class_bucket: String, orientation_bucket: String) -> String:
	match class_bucket:
		"expressway":
			return "Skyway"
		"arterial":
			return "Boulevard" if orientation_bucket.begins_with("diag") else "Avenue"
		_:
			if orientation_bucket == "vertical":
				return "Street"
			if orientation_bucket == "horizontal":
				return "Drive"
			return "Lane"

func _edge_midpoint(edge: Dictionary) -> Vector2:
	var points: Array = edge.get("points", [])
	if points.is_empty():
		return Vector2.ZERO
	return points[int(floor(float(points.size() - 1) * 0.5))]

func _edge_length(edge: Dictionary) -> float:
	var points: Array = edge.get("points", [])
	var total_length := 0.0
	for point_index in range(points.size() - 1):
		total_length += (points[point_index + 1] as Vector2).distance_to(points[point_index] as Vector2)
	return total_length

func _merge_bounds(a: Rect2, b: Rect2) -> Rect2:
	if a == Rect2():
		return b
	if b == Rect2():
		return a
	return a.merge(b)

func _quantize_value(value: float, step: float) -> int:
	if step <= 0.001:
		return int(round(value))
	return int(floor(value / step))
