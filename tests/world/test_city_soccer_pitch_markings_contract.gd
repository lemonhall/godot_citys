extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SOCCER_CHUNK_ID := "chunk_129_139"
const SOCCER_VENUE_ID := "venue:v26:soccer_pitch:chunk_129_139"
const SOCCER_WORLD_POSITION := Vector3(-1877.94, 2.52, 618.57)
const MARKING_SIZE_TOLERANCE_M := 0.45
const EXPECTED_CENTER_CIRCLE_RADIUS_M := 9.15
const EXPECTED_PENALTY_AREA_DEPTH_M := 16.5
const EXPECTED_PENALTY_AREA_WIDTH_M := 40.32
const EXPECTED_GOAL_BOX_DEPTH_M := 5.5
const EXPECTED_GOAL_BOX_WIDTH_M := 18.32
const EXPECTED_PENALTY_SPOT_DISTANCE_M := 11.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for soccer pitch markings contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Soccer pitch markings contract requires Player teleport API"):
		return

	player.teleport_to_world_position(SOCCER_WORLD_POSITION + Vector3(0.0, 8.0, 12.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null, "Soccer pitch markings contract must mount the venue before scene inspection"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_pitch_markings_contract"), "Soccer pitch markings contract requires get_pitch_markings_contract() on the mounted venue"):
		return

	var markings_root := mounted_venue.get_node_or_null("PitchMarkings") as Node3D
	if not T.require_true(self, markings_root != null, "Soccer pitch markings contract requires a dedicated PitchMarkings root instead of folding all cues into four border strips"):
		return

	var play_surface: Dictionary = mounted_venue.get_play_surface_contract()
	var surface_size_variant: Variant = play_surface.get("surface_size", Vector3.ZERO)
	if not T.require_true(self, surface_size_variant is Vector3, "Soccer pitch markings contract requires play surface size as Vector3"):
		return
	var surface_size := surface_size_variant as Vector3
	var markings_contract: Dictionary = mounted_venue.get_pitch_markings_contract()
	if not T.require_true(self, absf(float(markings_contract.get("halfway_line_length_m", 0.0)) - surface_size.x) <= 0.2, "Soccer pitch markings contract must keep the halfway line aligned with the full field width"):
		return
	if not T.require_true(self, absf(float(markings_contract.get("center_circle_radius_m", 0.0)) - EXPECTED_CENTER_CIRCLE_RADIUS_M) <= MARKING_SIZE_TOLERANCE_M, "Soccer pitch markings contract must expose a near-standard center circle radius"):
		return
	if not T.require_true(self, absf(float(markings_contract.get("penalty_area_depth_m", 0.0)) - EXPECTED_PENALTY_AREA_DEPTH_M) <= MARKING_SIZE_TOLERANCE_M, "Soccer pitch markings contract must expose near-standard penalty area depth"):
		return
	if not T.require_true(self, absf(float(markings_contract.get("penalty_area_width_m", 0.0)) - EXPECTED_PENALTY_AREA_WIDTH_M) <= MARKING_SIZE_TOLERANCE_M, "Soccer pitch markings contract must expose near-standard penalty area width"):
		return
	if not T.require_true(self, absf(float(markings_contract.get("goal_box_depth_m", 0.0)) - EXPECTED_GOAL_BOX_DEPTH_M) <= MARKING_SIZE_TOLERANCE_M, "Soccer pitch markings contract must expose near-standard goal box depth"):
		return
	if not T.require_true(self, absf(float(markings_contract.get("goal_box_width_m", 0.0)) - EXPECTED_GOAL_BOX_WIDTH_M) <= MARKING_SIZE_TOLERANCE_M, "Soccer pitch markings contract must expose near-standard goal box width"):
		return
	if not T.require_true(self, absf(float(markings_contract.get("penalty_spot_distance_m", 0.0)) - EXPECTED_PENALTY_SPOT_DISTANCE_M) <= MARKING_SIZE_TOLERANCE_M, "Soccer pitch markings contract must expose near-standard penalty spot distance"):
		return

	var halfway_line := markings_root.get_node_or_null("HalfwayLine") as Node3D
	var center_circle := markings_root.get_node_or_null("CenterCircle") as Node3D
	var center_spot := markings_root.get_node_or_null("CenterSpot") as Node3D
	var penalty_area_a := markings_root.get_node_or_null("PenaltyAreaA") as Node3D
	var penalty_area_b := markings_root.get_node_or_null("PenaltyAreaB") as Node3D
	var goal_box_a := markings_root.get_node_or_null("GoalBoxA") as Node3D
	var goal_box_b := markings_root.get_node_or_null("GoalBoxB") as Node3D
	var penalty_spot_a := markings_root.get_node_or_null("PenaltySpotA") as Node3D
	var penalty_spot_b := markings_root.get_node_or_null("PenaltySpotB") as Node3D
	if not T.require_true(self, halfway_line is MeshInstance3D, "Soccer pitch markings contract requires an explicit HalfwayLine visual node"):
		return
	if not T.require_true(self, center_circle is MeshInstance3D, "Soccer pitch markings contract requires an explicit CenterCircle visual node"):
		return
	if not T.require_true(self, center_spot is MeshInstance3D, "Soccer pitch markings contract requires an explicit CenterSpot visual node"):
		return
	if not T.require_true(self, penalty_area_a != null and penalty_area_b != null, "Soccer pitch markings contract requires both penalty area visuals"):
		return
	if not T.require_true(self, goal_box_a != null and goal_box_b != null, "Soccer pitch markings contract requires both goal box visuals"):
		return
	if not T.require_true(self, penalty_spot_a is MeshInstance3D and penalty_spot_b is MeshInstance3D, "Soccer pitch markings contract requires both penalty spot visuals"):
		return
	if not T.require_true(self, penalty_area_a.get_child_count() >= 3 and penalty_area_b.get_child_count() >= 3, "Soccer pitch markings contract penalty areas must be drawn as explicit three-sided box outlines"):
		return
	if not T.require_true(self, goal_box_a.get_child_count() >= 3 and goal_box_b.get_child_count() >= 3, "Soccer pitch markings contract goal boxes must be drawn as explicit three-sided box outlines"):
		return
	if not T.require_true(self, penalty_area_a.position.z < 0.0 and penalty_area_b.position.z > 0.0, "Soccer pitch markings contract must place the two penalty areas on opposite field ends"):
		return
	if not T.require_true(self, goal_box_a.position.z < 0.0 and goal_box_b.position.z > 0.0, "Soccer pitch markings contract must place the two goal boxes on opposite field ends"):
		return
	if not T.require_true(self, penalty_spot_a.position.z < 0.0 and penalty_spot_b.position.z > 0.0, "Soccer pitch markings contract must place both penalty spots toward their respective goal mouths"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _wait_for_mounted_venue(world) -> Variant:
	var chunk_renderer: Variant = world.get_chunk_renderer() if world.has_method("get_chunk_renderer") else null
	if chunk_renderer == null or not chunk_renderer.has_method("get_chunk_scene"):
		return null
	for _frame in range(180):
		await process_frame
		var chunk_scene: Variant = chunk_renderer.get_chunk_scene(SOCCER_CHUNK_ID)
		if chunk_scene == null or not chunk_scene.has_method("find_scene_minigame_venue_node"):
			continue
		var mounted_venue: Variant = chunk_scene.find_scene_minigame_venue_node(SOCCER_VENUE_ID)
		if mounted_venue != null:
			return mounted_venue
	return null
