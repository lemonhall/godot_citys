extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/LobsterCrawlerLab.tscn"
const CRAWLER_SCENE_PATH := "res://city_game/world/creatures/arthropods/CityLobsterCrawler.tscn"
const LOBSTER_MODEL_PATH := "res://city_game/assets/environment/source/creatures/lobster_02.glb"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(LAB_SCENE_PATH, "PackedScene"), "Lobster crawler lab contract requires a dedicated LobsterCrawlerLab.tscn scene"):
		return
	if not T.require_true(self, ResourceLoader.exists(CRAWLER_SCENE_PATH, "PackedScene"), "Lobster crawler lab contract requires the formal CityLobsterCrawler.tscn scene resource"):
		return

	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Lobster crawler lab contract must load the lab scene as PackedScene"):
		return

	var lab_scene_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(LAB_SCENE_PATH))
	for authored_node_name in [
		"GroundBody",
		"FixtureRoot",
		"RampBody",
		"ShelfBody",
		"ChannelBody",
	]:
		if not T.require_true(self, lab_scene_text.find('[node name="%s"' % authored_node_name) >= 0, "Lobster crawler lab scene-first contract requires %s to be authored directly in LobsterCrawlerLab.tscn" % authored_node_name):
			return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	for required_method in [
		"get_lobster_crawler",
		"get_crawler_debug_state",
		"step_lobster",
		"reset_lab_state",
	]:
		if not T.require_true(self, lab.has_method(required_method), "Lobster crawler lab scene must expose %s()" % required_method):
			return

	for required_node_path in [
		"GroundBody",
		"GroundBody/CollisionShape3D",
		"GroundBody/GroundMesh",
		"FixtureRoot",
		"FixtureRoot/RampBody",
		"FixtureRoot/ShelfBody",
		"FixtureRoot/ChannelBody",
		"Player",
		"Player/CameraRig/Camera3D",
		"Hud",
		"LobsterRoot",
	]:
		if not T.require_true(self, lab.get_node_or_null(required_node_path) != null, "Lobster crawler lab scene must author %s in the scene-first hierarchy" % required_node_path):
			return

	var lobster := lab.get_lobster_crawler() as Node3D
	if not T.require_true(self, lobster != null, "Lobster crawler lab scene must mount a formal lobster crawler root"):
		return
	if not T.require_true(self, lobster.scene_file_path == CRAWLER_SCENE_PATH, "Lobster crawler lab must mount the formal CityLobsterCrawler.tscn instead of building the lobster entirely from lab-only script state"):
		return
	for crawler_method in [
		"get_debug_state",
		"get_profile_contract",
		"get_portability_contract",
		"tick_crawler",
		"reset_crawler_state",
		"debug_force_replan_all_legs",
		"teleport_body_to_world_position",
	]:
		if not T.require_true(self, lobster.has_method(crawler_method), "Formal lobster crawler scene must expose %s()" % crawler_method):
			return

	var initial_state: Dictionary = lab.get_crawler_debug_state()
	if not T.require_true(self, str(initial_state.get("species_id", "")) == "lobster", "Lobster crawler lab must boot with lobster as the formal species_id"):
		return
	if not T.require_true(self, str(initial_state.get("gait_profile_id", "")) == "metachronal_forward", "Lobster crawler lab must freeze the gait profile to metachronal_forward"):
		return
	if not T.require_true(self, int(initial_state.get("leg_count", 0)) == 10, "Lobster crawler lab must preserve 10 lobster support limbs in the shared debug state"):
		return

	var profile_contract: Dictionary = lobster.get_profile_contract()
	if not T.require_true(self, float(profile_contract.get("body_clearance_m", 1.0)) < 0.5, "Lobster crawler lab must keep a distinctly lower body clearance profile than the spider lab"):
		return
	var legs: Array = profile_contract.get("legs", [])
	if not T.require_true(self, int(legs.size()) == 10, "Lobster crawler lab profile must expose all 10 limb contracts"):
		return
	var claw_contract := _find_leg_contract(legs, "lf_claw")
	if not T.require_true(self, float(claw_contract.get("stride_scale", 1.0)) < 0.6, "Lobster crawler lab profile must demote claw stride so the chelipeds are not the primary propulsion legs"):
		return

	var model_root := lobster.get_node_or_null("BodyPivot/Model") as Node3D
	if not T.require_true(self, model_root != null, "Lobster crawler scene must mount the curated lobster glb under BodyPivot/Model"):
		return
	if not T.require_true(self, str(model_root.scene_file_path) == LOBSTER_MODEL_PATH, "Lobster crawler scene must source the curated lobster glb from the formal creature asset directory"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _find_leg_contract(legs: Array, leg_id: String) -> Dictionary:
	for leg_variant in legs:
		if not (leg_variant is Dictionary):
			continue
		var leg_contract: Dictionary = leg_variant as Dictionary
		if str(leg_contract.get("leg_id", "")) == leg_id:
			return leg_contract
	return {}
