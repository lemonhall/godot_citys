extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityChunkKey := preload("res://city_game/world/streaming/CityChunkKey.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for minimap pedestrian debug layer")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("build_minimap_snapshot"), "CityPrototype must expose build_minimap_snapshot() for minimap pedestrian debug layer"):
		return
	if not T.require_true(self, world.has_method("get_world_data"), "CityPrototype must expose get_world_data() for minimap pedestrian debug layer validation"):
		return
	if not T.require_true(self, world.has_method("get_world_config"), "CityPrototype must expose get_world_config() for minimap pedestrian debug layer validation"):
		return

	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, hud != null, "Minimap pedestrian debug layer requires Hud node"):
		return
	if not T.require_true(self, hud.has_method("toggle_debug_expanded"), "PrototypeHud must expose toggle_debug_expanded() for minimap debug layer activation"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Minimap pedestrian debug layer requires Player node"):
		return

	var default_snapshot: Dictionary = world.build_minimap_snapshot()
	if not T.require_true(self, default_snapshot.has("crowd_debug_layer"), "Minimap snapshot must expose crowd_debug_layer metadata"):
		return
	if not T.require_true(self, not bool((default_snapshot.get("crowd_debug_layer", {}) as Dictionary).get("visible", true)), "Minimap crowd debug layer must stay hidden while HUD debug is collapsed"):
		return

	hud.toggle_debug_expanded()
	var debug_snapshot: Dictionary = world.build_minimap_snapshot()
	var crowd_debug_layer: Dictionary = debug_snapshot.get("crowd_debug_layer", {})
	if not T.require_true(self, bool(crowd_debug_layer.get("visible", false)), "Expanded HUD must enable the minimap crowd debug layer"):
		return
	if not T.require_true(self, int(crowd_debug_layer.get("sidewalk_lane_count", 0)) > 0, "Minimap crowd debug layer must project real sidewalk lanes"):
		return
	if not T.require_true(self, int(crowd_debug_layer.get("spawn_marker_count", 0)) > 0, "Minimap crowd debug layer must project real pedestrian spawn markers"):
		return
	if not T.require_true(self, (crowd_debug_layer.get("chunk_samples", []) as Array).size() > 0, "Minimap crowd debug layer must expose chunk density samples"):
		return

	var world_data: Dictionary = world.get_world_data()
	var pedestrian_query = world_data.get("pedestrian_query")
	if not T.require_true(self, pedestrian_query != null, "World data must include pedestrian_query for minimap debug validation"):
		return

	var config = world.get_world_config()
	var center_chunk := CityChunkKey.world_to_chunk_key(config, player.global_position)
	var center_query: Dictionary = pedestrian_query.get_pedestrian_query_for_chunk(center_chunk)
	var found_center_chunk := false
	for sample_variant in crowd_debug_layer.get("chunk_samples", []):
		var sample: Dictionary = sample_variant
		if str(sample.get("chunk_id", "")) != str(center_query.get("chunk_id", "")):
			continue
		found_center_chunk = true
		if not T.require_true(self, is_equal_approx(float(sample.get("density_scalar", -1.0)), float(center_query.get("density_scalar", -2.0))), "Minimap crowd debug layer must reuse the pedestrian query density scalar for the center chunk"):
			return
		if not T.require_true(self, int(sample.get("spawn_capacity", -1)) == int(center_query.get("spawn_capacity", -2)), "Minimap crowd debug layer must reuse the pedestrian query spawn capacity for the center chunk"):
			return
		break
	if not T.require_true(self, found_center_chunk, "Minimap crowd debug layer must include the player's current chunk in its density samples"):
		return

	world.queue_free()
	T.pass_and_quit(self)
