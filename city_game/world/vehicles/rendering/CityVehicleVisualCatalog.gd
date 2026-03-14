extends RefCounted

const MANIFEST_PATH := "res://city_game/assets/vehicles/vehicle_model_manifest.json"
const DEFAULT_DIMENSIONS_M := {
	"length_m": 4.4,
	"width_m": 1.9,
	"height_m": 1.5,
}
const ROLE_COLORS := {
	"civilian": Color(0.72, 0.75, 0.8, 1.0),
	"service": Color(0.35, 0.45, 0.82, 1.0),
	"commercial": Color(0.78, 0.62, 0.34, 1.0),
}
const PRESENTATION_SCALE_BOOST := 1.35

static var _shared_manifest_loaded := false
static var _shared_manifest_snapshot: Dictionary = {}
static var _shared_model_entries: Array[Dictionary] = []
static var _shared_entries_by_id: Dictionary = {}
static var _shared_entries_by_role: Dictionary = {}
static var _shared_spawn_pools_by_road_class: Dictionary = {}
static var _shared_scene_cache: Dictionary = {}

var _manifest_snapshot: Dictionary = {}
var _model_entries: Array[Dictionary] = []
var _entries_by_id: Dictionary = {}
var _entries_by_role: Dictionary = {}
var _spawn_pools_by_road_class: Dictionary = {}
var _scene_cache: Dictionary = {}

static func prewarm_shared_resources() -> void:
	_ensure_shared_manifest_loaded()
	for entry_variant in _shared_model_entries:
		var entry: Dictionary = entry_variant
		var file_path := str(entry.get("file", ""))
		if file_path == "":
			continue
		if _shared_scene_cache.has(file_path):
			continue
		var scene_resource := load(file_path)
		var packed_scene := scene_resource as PackedScene
		if packed_scene != null:
			_shared_scene_cache[file_path] = packed_scene

func _init() -> void:
	_load_manifest()

func get_manifest_snapshot() -> Dictionary:
	return _manifest_snapshot.duplicate(true)

func get_model_count() -> int:
	return _model_entries.size()

func get_entry(model_id: String) -> Dictionary:
	if not _entries_by_id.has(model_id):
		return {}
	return (_entries_by_id[model_id] as Dictionary).duplicate(true)

func build_descriptor(spawn_slot: Dictionary) -> Dictionary:
	var entry := _select_entry_for_spawn_slot(spawn_slot)
	var dimensions := resolve_dimensions_m(entry)
	return {
		"model_id": str(entry.get("model_id", "car_b")),
		"model_signature": "%s:%s" % [
			str(entry.get("model_id", "car_b")),
			str(entry.get("vehicle_class", "sedan")),
		],
		"traffic_role": str(entry.get("traffic_role", "civilian")),
		"vehicle_class": str(entry.get("vehicle_class", "sedan")),
		"length_m": float(dimensions.get("length_m", 4.4)),
		"width_m": float(dimensions.get("width_m", 1.9)),
		"height_m": float(dimensions.get("height_m", 1.5)),
		"runtime_uniform_scale": resolve_runtime_scale(entry),
		"ground_offset_m": resolve_ground_offset_m(entry),
		"scene_path": str(entry.get("file", "")),
	}

func select_entry_for_state(state) -> Dictionary:
	var model_id := _state_model_id(state)
	if model_id != "" and _entries_by_id.has(model_id):
		return (_entries_by_id[model_id] as Dictionary).duplicate(true)
	if _model_entries.is_empty():
		return {}
	var seed_value := _state_seed(state)
	return (_model_entries[posmod(seed_value, _model_entries.size())] as Dictionary).duplicate(true)

func instantiate_scene_for_entry(entry: Dictionary) -> Node3D:
	var packed_scene := _resolve_packed_scene(entry)
	if packed_scene == null:
		return null
	var instance_variant = packed_scene.instantiate()
	var node_3d := instance_variant as Node3D
	if node_3d != null:
		return node_3d
	var wrapper := Node3D.new()
	if instance_variant is Node:
		wrapper.add_child(instance_variant as Node)
	return wrapper

func resolve_runtime_scale(entry: Dictionary) -> float:
	return float(entry.get("runtime_uniform_scale", 1.0)) * PRESENTATION_SCALE_BOOST

