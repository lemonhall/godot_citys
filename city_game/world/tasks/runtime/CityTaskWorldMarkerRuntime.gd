extends Node3D

const FAMILY_ID := "city_world_ring_marker"
const CityWorldRingMarker := preload("res://city_game/world/navigation/CityWorldRingMarker.gd")

var _task_runtime = null
var _ground_resolver: Callable = Callable()
var _markers_by_slot_id: Dictionary = {}
var _marker_states_by_slot_id: Dictionary = {}

func setup(task_runtime, ground_resolver: Callable = Callable()) -> void:
	_task_runtime = task_runtime
	_ground_resolver = ground_resolver

func refresh(focus_world_position: Vector3, nearby_radius_m: float = 320.0) -> void:
	var desired_markers: Dictionary = {}
	if _task_runtime != null and _task_runtime.has_method("get_slots_for_rect"):
		var nearby_rect := Rect2(
			Vector2(focus_world_position.x - nearby_radius_m, focus_world_position.z - nearby_radius_m),
			Vector2.ONE * nearby_radius_m * 2.0
		)
		for slot_variant in _task_runtime.get_slots_for_rect(nearby_rect, ["available"], ["start"]):
			var slot: Dictionary = slot_variant
			desired_markers[str(slot.get("slot_id", ""))] = _build_marker_contract(slot, "task_available_start")
		if _task_runtime.has_method("get_current_objective_slot"):
			var objective_slot: Dictionary = _task_runtime.get_current_objective_slot()
			if not objective_slot.is_empty():
				desired_markers[str(objective_slot.get("slot_id", ""))] = _build_marker_contract(objective_slot, "task_active_objective")
	_sync_markers(desired_markers)

func tick(delta: float) -> void:
	for marker_variant in _markers_by_slot_id.values():
		var marker := marker_variant as Node3D
		if marker != null and marker.has_method("tick"):
			marker.tick(delta)

func get_state() -> Dictionary:
	var markers: Array[Dictionary] = []
	var themes: Array[String] = []
	var family_ids: Array[String] = []
	var theme_seen: Dictionary = {}
	var family_seen: Dictionary = {}
	var slot_ids: Array[String] = []
	for slot_id_variant in _markers_by_slot_id.keys():
		slot_ids.append(str(slot_id_variant))
	slot_ids.sort()
	for slot_id in slot_ids:
		var marker := _markers_by_slot_id[slot_id] as Node3D
		if marker == null or not marker.has_method("get_state"):
			continue
		var marker_state: Dictionary = marker.get_state()
		marker_state["slot_id"] = slot_id
		var stored_contract: Dictionary = _marker_states_by_slot_id.get(slot_id, {})
		marker_state["task_id"] = str(stored_contract.get("task_id", ""))
		markers.append(marker_state)
		var theme_id := str(marker_state.get("theme_id", ""))
		if theme_id != "" and not theme_seen.has(theme_id):
			theme_seen[theme_id] = true
			themes.append(theme_id)
		var family_id := str(marker_state.get("family_id", ""))
		if family_id != "" and not family_seen.has(family_id):
			family_seen[family_id] = true
			family_ids.append(family_id)
	return {
		"marker_count": markers.size(),
		"themes": themes,
		"family_ids": family_ids,
		"markers": markers,
	}

func _build_marker_contract(slot: Dictionary, theme_id: String) -> Dictionary:
	var anchor: Vector3 = slot.get("world_anchor", Vector3.ZERO)
	var slot_id := str(slot.get("slot_id", ""))
	var resolved_radius := float(slot.get("trigger_radius_m", 0.0))
	var task_id := str(slot.get("task_id", ""))
	var contract_key := _make_marker_contract_key(task_id, theme_id, resolved_radius, anchor)
	var cached_contract: Dictionary = _marker_states_by_slot_id.get(slot_id, {})
	if _can_reuse_marker_contract(cached_contract, contract_key):
		return cached_contract.duplicate(true)
	var marker_position := _resolve_marker_world_position(anchor)
	return {
		"slot_id": slot_id,
		"task_id": task_id,
		"contract_key": contract_key,
		"theme_id": theme_id,
		"radius_m": resolved_radius,
		"world_anchor": anchor,
		"world_position": marker_position,
		"family_id": FAMILY_ID,
	}

func _sync_markers(desired_markers: Dictionary) -> void:
	var stale_slot_ids: Array[String] = []
	for slot_id_variant in _markers_by_slot_id.keys():
		var slot_id := str(slot_id_variant)
		if desired_markers.has(slot_id):
			continue
		stale_slot_ids.append(slot_id)
	for slot_id in stale_slot_ids:
		var stale_marker := _markers_by_slot_id[slot_id] as Node3D
		if stale_marker != null and is_instance_valid(stale_marker):
			stale_marker.queue_free()
		_markers_by_slot_id.erase(slot_id)
		_marker_states_by_slot_id.erase(slot_id)
	for slot_id_variant in desired_markers.keys():
		var slot_id := str(slot_id_variant)
		var contract: Dictionary = desired_markers[slot_id]
		var previous_contract: Dictionary = _marker_states_by_slot_id.get(slot_id, {})
		var marker := _markers_by_slot_id.get(slot_id) as Node3D
		if marker == null or not is_instance_valid(marker):
			marker = CityWorldRingMarker.new()
			marker.name = "TaskWorldRing_%s" % slot_id.replace(":", "_")
			add_child(marker)
			_markers_by_slot_id[slot_id] = marker
		if not previous_contract.is_empty() and previous_contract == contract:
			continue
		if marker.has_method("set_marker_theme"):
			marker.set_marker_theme(str(contract.get("theme_id", "destination")))
		if marker.has_method("set_marker_radius"):
			marker.set_marker_radius(float(contract.get("radius_m", 8.0)))
		if marker.has_method("set_marker_world_position"):
			marker.set_marker_world_position(contract.get("world_position", Vector3.ZERO))
		if marker.has_method("set_marker_visible"):
			marker.set_marker_visible(true)
		_marker_states_by_slot_id[slot_id] = contract.duplicate(true)

func _resolve_marker_world_position(world_anchor: Vector3) -> Vector3:
	if _ground_resolver.is_valid():
		return _ground_resolver.call(world_anchor)
	return world_anchor

func _can_reuse_marker_contract(cached_contract: Dictionary, contract_key: String) -> bool:
	if cached_contract.is_empty():
		return false
	return str(cached_contract.get("contract_key", "")) == contract_key and cached_contract.has("world_position")

func _make_marker_contract_key(task_id: String, theme_id: String, radius_m: float, world_anchor: Vector3) -> String:
	return "%s|%s|%.3f|%.3f|%.3f|%.3f" % [
		task_id,
		theme_id,
		radius_m,
		world_anchor.x,
		world_anchor.y,
		world_anchor.z,
	]
