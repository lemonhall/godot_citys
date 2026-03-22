extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/LakeFishingLab.tscn"
const VENUE_SCENE_PATH := "res://city_game/serviceability/minigame_venues/generated/venue_v38_lakeside_fishing_chunk_147_181/lake_fishing_minigame_venue.tscn"
const VENUE_ID := "venue:v38:lakeside_fishing:chunk_147_181"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(LAB_SCENE_PATH, "PackedScene"), "Lake fishing lab contract requires a dedicated LakeFishingLab.tscn scene"):
		return

	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Lake fishing lab contract must load the lab scene as PackedScene"):
		return
	if not T.require_true(self, ResourceLoader.exists(VENUE_SCENE_PATH, "PackedScene"), "Lake fishing lab contract requires the canonical fishing venue scene resource"):
		return

	var lab_scene_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(LAB_SCENE_PATH))
	if not T.require_true(self, lab_scene_text.find('[node name="GroundBody"') >= 0, "Lake fishing lab scene-first contract requires GroundBody to be authored directly in LakeFishingLab.tscn instead of rebuilt in runtime"):
		return
	if not T.require_true(self, lab_scene_text.find('[node name="WaterSurface"') >= 0, "Lake fishing lab scene-first contract requires WaterSurface to be authored directly in LakeFishingLab.tscn"):
		return
	if not T.require_true(self, lab_scene_text.find('[node name="SurfaceMesh"') >= 0, "Lake fishing lab scene-first contract requires SurfaceMesh to be authored directly in LakeFishingLab.tscn so the lake footprint is editor-visible"):
		return

	var venue_scene_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(VENUE_SCENE_PATH))
	if not T.require_true(self, venue_scene_text.find('[node name="MatchStartRing"') >= 0, "Lake fishing venue scene-first contract requires MatchStartRing to be authored in the venue scene so the green ring is editor-visible"):
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	for required_method in [
		"get_lake_player_water_state",
		"get_fish_school_summaries",
		"get_fishing_runtime_state",
		"request_fishing_primary_interaction",
		"reset_lab_state",
		"find_scene_minigame_venue_node",
	]:
		if not T.require_true(self, lab.has_method(required_method), "Lake fishing lab scene must expose %s()" % required_method):
			return

	for required_node_path in [
		"GroundBody",
		"GroundBody/CollisionShape3D",
		"GroundBody/MeshInstance3D",
		"Player",
		"Hud",
		"LakeRoot",
		"LakeRoot/WaterSurface",
		"LakeRoot/WaterSurface/SurfaceMesh",
		"LakeRoot/FishSchools",
		"VenueRoot",
		"VenueRoot/SeatAnchorMain",
		"VenueRoot/CastOriginMain",
		"VenueRoot/MatchStartRing",
	]:
		if not T.require_true(self, lab.get_node_or_null(required_node_path) != null, "Lake fishing lab scene must author %s in the scene-first hierarchy" % required_node_path):
			return

	var ground_mesh := lab.get_node_or_null("GroundBody/MeshInstance3D") as MeshInstance3D
	if not T.require_true(self, ground_mesh != null and ground_mesh.mesh != null, "Lake fishing lab scene-first contract requires authored ground mesh geometry on GroundBody/MeshInstance3D"):
		return
	var water_surface_mesh := lab.get_node_or_null("LakeRoot/WaterSurface/SurfaceMesh") as MeshInstance3D
	if not T.require_true(self, water_surface_mesh != null and water_surface_mesh.mesh != null, "Lake fishing lab scene-first contract requires authored water mesh geometry on LakeRoot/WaterSurface/SurfaceMesh"):
		return

	var player := lab.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Lake fishing lab contract requires the formal Player teleport API"):
		return
	var venue_node := lab.find_scene_minigame_venue_node(VENUE_ID) as Node3D
	if not T.require_true(self, venue_node != null, "Lake fishing lab scene must mount the formal fishing venue root under find_scene_minigame_venue_node()"):
		return
	if not T.require_true(self, player.global_position.length() <= 96.0, "Lake fishing lab scene-first contract requires the authored player start to stay near the editor origin instead of several kilometers away"):
		return
	if not T.require_true(self, venue_node.global_position.length() <= 64.0, "Lake fishing lab scene-first contract requires the authored fishing venue to stay near the editor origin for hand-tuning"):
		return
	if not T.require_true(self, venue_node.has_method("get_fishing_contract"), "Lake fishing venue scene must expose get_fishing_contract() for runtime reuse"):
		return
	var match_start_ring := venue_node.get_node_or_null("MatchStartRing")
	if not T.require_true(self, match_start_ring != null and match_start_ring.has_method("set_marker_theme"), "Lake fishing venue scene-first contract requires the authored MatchStartRing node to preserve the shared ring marker API"):
		return
	var venue_contract: Dictionary = venue_node.get_fishing_contract()
	if not T.require_true(self, str(venue_contract.get("venue_id", "")) == VENUE_ID, "Lake fishing lab must preserve the formal venue_id on the mounted fishing venue"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)