func resolve_ground_offset_m(entry: Dictionary) -> float:
	return float(entry.get("source_ground_offset_m", 0.0))

func resolve_dimensions_m(entry: Dictionary) -> Dictionary:
	var dimensions: Dictionary = entry.get("final_dimensions_m", {})
	if dimensions.is_empty():
		return {
			"length_m": DEFAULT_DIMENSIONS_M["length_m"] * PRESENTATION_SCALE_BOOST,
			"width_m": DEFAULT_DIMENSIONS_M["width_m"] * PRESENTATION_SCALE_BOOST,
			"height_m": DEFAULT_DIMENSIONS_M["height_m"] * PRESENTATION_SCALE_BOOST,
		}
	return {
		"length_m": float(dimensions.get("length_m", DEFAULT_DIMENSIONS_M["length_m"])) * PRESENTATION_SCALE_BOOST,
		"width_m": float(dimensions.get("width_m", DEFAULT_DIMENSIONS_M["width_m"])) * PRESENTATION_SCALE_BOOST,
		"height_m": float(dimensions.get("height_m", DEFAULT_DIMENSIONS_M["height_m"])) * PRESENTATION_SCALE_BOOST,
	}

func resolve_role_color(role: String) -> Color:
	return ROLE_COLORS.get(role, ROLE_COLORS["civilian"])

func _load_manifest() -> void:
	_manifest_snapshot.clear()
	_model_entries.clear()
	_entries_by_id.clear()
	_entries_by_role.clear()
	_spawn_pools_by_road_class.clear()
	_scene_cache = _shared_scene_cache
	if _shared_manifest_loaded:
		_manifest_snapshot = _shared_manifest_snapshot
		_model_entries = _shared_model_entries
		_entries_by_id = _shared_entries_by_id
		_entries_by_role = _shared_entries_by_role
		_spawn_pools_by_road_class = _shared_spawn_pools_by_road_class
		return
	if not FileAccess.file_exists(MANIFEST_PATH):
		_shared_manifest_snapshot = _manifest_snapshot
		_shared_model_entries = _model_entries
		_shared_entries_by_id = _entries_by_id
		_shared_entries_by_role = _entries_by_role
		_shared_spawn_pools_by_road_class = _spawn_pools_by_road_class
		_shared_manifest_loaded = true
		return
	var manifest_text := FileAccess.get_file_as_string(MANIFEST_PATH)
	var manifest_variant = JSON.parse_string(manifest_text)
	if not manifest_variant is Dictionary:
		_shared_manifest_snapshot = _manifest_snapshot
		_shared_model_entries = _model_entries
		_shared_entries_by_id = _entries_by_id
		_shared_entries_by_role = _entries_by_role
		_shared_spawn_pools_by_road_class = _spawn_pools_by_road_class
		_shared_manifest_loaded = true
		return
	_manifest_snapshot = (manifest_variant as Dictionary).duplicate(true)
	var models: Array = _manifest_snapshot.get("models", [])
	for model_variant in models:
		if not model_variant is Dictionary:
			continue
		var entry := (model_variant as Dictionary).duplicate(true)
		_model_entries.append(entry)
		_entries_by_id[str(entry.get("model_id", ""))] = entry
		var role := str(entry.get("traffic_role", "civilian"))
		if not _entries_by_role.has(role):
			_entries_by_role[role] = []
		(_entries_by_role[role] as Array).append(entry)
	_spawn_pools_by_road_class = _build_spawn_pools(_entries_by_role, _model_entries)
	_shared_manifest_snapshot = _manifest_snapshot
	_shared_model_entries = _model_entries
	_shared_entries_by_id = _entries_by_id
	_shared_entries_by_role = _entries_by_role
	_shared_spawn_pools_by_road_class = _spawn_pools_by_road_class
	_shared_manifest_loaded = true

func _prewarm_scene_resources() -> void:
	for entry in _model_entries:
		_resolve_packed_scene(entry)

