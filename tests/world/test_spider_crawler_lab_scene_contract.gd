extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/SpiderCrawlerLab.tscn"
const CRAWLER_SCENE_PATH := "res://city_game/world/creatures/arthropods/CitySpiderCrawler.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(LAB_SCENE_PATH, "PackedScene"), "Spider crawler lab contract requires a dedicated SpiderCrawlerLab.tscn scene"):
		return
	if not T.require_true(self, ResourceLoader.exists(CRAWLER_SCENE_PATH, "PackedScene"), "Spider crawler lab contract requires the formal CitySpiderCrawler.tscn scene resource"):
		return

	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Spider crawler lab contract must load the lab scene as PackedScene"):
		return

	var lab_scene_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(LAB_SCENE_PATH))
	for authored_node_name in [
		"GroundBody",
		"FixtureRoot",
		"RampBody",
		"StepBody",
		"BeamBody",
	]:
		if not T.require_true(self, lab_scene_text.find('[node name="%s"' % authored_node_name) >= 0, "Spider crawler lab scene-first contract requires %s to be authored directly in SpiderCrawlerLab.tscn" % authored_node_name):
			return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	for required_method in [
		"get_spider_crawler",
		"get_crawler_debug_state",
		"step_spider",
		"reset_lab_state",
	]:
		if not T.require_true(self, lab.has_method(required_method), "Spider crawler lab scene must expose %s()" % required_method):
			return

	for required_node_path in [
		"GroundBody",
		"GroundBody/CollisionShape3D",
		"GroundBody/GroundMesh",
		"FixtureRoot",
		"FixtureRoot/RampBody",
		"FixtureRoot/RampBody/CollisionShape3D",
		"FixtureRoot/StepBody",
		"FixtureRoot/BeamBody",
		"Player",
		"Player/CameraRig/Camera3D",
		"Hud",
		"CrawlerRoot",
	]:
		if not T.require_true(self, lab.get_node_or_null(required_node_path) != null, "Spider crawler lab scene must author %s in the scene-first hierarchy" % required_node_path):
			return

	var spider := lab.get_spider_crawler() as Node3D
	if not T.require_true(self, spider != null, "Spider crawler lab scene must mount a formal spider crawler root"):
		return
	if not T.require_true(self, spider.scene_file_path == CRAWLER_SCENE_PATH, "Spider crawler lab must mount the formal CitySpiderCrawler.tscn instead of building the spider entirely from lab-only script state"):
		return
	for crawler_method in [
		"get_debug_state",
		"tick_crawler",
		"reset_crawler_state",
		"debug_force_replan_all_legs",
		"teleport_body_to_world_position",
	]:
		if not T.require_true(self, spider.has_method(crawler_method), "Formal spider crawler scene must expose %s()" % crawler_method):
			return

	var initial_state: Dictionary = lab.get_crawler_debug_state()
	if not T.require_true(self, str(initial_state.get("species_id", "")) == "spider", "Spider crawler lab must boot with spider as the formal species_id"):
		return
	if not T.require_true(self, int(initial_state.get("leg_count", 0)) == 8, "Spider crawler lab must preserve 8 spider legs in the shared debug state"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)
