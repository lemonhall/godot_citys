extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config_script := load("res://city_game/world/model/CityWorldConfig.gd")
	var generator_script := load("res://city_game/world/generation/CityWorldGenerator.gd")
	if config_script == null or generator_script == null:
		T.fail_and_quit(self, "Street cluster naming test requires CityWorldConfig and CityWorldGenerator")
		return

	var config = config_script.new()
	var generator = generator_script.new()
	var world_data: Dictionary = generator.generate_world(config)
	var road_graph = world_data.get("road_graph")
	var street_cluster_catalog = world_data.get("street_cluster_catalog")
	if not T.require_true(self, road_graph != null and road_graph.has_method("get_edge_count"), "Street cluster naming test requires road_graph"):
		return
	if not T.require_true(self, street_cluster_catalog != null and street_cluster_catalog.has_method("get_cluster_for_edge"), "street_cluster_catalog must expose get_cluster_for_edge()"):
		return
	if not T.require_true(self, street_cluster_catalog.has_method("get_edge_canonical_name"), "street_cluster_catalog must expose get_edge_canonical_name()"):
		return

	var multi_edge_cluster_found := false
	var cluster_edge_counts: Dictionary = {}
	for edge_variant in road_graph.edges:
		var edge: Dictionary = edge_variant
		var edge_id := str(edge.get("edge_id", ""))
		var cluster: Dictionary = street_cluster_catalog.get_cluster_for_edge(edge_id)
		if not T.require_true(self, not cluster.is_empty(), "Every road edge must resolve to a canonical street cluster"):
			return
		var cluster_id := str(cluster.get("street_cluster_id", ""))
		if not T.require_true(self, cluster_id != "", "Street clusters must expose street_cluster_id"):
			return
		cluster_edge_counts[cluster_id] = int(cluster_edge_counts.get(cluster_id, 0)) + 1
		var canonical_name := str(street_cluster_catalog.get_edge_canonical_name(edge_id))
		if not T.require_true(self, canonical_name != "", "Every road edge must resolve to a non-empty canonical street name"):
			return
		if not T.require_true(self, not canonical_name.begins_with("Reference "), "Technical placeholder names must not leak into canonical road names"):
			return
		if not T.require_true(self, canonical_name.find("Connector") == -1 or not canonical_name.begins_with("district_"), "District connector placeholders must not become canonical street names"):
			return
	for cluster_id_variant in cluster_edge_counts.keys():
		if int(cluster_edge_counts.get(cluster_id_variant, 0)) >= 2:
			multi_edge_cluster_found = true
			break
	if not T.require_true(self, multi_edge_cluster_found, "At least one canonical street cluster must span multiple road edges instead of one edge per name"):
		return

	T.pass_and_quit(self)
