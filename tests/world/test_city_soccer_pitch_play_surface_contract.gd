extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SOCCER_CHUNK_ID := "chunk_129_139"
const SOCCER_VENUE_ID := "venue:v26:soccer_pitch:chunk_129_139"
const SOCCER_WORLD_POSITION := Vector3(-1877.94, 2.52, 618.57)
const MIN_RAISED_SURFACE_DELTA_M := 2.8
const MIN_SURFACE_WIDTH_M := 72.0
const MIN_SURFACE_LENGTH_M := 112.0
const MIN_PODIUM_MARGIN_M := 24.0
const EXPECTED_RELEASE_BUFFER_M := 24.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for soccer pitch play surface contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	var chunk_renderer = world.get_chunk_renderer() if world.has_method("get_chunk_renderer") else null
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Soccer pitch play surface contract requires Player teleport API"):
		return
	if not T.require_true(self, chunk_renderer != null and chunk_renderer.has_method("get_chunk_scene"), "Soccer pitch play surface contract requires chunk renderer lookup"):
		return

	player.teleport_to_world_position(SOCCER_WORLD_POSITION + Vector3(0.0, 8.0, 12.0))
	var mounted_venue: Node3D = null
	for _frame in range(180):
		await process_frame
		var chunk_scene = chunk_renderer.get_chunk_scene(SOCCER_CHUNK_ID)
		if chunk_scene == null or not chunk_scene.has_method("find_scene_minigame_venue_node"):
			continue
		mounted_venue = chunk_scene.find_scene_minigame_venue_node(SOCCER_VENUE_ID) as Node3D
		if mounted_venue != null:
			break
	if not T.require_true(self, mounted_venue != null, "Soccer pitch play surface contract must mount the venue in chunk_129_139"):
		return
	if not T.require_true(self, bool(mounted_venue.get_meta("city_scene_minigame_venue", false)), "Mounted soccer venue node must expose city_scene_minigame_venue metadata"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_play_surface_contract"), "Soccer pitch venue must expose get_play_surface_contract()"):
		return
	if not T.require_true(self, mounted_venue.has_method("is_world_point_in_play_bounds"), "Soccer pitch venue must expose is_world_point_in_play_bounds()"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_pitch_markings_contract"), "Soccer pitch venue must expose get_pitch_markings_contract() for standard field layout validation"):
		return

	var play_surface: Dictionary = mounted_venue.get_play_surface_contract()
	var floor_node := mounted_venue.get_node_or_null("PlayableFloor") as StaticBody3D
	if not T.require_true(self, floor_node != null, "Soccer pitch venue must contain a dedicated PlayableFloor StaticBody3D instead of relying on terrain"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("PitchPodium") is Node3D, "Soccer pitch venue must include a dedicated raised podium root instead of leaving the field as a thin patch glued into terrain"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("PitchApron") is Node3D, "Soccer pitch venue must include a dedicated apron ring so terrain cannot visually bite into the raised field corners"):
		return
	var floor_collision := floor_node.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not T.require_true(self, floor_collision != null and floor_collision.shape != null, "PlayableFloor must expose an explicit collision shape for ball and player grounding"):
		return

	var surface_top_y := float(play_surface.get("surface_top_y", -INF))
	var surface_size: Vector3 = play_surface.get("surface_size", Vector3.ZERO)
	var kickoff_anchor: Vector3 = play_surface.get("kickoff_anchor", Vector3.ZERO)
	var release_buffer_m := float(play_surface.get("release_buffer_m", 0.0))
	var podium_height_m := float(play_surface.get("podium_height_m", 0.0))
	var podium_footprint_size_variant: Variant = play_surface.get("podium_footprint_size", Vector3.ZERO)
	if not T.require_true(self, podium_footprint_size_variant is Vector3, "Play surface contract must expose podium_footprint_size as Vector3"):
		return
	var podium_footprint_size := podium_footprint_size_variant as Vector3
	if not T.require_true(self, surface_top_y >= SOCCER_WORLD_POSITION.y + MIN_RAISED_SURFACE_DELTA_M, "PlayableFloor top surface must be lifted well above the raw terrain anchor so the pitch no longer gets eaten by the world relief"):
		return
	if not T.require_true(self, surface_size.x >= MIN_SURFACE_WIDTH_M, "PlayableFloor width must be large enough for actual v26 football play instead of a token patch"):
		return
	if not T.require_true(self, surface_size.z >= MIN_SURFACE_LENGTH_M, "PlayableFloor length must be large enough for actual v26 football play instead of a token patch"):
		return
	if not T.require_true(self, absf(kickoff_anchor.x - SOCCER_WORLD_POSITION.x) <= 0.001 and absf(kickoff_anchor.z - SOCCER_WORLD_POSITION.z) <= 0.001, "Play surface contract must preserve the frozen kickoff anchor XZ position"):
		return
	if not T.require_true(self, absf(kickoff_anchor.y - surface_top_y) <= 0.001, "Play surface contract kickoff anchor must sit on the raised pitch top surface"):
		return
	if not T.require_true(self, podium_height_m >= MIN_RAISED_SURFACE_DELTA_M, "Play surface contract must expose a meaningful podium_height_m instead of pretending the terrain itself is the court foundation"):
		return
	if not T.require_true(self, podium_footprint_size.x >= surface_size.x + MIN_PODIUM_MARGIN_M, "Play surface contract must keep a broad X-direction podium footprint so terrain cannot immediately clip the field corners"):
		return
	if not T.require_true(self, podium_footprint_size.z >= surface_size.z + MIN_PODIUM_MARGIN_M, "Play surface contract must keep a broad Z-direction podium footprint so terrain cannot immediately clip the field corners"):
		return
	if not T.require_true(self, absf(release_buffer_m - EXPECTED_RELEASE_BUFFER_M) <= 0.001, "Play surface contract must freeze the ambient release buffer at 24m"):
		return
	if not T.require_true(self, bool(mounted_venue.is_world_point_in_play_bounds(SOCCER_WORLD_POSITION)), "Kickoff anchor must lie inside the in-play bounds contract"):
		return
	if not T.require_true(self, not bool(mounted_venue.is_world_point_in_play_bounds(SOCCER_WORLD_POSITION + Vector3(surface_size.x + 8.0, 0.0, 0.0))), "A far sideline point must not be treated as inside the in-play bounds"):
		return

	world.queue_free()
	T.pass_and_quit(self)
