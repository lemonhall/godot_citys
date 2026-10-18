extends SceneTree

# v63 M5 walkthrough E2E: waterfront -> market -> old-town lane -> landmark roof.
# REQ-0034-006.

const T := preload("res://tests/_test_util.gd")
const RoofAccess := preload("res://city_game/world/generation/plan/CityPlanRoofAccess.gd")

const OUT_DIR := "user://debug"
const WAYPOINTS := [
	{"name": "waterfront", "position": Vector3(0.0, 1.2, 150.0)},
	{"name": "market", "position": Vector3(0.0, 1.2, 320.0)},
	{"name": "lane", "position": Vector3(620.0, 1.2, 40.0)},
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if not T.require_true(self, scene != null, "CityPrototype must exist"):
		return
	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	for _frame in range(200):
		await process_frame
	var player := world.get_node_or_null("Player") as Node3D
	if not T.require_true(self, player != null, "walkthrough needs a Player"):
		return
	player.set_process(false)
	player.set_physics_process(false)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var captured := 0
	for waypoint_variant in WAYPOINTS:
		var waypoint: Dictionary = waypoint_variant
		if player.has_method("teleport_to_world_position"):
			player.call("teleport_to_world_position", waypoint["position"])
		else:
			player.global_position = waypoint["position"]
		for _frame in range(40):
			await process_frame
		var path := "%s/v63_walk_%s.png" % [OUT_DIR, str(waypoint["name"])]
		await RenderingServer.frame_post_draw
		var image := root.get_viewport().get_texture().get_image()
		image.save_png(path)
		var file := FileAccess.open(path, FileAccess.READ)
		if not T.require_true(self, file != null, "walkthrough capture must exist for %s" % str(waypoint["name"])):
			return
		var size := file.get_length()
		file.close()
		if not T.require_true(self, size > 50000, "walkthrough capture %s must not be empty" % str(waypoint["name"])):
			return
		captured += 1
	var access := world.find_child("RoofAccess", true, false) as Node3D
	if not T.require_true(self, access != null, "walkthrough needs the landmark roof pad"):
		return
	var height := float(access.get_meta("city_landmark_height_m", 0.0))
	player.global_position = access.global_position
	if not T.require_true(self, RoofAccess.try_travel(player, access), "walkthrough must ride the roof pad"):
		return
	var climbed := player.global_position.y - access.global_position.y
	if not T.require_true(self, climbed >= height * 0.9, "walkthrough must reach the landmark roof"):
		return
	await RenderingServer.frame_post_draw
	var roof_image := root.get_viewport().get_texture().get_image()
	roof_image.save_png("%s/v63_walk_roof.png" % OUT_DIR)
	print("V63_WALKTHROUGH captured=%d roof_height=%.1f" % [captured + 1, climbed])
	T.pass_and_quit(self)
