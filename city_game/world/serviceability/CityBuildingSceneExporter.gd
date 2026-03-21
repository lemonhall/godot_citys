extends RefCounted

const CityBuildingSceneBuilder := preload("res://city_game/world/serviceability/CityBuildingSceneBuilder.gd")

const EXPORT_SCHEMA_VERSION := "v16-building-export-1"
const REGISTRY_FILE_NAME := "building_override_registry.json"
const MANIFEST_FILE_NAME := "building_manifest.json"
const SCENE_FILE_NAME := "building_scene.tscn"

func prepare_export_payload(request: Dictionary) -> Dictionary:
	var building_contract: Dictionary = (request.get("building_contract", {}) as Dictionary).duplicate(true)
	var building_id := str(request.get("building_id", building_contract.get("building_id", "")))
	if building_id == "":
		return {
			"success": false,
			"error": "missing_building_id",
		}
	var scene_root := _normalize_resource_path(str(request.get("scene_root", "")))
	if scene_root == "":
		return {
			"success": false,
			"error": "missing_scene_root",
			"building_id": building_id,
		}
	var safe_stem := _sanitize_building_id(building_id)
	var scene_directory := "%s/%s" % [scene_root.trim_suffix("/"), safe_stem]
	var scene_path := "%s/%s" % [scene_directory, SCENE_FILE_NAME]
	var manifest_path := "%s/%s" % [scene_directory, MANIFEST_FILE_NAME]
	if FileAccess.file_exists(_globalize_path(scene_path)) or FileAccess.file_exists(_globalize_path(manifest_path)):
		return {
			"success": false,
			"error": "export_target_exists",
			"building_id": building_id,
			"scene_root": scene_root,
			"scene_path": scene_path,
			"manifest_path": manifest_path,
		}
	var display_name := str(request.get("display_name", building_contract.get("display_name", "")))
	var generation_locator: Dictionary = (request.get("generation_locator", building_contract.get("generation_locator", {})) as Dictionary).duplicate(true)
	var export_root_kind := str(request.get("export_root_kind", "preferred"))
	var requested_at_unix_sec := int(request.get("requested_at_unix_sec", 0))
	var manifest := {
		"schema_version": EXPORT_SCHEMA_VERSION,
		"building_id": building_id,
		"display_name": display_name,
		"scene_path": scene_path,
		"manifest_path": manifest_path,
		"export_root_kind": export_root_kind,
		"requested_at_unix_sec": requested_at_unix_sec,
		"generation_locator": _serialize_variant(generation_locator),
		"source_building_contract": _serialize_variant(building_contract),
	}
	return {
		"success": true,
		"building_id": building_id,
		"display_name": display_name,
		"scene_root": scene_root,
		"scene_directory": scene_directory,
		"scene_path": scene_path,
		"manifest_path": manifest_path,
		"manifest": manifest,
		"building_contract": building_contract,
		"export_root_kind": export_root_kind,
	}

