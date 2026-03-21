extends Node3D

signal exploded(result: Dictionary)

const MISSILE_LAUNCH_AUDIO_PATH := "res://city_game/combat/helicopter/audio/rockt-explosions.wav"

@export var speed_mps := 210.0
@export var max_distance_m := 500.0
@export var max_lifetime_sec := 6.0
@export var explosion_radius_m := 18.0
@export var explosion_damage := 14.0
@export var explosion_effect_duration_sec := 0.72
@export var explosion_camera_shake_duration_sec := 0.52
@export var explosion_camera_shake_amplitude_m := 0.56
@export var sway_primary_amplitude_m := 0.34
@export var sway_secondary_amplitude_m := 0.18
@export var sway_primary_frequency := 0.16
@export var sway_secondary_frequency := 0.23
@export var launch_audio_enabled := true

var _forward_direction := Vector3.FORWARD
var _owner_node: Node = null
var _player_target: Node = null
var _spawn_world_position := Vector3.ZERO
var _distance_travelled_m := 0.0
var _lifetime_sec := 0.0
var _exploded := false
var _explosion_elapsed_sec := 0.0
var _explosion_trigger_kind := ""
var _current_velocity := Vector3.ZERO
var _visual_root: Node3D = null
var _explosion_ring: MeshInstance3D = null
var _explosion_sphere: MeshInstance3D = null
var _launch_audio: AudioStreamPlayer3D = null
var _launch_audio_trigger_count := 0
var _sway_axis_primary := Vector3.RIGHT
var _sway_axis_secondary := Vector3.UP

func _ready() -> void:
	add_to_group("city_missile")
	_cache_nodes()
	_resolve_sway_axes()
	_sync_visual(Vector3.ZERO, false)

func configure(origin: Vector3, direction: Vector3, owner_node: Node = null, player_target: Node = null) -> void:
	global_position = origin
	_spawn_world_position = origin
	_forward_direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
	_owner_node = owner_node
	_player_target = player_target
	_distance_travelled_m = 0.0
	_lifetime_sec = 0.0
	_exploded = false
	_explosion_elapsed_sec = 0.0
	_explosion_trigger_kind = ""
	_resolve_sway_axes()
	_sync_visual(_forward_direction * speed_mps, false)
	_play_launch_audio()

func get_velocity() -> Vector3:
	return _current_velocity

func has_exploded() -> bool:
	return _exploded

func get_distance_travelled_m() -> float:
	return _distance_travelled_m

func get_debug_state() -> Dictionary:
	return {
		"launch_audio": {
			"enabled": launch_audio_enabled,
			"stream_bound": _launch_audio != null and _launch_audio.stream != null,
			"stream_path": _launch_audio.stream.resource_path if _launch_audio != null and _launch_audio.stream != null else "",
			"playing": _launch_audio.playing if _launch_audio != null else false,
			"trigger_count": _launch_audio_trigger_count,
			"expected_stream_path": MISSILE_LAUNCH_AUDIO_PATH,
		},
		"exploded": _exploded,
		"explosion_trigger_kind": _explosion_trigger_kind,
		"distance_travelled_m": _distance_travelled_m,
	}

func get_last_explosion_result() -> Dictionary:
	return {
		"trigger_kind": _explosion_trigger_kind,
		"world_position": global_position,
		"distance_travelled_m": _distance_travelled_m,
		"radius_m": explosion_radius_m,
	}

func _physics_process(delta: float) -> void:
	if _exploded:
		_update_explosion_fx(delta)
		return
	if get_world_3d() == null or get_world_3d().direct_space_state == null:
		return

	_lifetime_sec += delta
	if _lifetime_sec >= max_lifetime_sec:
		_explode("max_distance")
		return

	var previous_position := global_position
	var next_distance := minf(_distance_travelled_m + speed_mps * maxf(delta, 0.0), max_distance_m)
	var next_position := _compute_world_position(next_distance)
	var query := PhysicsRayQueryParameters3D.create(previous_position, next_position)
	query.collide_with_areas = false
	query.exclude = _build_query_exclusions()
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.get("position", next_position)
		_distance_travelled_m += previous_position.distance_to(global_position)
		_sync_visual(global_position - previous_position, true)
		_explode("impact")
		return

	global_position = next_position
	_distance_travelled_m += previous_position.distance_to(next_position)
	_sync_visual(next_position - previous_position, true)
	if _distance_travelled_m >= max_distance_m - 0.001:
		_explode("max_distance")

func _build_query_exclusions() -> Array[RID]:
	var exclusions: Array[RID] = []
	if _owner_node is CollisionObject3D:
		exclusions.append((_owner_node as CollisionObject3D).get_rid())
	return exclusions

func _explode(trigger_kind: String) -> void:
	if _exploded:
		return
	_exploded = true
	_explosion_trigger_kind = trigger_kind
	_apply_explosion_damage()
	_trigger_camera_shake()
	_sync_visual(Vector3.ZERO, false)
	if _visual_root != null and is_instance_valid(_visual_root):
		_visual_root.visible = false
	if _explosion_ring != null and is_instance_valid(_explosion_ring):
		_explosion_ring.visible = true
		_explosion_ring.scale = Vector3(0.36, 1.0, 0.36)
	if _explosion_sphere != null and is_instance_valid(_explosion_sphere):
		_explosion_sphere.visible = true
		_explosion_sphere.scale = Vector3.ONE * 0.42
	exploded.emit(get_last_explosion_result())

