extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SPIDER_SCENE_PATH := "res://city_game/world/creatures/arthropods/CitySpiderCrawler.tscn"
const EXPECTED_BODY_SOLVER_ID := "reference_leg_centroid_plane_v3"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(SPIDER_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Spider reference body solver contract requires CitySpiderCrawler.tscn"):
		return

	var spider := scene.instantiate() as Node3D
	root.add_child(spider)
	await process_frame
	await process_frame

	spider.set_debug_motion_velocity(Vector3(0.0, 0.0, 3.0))
	for _tick in range(6):
		spider.tick_crawler(0.12)

	var state: Dictionary = spider.get_debug_state()
	if not T.require_true(self, str(state.get("body_solver_id", "")) == EXPECTED_BODY_SOLVER_ID, "Spider reference body solver contract requires an explicit leg-centroid/plane-normal solver id"):
		return
	var body_target_transform: Dictionary = state.get("body_target_transform", {})
	if not T.require_true(self, body_target_transform.has("default_centroid_world_position"), "Spider reference body solver contract requires default_centroid_world_position in body_target_transform"):
		return
	if not T.require_true(self, body_target_transform.has("leg_centroid_world_position"), "Spider reference body solver contract requires leg_centroid_world_position in body_target_transform"):
		return
	if not T.require_true(self, body_target_transform.has("plane_normal"), "Spider reference body solver contract requires plane_normal in body_target_transform"):
		return
	if not T.require_true(self, body_target_transform.has("centroid_normal_offset"), "Spider reference body solver contract requires centroid_normal_offset in body_target_transform"):
		return
	if not T.require_true(self, body_target_transform.has("centroid_tangent_offset"), "Spider reference body solver contract requires centroid_tangent_offset in body_target_transform"):
		return
	var plane_normal: Vector3 = body_target_transform.get("plane_normal", Vector3.ZERO)
	if not T.require_true(self, plane_normal.length() > 0.5, "Spider reference body solver contract requires a non-degenerate plane normal from leg geometry"):
		return

	spider.queue_free()
	await process_frame
	T.pass_and_quit(self)
