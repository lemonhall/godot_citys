extends Node3D

const CityArtilleryBallisticsScript := preload("res://city_game/combat/artillery/CityArtilleryBallistics.gd")
const CityChunkKeyScript := preload("res://city_game/world/streaming/CityChunkKey.gd")
const CityM777HowitzerScene := preload("res://city_game/combat/artillery/CityM777Howitzer.tscn")

const MISSION_ID := "artillery_fire_mission:active"
const OBSERVER_CAMERA_OWNER := "artillery_observer"

@export var observer_muzzle_stage_duration_sec := 0.85
@export var observer_impact_hold_duration_sec := 1.15
@export var observer_height_m := 36.0
@export var observer_backoff_m := 58.0
@export var observer_look_at_height_offset_m := 4.0
@export var prewarm_ring_radius_chunks := 1

var _world_config = null
var _chunk_renderer = null
var _player: Node3D = null
var _player_camera: Camera3D = null
var _ballistics = CityArtilleryBallisticsScript.new()
var _fire_mission_state: Dictionary = _build_inactive_fire_mission_state()
var _observation_state: Dictionary = _build_idle_observation_state()
var _observation_phase_elapsed_sec := 0.0
var _latest_shell_explosion_result: Dictionary = {}
var _locked_player_world_position := Vector3.ZERO
var _reference_platform_local_offset := Vector3.ZERO
var _reference_root_vertical_offset_m := 0.0

@onready var _observer_rig := Node3D.new()
@onready var _observer_camera := Camera3D.new()

func _ready() -> void:
	name = "ArtilleryFireMissionRuntime"
	process_mode = Node.PROCESS_MODE_INHERIT
	_capture_reference_offsets()
	_ensure_observer_camera()

func _process(delta: float) -> void:
	if not bool(_observation_state.get("active", false)):
		return
	_maintain_player_lock_position()
	_observation_phase_elapsed_sec += maxf(delta, 0.0)
	match str(_observation_state.get("phase", "idle")):
		"muzzle_stage":
			if _observation_phase_elapsed_sec >= maxf(observer_muzzle_stage_duration_sec, 0.01):
				_enter_impact_stage()
		"impact_stage":
			if _latest_shell_explosion_result.is_empty():
				return
			var remaining_sec := maxf(float(_observation_state.get("impact_hold_remaining_sec", observer_impact_hold_duration_sec)) - maxf(delta, 0.0), 0.0)
			_observation_state["impact_hold_remaining_sec"] = remaining_sec
			if remaining_sec <= 0.0:
				_complete_observation()

func configure(world_config, chunk_renderer, player: Node3D) -> void:
	_world_config = world_config
	_chunk_renderer = chunk_renderer
	_player = player
	_player_camera = _resolve_player_camera()

func build_battery_snapshot_from_world_howitzer(howitzer: Node3D) -> Dictionary:
	if howitzer == null or not is_instance_valid(howitzer):
		return {}
	var spawn_forward_world := -howitzer.global_transform.basis.z
	spawn_forward_world.y = 0.0
	if spawn_forward_world.length_squared() <= 0.0001:
		spawn_forward_world = Vector3.FORWARD
	spawn_forward_world = spawn_forward_world.normalized()
	var platform_world_position := howitzer.global_position + _rotate_reference_offset_yaw(_reference_platform_local_offset, spawn_forward_world)
	if howitzer.has_method("get_firing_solution_snapshot"):
		var firing_solution := howitzer.get_firing_solution_snapshot() as Dictionary
		if firing_solution.get("platform_world_position", null) is Vector3:
			platform_world_position = firing_solution.get("platform_world_position", platform_world_position) as Vector3
	var chunk_key := _resolve_chunk_key(platform_world_position)
	return {
		"spawn_root_world_position": howitzer.global_position,
		"spawn_forward_world": spawn_forward_world,
		"platform_world_position": platform_world_position,
		"chunk_key": chunk_key,
		"chunk_id": _format_chunk_id(chunk_key),
	}

