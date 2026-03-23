extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/SpiderCrawlerLab.tscn"
const SAMPLE_POSITIONS := [
	Vector3(18.0, 0.0, 0.0),
	Vector3(40.0, 0.0, 0.0),
	Vector3(-10.0, 0.0, 20.0),
]
const MAX_ALLOWED_PENETRATION_M := 0.05

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Spider obstacle body clearance contract requires SpiderCrawlerLab.tscn"):
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	for required_method in [
		"teleport_spider_to_world_position",
		"force_spider_replan",
		"step_spider",
		"get_spider_crawler",
	]:
		if not T.require_true(self, lab.has_method(required_method), "Spider obstacle body clearance contract requires %s()" % required_method):
			return

	var spider := lab.get_spider_crawler() as Node3D
	if not T.require_true(self, spider != null, "Spider obstacle body clearance contract requires a live crawler node"):
		return
	var prosoma := spider.get_node_or_null("BodyPivot/ProsomaMesh") as MeshInstance3D
	var abdomen := spider.get_node_or_null("BodyPivot/AbdomenMesh") as MeshInstance3D
	if not T.require_true(self, prosoma != null and abdomen != null, "Spider obstacle body clearance contract requires body meshes"):
		return

	var worst_penetration_m := 0.0
	for sample_position_variant in SAMPLE_POSITIONS:
		var sample_position: Vector3 = sample_position_variant as Vector3
		lab.teleport_spider_to_world_position(sample_position)
		lab.force_spider_replan()
		lab.step_spider(1.0 / 60.0, 12)
		worst_penetration_m = maxf(worst_penetration_m, _compute_mesh_penetration(spider, prosoma))
		worst_penetration_m = maxf(worst_penetration_m, _compute_mesh_penetration(spider, abdomen))

	if not T.require_true(
		self,
		worst_penetration_m <= MAX_ALLOWED_PENETRATION_M,
		"Spider obstacle body clearance contract forbids visible body meshes from sinking into authored obstacles (worst penetration %.3fm)" % worst_penetration_m
	):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _compute_mesh_penetration(spider: Node3D, mesh_instance: MeshInstance3D) -> float:
	var bottom_world_y := _compute_mesh_bottom_world_y(mesh_instance)
	var ray_origin := mesh_instance.global_position + Vector3.UP * 8.0
	var ray_end := mesh_instance.global_position + Vector3.DOWN * 8.0
	if spider.get_world_3d() == null:
		return 0.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var hit: Dictionary = spider.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return 0.0
	var ground_y := float((hit.get("position", Vector3.ZERO) as Vector3).y)
	return maxf(ground_y - bottom_world_y, 0.0)

func _compute_mesh_bottom_world_y(mesh_instance: MeshInstance3D) -> float:
	var local_aabb := mesh_instance.get_aabb()
	var min_world_y := INF
	for x_index in range(2):
		for y_index in range(2):
			for z_index in range(2):
				var corner := local_aabb.position + Vector3(
					local_aabb.size.x * float(x_index),
					local_aabb.size.y * float(y_index),
					local_aabb.size.z * float(z_index)
				)
				var world_corner := mesh_instance.global_transform * corner
				min_world_y = minf(min_world_y, world_corner.y)
	return min_world_y
