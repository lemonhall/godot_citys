extends Node3D

const DRONE_MODEL_SCENE := preload("res://city_game/assets/environment/source/aircraft/drone_a.glb")
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
	visible = true
	if _visual_root != null:
		_visual_root.visible = true
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
	var previous_position := global_position
	var to_target := _strike_target_world_position - previous_position
	var distance_to_target := to_target.length()
	if distance_to_target <= strike_impact_radius_m:
		_explode("target_reached", _strike_target_world_position)
		return
	var direction := to_target / maxf(distance_to_target, 0.001)
	look_at(global_position + direction, Vector3.UP, true)
	var travel_distance := minf(strike_speed_mps * maxf(delta, 0.0), distance_to_target)
	var next_position := previous_position + direction * travel_distance
	if get_world_3d() != null and get_world_3d().direct_space_state != null:
		var query := PhysicsRayQueryParameters3D.create(previous_position, next_position)
		query.collide_with_areas = false
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			_explode("impact", hit.get("position", next_position))
			return
	global_position = next_position
	if travel_distance >= distance_to_target - 0.0001:
		_explode("target_reached", _strike_target_world_position)

func _explode(trigger_kind: String, explosion_world_position: Vector3) -> void:
	if _state == STATE_EXPLODING or _state == STATE_SPENT:
		return
	global_position = explosion_world_position
	_state = STATE_EXPLODING
	_explosion_elapsed_sec = 0.0
	_last_strike_result = _apply_explosion_damage(explosion_world_position)
	_last_strike_result["trigger_kind"] = trigger_kind
	_last_strike_result["order_kind"] = _strike_order_kind
	_last_strike_result["wave_index"] = _wave_index
	_last_strike_result["explosion_world_position"] = explosion_world_position
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
