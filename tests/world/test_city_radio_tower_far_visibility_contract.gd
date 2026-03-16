extends SceneTree

const T := preload("res://tests/_test_util.gd")

const RADIO_TOWER_LANDMARK_ID := "landmark:v21:radio_tower:chunk_131_138"
const RADIO_TOWER_CHUNK_ID := "chunk_131_138"
const RADIO_TOWER_WORLD_POSITION := Vector3(-1296.81, -7.25, 433.84)
const FAR_PROXY_STAGING_POSITION := Vector3(903.19, 32.0, 433.84)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for radio tower far visibility contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Radio tower far visibility contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("get_chunk_renderer"), "Radio tower far visibility contract requires chunk renderer introspection"):
		return
	var chunk_renderer = world.get_chunk_renderer()
	if not T.require_true(self, chunk_renderer != null and chunk_renderer.has_method("get_chunk_scene"), "Radio tower far visibility contract requires chunk scene lookup"):
		return
	if not T.require_true(self, chunk_renderer.has_method("find_scene_landmark_far_proxy_node"), "Radio tower far visibility contract requires far proxy lookup for tall landmarks"):
		return

	player.teleport_to_world_position(FAR_PROXY_STAGING_POSITION)
	var far_proxy: Node3D = null
	for _frame in range(180):
		await process_frame
		far_proxy = chunk_renderer.find_scene_landmark_far_proxy_node(RADIO_TOWER_LANDMARK_ID) as Node3D
		if far_proxy != null and far_proxy.visible:
			break
	if not T.require_true(self, far_proxy != null, "Radio tower far visibility contract must instantiate a far proxy when the player is outside the active chunk window but within visibility radius"):
		return
	if not T.require_true(self, far_proxy.visible, "Radio tower far proxy must remain visible while the player is within far_visibility radius"):
		return
	if not T.require_true(self, far_proxy.global_position.distance_to(RADIO_TOWER_WORLD_POSITION) <= 0.25, "Radio tower far proxy must stay anchored to the landmark world position"):
		return
	if not T.require_true(self, chunk_renderer.get_chunk_scene(RADIO_TOWER_CHUNK_ID) == null, "Radio tower far visibility contract must not require the tower chunk itself to be mounted near the player"):
		return

	player.teleport_to_world_position(RADIO_TOWER_WORLD_POSITION + Vector3(0.0, 12.0, 24.0))
	var mounted_landmark: Node = null
	for _frame in range(180):
		await process_frame
		var chunk_scene = chunk_renderer.get_chunk_scene(RADIO_TOWER_CHUNK_ID)
		if chunk_scene == null or not chunk_scene.has_method("find_scene_landmark_node"):
			continue
		mounted_landmark = chunk_scene.find_scene_landmark_node(RADIO_TOWER_LANDMARK_ID)
		if mounted_landmark != null:
			break
	if not T.require_true(self, mounted_landmark != null, "Radio tower far visibility contract must still mount the authored landmark scene after the player approaches the tower chunk"):
		return
	far_proxy = chunk_renderer.find_scene_landmark_far_proxy_node(RADIO_TOWER_LANDMARK_ID) as Node3D
	if not T.require_true(self, far_proxy != null and not far_proxy.visible, "Radio tower far proxy must hide once the near landmark scene takes ownership"):
		return

	world.queue_free()
	T.pass_and_quit(self)