func build_battery_snapshot_from_spawn(raw_spawn_world_position: Vector3, spawn_forward_world: Vector3) -> Dictionary:
	var resolved_forward := spawn_forward_world
	resolved_forward.y = 0.0
	if resolved_forward.length_squared() <= 0.0001:
		resolved_forward = Vector3.FORWARD
	resolved_forward = resolved_forward.normalized()
	var spawn_root_world_position := raw_spawn_world_position + Vector3.UP * _reference_root_vertical_offset_m
	var platform_world_position := spawn_root_world_position + _rotate_reference_offset_yaw(_reference_platform_local_offset, resolved_forward)
	var chunk_key := _resolve_chunk_key(platform_world_position)
	return {
		"spawn_root_world_position": spawn_root_world_position,
		"spawn_forward_world": resolved_forward,
		"platform_world_position": platform_world_position,
		"chunk_key": chunk_key,
		"chunk_id": _format_chunk_id(chunk_key),
	}

func plan_fire_mission(target_world_position: Vector3, battery_snapshot: Dictionary) -> Dictionary:
	if battery_snapshot.is_empty():
		_fire_mission_state = _build_inactive_fire_mission_state()
		return {}
	var solved_solution := _ballistics.solve_firing_solution_to_target(
		battery_snapshot.get("platform_world_position", target_world_position) as Vector3,
		target_world_position
	) if _ballistics != null and _ballistics.has_method("solve_firing_solution_to_target") else {}
	var solution_state := _build_solution_state(solved_solution)
	var target_chunk_key := _resolve_chunk_key(target_world_position)
	_fire_mission_state = {
		"active": true,
		"mission_id": MISSION_ID,
		"target_world_position": target_world_position,
		"target_chunk_key": target_chunk_key,
		"target_chunk_id": _format_chunk_id(target_chunk_key),
		"battery_snapshot": battery_snapshot.duplicate(true),
		"solution_state": solution_state.duplicate(true),
	}
	return _fire_mission_state.duplicate(true)

func clear_fire_mission() -> void:
	_fire_mission_state = _build_inactive_fire_mission_state()

func get_fire_mission_state() -> Dictionary:
	return _fire_mission_state.duplicate(true)

func build_fire_mission_pin() -> Dictionary:
	if not bool(_fire_mission_state.get("active", false)):
		return {}
	var solution_state: Dictionary = _fire_mission_state.get("solution_state", {})
	var subtitle := str(solution_state.get("reason", ""))
	if bool(solution_state.get("solved", false)):
		subtitle = "方位 %.1f°  高低 %.1f°" % [
			float(solution_state.get("world_bearing_deg", 0.0)),
			float(solution_state.get("pitch_deg", 0.0)),
		]
	return {
		"pin_id": str(_fire_mission_state.get("mission_id", MISSION_ID)),
		"pin_type": "artillery_fire_mission",
		"pin_source": "artillery_fire_mission",
		"visibility_scope": "all",
		"world_position": _fire_mission_state.get("target_world_position", Vector3.ZERO),
		"title": "炮击标记",
		"subtitle": subtitle,
		"priority": 125,
		"icon_id": "",
		"is_selectable": true,
		"marker_style": "cross",
	}

func start_observation_from_firing_solution(firing_solution: Dictionary) -> Dictionary:
	if firing_solution.is_empty():
		return {}
	var predicted := _ballistics.predict_impact_from_firing_solution(firing_solution, {
		"impact_plane_y": 0.0,
	}) if _ballistics != null and _ballistics.has_method("predict_impact_from_firing_solution") else {}
	var predicted_impact_world_position := predicted.get("impact_world_position", firing_solution.get("origin_world_position", Vector3.ZERO)) as Vector3
	var predicted_chunk_key := _resolve_chunk_key(predicted_impact_world_position)
	var prewarm_entries := _build_chunk_ring_entries(predicted_chunk_key, prewarm_ring_radius_chunks)
	_prewarm_observation_entries(prewarm_entries)
	_lock_player_for_observation()
	_latest_shell_explosion_result.clear()
	_observation_phase_elapsed_sec = 0.0
	_observation_state = {
		"active": true,
		"phase": "muzzle_stage",
		"camera_owner": "player",
		"predicted_impact_world_position": predicted_impact_world_position,
		"predicted_impact_chunk_key": predicted_chunk_key,
		"predicted_impact_chunk_id": _format_chunk_id(predicted_chunk_key),
		"prewarm_entry_count": prewarm_entries.size(),
		"impact_hold_remaining_sec": maxf(observer_impact_hold_duration_sec, 0.0),
		"firing_solution": firing_solution.duplicate(true),
		"shell_explosion_result": {},
	}
	return _observation_state.duplicate(true)