func commit_export(prepared: Dictionary) -> Dictionary:
	if not bool(prepared.get("success", false)):
		return prepared
	var scene_directory := str(prepared.get("scene_directory", ""))
	var scene_path := str(prepared.get("scene_path", ""))
	var manifest_path := str(prepared.get("manifest_path", ""))
	var building_contract: Dictionary = (prepared.get("building_contract", {}) as Dictionary).duplicate(true)
	var manifest: Dictionary = (prepared.get("manifest", {}) as Dictionary).duplicate(true)
	var dir_error := DirAccess.make_dir_recursive_absolute(_globalize_path(scene_directory))
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		return _build_failure_result(prepared, "dir_create_failed:%s" % scene_directory)
	var service_root := CityBuildingSceneBuilder.build_service_scene_root(building_contract, true)
	var packed_scene := PackedScene.new()
	var pack_error := packed_scene.pack(service_root)
	if pack_error != OK:
		service_root.queue_free()
		return _build_failure_result(prepared, "pack_failed:%d" % pack_error)
	var save_error := ResourceSaver.save(packed_scene, scene_path)
	if save_error != OK:
		service_root.queue_free()
		return _build_failure_result(prepared, "scene_save_failed:%d" % save_error)
	var manifest_file := FileAccess.open(_globalize_path(manifest_path), FileAccess.WRITE)
	if manifest_file == null:
		service_root.queue_free()
		return _build_failure_result(prepared, "manifest_open_failed:%s" % manifest_path)
	manifest_file.store_string(JSON.stringify(manifest, "\t"))
	manifest_file.close()
	service_root.queue_free()
	var registry_entry := {
		"building_id": str(prepared.get("building_id", "")),
		"scene_path": scene_path,
		"manifest_path": manifest_path,
		"export_root_kind": str(prepared.get("export_root_kind", "")),
	}
	return {
		"success": true,
		"status": "completed",
		"building_id": str(prepared.get("building_id", "")),
		"display_name": str(prepared.get("display_name", "")),
		"scene_root": str(prepared.get("scene_root", "")),
		"scene_path": scene_path,
		"manifest_path": manifest_path,
		"export_root_kind": str(prepared.get("export_root_kind", "")),
		"registry_entry": registry_entry,
	}

static func build_registry_path(scene_root: String) -> String:
	var normalized_root := _normalize_resource_path(scene_root)
	if normalized_root == "":
		return ""
	return "%s/%s" % [normalized_root.trim_suffix("/"), REGISTRY_FILE_NAME]

static func _build_failure_result(prepared: Dictionary, error_text: String) -> Dictionary:
	return {
		"success": false,
		"status": "failed",
		"building_id": str(prepared.get("building_id", "")),
		"display_name": str(prepared.get("display_name", "")),
		"scene_root": str(prepared.get("scene_root", "")),
		"scene_path": str(prepared.get("scene_path", "")),
		"manifest_path": str(prepared.get("manifest_path", "")),
		"error": error_text,
		"export_root_kind": str(prepared.get("export_root_kind", "")),
	}

static func _sanitize_building_id(building_id: String) -> String:
	var safe_id := building_id.strip_edges()
	for forbidden in [":", "/", "\\", " ", "[", "]", "{", "}", "(", ")", "|", "<", ">", "\"", "'", "?", "*"]:
		safe_id = safe_id.replace(forbidden, "_")
	while safe_id.find("__") >= 0:
		safe_id = safe_id.replace("__", "_")
	return safe_id.strip_edges()

static func _normalize_resource_path(path: String) -> String:
	return path.replace("\\", "/").trim_suffix("/").strip_edges()

static func _globalize_path(path: String) -> String:
	var normalized := _normalize_resource_path(path)
	if normalized.begins_with("res://") or normalized.begins_with("user://"):
		return ProjectSettings.globalize_path(normalized)
	return normalized

static func _serialize_variant(value: Variant) -> Variant:
	if value == null:
		return null
	if value is bool or value is int or value is float or value is String:
		return value
	if value is Vector2:
		var vector2 := value as Vector2
		return {"@type": "Vector2", "x": vector2.x, "y": vector2.y}
	if value is Vector2i:
		var vector2i := value as Vector2i
		return {"@type": "Vector2i", "x": vector2i.x, "y": vector2i.y}
	if value is Vector3:
		var vector3 := value as Vector3
		return {"@type": "Vector3", "x": vector3.x, "y": vector3.y, "z": vector3.z}
	if value is Color:
		var color := value as Color
		return {"@type": "Color", "r": color.r, "g": color.g, "b": color.b, "a": color.a}
	if value is Array:
		var serialized_array: Array = []
		for item in value:
			serialized_array.append(_serialize_variant(item))
		return serialized_array
	if value is Dictionary:
		var serialized_dict := {}
		for key in value.keys():
			serialized_dict[str(key)] = _serialize_variant(value[key])
		return serialized_dict
	if value is PackedStringArray:
		var strings: PackedStringArray = value
		var serialized_strings: Array = []
		for item in strings:
			serialized_strings.append(str(item))
		return serialized_strings
	return str(value)
