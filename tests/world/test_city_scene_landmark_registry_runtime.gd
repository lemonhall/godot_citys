extends SceneTree

const T := preload("res://tests/_test_util.gd")
const REGISTRY_SCRIPT_PATH := "res://city_game/world/features/CitySceneLandmarkRegistry.gd"
const RUNTIME_SCRIPT_PATH := "res://city_game/world/features/CitySceneLandmarkRuntime.gd"
const REGISTRY_PATH := "res://city_game/serviceability/landmarks/generated/landmark_override_registry.json"
const FOUNTAIN_LANDMARK_ID := "landmark:v21:fountain:chunk_129_142"
const FOUNTAIN_CHUNK_ID := "chunk_129_142"
const FOUNTAIN_SCENE_PATH := "res://city_game/serviceability/landmarks/generated/landmark_v21_fountain_chunk_129_142/fountain_landmark.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry_script := load(REGISTRY_SCRIPT_PATH)
	if not T.require_true(self, registry_script != null, "Scene landmark registry runtime contract requires CitySceneLandmarkRegistry.gd"):
		return
	var runtime_script := load(RUNTIME_SCRIPT_PATH)
	if not T.require_true(self, runtime_script != null, "Scene landmark registry runtime contract requires CitySceneLandmarkRuntime.gd"):
		return

	var registry = registry_script.new()
	if not T.require_true(self, registry != null and registry.has_method("configure"), "Scene landmark registry runtime contract requires configure()"):
		return
	if not T.require_true(self, registry.has_method("load_registry"), "Scene landmark registry runtime contract requires load_registry()"):
		return
	var runtime = runtime_script.new()
	if not T.require_true(self, runtime != null and runtime.has_method("configure"), "Scene landmark runtime contract requires configure()"):
		return
	if not T.require_true(self, runtime.has_method("get_entries_for_chunk"), "Scene landmark runtime contract requires get_entries_for_chunk()"):
		return
	if not T.require_true(self, runtime.has_method("get_state"), "Scene landmark runtime contract requires get_state()"):
		return

	registry.configure(REGISTRY_PATH, [REGISTRY_PATH])
	var entries: Dictionary = registry.load_registry()
	if not T.require_true(self, entries.has(FOUNTAIN_LANDMARK_ID), "Scene landmark registry must load the generated fountain landmark entry from registry json"):
		return

	runtime.configure(entries)
	var runtime_state: Dictionary = runtime.get_state()
	if not T.require_true(self, int(runtime_state.get("entry_count", 0)) >= 1, "Scene landmark runtime must cache at least one resolved landmark entry"):
		return
	if not T.require_true(self, int(runtime_state.get("manifest_read_count", 0)) >= 1, "Scene landmark runtime must read landmark manifests instead of synthesizing entries"):
		return

	var chunk_entries: Array = runtime.get_entries_for_chunk(FOUNTAIN_CHUNK_ID)
	if not T.require_true(self, chunk_entries.size() == 1, "Scene landmark runtime must index the fountain under chunk_129_142"):
		return
	var fountain_entry: Dictionary = chunk_entries[0]
	if not T.require_true(self, str(fountain_entry.get("landmark_id", "")) == FOUNTAIN_LANDMARK_ID, "Scene landmark runtime chunk lookup must preserve the formal fountain landmark_id"):
		return
	if not T.require_true(self, str(fountain_entry.get("feature_kind", "")) == "scene_landmark", "Scene landmark runtime must preserve feature_kind = scene_landmark"):
		return
	if not T.require_true(self, str(fountain_entry.get("scene_path", "")) == FOUNTAIN_SCENE_PATH, "Scene landmark runtime must preserve the resolved fountain scene_path"):
		return
	if not T.require_true(self, fountain_entry.get("world_position", null) is Vector3, "Scene landmark runtime must expose manifest world_position as Vector3"):
		return

	var second_registry = registry_script.new()
	second_registry.configure(REGISTRY_PATH, [REGISTRY_PATH])
	var second_entries: Dictionary = second_registry.load_registry()
	var second_runtime = runtime_script.new()
	second_runtime.configure(second_entries)
	var second_chunk_entries: Array = second_runtime.get_entries_for_chunk(FOUNTAIN_CHUNK_ID)
	if not T.require_true(self, second_chunk_entries.size() == 1, "Scene landmark registry/runtime contract must reload the fountain on a second session"):
		return

	T.pass_and_quit(self)
