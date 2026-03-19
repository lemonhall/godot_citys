extends SceneTree

const T := preload("res://tests/_test_util.gd")

const TENNIS_CHUNK_ID := "chunk_158_140"
const TENNIS_VENUE_ID := "venue:v28:tennis_court:chunk_158_140"
const TENNIS_WORLD_POSITION := Vector3(5489.46, 20.62, 1029.73)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for tennis court geometry contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Tennis court geometry contract requires Player teleport API"):
		return

	player.teleport_to_world_position(TENNIS_WORLD_POSITION + Vector3(0.0, 2.0, 10.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null, "Tennis court geometry contract must mount the tennis venue before scene inspection"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_tennis_court_contract"), "Tennis court geometry contract requires get_tennis_court_contract() on the mounted venue"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_match_start_contract"), "Tennis court geometry contract requires get_match_start_contract() on the mounted venue"):
		return
	if not T.require_true(self, mounted_venue.has_method("is_world_point_in_play_bounds"), "Tennis court geometry contract requires in-play bounds query on the mounted venue"):
		return
	if not T.require_true(self, mounted_venue.has_method("is_world_point_in_release_bounds"), "Tennis court geometry contract requires release bounds query on the mounted venue"):
		return

	var court_contract: Dictionary = mounted_venue.get_tennis_court_contract()
	if not T.require_true(self, is_equal_approx(float(court_contract.get("base_court_length_m", 0.0)), 23.77), "Tennis court geometry contract must preserve the official base court_length_m = 23.77"):
		return
	if not T.require_true(self, is_equal_approx(float(court_contract.get("base_singles_width_m", 0.0)), 8.23), "Tennis court geometry contract must preserve the official base singles_width_m = 8.23"):
		return
	if not T.require_true(self, is_equal_approx(float(court_contract.get("base_service_line_distance_m", 0.0)), 6.40), "Tennis court geometry contract must preserve the official base service_line_distance_m = 6.40"):
		return
	if not T.require_true(self, is_equal_approx(float(court_contract.get("court_scale_factor", 0.0)), 7.5), "Tennis court geometry contract must freeze court_scale_factor = 7.5"):
		return
	if not T.require_true(self, is_equal_approx(float(court_contract.get("court_length_m", 0.0)), 23.77 * 7.5), "Tennis court geometry contract must expose the scaled arcade court_length_m"):
		return
	if not T.require_true(self, is_equal_approx(float(court_contract.get("singles_width_m", 0.0)), 8.23 * 7.5), "Tennis court geometry contract must expose the scaled arcade singles_width_m"):
		return
	if not T.require_true(self, is_equal_approx(float(court_contract.get("service_line_distance_m", 0.0)), 6.40 * 7.5), "Tennis court geometry contract must expose the scaled arcade service_line_distance_m"):
		return
	if not T.require_true(self, is_equal_approx(float(court_contract.get("net_center_height_m", 0.0)), 0.914), "Tennis court geometry contract must freeze net_center_height_m = 0.914"):
		return
	if not T.require_true(self, is_equal_approx(float(court_contract.get("net_post_height_m", 0.0)), 1.07), "Tennis court geometry contract must freeze net_post_height_m = 1.07"):
		return
	if not T.require_true(self, float(court_contract.get("release_buffer_m", 0.0)) >= 28.0, "Tennis court geometry contract must expose the enlarged release buffer for the arcade-scale court"):
		return
	if not T.require_true(self, float(court_contract.get("surface_top_y", 0.0)) >= TENNIS_WORLD_POSITION.y + 2.7, "Tennis court geometry contract must preserve the ECN-0026 total platform lift so the court stays above terrain relief"):
		return
	var service_box_ids: Array = court_contract.get("service_box_ids", [])
	if not T.require_true(self, service_box_ids.size() == 4, "Tennis court geometry contract must expose 4 named service boxes"):
		return
	var start_contract: Dictionary = mounted_venue.get_match_start_contract()
	if not T.require_true(self, str(start_contract.get("theme_id", "")) == "task_available_start", "Tennis start ring must reuse the shared start ring theme family"):
		return
	var podium_foundation := mounted_venue.get_node_or_null("CourtPodium/Foundation") as MeshInstance3D
	var floor_mesh := mounted_venue.get_node_or_null("PlayableFloor/MeshInstance3D") as MeshInstance3D
	if not T.require_true(self, podium_foundation != null and floor_mesh != null, "Tennis court geometry contract must mount the podium foundation and playable floor meshes"):
		return
	var foundation_box := podium_foundation.mesh as BoxMesh
	var floor_box := floor_mesh.mesh as BoxMesh
	if not T.require_true(self, foundation_box != null and floor_box != null, "Tennis court geometry contract requires box-mesh backed podium/floor surfaces for depth ordering checks"):
		return
	var foundation_top_y: float = podium_foundation.position.y + foundation_box.size.y * 0.5
	var floor_parent := floor_mesh.get_parent() as Node3D
	var floor_top_y: float = (floor_parent.position.y if floor_parent != null else 0.0) + floor_box.size.y * 0.5
	if not T.require_true(self, floor_top_y - foundation_top_y >= 0.17, "Tennis court geometry contract must recess the podium top below the playable floor to avoid blue-surface z-fighting"):
		return
	var start_world_position_variant: Variant = start_contract.get("world_position", null)
	if not T.require_true(self, start_world_position_variant is Vector3, "Tennis court geometry contract must expose start ring world_position as Vector3"):
		return
	var start_world_position := start_world_position_variant as Vector3
	var home_server_anchor: Dictionary = court_contract.get("home_deuce_server_anchor", {})
	var home_server_world_position: Vector3 = home_server_anchor.get("world_position", TENNIS_WORLD_POSITION)
	if not T.require_true(self, start_world_position.distance_to(home_server_world_position) <= 14.0, "Tennis start ring must sit near the home serve setup zone instead of a far sideline offset"):
		return
	if not T.require_true(self, mounted_venue.to_local(start_world_position).z > 0.0, "Tennis start ring must stay on the player/home side of the court"):
		return
	if not T.require_true(self, bool(mounted_venue.is_world_point_in_release_bounds(TENNIS_WORLD_POSITION)), "Tennis world anchor must sit inside release bounds"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _wait_for_mounted_venue(world) -> Variant:
	var chunk_renderer: Variant = world.get_chunk_renderer() if world.has_method("get_chunk_renderer") else null
	if chunk_renderer == null or not chunk_renderer.has_method("get_chunk_scene"):
		return null
	for _frame in range(180):
		await process_frame
		var chunk_scene: Variant = chunk_renderer.get_chunk_scene(TENNIS_CHUNK_ID)
		if chunk_scene == null or not chunk_scene.has_method("find_scene_minigame_venue_node"):
			continue
		var mounted_venue: Variant = chunk_scene.find_scene_minigame_venue_node(TENNIS_VENUE_ID)
		if mounted_venue != null:
			return mounted_venue
	return null
