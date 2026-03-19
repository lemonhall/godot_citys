extends RefCounted
class_name CityMusicRoadRuntime

const CityMusicRoadDefinition := preload("res://city_game/world/features/music_road/CityMusicRoadDefinition.gd")

var _entries_by_landmark_id: Dictionary = {}
var _definitions_by_landmark_id: Dictionary = {}
var _state := {
	"landmark_count": 0,
	"mounted_landmark_count": 0,
	"active_landmark_ids": [],
	"landmarks": {},
	"road_length_m": 0.0,
	"target_speed_mps": 0.0,
	"last_completed_run": {},
}

func configure(scene_landmark_entries: Dictionary) -> void:
	_entries_by_landmark_id.clear()
	_definitions_by_landmark_id.clear()
	for landmark_id_variant in scene_landmark_entries.keys():
		var landmark_id := str(landmark_id_variant).strip_edges()
		if landmark_id == "":
			continue
		var entry_variant = scene_landmark_entries.get(landmark_id, {})
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = (entry_variant as Dictionary).duplicate(true)
		var definition_path := str(entry.get("music_road_definition_path", "")).strip_edges()
		if definition_path == "":
			continue
		_entries_by_landmark_id[landmark_id] = entry
		var definition: Variant = CityMusicRoadDefinition.load_from_path(definition_path)
		if definition != null:
			_definitions_by_landmark_id[landmark_id] = definition
	_rebuild_static_state()

func update(chunk_renderer, vehicle_state: Dictionary, time_sec: float) -> void:
	var active_landmark_ids: Array[String] = []
	var landmarks_state := {}
	var mounted_landmark_count := 0
	var best_completed_time_sec := -1.0
	var best_completed_run := {}
	for landmark_id_variant in _entries_by_landmark_id.keys():
		var landmark_id := str(landmark_id_variant)
		var entry: Dictionary = (_entries_by_landmark_id.get(landmark_id, {}) as Dictionary).duplicate(true)
		var mounted_landmark = _resolve_mounted_landmark(chunk_renderer, entry)
		if mounted_landmark == null:
			continue
		mounted_landmark_count += 1
		active_landmark_ids.append(landmark_id)
		var definition: Variant = _definitions_by_landmark_id.get(landmark_id, null)
		if mounted_landmark.has_method("configure_music_road"):
			mounted_landmark.configure_music_road(entry, definition)
		if mounted_landmark.has_method("apply_music_road_vehicle_state"):
			mounted_landmark.apply_music_road_vehicle_state(vehicle_state, time_sec)
		if mounted_landmark.has_method("get_music_road_runtime_state"):
			var landmark_state: Dictionary = mounted_landmark.get_music_road_runtime_state()
			landmarks_state[landmark_id] = landmark_state.duplicate(true)
			var last_completed_run: Dictionary = landmark_state.get("last_completed_run", {})
			var completed_time_sec := float(last_completed_run.get("completed_time_sec", -1.0))
			if completed_time_sec > best_completed_time_sec:
				best_completed_time_sec = completed_time_sec
				best_completed_run = last_completed_run.duplicate(true)
	active_landmark_ids.sort()
	_state["mounted_landmark_count"] = mounted_landmark_count
	_state["active_landmark_ids"] = active_landmark_ids
	_state["landmarks"] = landmarks_state
	_state["last_completed_run"] = best_completed_run

func get_state() -> Dictionary:
	return _state.duplicate(true)

func _rebuild_static_state() -> void:
	var road_length_m := 0.0
	var target_speed_mps := 0.0
	for definition_variant in _definitions_by_landmark_id.values():
		var definition: Variant = definition_variant
		if definition == null:
			continue
		road_length_m = float(definition.get_value("road_length_m", 0.0))
		target_speed_mps = float(definition.get_value("target_speed_mps", 0.0))
		break
	_state = {
		"landmark_count": _entries_by_landmark_id.size(),
		"mounted_landmark_count": 0,
		"active_landmark_ids": [],
		"landmarks": {},
		"road_length_m": road_length_m,
		"target_speed_mps": target_speed_mps,
		"last_completed_run": {},
	}

func _resolve_mounted_landmark(chunk_renderer, entry: Dictionary):
	if chunk_renderer == null:
		return null
	if chunk_renderer.has_method("find_scene_landmark_node"):
		var direct_landmark_id := str(entry.get("landmark_id", "")).strip_edges()
		if direct_landmark_id != "":
			var mounted_landmark = chunk_renderer.find_scene_landmark_node(direct_landmark_id)
			if mounted_landmark != null:
				return mounted_landmark
	if not chunk_renderer.has_method("get_chunk_scene"):
		return null
	var chunk_id := str(entry.get("anchor_chunk_id", "")).strip_edges()
	var chunk_landmark_id := str(entry.get("landmark_id", "")).strip_edges()
	if chunk_id == "" or chunk_landmark_id == "":
		return null
	var chunk_scene = chunk_renderer.get_chunk_scene(chunk_id)
	if chunk_scene == null or not chunk_scene.has_method("find_scene_landmark_node"):
		return null
	return chunk_scene.find_scene_landmark_node(chunk_landmark_id)
