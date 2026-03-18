extends SceneTree

const T := preload("res://tests/_test_util.gd")
const REGISTRY_SCRIPT_PATH := "res://city_game/world/features/CitySceneMinigameVenueRegistry.gd"
const RUNTIME_SCRIPT_PATH := "res://city_game/world/features/CitySceneMinigameVenueRuntime.gd"
const REGISTRY_PATH := "res://city_game/serviceability/minigame_venues/generated/minigame_venue_registry.json"
const SOCCER_VENUE_ID := "venue:v26:soccer_pitch:chunk_129_139"
const SOCCER_CHUNK_ID := "chunk_129_139"
const SOCCER_SCENE_PATH := "res://city_game/serviceability/minigame_venues/generated/venue_v26_soccer_pitch_chunk_129_139/soccer_minigame_venue.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry_script := load(REGISTRY_SCRIPT_PATH)
	if not T.require_true(self, registry_script != null, "Scene minigame venue registry/runtime contract requires CitySceneMinigameVenueRegistry.gd"):
		return
	var runtime_script := load(RUNTIME_SCRIPT_PATH)
	if not T.require_true(self, runtime_script != null, "Scene minigame venue registry/runtime contract requires CitySceneMinigameVenueRuntime.gd"):
		return

	var registry = registry_script.new()
	if not T.require_true(self, registry != null and registry.has_method("configure"), "Scene minigame venue registry/runtime contract requires configure()"):
		return
	if not T.require_true(self, registry.has_method("load_registry"), "Scene minigame venue registry/runtime contract requires load_registry()"):
		return

	var runtime = runtime_script.new()
	if not T.require_true(self, runtime != null and runtime.has_method("configure"), "Scene minigame venue runtime contract requires configure()"):
		return
	if not T.require_true(self, runtime.has_method("get_entries_for_chunk"), "Scene minigame venue runtime contract requires get_entries_for_chunk()"):
		return
	if not T.require_true(self, runtime.has_method("get_state"), "Scene minigame venue runtime contract requires get_state()"):
		return

	registry.configure(REGISTRY_PATH, [REGISTRY_PATH])
	var entries: Dictionary = registry.load_registry()
	if not T.require_true(self, entries.has(SOCCER_VENUE_ID), "Scene minigame venue registry must load the soccer pitch entry from registry json"):
		return

	runtime.configure(entries)
	var runtime_state: Dictionary = runtime.get_state()
	if not T.require_true(self, int(runtime_state.get("entry_count", 0)) >= 1, "Scene minigame venue runtime must cache at least one resolved entry"):
		return
	if not T.require_true(self, int(runtime_state.get("manifest_read_count", 0)) >= 1, "Scene minigame venue runtime must read venue manifests instead of synthesizing entries"):
		return

	var chunk_entries: Array = runtime.get_entries_for_chunk(SOCCER_CHUNK_ID)
	if not T.require_true(self, chunk_entries.size() == 1, "Scene minigame venue runtime must index the soccer pitch under chunk_129_139"):
		return
	var soccer_entry: Dictionary = chunk_entries[0]
	if not T.require_true(self, str(soccer_entry.get("venue_id", "")) == SOCCER_VENUE_ID, "Scene minigame venue chunk lookup must preserve the formal soccer venue_id"):
		return
	if not T.require_true(self, str(soccer_entry.get("feature_kind", "")) == "scene_minigame_venue", "Scene minigame venue runtime must preserve feature_kind = scene_minigame_venue"):
		return
	if not T.require_true(self, str(soccer_entry.get("scene_path", "")) == SOCCER_SCENE_PATH, "Scene minigame venue runtime must preserve the resolved soccer venue scene_path"):
		return
	if not T.require_true(self, str(soccer_entry.get("game_kind", "")) == "soccer_pitch", "Scene minigame venue runtime must preserve the formal game_kind"):
		return
	if not T.require_true(self, soccer_entry.get("world_position", null) is Vector3, "Scene minigame venue runtime must expose manifest world_position as Vector3"):
		return
	if not T.require_true(self, soccer_entry.get("scene_root_offset", null) is Vector3, "Scene minigame venue runtime must expose scene_root_offset as Vector3"):
		return
	if not T.require_true(self, str(soccer_entry.get("primary_ball_prop_id", "")) == "prop:v25:soccer_ball:chunk_129_139", "Scene minigame venue runtime must preserve the primary_ball_prop_id binding to the v25 soccer ball"):
		return

	var second_registry = registry_script.new()
	second_registry.configure(REGISTRY_PATH, [REGISTRY_PATH])
	var second_entries: Dictionary = second_registry.load_registry()
	var second_runtime = runtime_script.new()
	second_runtime.configure(second_entries)
	var second_chunk_entries: Array = second_runtime.get_entries_for_chunk(SOCCER_CHUNK_ID)
	if not T.require_true(self, second_chunk_entries.size() == 1, "Scene minigame venue registry/runtime contract must reload the soccer venue on a second session"):
		return

	T.pass_and_quit(self)
