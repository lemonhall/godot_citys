extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityBuildingOverrideRegistry := preload("res://city_game/world/serviceability/CityBuildingOverrideRegistry.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var unique_id := "registry_priority_%d" % Time.get_ticks_msec()
	var base_root := "user://serviceability_tests/%s" % unique_id
	var preferred_registry_path := "%s/preferred/building_override_registry.json" % base_root
	var fallback_registry_path := "%s/fallback/building_override_registry.json" % base_root
	var building_id := "bld:test:priority"
	_write_registry(preferred_registry_path, building_id, "res://preferred_scene.tscn")
	_write_registry(fallback_registry_path, building_id, "user://fallback_scene.tscn")

	var registry := CityBuildingOverrideRegistry.new()
	registry.configure(preferred_registry_path, [preferred_registry_path, fallback_registry_path])
	var entries: Dictionary = registry.load_registry()
	if not T.require_true(self, entries.has(building_id), "Registry priority test requires the preferred entry to load"):
		return
	var resolved_entry: Dictionary = entries.get(building_id, {})
	if not T.require_true(self, str(resolved_entry.get("scene_path", "")) == "res://preferred_scene.tscn", "Preferred registry path must win when both registries contain the same building_id"):
		return
	T.pass_and_quit(self)

func _write_registry(resource_path: String, building_id: String, scene_path: String) -> void:
	var global_path := ProjectSettings.globalize_path(resource_path)
	var dir_error := DirAccess.make_dir_recursive_absolute(global_path.get_base_dir())
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		push_error("dir_create_failed:%s" % resource_path)
		quit(1)
		return
	var file := FileAccess.open(global_path, FileAccess.WRITE)
	if file == null:
		push_error("file_open_failed:%s" % resource_path)
		quit(1)
		return
	file.store_string(JSON.stringify({
		"schema_version": "v16-building-override-registry-1",
		"entries": {
			building_id: {
				"building_id": building_id,
				"scene_path": scene_path,
				"manifest_path": "%s/manifest.json" % scene_path.get_base_dir(),
				"export_root_kind": "preferred",
			}
		}
	}, "\t"))
	file.close()
