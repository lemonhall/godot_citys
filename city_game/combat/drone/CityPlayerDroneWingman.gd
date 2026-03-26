extends Node3D

const DRONE_MODEL_SCENE := preload("res://city_game/assets/environment/source/aircraft/drone_a.glb")
const CitySurfaceExplosionFxScript := preload("res://city_game/combat/CitySurfaceExplosionFx.gd")
const STATE_FORMATION := "formation"
const STATE_STRIKING := "striking"
const STATE_EXPLODING := "exploding"
const STATE_SPENT := "spent"

@export var presentation_scale := 3.0
@export var follow_response := 6.5
@export var yaw_response := 6.5
@export var bob_amplitude_m := 0.14
@export var bob_frequency_hz := 0.9
@export var strike_speed_mps := 210.0
@export var strike_impact_radius_m := 2.8
@export var strike_explosion_radius_m := 16.0
@export var strike_explosion_damage := 26.0
@export var strike_explosion_effect_duration_sec := 0.22
@export var strike_surface_fx_duration_sec := 0.72
@export var strike_curve_base_lateral_offset_m := 0.55
@export var strike_curve_lateral_offset_variation_m := 1.25
@export var strike_curve_base_arc_height_m := 0.9
@export var strike_curve_arc_height_variation_m := 1.4
@export var strike_entry_speed_scale_min := 0.72
@export var strike_entry_speed_scale_max := 0.94
@export var strike_terminal_speed_scale_min := 1.14
@export var strike_terminal_speed_scale_max := 1.42

var _slot_index := 0
var _target_world_position := Vector3.ZERO
var _look_direction := Vector3.FORWARD
var _elapsed_sec := 0.0
var _visual_root: Node3D = null
var _state := STATE_FORMATION
var _strike_target_world_position := Vector3.ZERO
var _strike_order_kind := ""
var _wave_index := -1
var _explosion_elapsed_sec := 0.0
var _last_strike_result: Dictionary = {}
var _impact_fx_debug: Dictionary = {}
var _strike_progress := 0.0
var _strike_start_world_position := Vector3.ZERO
var _strike_control_world_position := Vector3.ZERO
var _strike_path_length_estimate_m := 0.0
var _path_seed := 0
var _path_lateral_offset_m := 0.0
var _path_arc_height_m := 0.0
var _path_entry_speed_scale := 1.0
var _path_terminal_speed_scale := 1.0
var _max_recorded_curve_offset_m := 0.0
var _max_recorded_vertical_offset_m := 0.0
var _min_recorded_speed_scale := 0.0
var _max_recorded_speed_scale := 0.0

func _ready() -> void:
	_ensure_visual_root()

func configure(slot_index: int, initial_world_position: Vector3, look_direction: Vector3) -> void:
	_slot_index = slot_index
	global_position = initial_world_position
	_target_world_position = initial_world_position
	_look_direction = look_direction.normalized() if look_direction.length_squared() > 0.0001 else Vector3.FORWARD
	_state = STATE_FORMATION
	_strike_target_world_position = Vector3.ZERO
	_strike_order_kind = ""
	_wave_index = -1
	_explosion_elapsed_sec = 0.0
	_last_strike_result.clear()
	_impact_fx_debug.clear()
	_strike_progress = 0.0
	_strike_start_world_position = initial_world_position
	_strike_control_world_position = initial_world_position
	_strike_path_length_estimate_m = 0.0
	_path_seed = 0
	_path_lateral_offset_m = 0.0
	_path_arc_height_m = 0.0
	_path_entry_speed_scale = 1.0
	_path_terminal_speed_scale = 1.0
	_max_recorded_curve_offset_m = 0.0
	_max_recorded_vertical_offset_m = 0.0
	_min_recorded_speed_scale = 0.0
	_max_recorded_speed_scale = 0.0
	visible = true
	if _visual_root != null:
		_visual_root.visible = true
		_visual_root.rotation = Vector3.ZERO
	_apply_immediate_orientation()

func set_follow_target(target_world_position: Vector3, look_direction: Vector3) -> void:
	if _state != STATE_FORMATION:
		return
	_target_world_position = target_world_position
	if look_direction.length_squared() > 0.0001:
		_look_direction = look_direction.normalized()