func notify_shell_exploded(result: Dictionary) -> void:
	if result.is_empty():
		return
	_latest_shell_explosion_result = result.duplicate(true)
	if not bool(_observation_state.get("active", false)):
		return
	_observation_state["shell_explosion_result"] = _latest_shell_explosion_result.duplicate(true)
	if str(_observation_state.get("phase", "")) == "impact_stage":
		_observation_state["impact_hold_remaining_sec"] = maxf(observer_impact_hold_duration_sec, 0.0)

func get_observation_state() -> Dictionary:
	return _observation_state.duplicate(true)

func _build_solution_state(result: Dictionary) -> Dictionary:
	if result.is_empty():
		return {
			"solved": false,
			"reason": "solver_unavailable",
			"range_state": "solver_unavailable",
			"world_bearing_deg": 0.0,
			"pitch_deg": 0.0,
			"horizontal_distance_m": 0.0,
			"flight_time_sec": 0.0,
			"arc_kind": "",
		}
	return {
		"solved": bool(result.get("solved", false)),
		"reason": str(result.get("reason", result.get("range_state", ""))),
		"range_state": str(result.get("range_state", "")),
		"world_bearing_deg": float(result.get("world_bearing_deg", 0.0)),
		"pitch_deg": float(result.get("pitch_deg", 0.0)),
		"horizontal_distance_m": float(result.get("horizontal_distance_m", 0.0)),
		"flight_time_sec": float(result.get("flight_time_sec", 0.0)),
		"arc_kind": str(result.get("arc_kind", "")),
		"predicted_impact_world_position": result.get("predicted_impact_world_position", Vector3.ZERO),
	}

func _build_inactive_fire_mission_state() -> Dictionary:
	return {
		"active": false,
		"mission_id": "",
		"target_world_position": Vector3.ZERO,
		"target_chunk_key": Vector2i.ZERO,
		"target_chunk_id": "",
		"battery_snapshot": {},
		"solution_state": {},
	}

func _build_idle_observation_state() -> Dictionary:
	return {
		"active": false,
		"phase": "idle",
		"camera_owner": "player",
		"predicted_impact_world_position": Vector3.ZERO,
		"predicted_impact_chunk_key": Vector2i.ZERO,
		"predicted_impact_chunk_id": "",
		"prewarm_entry_count": 0,
		"impact_hold_remaining_sec": 0.0,
		"firing_solution": {},
		"shell_explosion_result": {},
	}

func _capture_reference_offsets() -> void:
	if CityM777HowitzerScene == null:
		return
	var reference_howitzer := CityM777HowitzerScene.instantiate() as Node3D
	if reference_howitzer == null:
		return
	_reference_root_vertical_offset_m = reference_howitzer.position.y
	var pitch_anchor := reference_howitzer.get_node_or_null("Anchors/PitchPivotAnchor") as Node3D
	if pitch_anchor != null:
		_reference_platform_local_offset = pitch_anchor.position
	reference_howitzer.queue_free()

func _ensure_observer_camera() -> void:
	if _observer_rig.get_parent() == null:
		_observer_rig.name = "ObserverRig"
		add_child(_observer_rig)
	if _observer_camera.get_parent() == null:
		_observer_camera.name = "ObserverCamera"
		_observer_camera.current = false
		_observer_camera.fov = 52.0
		_observer_rig.add_child(_observer_camera)

