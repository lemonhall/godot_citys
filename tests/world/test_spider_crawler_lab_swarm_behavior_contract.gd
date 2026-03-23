extends SceneTree

const T := preload("res://tests/_test_util.gd")
const LAB_SCENE_PATH := "res://city_game/scenes/labs/SpiderCrawlerLab.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Spider swarm behavior contract requires SpiderCrawlerLab.tscn"):
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	if not T.require_true(self, lab.has_method("get_spider_crawlers"), "Spider swarm behavior contract requires get_spider_crawlers()"):
		return

	var all_spiders: Array = lab.get_spider_crawlers()
	var spawn_spiders: Array[Node3D] = []
	for spider_variant in all_spiders:
		var spider := spider_variant as Node3D
		if spider == null:
			continue
		if int(spider.get_meta("swarm_slot_index", -1)) <= 0:
			continue
		spawn_spiders.append(spider)
	if not T.require_true(self, spawn_spiders.size() >= 12, "Spider swarm behavior contract requires at least twelve spawned swarm spiders"):
		return

	var centroid := Vector3.ZERO
	for spider in spawn_spiders:
		centroid += spider.global_position
	centroid /= float(spawn_spiders.size())

	var min_radius := INF
	var max_radius := 0.0
	for spider in spawn_spiders:
		var planar_position := Vector2(spider.global_position.x - centroid.x, spider.global_position.z - centroid.z)
		var radius := planar_position.length()
		min_radius = minf(min_radius, radius)
		max_radius = maxf(max_radius, radius)
	if not T.require_true(self, max_radius - min_radius >= 6.0, "Spider swarm behavior contract requires spawn positions to avoid a tight circular ring"):
		return

	var unique_behavior_seeds: Dictionary = {}
	for spider in spawn_spiders:
		if not T.require_true(self, spider.has_method("get_debug_state"), "Spider swarm behavior contract requires spawned spiders to expose get_debug_state()"):
			return
		var debug_state: Dictionary = spider.get_debug_state()
		unique_behavior_seeds[int(debug_state.get("behavior_seed", -1))] = true
	if not T.require_true(self, unique_behavior_seeds.size() >= 8, "Spider swarm behavior contract requires most spawned spiders to carry distinct behavior seeds"):
		return

	var sample_spider := spawn_spiders[0]
	var body_pivot := sample_spider.get_node_or_null("BodyPivot") as Node3D
	var prosoma_mesh := sample_spider.get_node_or_null("BodyPivot/ProsomaMesh") as MeshInstance3D
	var abdomen_mesh := sample_spider.get_node_or_null("BodyPivot/AbdomenMesh") as MeshInstance3D
	if not T.require_true(self, body_pivot != null and prosoma_mesh != null and abdomen_mesh != null, "Spider swarm behavior contract requires the authored body nodes"):
		return
	var body_forward := body_pivot.global_basis.z
	var head_vs_tail := (prosoma_mesh.global_position - abdomen_mesh.global_position).dot(body_forward)
	if not T.require_true(self, head_vs_tail > 0.1, "Spider swarm behavior contract requires the prosoma to face the movement direction instead of the abdomen leading"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)
