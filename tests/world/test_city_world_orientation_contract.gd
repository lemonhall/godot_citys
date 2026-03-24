extends SceneTree

const T := preload("res://tests/_test_util.gd")

const ORIENTATION_SCRIPT_PATH := "res://city_game/world/navigation/CityWorldOrientation.gd"
const MINIMAP_PROJECTOR_SCRIPT_PATH := "res://city_game/world/map/CityMinimapProjector.gd"
const MAP_SCREEN_SCENE_PATH := "res://city_game/ui/CityMapScreen.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(ORIENTATION_SCRIPT_PATH, "Script"), "World orientation contract requires a shared CityWorldOrientation helper"):
		return
	if not T.require_true(self, ResourceLoader.exists(MINIMAP_PROJECTOR_SCRIPT_PATH, "Script"), "World orientation contract requires CityMinimapProjector to stay loadable"):
		return
	if not T.require_true(self, ResourceLoader.exists(MAP_SCREEN_SCENE_PATH, "PackedScene"), "World orientation contract requires CityMapScreen.tscn to stay loadable"):
		return

	var orientation_script := load(ORIENTATION_SCRIPT_PATH)
	var orientation = orientation_script.new()
	if not T.require_true(self, orientation != null, "World orientation contract must instantiate the shared helper"):
		return

	var north_bearing := float(orientation.bearing_deg_from_world_vector(Vector3(0.0, 0.0, -1.0)))
	var east_bearing := float(orientation.bearing_deg_from_world_vector(Vector3(1.0, 0.0, 0.0)))
	var south_bearing := float(orientation.bearing_deg_from_world_vector(Vector3(0.0, 0.0, 1.0)))
	var west_bearing := float(orientation.bearing_deg_from_world_vector(Vector3(-1.0, 0.0, 0.0)))
	if not T.require_true(self, absf(north_bearing) <= 0.01, "Shared orientation contract must freeze world north (-Z) as 0 degrees"):
		return
	if not T.require_true(self, absf(east_bearing - 90.0) <= 0.01, "Shared orientation contract must freeze east (+X) as 90 degrees"):
		return
	if not T.require_true(self, absf(south_bearing - 180.0) <= 0.01, "Shared orientation contract must freeze south (+Z) as 180 degrees"):
		return
	if not T.require_true(self, absf(west_bearing - 270.0) <= 0.01, "Shared orientation contract must freeze west (-X) as 270 degrees"):
		return

	var orientation_contract: Dictionary = orientation.get_orientation_contract()
	if not T.require_true(self, bool(orientation_contract.get("bearing_clockwise", false)), "Shared orientation contract must declare clockwise bearing growth"):
		return
	if not T.require_true(self, bool(orientation_contract.get("north_up", false)), "Shared orientation contract must declare north-up map semantics"):
		return
	var near_northwest_compass: Dictionary = orientation.build_compass_state_from_bearing_deg(347.0, true)
	var near_northwest_labels := _collect_compass_labels(near_northwest_compass)
	if not T.require_true(self, near_northwest_labels.has("300"), "Compass label contract must keep the 300-degree label visible near 347 degrees instead of letting labels disappear between phase steps"):
		return
	if not T.require_true(self, near_northwest_labels.has("330"), "Compass label contract must keep the 330-degree label visible near 347 degrees instead of flickering it on and off with player yaw"):
		return
	if not T.require_true(self, near_northwest_labels.has("N"), "Compass label contract must keep the north cardinal label visible near 347 degrees"):
		return
	if not T.require_true(self, near_northwest_labels.has("030"), "Compass label contract must keep the 030-degree label visible near 347 degrees instead of dropping all outer labels"):
		return

	var projector_script := load(MINIMAP_PROJECTOR_SCRIPT_PATH)
	var projector = projector_script.new()
	if not T.require_true(self, projector != null, "World orientation contract must instantiate CityMinimapProjector"):
		return

	var center_world := Vector3.ZERO
	var world_radius_m := 1000.0
	var road_snapshot: Dictionary = projector.build_road_snapshot(center_world, world_radius_m)
	var map_size_px := float(road_snapshot.get("map_size_px", 0.0))
	var map_center := Vector2(map_size_px * 0.5, map_size_px * 0.5)

	var north_marker: Dictionary = projector.build_player_marker(center_world, Vector3(0.0, 0.0, -250.0), 0.0, world_radius_m)
	var east_marker: Dictionary = projector.build_player_marker(center_world, Vector3(250.0, 0.0, 0.0), 0.0, world_radius_m)
	var south_marker: Dictionary = projector.build_player_marker(center_world, Vector3(0.0, 0.0, 250.0), 0.0, world_radius_m)
	var west_marker: Dictionary = projector.build_player_marker(center_world, Vector3(-250.0, 0.0, 0.0), 0.0, world_radius_m)
	if not T.require_true(self, Vector2(north_marker.get("position", map_center)).y < map_center.y, "Minimap north-up contract requires world north to project above the map center"):
		return
	if not T.require_true(self, Vector2(east_marker.get("position", map_center)).x > map_center.x, "Minimap north-up contract requires world east to project to the right of the map center"):
		return
	if not T.require_true(self, Vector2(south_marker.get("position", map_center)).y > map_center.y, "Minimap north-up contract requires world south to project below the map center"):
		return
	if not T.require_true(self, Vector2(west_marker.get("position", map_center)).x < map_center.x, "Minimap north-up contract requires world west to project to the left of the map center"):
		return
	var minimap_orientation: Dictionary = road_snapshot.get("orientation", {})
	if not T.require_true(self, bool(minimap_orientation.get("north_up", false)), "Minimap road snapshot must expose an explicit north-up contract instead of only relying on implicit projection math"):
		return

	var map_scene := load(MAP_SCREEN_SCENE_PATH) as PackedScene
	if not T.require_true(self, map_scene != null, "World orientation contract must load CityMapScreen as PackedScene"):
		return
	var map_screen := map_scene.instantiate() as Control
	if not T.require_true(self, map_screen != null, "World orientation contract must instantiate CityMapScreen"):
		return
	root.add_child(map_screen)
	map_screen.anchor_left = 0.0
	map_screen.anchor_top = 0.0
	map_screen.anchor_right = 0.0
	map_screen.anchor_bottom = 0.0
	map_screen.size = Vector2(1280.0, 720.0)
	if map_screen.has_method("setup"):
		map_screen.setup(Rect2(Vector2(-2000.0, -2000.0), Vector2(4000.0, 4000.0)))
	if map_screen.has_method("set_map_open"):
		map_screen.set_map_open(true)
	await process_frame

	var north_map: Vector2 = map_screen.world_to_map(Vector3(0.0, 0.0, -1000.0))
	var east_map: Vector2 = map_screen.world_to_map(Vector3(1000.0, 0.0, 0.0))
	var south_map: Vector2 = map_screen.world_to_map(Vector3(0.0, 0.0, 1000.0))
	var west_map: Vector2 = map_screen.world_to_map(Vector3(-1000.0, 0.0, 0.0))
	if not T.require_true(self, north_map.y < south_map.y, "Full map contract requires world north to render above world south"):
		return
	if not T.require_true(self, east_map.x > west_map.x, "Full map contract requires world east to render to the right of world west"):
		return
	var map_state: Dictionary = map_screen.get_render_state()
	var map_orientation: Dictionary = map_state.get("orientation", {})
	if not T.require_true(self, bool(map_orientation.get("north_up", false)), "Full map render state must expose north_up = true for future consumers and tests"):
		return

	map_screen.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _collect_compass_labels(compass_state: Dictionary) -> Dictionary:
	var labels := {}
	for tick_variant in compass_state.get("tick_entries", []):
		var tick: Dictionary = tick_variant
		var label := str(tick.get("label", "")).strip_edges()
		if label == "":
			continue
		labels[label] = true
	return labels
