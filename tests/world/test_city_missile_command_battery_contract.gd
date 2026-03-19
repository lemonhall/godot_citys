extends SceneTree

const T := preload("res://tests/_test_util.gd")

const VENUE_ID := "venue:v29:missile_command_battery:chunk_183_152"
const CHUNK_ID := "chunk_183_152"
const WORLD_POSITION := Vector3(11925.63, -4.74, 4126.84)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for Missile Command battery contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Missile Command battery contract requires Player teleport API"):
		return

	player.teleport_to_world_position(WORLD_POSITION + Vector3(0.0, 2.0, 12.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null, "Missile Command battery contract must mount the v29 venue in chunk_183_152"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_missile_command_contract"), "Missile Command battery contract requires get_missile_command_contract() on the mounted venue"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_match_start_contract"), "Missile Command battery contract requires get_match_start_contract() on the mounted venue"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_scoreboard_contract"), "Missile Command battery contract requires get_scoreboard_contract() on the mounted venue"):
		return

	var battery_contract: Dictionary = mounted_venue.get_missile_command_contract()
	if not T.require_true(self, str(battery_contract.get("venue_id", "")) == VENUE_ID, "Missile Command battery contract must preserve the formal venue_id"):
		return
	if not T.require_true(self, str(battery_contract.get("game_kind", "")) == "missile_command_battery", "Missile Command battery contract must preserve game_kind = missile_command_battery"):
		return
	if not T.require_true(self, battery_contract.get("gameplay_plane_origin", null) is Vector3, "Missile Command battery contract must expose gameplay_plane_origin as Vector3"):
		return
	if not T.require_true(self, float(battery_contract.get("gameplay_plane_half_width_m", 0.0)) >= 28.0, "Missile Command battery contract must expose a formally sized gameplay plane width"):
		return
	if not T.require_true(self, float(battery_contract.get("gameplay_plane_height_m", 0.0)) >= 42.0, "Missile Command battery contract must expose a formally sized gameplay plane height"):
		return
	if not T.require_true(self, battery_contract.get("camera_world_position", null) is Vector3, "Missile Command battery contract must expose camera_world_position as Vector3"):
		return
	if not T.require_true(self, battery_contract.get("camera_look_target", null) is Vector3, "Missile Command battery contract must expose camera_look_target as Vector3"):
		return
	var gameplay_plane_origin := battery_contract.get("gameplay_plane_origin", Vector3.ZERO) as Vector3
	var camera_look_target := battery_contract.get("camera_look_target", Vector3.ZERO) as Vector3
	var gameplay_plane_height_m := float(battery_contract.get("gameplay_plane_height_m", 0.0))
	if not T.require_true(self, camera_look_target.y >= gameplay_plane_origin.y - gameplay_plane_height_m * 0.12, "Missile Command battery contract must aim the camera into the authored gameplay plane instead of the ground scenery"):
		return
	var silo_ids: Array = battery_contract.get("silo_ids", [])
	if not T.require_true(self, silo_ids.size() == 3, "Missile Command battery contract must freeze exactly three launch silos in v29"):
		return
	var city_ids: Array = battery_contract.get("city_ids", [])
	if not T.require_true(self, city_ids.size() == 3, "Missile Command battery contract must freeze exactly three defended city targets in v29"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("BatteryCameraPivot") != null, "Missile Command battery contract requires an authored BatteryCameraPivot node"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("BatteryCameraPivot/BatteryCamera") != null, "Missile Command battery contract requires an authored BatteryCamera node under BatteryCameraPivot"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("GameplayPlaneAnchor") != null, "Missile Command battery contract requires an authored GameplayPlaneAnchor node"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("LaunchSilos/Left") != null, "Missile Command battery contract requires an authored left launch silo anchor"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("LaunchSilos/Center") != null, "Missile Command battery contract requires an authored center launch silo anchor"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("LaunchSilos/Right") != null, "Missile Command battery contract requires an authored right launch silo anchor"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("CityTargets/Left") != null, "Missile Command battery contract requires an authored left city target anchor"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("CityTargets/Center") != null, "Missile Command battery contract requires an authored center city target anchor"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("CityTargets/Right") != null, "Missile Command battery contract requires an authored right city target anchor"):
		return
	var start_contract: Dictionary = mounted_venue.get_match_start_contract()
	if not T.require_true(self, bool(start_contract.get("visible", false)), "Missile Command battery contract must expose a visible start ring while idle"):
		return
	if not T.require_true(self, start_contract.get("world_position", null) is Vector3, "Missile Command battery contract must expose start ring world_position as Vector3"):
		return
	if not T.require_true(self, float(start_contract.get("trigger_radius_m", 0.0)) >= 3.0, "Missile Command battery contract must expose a practical trigger radius for entering battery mode"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _wait_for_mounted_venue(world) -> Variant:
	var chunk_renderer: Variant = world.get_chunk_renderer() if world.has_method("get_chunk_renderer") else null
	if chunk_renderer == null or not chunk_renderer.has_method("get_chunk_scene"):
		return null
	for _frame in range(180):
		await process_frame
		var chunk_scene: Variant = chunk_renderer.get_chunk_scene(CHUNK_ID)
		if chunk_scene == null or not chunk_scene.has_method("find_scene_minigame_venue_node"):
			continue
		var mounted_venue: Variant = chunk_scene.find_scene_minigame_venue_node(VENUE_ID)
		if mounted_venue != null:
			return mounted_venue
	return null
