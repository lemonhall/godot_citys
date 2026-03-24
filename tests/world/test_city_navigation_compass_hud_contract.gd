extends SceneTree

const T := preload("res://tests/_test_util.gd")

const CITY_SCENE_PATH := "res://city_game/scenes/CityPrototype.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(CITY_SCENE_PATH)
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Navigation compass HUD contract requires CityPrototype.tscn")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("get_world_orientation_contract"), "CityPrototype must expose get_world_orientation_contract() for v45 orientation consumers"):
		return
	if not T.require_true(self, world.has_method("get_player_compass_state"), "CityPrototype must expose get_player_compass_state() for v45 compass consumers"):
		return

	var orientation_contract: Dictionary = world.get_world_orientation_contract()
	if not T.require_true(self, bool(orientation_contract.get("north_up", false)), "World orientation contract must freeze map north = world north"):
		return
	if not T.require_true(self, absf(float(orientation_contract.get("east_bearing_deg", 0.0)) - 90.0) <= 0.01, "World orientation contract must freeze east as 90 degrees"):
		return

	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, hud != null, "Navigation compass HUD contract requires the main HUD canvas to exist"):
		return
	if not T.require_true(self, hud.has_method("get_navigation_state"), "PrototypeHud must expose get_navigation_state() once compass state is added"):
		return
	if not T.require_true(self, hud.get_node_or_null("Root/Compass") != null, "PrototypeHud must mount a formal Compass control instead of only exposing raw debug text"):
		return

	var compass_state: Dictionary = world.get_player_compass_state()
	if not T.require_true(self, bool(compass_state.get("visible", false)), "Player compass state must stay visible in the main world HUD"):
		return
	if not T.require_true(self, str(compass_state.get("cardinal_text", "")) != "", "Player compass state must expose a readable cardinal cue"):
		return
	var hud_navigation_state: Dictionary = hud.get_navigation_state()
	var hud_compass_state: Dictionary = hud_navigation_state.get("compass", {})
	if not T.require_true(self, not hud_compass_state.is_empty(), "PrototypeHud navigation state must include a formal compass payload"):
		return
	if not T.require_true(self, absf(float(hud_compass_state.get("bearing_deg", -999.0)) - float(compass_state.get("bearing_deg", 0.0))) <= 0.01, "HUD compass payload must mirror CityPrototype's shared player compass state"):
		return

	var minimap_snapshot: Dictionary = world.build_minimap_snapshot()
	var minimap_orientation: Dictionary = minimap_snapshot.get("orientation", {})
	if not T.require_true(self, bool(minimap_orientation.get("north_up", false)), "build_minimap_snapshot() must expose north_up = true once the orientation contract is formalized"):
		return

	world.set_full_map_open(true)
	await process_frame
	var map_state: Dictionary = world.get_map_screen_state()
	var map_orientation: Dictionary = map_state.get("orientation", {})
	if not T.require_true(self, bool(map_orientation.get("north_up", false)), "Full map render state must expose north_up = true once map north is formalized"):
		return

	var player := world.get_node_or_null("Player") as Node3D
	if not T.require_true(self, player != null, "Navigation compass HUD contract requires the main world player node"):
		return
	player.rotation.y = -PI * 0.5
	world.call("_sync_navigation_consumers", true)
	world.call("_refresh_hud_status", {}, true)
	await process_frame

	compass_state = world.get_player_compass_state()
	if not T.require_true(self, absf(float(compass_state.get("bearing_deg", -999.0)) - 90.0) <= 0.5, "Rotating the player to face east must drive the shared compass state to 90 degrees"):
		return
	if not T.require_true(self, str(compass_state.get("cardinal_text", "")) == "E", "Rotating the player to face east must drive the compass cardinal cue to E"):
		return

	hud_navigation_state = hud.get_navigation_state()
	hud_compass_state = hud_navigation_state.get("compass", {})
	if not T.require_true(self, absf(float(hud_compass_state.get("bearing_deg", -999.0)) - 90.0) <= 0.5, "PrototypeHud compass payload must follow the shared east-facing 90 degree contract"):
		return

	minimap_snapshot = world.build_minimap_snapshot()
	var minimap_player_marker: Dictionary = minimap_snapshot.get("player_marker", {})
	if not T.require_true(self, absf(float(minimap_player_marker.get("bearing_deg", -999.0)) - 90.0) <= 0.5, "Minimap player marker must expose the same east-facing 90 degree bearing contract"):
		return

	map_state = world.get_map_screen_state()
	var map_player_marker: Dictionary = map_state.get("player_marker", {})
	if not T.require_true(self, absf(float(map_player_marker.get("bearing_deg", -999.0)) - 90.0) <= 0.5, "Full map player marker must expose the same east-facing 90 degree bearing contract"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