func begin_strike(target_world_position: Vector3, order_kind: String, wave_index: int = -1) -> bool:
	if _state != STATE_FORMATION:
		return false
	_state = STATE_STRIKING
	_strike_target_world_position = target_world_position
	_strike_order_kind = order_kind
	_wave_index = wave_index
	_explosion_elapsed_sec = 0.0
	_last_strike_result.clear()
	_impact_fx_debug.clear()
	_configure_strike_path()
	return true

func is_available_for_strike() -> bool:
	return _state == STATE_FORMATION

func is_spent() -> bool:
	return _state == STATE_SPENT

func get_slot_index() -> int:
	return _slot_index

func get_debug_state() -> Dictionary:
	return {
		"slot_index": _slot_index,
		"state": _state,
		"world_position": global_position,
		"target_world_position": _target_world_position,
		"strike_target_world_position": _strike_target_world_position,
		"strike_order_kind": _strike_order_kind,
		"wave_index": _wave_index,
		"path_seed": _path_seed,
		"planned_lateral_offset_m": _path_lateral_offset_m,
		"planned_arc_height_m": _path_arc_height_m,
		"strike_progress": _strike_progress,
		"min_recorded_speed_scale": _min_recorded_speed_scale,
		"max_recorded_speed_scale": _max_recorded_speed_scale,
		"max_recorded_curve_offset_m": _max_recorded_curve_offset_m,
		"max_recorded_vertical_offset_m": _max_recorded_vertical_offset_m,
		"impact_fx": _impact_fx_debug.duplicate(true),
		"last_strike_result": _last_strike_result.duplicate(true),
	}

func _process(delta: float) -> void:
	_elapsed_sec += maxf(delta, 0.0)
	match _state:
		STATE_STRIKING:
			_step_strike(delta)
			return
		STATE_EXPLODING:
			_step_explosion(delta)
			return
		STATE_SPENT:
			return
	var bob_offset := Vector3.UP * sin(_elapsed_sec * TAU * bob_frequency_hz + float(_slot_index) * 0.6) * bob_amplitude_m
	var desired_world_position := _target_world_position + bob_offset
	var blend := clampf(follow_response * maxf(delta, 0.0), 0.0, 1.0)
	if global_position.distance_to(desired_world_position) >= 24.0:
		global_position = desired_world_position
	else:
		global_position = global_position.lerp(desired_world_position, blend)
	var desired_yaw_rad := atan2(-_look_direction.x, -_look_direction.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw_rad, clampf(yaw_response * maxf(delta, 0.0), 0.0, 1.0))

func _ensure_visual_root() -> void:
	if _visual_root != null and is_instance_valid(_visual_root):
		return
	_visual_root = Node3D.new()
	_visual_root.name = "ModelRoot"
	add_child(_visual_root)
	if DRONE_MODEL_SCENE != null:
		var drone_model := DRONE_MODEL_SCENE.instantiate() as Node3D
		if drone_model != null:
			_visual_root.add_child(drone_model)
	_visual_root.scale = Vector3.ONE * presentation_scale

func _apply_immediate_orientation() -> void:
	var desired_yaw_rad := atan2(-_look_direction.x, -_look_direction.z)
	rotation.y = desired_yaw_rad

func _step_strike(delta: float) -> void:
	if _strike_target_world_position == Vector3.ZERO:
		_explode("missing_target", global_position)
		return
	if _strike_progress >= 1.0 - 0.0001:
		_explode("target_reached", _strike_target_world_position)
		return
	var previous_progress := _strike_progress
	var start_speed_scale := _resolve_speed_scale(previous_progress)
	var progress_step := (strike_speed_mps * start_speed_scale * maxf(delta, 0.0)) / maxf(_strike_path_length_estimate_m, 0.001)
	var next_progress := minf(previous_progress + progress_step, 1.0)
	var end_speed_scale := _resolve_speed_scale(next_progress)
	var previous_position := _evaluate_strike_curve(previous_progress)
	var next_position := _evaluate_strike_curve(next_progress)
	var frame_delta := next_position - previous_position
	if get_world_3d() != null and get_world_3d().direct_space_state != null:
		var query := PhysicsRayQueryParameters3D.create(previous_position, next_position)
		query.collide_with_areas = false
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			_explode("impact", hit.get("position", next_position))
			return
	global_position = next_position
	_strike_progress = next_progress
	_record_path_metrics(next_position, next_progress, start_speed_scale, end_speed_scale)
	_sync_strike_visual(frame_delta)
	if next_progress >= 1.0 or global_position.distance_to(_strike_target_world_position) <= strike_impact_radius_m:
		_explode("target_reached", _strike_target_world_position)

