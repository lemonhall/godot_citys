extends SceneTree

const T := preload("res://tests/_test_util.gd")
const REGISTRY_SCRIPT_PATH := "res://city_game/world/features/CitySceneInteractivePropRegistry.gd"
const RUNTIME_SCRIPT_PATH := "res://city_game/world/features/CitySceneInteractivePropRuntime.gd"
const REGISTRY_PATH := "res://city_game/serviceability/interactive_props/generated/interactive_prop_registry.json"
const SOCCER_PROP_ID := "prop:v25:soccer_ball:chunk_129_139"
const SOCCER_CHUNK_ID := "chunk_129_139"
const SOCCER_SCENE_PATH := "res://city_game/serviceability/interactive_props/generated/prop_v25_soccer_ball_chunk_129_139/soccer_ball_prop.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry_script := load(REGISTRY_SCRIPT_PATH)
	if not T.require_true(self, registry_script != null, "Scene interactive prop registry/runtime contract requires CitySceneInteractivePropRegistry.gd"):
		return
	var runtime_script := load(RUNTIME_SCRIPT_PATH)
	if not T.require_true(self, runtime_script != null, "Scene interactive prop registry/runtime contract requires CitySceneInteractivePropRuntime.gd"):
		return

	var registry = registry_script.new()
	if not T.require_true(self, registry != null and registry.has_method("configure"), "Scene interactive prop registry/runtime contract requires configure()"):
		return
	if not T.require_true(self, registry.has_method("load_registry"), "Scene interactive prop registry/runtime contract requires load_registry()"):
		return

	var runtime = runtime_script.new()
	if not T.require_true(self, runtime != null and runtime.has_method("configure"), "Scene interactive prop runtime contract requires configure()"):
		return
	if not T.require_true(self, runtime.has_method("get_entries_for_chunk"), "Scene interactive prop runtime contract requires get_entries_for_chunk()"):
		return
	if not T.require_true(self, runtime.has_method("get_state"), "Scene interactive prop runtime contract requires get_state()"):
		return

	registry.configure(REGISTRY_PATH, [REGISTRY_PATH])
	var entries: Dictionary = registry.load_registry()
	if not T.require_true(self, entries.has(SOCCER_PROP_ID), "Scene interactive prop registry must load the soccer ball entry from registry json"):
		return

	runtime.configure(entries)
	var runtime_state: Dictionary = runtime.get_state()
	if not T.require_true(self, int(runtime_state.get("entry_count", 0)) >= 1, "Scene interactive prop runtime must cache at least one resolved entry"):
		return
	if not T.require_true(self, int(runtime_state.get("manifest_read_count", 0)) >= 1, "Scene interactive prop runtime must read prop manifests instead of synthesizing entries"):
		return

	var chunk_entries: Array = runtime.get_entries_for_chunk(SOCCER_CHUNK_ID)
	if not T.require_true(self, chunk_entries.size() == 1, "Scene interactive prop runtime must index the soccer ball under chunk_129_139"):
		return
	var soccer_entry: Dictionary = chunk_entries[0]
	if not T.require_true(self, str(soccer_entry.get("prop_id", "")) == SOCCER_PROP_ID, "Scene interactive prop chunk lookup must preserve the formal soccer prop_id"):
		return
	if not T.require_true(self, str(soccer_entry.get("feature_kind", "")) == "scene_interactive_prop", "Scene interactive prop runtime must preserve feature_kind = scene_interactive_prop"):
		return
	if not T.require_true(self, str(soccer_entry.get("scene_path", "")) == SOCCER_SCENE_PATH, "Scene interactive prop runtime must preserve the resolved soccer scene_path"):
		return
	if not T.require_true(self, soccer_entry.get("world_position", null) is Vector3, "Scene interactive prop runtime must expose manifest world_position as Vector3"):
		return
	if not T.require_true(self, soccer_entry.get("scene_root_offset", null) is Vector3, "Scene interactive prop runtime must expose scene_root_offset as Vector3"):
		return

	var second_registry = registry_script.new()
	second_registry.configure(REGISTRY_PATH, [REGISTRY_PATH])
	var second_entries: Dictionary = second_registry.load_registry()
	var second_runtime = runtime_script.new()
	second_runtime.configure(second_entries)
	var second_chunk_entries: Array = second_runtime.get_entries_for_chunk(SOCCER_CHUNK_ID)
	if not T.require_true(self, second_chunk_entries.size() == 1, "Scene interactive prop registry/runtime contract must reload the soccer ball on a second session"):
		return

	T.pass_and_quit(self)
