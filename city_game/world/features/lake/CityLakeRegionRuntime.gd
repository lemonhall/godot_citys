extends RefCounted

const CityLakeRegionDefinition := preload("res://city_game/world/features/lake/CityLakeRegionDefinition.gd")

var _manifest_path := ""
var _manifest: Dictionary = {}
var _shoreline_profile: Dictionary = {}
var _bathymetry_profile: Dictionary = {}
var _habitat_profile: Dictionary = {}
var _runtime_contract: Dictionary = {}

func load_from_manifest(manifest_path: String) -> bool:
	_manifest_path = manifest_path.replace("\\", "/").trim_suffix("/").strip_edges()
	_manifest = _load_json_dict(_manifest_path)
	if _manifest.is_empty():
		return false
	_manifest["manifest_path"] = _manifest_path
	_shoreline_profile = _load_json_dict(str(_manifest.get("shoreline_profile_path", "")))
	_bathymetry_profile = _load_json_dict(str(_manifest.get("bathymetry_profile_path", "")))
	_habitat_profile = _load_json_dict(str(_manifest.get("habitat_profile_path", "")))
	if _shoreline_profile.is_empty() or _bathymetry_profile.is_empty() or _habitat_profile.is_empty():
		return false
	_runtime_contract = CityLakeRegionDefinition.build_runtime_contract(
		_manifest,
		_shoreline_profile,
		_bathymetry_profile,
		_habitat_profile
	)
	return not _runtime_contract.is_empty()

func get_state() -> Dictionary:
	return {
		"manifest_path": _manifest_path,
		"region_id": str(_runtime_contract.get("region_id", "")),
		"anchor_chunk_id": str(_runtime_contract.get("anchor_chunk_id", "")),
		"water_level_y_m": float(_runtime_contract.get("water_level_y_m", 0.0)),
		"polygon_point_count": (_runtime_contract.get("polygon_world_points", []) as Array).size(),
	}

func get_manifest_snapshot() -> Dictionary:
	return _manifest.duplicate(true)

func get_runtime_contract() -> Dictionary:
	return _runtime_contract.duplicate(true)

func contains_world_position(world_position: Vector3) -> bool:
	return bool(sample_depth_at_world_position(world_position).get("inside_region", false))

func sample_depth_at_world_position(world_position: Vector3) -> Dictionary:
	if _runtime_contract.is_empty():
		return {
			"inside_region": false,
			"world_position": world_position,
		}
	return CityLakeRegionDefinition.sample_depth_from_contract(_runtime_contract, world_position)

func query_water_state(world_position: Vector3) -> Dictionary:
	if _runtime_contract.is_empty():
		return {
			"in_water": false,
			"underwater": false,
			"region_id": "",
			"world_position": world_position,
		}
	return CityLakeRegionDefinition.build_water_state(_runtime_contract, world_position)

func get_fish_school_profiles() -> Array:
	return (_runtime_contract.get("schools", []) as Array).duplicate(true)

func _load_json_dict(resource_path: String) -> Dictionary:
	var normalized_path := resource_path.replace("\\", "/").trim_suffix("/").strip_edges()
	if normalized_path == "":
		return {}
	var global_path := ProjectSettings.globalize_path(normalized_path)
	if not FileAccess.file_exists(global_path):
		return {}
	var text := FileAccess.get_file_as_string(global_path)
	if text.strip_edges() == "":
		return {}
	var payload = JSON.parse_string(text)
	if not (payload is Dictionary):
		return {}
	return (payload as Dictionary).duplicate(true)