func _explode(trigger_kind: String, explosion_world_position: Vector3) -> void:
	if _state == STATE_EXPLODING or _state == STATE_SPENT:
		return
	var resolved_impact_world_position := _resolve_effect_surface_world_position(explosion_world_position)
	global_position = resolved_impact_world_position
	_state = STATE_EXPLODING
	_explosion_elapsed_sec = 0.0
	_last_strike_result = _apply_explosion_damage(resolved_impact_world_position)
	_impact_fx_debug = _spawn_surface_explosion_fx(resolved_impact_world_position)
	_last_strike_result["trigger_kind"] = trigger_kind
	_last_strike_result["order_kind"] = _strike_order_kind
	_last_strike_result["wave_index"] = _wave_index
	_last_strike_result["impact_world_position"] = resolved_impact_world_position
	_last_strike_result["explosion_world_position"] = resolved_impact_world_position
	_last_strike_result["path_seed"] = _path_seed
	_last_strike_result["planned_lateral_offset_m"] = _path_lateral_offset_m
	_last_strike_result["planned_arc_height_m"] = _path_arc_height_m
	_last_strike_result["min_recorded_speed_scale"] = _min_recorded_speed_scale
	_last_strike_result["max_recorded_speed_scale"] = _max_recorded_speed_scale
	_last_strike_result["max_recorded_curve_offset_m"] = _max_recorded_curve_offset_m
	_last_strike_result["max_recorded_vertical_offset_m"] = _max_recorded_vertical_offset_m
	_last_strike_result["impact_fx"] = _impact_fx_debug.duplicate(true)
	_last_strike_result["impact_fx_played"] = bool(_impact_fx_debug.get("played", false))
	_last_strike_result["impact_fx_ring_enabled"] = bool(_impact_fx_debug.get("ring_enabled", false))
	_last_strike_result["impact_fx_sphere_enabled"] = bool(_impact_fx_debug.get("sphere_enabled", false))
	_last_strike_result["impact_audio_trigger_count"] = int(_impact_fx_debug.get("audio_trigger_count", 0))
	_last_strike_result["impact_audio_stream_path"] = str(_impact_fx_debug.get("audio_stream_path", ""))
	if _visual_root != null:
		_visual_root.visible = false

func _step_explosion(delta: float) -> void:
	_explosion_elapsed_sec += maxf(delta, 0.0)
	if _exposure_done():
		_state = STATE_SPENT
		visible = false

func _apply_explosion_damage(explosion_world_position: Vector3) -> Dictionary:
	var enemy_hit_count := 0
	var building_hit_count := 0
	if get_tree() != null:
		for enemy_node in get_tree().get_nodes_in_group("city_enemy"):
			var enemy := enemy_node as Node3D
			if enemy == null or not is_instance_valid(enemy):
				continue
			if enemy.global_position.distance_to(explosion_world_position) > strike_explosion_radius_m:
				continue
			if enemy.has_method("apply_projectile_hit"):
				var impulse_direction := enemy.global_position - explosion_world_position
				if impulse_direction.length_squared() <= 0.0001:
					impulse_direction = Vector3.UP
				enemy.apply_projectile_hit(strike_explosion_damage, explosion_world_position, impulse_direction.normalized() * 24.0)
				enemy_hit_count += 1
		for building_node in get_tree().get_nodes_in_group("city_destructible_building"):
			if building_node == null or not is_instance_valid(building_node):
				continue
			if not building_node.has_method("apply_explosion_damage"):
				continue
			var building_result: Dictionary = building_node.apply_explosion_damage(explosion_world_position, strike_explosion_damage, strike_explosion_radius_m)
			if bool(building_result.get("accepted", false)):
				building_hit_count += 1
	var pedestrian_result: Dictionary = {}
	var vehicle_result: Dictionary = {}
	var world_runtime := _resolve_world_runtime()
	if world_runtime != null:
		if world_runtime.has_method("resolve_pedestrian_explosion"):
			pedestrian_result = world_runtime.resolve_pedestrian_explosion(explosion_world_position, maxf(strike_explosion_radius_m * 0.42, 5.0), strike_explosion_radius_m)
		if world_runtime.has_method("resolve_vehicle_explosion"):
			vehicle_result = world_runtime.resolve_vehicle_explosion(explosion_world_position, strike_explosion_radius_m)
	return {
		"enemy_hit_count": enemy_hit_count,
		"building_hit_count": building_hit_count,
		"pedestrian_result": pedestrian_result.duplicate(true),
		"vehicle_result": vehicle_result.duplicate(true),
	}