func _rotate_reference_offset_yaw(local_offset: Vector3, forward_world: Vector3) -> Vector3:
	var yaw_rad := atan2(-forward_world.x, -forward_world.z)
	return Basis(Vector3.UP, yaw_rad) * local_offset

func _resolve_chunk_key(world_position: Vector3) -> Vector2i:
	if _world_config == null:
		return Vector2i.ZERO
	return CityChunkKeyScript.world_to_chunk_key(_world_config, world_position)

func _format_chunk_id(chunk_key: Vector2i) -> String:
	if _world_config == null or not _world_config.has_method("format_chunk_id"):
		return ""
	return _world_config.format_chunk_id(chunk_key)

func _build_chunk_ring_entries(center_chunk_key: Vector2i, ring_radius_chunks: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var resolved_radius := maxi(ring_radius_chunks, 0)
	for chunk_x in range(center_chunk_key.x - resolved_radius, center_chunk_key.x + resolved_radius + 1):
		for chunk_y in range(center_chunk_key.y - resolved_radius, center_chunk_key.y + resolved_radius + 1):
			var chunk_key := Vector2i(chunk_x, chunk_y)
			entries.append({
				"chunk_key": chunk_key,
				"chunk_id": _format_chunk_id(chunk_key),
			})
	return entries

func _prewarm_observation_entries(chunk_entries: Array[Dictionary]) -> void:
	if _chunk_renderer == null or not is_instance_valid(_chunk_renderer):
		return
	if _chunk_renderer.has_method("prewarm_actor_pages"):
		_chunk_renderer.prewarm_actor_pages(chunk_entries)
	if _chunk_renderer.has_method("prewarm_chunk_pages"):
		_chunk_renderer.prewarm_chunk_pages(chunk_entries, false, true)

func _lock_player_for_observation() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_player_camera = _resolve_player_camera()
	_locked_player_world_position = _player.global_position
	if _player.has_method("set_control_enabled"):
		_player.set_control_enabled(false)
	if _player.has_method("set_movement_locked"):
		_player.set_movement_locked(true)
	if _player_camera != null:
		_player_camera.current = true

func _maintain_player_lock_position() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.has_method("teleport_to_world_position"):
		_player.teleport_to_world_position(_locked_player_world_position)
	else:
		_player.global_position = _locked_player_world_position

func _enter_impact_stage() -> void:
	var predicted_impact_world_position := _observation_state.get("predicted_impact_world_position", Vector3.ZERO) as Vector3
	var look_target := predicted_impact_world_position + Vector3.UP * observer_look_at_height_offset_m
	var observer_origin := predicted_impact_world_position + Vector3.UP * observer_height_m + Vector3.BACK * observer_backoff_m
	_observer_rig.global_position = observer_origin
	_observer_rig.look_at(look_target, Vector3.UP, true)
	if _player_camera == null:
		_player_camera = _resolve_player_camera()
	if _player_camera != null:
		_player_camera.current = false
	_observer_camera.current = true
	_observation_phase_elapsed_sec = 0.0
	_observation_state["phase"] = "impact_stage"
	_observation_state["camera_owner"] = OBSERVER_CAMERA_OWNER
	if not _latest_shell_explosion_result.is_empty():
		_observation_state["impact_hold_remaining_sec"] = maxf(observer_impact_hold_duration_sec, 0.0)

func _complete_observation() -> void:
	_observer_camera.current = false
	if _player_camera == null:
		_player_camera = _resolve_player_camera()
	if _player_camera != null:
		_player_camera.current = true
	if _player != null and is_instance_valid(_player):
		if _player.has_method("set_control_enabled"):
			_player.set_control_enabled(true)
		if _player.has_method("set_movement_locked"):
			_player.set_movement_locked(false)
	_observation_phase_elapsed_sec = 0.0
	_observation_state = _build_idle_observation_state()
	_latest_shell_explosion_result.clear()

func _resolve_player_camera() -> Camera3D:
	if _player == null or not is_instance_valid(_player):
		return null
	return _player.get_node_or_null("CameraRig/Camera3D") as Camera3D