static func _ensure_shared_manifest_loaded() -> void:
	if _shared_manifest_loaded:
		return
	var manifest_snapshot: Dictionary = {}
	var model_entries: Array[Dictionary] = []
	var entries_by_id: Dictionary = {}
	var entries_by_role: Dictionary = {}
	var spawn_pools_by_road_class: Dictionary = {}
	if FileAccess.file_exists(MANIFEST_PATH):
		var manifest_text := FileAccess.get_file_as_string(MANIFEST_PATH)
		var manifest_variant = JSON.parse_string(manifest_text)
		if manifest_variant is Dictionary:
			manifest_snapshot = (manifest_variant as Dictionary).duplicate(true)
			var models: Array = manifest_snapshot.get("models", [])
			for model_variant in models:
				if not model_variant is Dictionary:
					continue
				var entry := (model_variant as Dictionary).duplicate(true)
				model_entries.append(entry)
				entries_by_id[str(entry.get("model_id", ""))] = entry
				var role := str(entry.get("traffic_role", "civilian"))
				if not entries_by_role.has(role):
					entries_by_role[role] = []
				(entries_by_role[role] as Array).append(entry)
			spawn_pools_by_road_class = _build_spawn_pools(entries_by_role, model_entries)
	_shared_manifest_snapshot = manifest_snapshot
	_shared_model_entries = model_entries
	_shared_entries_by_id = entries_by_id
	_shared_entries_by_role = entries_by_role
	_shared_spawn_pools_by_road_class = spawn_pools_by_road_class
	_shared_manifest_loaded = true

func _select_entry_for_spawn_slot(spawn_slot: Dictionary) -> Dictionary:
	if _model_entries.is_empty():
		return {}
	var preferred_pool := _resolve_pool_for_spawn_slot(spawn_slot)
	if preferred_pool.is_empty():
		preferred_pool = _model_entries
	var seed_value := int(spawn_slot.get("seed", 0))
	seed_value += int(round(float(spawn_slot.get("distance_along_lane_m", 0.0)) * 10.0))
	seed_value += abs(String(spawn_slot.get("lane_ref_id", "")).hash())
	seed_value += abs(String(spawn_slot.get("road_id", "")).hash()) * 3
	return (preferred_pool[posmod(seed_value, preferred_pool.size())] as Dictionary).duplicate(true)

func _resolve_pool_for_spawn_slot(spawn_slot: Dictionary) -> Array:
	var road_class := str(spawn_slot.get("road_class", "local"))
	if _spawn_pools_by_road_class.has(road_class):
		return _spawn_pools_by_road_class[road_class] as Array
	return _spawn_pools_by_road_class.get("__default__", _model_entries) as Array

static func _build_spawn_pools(entries_by_role: Dictionary, model_entries: Array) -> Dictionary:
	var civilian_pool: Array = entries_by_role.get("civilian", model_entries)
	var service_pool: Array = entries_by_role.get("service", [])
	var commercial_pool: Array = entries_by_role.get("commercial", [])
	var secondary_pool: Array = []
	var arterial_pool: Array = []
	secondary_pool.append_array(civilian_pool)
	secondary_pool.append_array(service_pool)
	arterial_pool.append_array(commercial_pool)
	arterial_pool.append_array(civilian_pool)
	arterial_pool.append_array(service_pool)
	return {
		"local": civilian_pool,
		"service": civilian_pool,
		"collector": civilian_pool,
		"secondary": secondary_pool if not secondary_pool.is_empty() else civilian_pool,
		"arterial": arterial_pool if not arterial_pool.is_empty() else civilian_pool,
		"expressway_elevated": arterial_pool if not arterial_pool.is_empty() else civilian_pool,
		"__default__": civilian_pool if not civilian_pool.is_empty() else model_entries,
	}

func _resolve_packed_scene(entry: Dictionary) -> PackedScene:
	var file_path := str(entry.get("file", ""))
	if file_path == "":
		return null
	if _scene_cache.has(file_path):
		return _scene_cache[file_path] as PackedScene
	var scene_resource := load(file_path)
	var packed_scene := scene_resource as PackedScene
	if packed_scene == null:
		return null
	_scene_cache[file_path] = packed_scene
	return packed_scene

func _state_model_id(state) -> String:
	if state is Dictionary:
		return str((state as Dictionary).get("model_id", ""))
	return str(state.model_id) if state != null else ""

func _state_seed(state) -> int:
	if state is Dictionary:
		return int((state as Dictionary).get("seed", 0))
	return int(state.seed_value) if state != null else 0