func _resolve_world_runtime() -> Node:
	var current: Node = get_parent()
	while current != null:
		if current.has_method("resolve_pedestrian_explosion") or current.has_method("resolve_vehicle_explosion"):
			return current
		current = current.get_parent()
	return null

func _exposure_done() -> bool:
	return _explosion_elapsed_sec >= maxf(strike_explosion_effect_duration_sec, 0.001)

func _configure_strike_path() -> void:
	_strike_progress = 0.0
	_strike_start_world_position = global_position
	_strike_control_world_position = global_position
	_path_seed = _build_path_seed()
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(_path_seed)
	var direct_delta := _strike_target_world_position - _strike_start_world_position
	var direct_distance_m := direct_delta.length()
	var forward := direct_delta.normalized() if direct_distance_m > 0.0001 else Vector3.FORWARD
	var reference_up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.94 else Vector3.FORWARD
	var lateral_axis := forward.cross(reference_up).normalized()
	if lateral_axis.length_squared() <= 0.0001:
		lateral_axis = Vector3.RIGHT
	var lateral_sign := -1.0 if rng.randf() < 0.5 else 1.0
	var lateral_cap := maxf(minf(direct_distance_m * 0.11, strike_curve_base_lateral_offset_m + strike_curve_lateral_offset_variation_m), strike_curve_base_lateral_offset_m)
	_path_lateral_offset_m = lateral_sign * lerpf(strike_curve_base_lateral_offset_m, lateral_cap, rng.randf())
	var arc_cap := maxf(minf(direct_distance_m * 0.16, strike_curve_base_arc_height_m + strike_curve_arc_height_variation_m), strike_curve_base_arc_height_m)
	_path_arc_height_m = lerpf(strike_curve_base_arc_height_m, arc_cap, rng.randf())
	_path_entry_speed_scale = lerpf(strike_entry_speed_scale_min, strike_entry_speed_scale_max, rng.randf())
	_path_terminal_speed_scale = lerpf(strike_terminal_speed_scale_min, strike_terminal_speed_scale_max, rng.randf())
	var midpoint := _strike_start_world_position.lerp(_strike_target_world_position, 0.5)
	_strike_control_world_position = midpoint + lateral_axis * _path_lateral_offset_m + Vector3.UP * _path_arc_height_m
	_strike_path_length_estimate_m = _estimate_curve_length()
	_max_recorded_curve_offset_m = 0.0
	_max_recorded_vertical_offset_m = 0.0
	_min_recorded_speed_scale = _path_entry_speed_scale
	_max_recorded_speed_scale = _path_entry_speed_scale
	_record_path_metrics(_strike_start_world_position, 0.0, _path_entry_speed_scale)
	if _visual_root != null:
		_visual_root.rotation = Vector3.ZERO

func _build_path_seed() -> int:
	var target_x := int(round(_strike_target_world_position.x * 10.0))
	var target_y := int(round(_strike_target_world_position.y * 10.0))
	var target_z := int(round(_strike_target_world_position.z * 10.0))
	var seed_text := "%s|%d|%d|%d|%d|%d" % [_strike_order_kind, _slot_index, _wave_index, target_x, target_y, target_z]
	var seed_value := int(hash(seed_text))
	if seed_value == 0:
		seed_value = (_slot_index + 1) * 97
	return seed_value

