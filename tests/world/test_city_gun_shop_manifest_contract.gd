extends SceneTree

const T := preload("res://tests/_test_util.gd")
const BUILDING_ID := "bld:v15-building-id-1:seed424242:chunk_134_130:014"
const REGISTRY_PATH := "res://city_game/serviceability/buildings/generated/building_override_registry.json"
const MANIFEST_PATH := "res://city_game/serviceability/buildings/generated/bld_v15-building-id-1_seed424242_chunk_134_130_014/building_manifest.json"
const SCENE_PATH := "res://city_game/serviceability/buildings/generated/bld_v15-building-id-1_seed424242_chunk_134_130_014/枪店_A.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry_variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(REGISTRY_PATH)))
	if not T.require_true(self, registry_variant is Dictionary, "Gun shop manifest contract requires a valid override registry JSON"):
		return
	var registry_entries: Dictionary = (registry_variant as Dictionary).get("entries", {})
	if not T.require_true(self, registry_entries.has(BUILDING_ID), "Gun shop manifest contract requires a formal registry entry for the gun shop building_id"):
		return
	var registry_entry: Dictionary = registry_entries.get(BUILDING_ID, {})
	if not T.require_true(self, str(registry_entry.get("scene_path", "")) == SCENE_PATH, "Gun shop registry entry must point at 枪店_A.tscn instead of the old exported placeholder path"):
		return
	if not T.require_true(self, str(registry_entry.get("manifest_path", "")) == MANIFEST_PATH, "Gun shop registry entry must keep the formal manifest path"):
		return

	var manifest_variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(MANIFEST_PATH)))
	if not T.require_true(self, manifest_variant is Dictionary, "Gun shop manifest contract requires a valid gun shop manifest JSON"):
		return
	var manifest: Dictionary = manifest_variant
	if not T.require_true(self, str(manifest.get("scene_path", "")) == SCENE_PATH, "Gun shop manifest must point at 枪店_A.tscn so direct scene loads and override mounts share the same contract"):
		return

	var full_map_pin_variant = manifest.get("full_map_pin", {})
	if not T.require_true(self, full_map_pin_variant is Dictionary, "Gun shop manifest must declare a formal full_map_pin payload"):
		return
	var full_map_pin: Dictionary = full_map_pin_variant
	if not T.require_true(self, bool(full_map_pin.get("visible", false)), "Gun shop full_map_pin must opt into visibility"):
		return
	if not T.require_true(self, str(full_map_pin.get("icon_id", "")) == "gun_shop", "Gun shop full_map_pin must use the formal gun_shop icon_id"):
		return
	if not T.require_true(self, str(full_map_pin.get("title", "")).strip_edges() != "", "Gun shop full_map_pin must expose a non-empty title"):
		return
	if not T.require_true(self, str(full_map_pin.get("subtitle", "")).find("Elmaestead") >= 0, "Gun shop full_map_pin subtitle must preserve the street address cue"):
		return

	var source_contract: Dictionary = manifest.get("source_building_contract", {})
	var inspection_payload: Dictionary = source_contract.get("inspection_payload", {})
	if not T.require_true(self, inspection_payload.has("world_position"), "Gun shop manifest must continue carrying inspection_payload.world_position for v18 pin projection"):
		return

	var scene := load(SCENE_PATH)
	if not T.require_true(self, scene != null and scene is PackedScene, "Gun shop scene_path from the manifest must load as PackedScene"):
		return

	T.pass_and_quit(self)