func _apply_explosion_damage() -> void:
	if get_tree() == null:
		return
	for enemy_node in get_tree().get_nodes_in_group("city_enemy"):
		var enemy := enemy_node as Node3D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(global_position) > explosion_radius_m:
			continue
		if enemy.has_method("apply_projectile_hit"):
			var impulse := (enemy.global_position - global_position).normalized() * 22.0
			enemy.apply_projectile_hit(explosion_damage, global_position, impulse)
	for building_node in get_tree().get_nodes_in_group("city_destructible_building"):
		if building_node == null or not is_instance_valid(building_node):
			continue
		if not building_node.has_method("apply_explosion_damage"):
			continue
		building_node.apply_explosion_damage(global_position, explosion_damage, explosion_radius_m)

func _trigger_camera_shake() -> void:
	if _player_target == null or not is_instance_valid(_player_target):
		return
	if not _player_target.has_method("trigger_camera_shake"):
		return
	var distance_to_player := 0.0
	if _player_target is Node3D:
		distance_to_player = (_player_target as Node3D).global_position.distance_to(global_position)
	var falloff := clampf(1.0 - distance_to_player / 48.0, 0.7, 1.0)
	_player_target.trigger_camera_shake(
		explosion_camera_shake_duration_sec,
		explosion_camera_shake_amplitude_m * falloff
	)

func _update_explosion_fx(delta: float) -> void:
	_explosion_elapsed_sec += delta
	var duration_sec := maxf(explosion_effect_duration_sec, 0.001)
	var progress := clampf(_explosion_elapsed_sec / duration_sec, 0.0, 1.0)
	if _explosion_ring != null and is_instance_valid(_explosion_ring):
		var ring_scale := lerpf(0.36, explosion_radius_m * 0.62, progress)
		_explosion_ring.scale = Vector3(ring_scale, 1.0, ring_scale)
		var ring_material := _explosion_ring.material_override as StandardMaterial3D
		if ring_material != null:
			ring_material.albedo_color.a = lerpf(0.76, 0.0, progress)
			ring_material.emission_energy_multiplier = lerpf(2.0, 0.0, progress)
	if _explosion_sphere != null and is_instance_valid(_explosion_sphere):
		var sphere_scale := lerpf(0.42, explosion_radius_m * 0.24, progress)
		_explosion_sphere.scale = Vector3.ONE * sphere_scale
		var sphere_material := _explosion_sphere.material_override as StandardMaterial3D
		if sphere_material != null:
			sphere_material.albedo_color.a = lerpf(0.46, 0.0, progress)
			sphere_material.emission_energy_multiplier = lerpf(2.4, 0.0, progress)
	if progress >= 1.0:
		queue_free()

func _compute_world_position(distance_m: float) -> Vector3:
	var sway_alpha := clampf(distance_m / 42.0, 0.0, 1.0)
	var primary_phase := distance_m * sway_primary_frequency
	var secondary_phase := distance_m * sway_secondary_frequency + 1.13
	var sway_offset := _sway_axis_primary * sin(primary_phase) * sway_primary_amplitude_m * sway_alpha
	sway_offset += _sway_axis_secondary * sin(secondary_phase) * sway_secondary_amplitude_m * sway_alpha
	return _spawn_world_position + _forward_direction * distance_m + sway_offset

func _sync_visual(frame_delta: Vector3, active: bool) -> void:
	var resolved_velocity := frame_delta / maxf(get_physics_process_delta_time(), 0.0001) if frame_delta.length_squared() > 0.0001 else _forward_direction * speed_mps
	_current_velocity = resolved_velocity
	if _visual_root == null or not is_instance_valid(_visual_root):
		return
	if _visual_root.has_method("sync_motion_state"):
		var direction := frame_delta.normalized() if frame_delta.length_squared() > 0.0001 else _forward_direction
		_visual_root.sync_motion_state(global_position, direction, _current_velocity.length(), active)
		return
	_visual_root.global_position = global_position
	if frame_delta.length_squared() > 0.0001:
		var up_axis := Vector3.UP if absf(frame_delta.normalized().dot(Vector3.UP)) < 0.94 else Vector3.FORWARD
		_visual_root.look_at(global_position + frame_delta.normalized(), up_axis, true)

func _resolve_sway_axes() -> void:
	var reference_up := Vector3.UP if absf(_forward_direction.dot(Vector3.UP)) < 0.94 else Vector3.FORWARD
	_sway_axis_primary = _forward_direction.cross(reference_up).normalized()
	if _sway_axis_primary.length_squared() <= 0.0001:
		_sway_axis_primary = Vector3.RIGHT
	_sway_axis_secondary = _sway_axis_primary.cross(_forward_direction).normalized()
	if _sway_axis_secondary.length_squared() <= 0.0001:
		_sway_axis_secondary = Vector3.UP

func _cache_nodes() -> void:
	_visual_root = get_node_or_null("InterceptorMissileVisual") as Node3D
	_explosion_ring = get_node_or_null("ExplosionRing") as MeshInstance3D
	_explosion_sphere = get_node_or_null("ExplosionSphere") as MeshInstance3D
	_launch_audio = get_node_or_null("LaunchAudio") as AudioStreamPlayer3D

func _play_launch_audio() -> void:
	if not launch_audio_enabled or _launch_audio == null or _launch_audio.stream == null:
		return
	_launch_audio_trigger_count += 1
	_launch_audio.play()