func _estimate_curve_length() -> float:
	var sampled_length := 0.0
	var previous_point := _strike_start_world_position
	for sample_index in range(1, 9):
		var progress := float(sample_index) / 8.0
		var sampled_point := _evaluate_strike_curve(progress)
		sampled_length += previous_point.distance_to(sampled_point)
		previous_point = sampled_point
	return maxf(sampled_length, _strike_start_world_position.distance_to(_strike_target_world_position))

func _evaluate_strike_curve(progress: float) -> Vector3:
	var clamped_progress := clampf(progress, 0.0, 1.0)
	var first_segment := _strike_start_world_position.lerp(_strike_control_world_position, clamped_progress)
	var second_segment := _strike_control_world_position.lerp(_strike_target_world_position, clamped_progress)
	return first_segment.lerp(second_segment, clamped_progress)

func _resolve_speed_scale(progress: float) -> float:
	var eased_progress := clampf(progress, 0.0, 1.0)
	eased_progress = eased_progress * eased_progress * (3.0 - 2.0 * eased_progress)
	return lerpf(_path_entry_speed_scale, _path_terminal_speed_scale, eased_progress)

func _record_path_metrics(world_position: Vector3, progress: float, start_speed_scale: float, end_speed_scale: float = INF) -> void:
	var linear_position := _strike_start_world_position.lerp(_strike_target_world_position, clampf(progress, 0.0, 1.0))
	_max_recorded_curve_offset_m = maxf(_max_recorded_curve_offset_m, world_position.distance_to(linear_position))
	_max_recorded_vertical_offset_m = maxf(_max_recorded_vertical_offset_m, absf(world_position.y - linear_position.y))
	var resolved_end_speed_scale := end_speed_scale if is_finite(end_speed_scale) else start_speed_scale
	_min_recorded_speed_scale = minf(_min_recorded_speed_scale, minf(start_speed_scale, resolved_end_speed_scale))
	_max_recorded_speed_scale = maxf(_max_recorded_speed_scale, maxf(start_speed_scale, resolved_end_speed_scale))

func _sync_strike_visual(frame_delta: Vector3) -> void:
	if frame_delta.length_squared() > 0.0001:
		var up_axis := Vector3.UP if absf(frame_delta.normalized().dot(Vector3.UP)) < 0.94 else Vector3.FORWARD
		look_at(global_position + frame_delta.normalized(), up_axis, true)
	if _visual_root == null:
		return
	var bank_sign := -1.0 if _path_lateral_offset_m < 0.0 else 1.0
	var dive_pitch := lerpf(-0.08, 0.22, _strike_progress)
	var bank_roll := bank_sign * lerpf(0.16, 0.04, _strike_progress)
	_visual_root.rotation = Vector3(dive_pitch, 0.0, bank_roll)

func _resolve_effect_surface_world_position(world_position: Vector3) -> Vector3:
	var world_runtime := _resolve_world_runtime()
	if world_runtime != null and world_runtime.has_method("resolve_observer_effect_surface_world_position"):
		return world_runtime.resolve_observer_effect_surface_world_position(world_position)
	return world_position

func _spawn_surface_explosion_fx(world_position: Vector3) -> Dictionary:
	if CitySurfaceExplosionFxScript == null:
		return {
			"played": false,
			"ring_enabled": false,
			"sphere_enabled": false,
			"audio_trigger_count": 0,
			"audio_stream_path": "",
			"world_position": world_position,
		}
	var fx := CitySurfaceExplosionFxScript.new() as Node3D
	if fx == null:
		return {
			"played": false,
			"ring_enabled": false,
			"sphere_enabled": false,
			"audio_trigger_count": 0,
			"audio_stream_path": "",
			"world_position": world_position,
		}
	var parent_node := get_parent() if get_parent() != null else self
	parent_node.add_child(fx)
	if fx.has_method("configure"):
		fx.configure(world_position, strike_explosion_radius_m, strike_surface_fx_duration_sec)
	if fx.has_method("play"):
		fx.play()
	return (fx.get_debug_state() as Dictionary).duplicate(true) if fx.has_method("get_debug_state") else {
		"played": true,
		"ring_enabled": false,
		"sphere_enabled": false,
		"audio_trigger_count": 0,
		"audio_stream_path": "",
		"world_position": world_position,
	}
