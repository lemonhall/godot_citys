extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/LakeFishingLab.tscn"
const VENUE_ID := "venue:v38:lakeside_fishing:chunk_147_181"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(LAB_SCENE_PATH, "PackedScene"), "Lake fishing lab contract requires a dedicated LakeFishingLab.tscn scene"):
		return

	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Lake fishing lab contract must load the lab scene as PackedScene"):
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
		"Player",
		"Hud",
		"LakeRoot",
		"LakeRoot/WaterSurface",
		"LakeRoot/FishSchools",
		"VenueRoot",
		"VenueRoot/SeatAnchorMain",
		"VenueRoot/CastOriginMain",
	]:
		if not T.require_true(self, lab.get_node_or_null(required_node_path) != null, "Lake fishing lab scene must author %s in the scene-first hierarchy" % required_node_path):
			return

	var player := lab.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Lake fishing lab contract requires the formal Player teleport API"):
		return
	var venue_node := lab.find_scene_minigame_venue_node(VENUE_ID) as Node3D
	if not T.require_true(self, venue_node != null, "Lake fishing lab scene must mount the formal fishing venue root under find_scene_minigame_venue_node()"):
		return
	if not T.require_true(self, venue_node.has_method("get_fishing_contract"), "Lake fishing venue scene must expose get_fishing_contract() for runtime reuse"):
		return
	var venue_contract: Dictionary = venue_node.get_fishing_contract()
	if not T.require_true(self, str(venue_contract.get("venue_id", "")) == VENUE_ID, "Lake fishing lab must preserve the formal venue_id on the mounted fishing venue"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)
