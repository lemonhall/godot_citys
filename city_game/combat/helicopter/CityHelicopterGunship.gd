extends CharacterBody3D

const MODEL_SCENE_PATH := "res://city_game/assets/environment/source/aircraft/helicopter_a.glb"
const ROTOR_AUDIO_PATH := "res://city_game/combat/helicopter/audio/helicopter.wav"
const MISSILE_FIRE_AUDIO_PATH := "res://city_game/combat/helicopter/audio/rockt-explosions.wav"

signal missile_fire_requested(origin: Vector3, direction: Vector3)
signal defeated
signal destroyed

@export var max_health := 160.0
@export var hover_height_m := 26.0
@export var orbit_radius_m := 18.0
@export var orbit_angular_speed_deg := 42.0
@export var orbit_follow_speed_mps := 28.0
@export var missile_fire_interval_sec := 1.35
@export var target_aim_height_m := 1.1
@export var engage_delay_sec := 0.15
@export var altitude_weave_amplitude_m := 30
@export var altitude_weave_cycle_sec := 6.2
@export var ambient_camera_shake_radius_m := 72.0
@export var ambient_camera_shake_duration_sec := 0.16
@export var ambient_camera_shake_amplitude_m := 0.09
@export var ambient_aim_disturbance_deg := 1.05
@export var death_airburst_duration_sec := 0.24
@export var death_fx_duration_sec := 0.92
@export var death_fall_duration_sec := 2.4
@export var death_fall_initial_speed_mps := 5.0
@export var death_fall_accel_mps2 := 19.0
@export var death_spin_rate_deg := 140.0
@export var death_target_pitch_deg := -58.0

@onready var _model_root := $ModelRoot as Node3D
@onready var _rotor_blur_root := $RotorBlurRoot as Node3D
@onready var _body_center := $Anchors/BodyCenter as Marker3D
@onready var _gun_muzzle := $Anchors/GunMuzzle as Marker3D
@onready var _missile_muzzle_left := $Anchors/MissileMuzzleLeft as Marker3D
@onready var _missile_muzzle_right := $Anchors/MissileMuzzleRight as Marker3D
@onready var _damage_smoke_anchor := $Anchors/DamageSmokeAnchor as Marker3D
@onready var _death_fx_root := $DeathFxRoot as Node3D
@onready var _death_explosion_ring := $DeathFxRoot/ExplosionRing as MeshInstance3D
@onready var _death_explosion_sphere := $DeathFxRoot/ExplosionSphere as MeshInstance3D
@onready var rotor_audio := $RotorAudio as AudioStreamPlayer3D
@onready var _missile_fire_audio := $MissileFireAudio as AudioStreamPlayer3D

var _health := 0.0
var _destroyed := false
var _last_hit_world_position := Vector3.ZERO
var _completion_count := 0
var _missile_fire_audio_trigger_count := 0
var _target: Node3D = null
var _resolved_hover_height_m := 0.0
var _resolved_orbit_radius_m := 0.0
var _orbit_angle_rad := 0.0
var _missile_fire_cooldown_sec := 0.0
var _missile_fire_index := 0
var _engage_delay_remaining_sec := 0.0
var _altitude_weave_elapsed_sec := 0.0
var _crash_state := ""
var _crash_elapsed_sec := 0.0
var _crash_fall_speed_mps := 0.0
var _crash_horizontal_velocity := Vector3.ZERO
var _death_fx_visible := false
var _destroyed_signal_emitted := false

func _ready() -> void:
	_health = maxf(max_health, 1.0)
	_destroyed = false
	_resolved_hover_height_m = hover_height_m
	_resolved_orbit_radius_m = orbit_radius_m
	_missile_fire_cooldown_sec = missile_fire_interval_sec * 0.45
	_engage_delay_remaining_sec = 0.0
	_altitude_weave_elapsed_sec = 0.0
	_crash_state = ""
	_crash_elapsed_sec = 0.0
	_crash_fall_speed_mps = 0.0
	_crash_horizontal_velocity = Vector3.ZERO
	_death_fx_visible = false
	_destroyed_signal_emitted = false
	add_to_group("city_enemy")
	add_to_group("city_helicopter_gunship")
	var wav := rotor_audio.stream as AudioStreamWAV
	#if wav != null:
		#wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_set_death_fx_visible(false)


func configure_combat(target_node: Node3D, orbit_reference_world_position: Vector3 = Vector3.ZERO) -> void:
	_target = target_node
	var target_position := target_node.global_position if target_node != null and is_instance_valid(target_node) else Vector3.ZERO
	var reference_position := global_position
	if reference_position.length_squared() <= 0.0001 and orbit_reference_world_position.length_squared() > 0.0001:
		reference_position = orbit_reference_world_position
	var planar_offset := Vector2(reference_position.x - target_position.x, reference_position.z - target_position.z)
	if planar_offset.length() > 0.5:
		_resolved_orbit_radius_m = maxf(planar_offset.length(), 8.0)
		_orbit_angle_rad = atan2(planar_offset.y, planar_offset.x)
	else:
		_resolved_orbit_radius_m = maxf(orbit_radius_m, 8.0)
		_orbit_angle_rad = 0.0
	_resolved_hover_height_m = maxf(reference_position.y - target_position.y, hover_height_m)
	_engage_delay_remaining_sec = maxf(engage_delay_sec, 0.0)
	_missile_fire_cooldown_sec = minf(_missile_fire_cooldown_sec, missile_fire_interval_sec * 0.45)
	_altitude_weave_elapsed_sec = 0.0

func get_visual_root() -> Node3D:
	return _model_root

func get_health_state() -> Dictionary:
	return {
		"current": _health,
		"max": maxf(max_health, 0.0),
		"ratio": clampf(_health / maxf(max_health, 0.001), 0.0, 1.0),
		"alive": not _destroyed,
		"destroyed": _destroyed,
		"last_hit_world_position": _last_hit_world_position,
		"completion_count": _completion_count,
	}

func get_combat_state() -> Dictionary:
	return {
		"target_present": _target != null and is_instance_valid(_target),
		"hover_height_m": _resolved_hover_height_m,
		"orbit_radius_m": _resolved_orbit_radius_m,
		"orbit_angle_rad": _orbit_angle_rad,
		"missile_fire_cooldown_sec": _missile_fire_cooldown_sec,
		"missile_fire_index": _missile_fire_index,
		"altitude_weave_offset_m": _compute_altitude_weave_offset_m(),
		"destroyed": _destroyed,
		"crash_state": _crash_state,
		"death_fx_visible": _death_fx_visible,
		"speed_mps": velocity.length(),
	}

func get_debug_state() -> Dictionary:
	return {
		"model_scene_path": MODEL_SCENE_PATH,
		"anchor_names": [
			_body_center.name,
			_gun_muzzle.name,
			_missile_muzzle_left.name,
			_missile_muzzle_right.name,
			_damage_smoke_anchor.name,
		],
		"weapon_fire_audio": {
			"stream_path": _missile_fire_audio.stream.resource_path if _missile_fire_audio != null and _missile_fire_audio.stream != null else "",
			"stream_bound": _missile_fire_audio != null and _missile_fire_audio.stream != null,
			"playing": _missile_fire_audio.playing if _missile_fire_audio != null else false,
			"trigger_count": _missile_fire_audio_trigger_count,
			"expected_stream_path": MISSILE_FIRE_AUDIO_PATH,
		},
		"health_state": get_health_state(),
		"combat_state": get_combat_state(),
	}

func apply_projectile_hit(projectile_damage: float, hit_position: Vector3, _impulse: Vector3) -> void:
	if _destroyed:
		return
	_last_hit_world_position = hit_position
	_health = maxf(_health - maxf(projectile_damage, 0.0), 0.0)
	if _health <= 0.0:
		_enter_destroyed_state()

func get_gun_muzzle_world_position() -> Vector3:
	return _gun_muzzle.global_position

func get_missile_muzzle_world_positions() -> Array:
	return [
		_missile_muzzle_left.global_position,
		_missile_muzzle_right.global_position,
	]

func _physics_process(delta: float) -> void:
	if _destroyed:
		_update_crash_sequence(delta)
		return
	_apply_ambient_camera_shake()
	if _engage_delay_remaining_sec > 0.0:
		_engage_delay_remaining_sec = maxf(_engage_delay_remaining_sec - delta, 0.0)
		velocity = Vector3.ZERO
		_face_target()
		return
	_update_orbit(delta)
	_update_attack(delta)

func _update_orbit(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		velocity = Vector3.ZERO
		return
	_orbit_angle_rad = wrapf(_orbit_angle_rad + deg_to_rad(orbit_angular_speed_deg) * delta, -PI, PI)
	_altitude_weave_elapsed_sec += maxf(delta, 0.0)
	var target_position := _target.global_position
	var desired_position := target_position + Vector3(
		cos(_orbit_angle_rad) * _resolved_orbit_radius_m,
		_resolved_hover_height_m + _compute_altitude_weave_offset_m(),
		sin(_orbit_angle_rad) * _resolved_orbit_radius_m
	)
	var previous_position := global_position
	global_position = global_position.move_toward(desired_position, orbit_follow_speed_mps * maxf(delta, 0.0))
	velocity = (global_position - previous_position) / maxf(delta, 0.0001)
	_face_target()

func _update_attack(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	_missile_fire_cooldown_sec = maxf(_missile_fire_cooldown_sec - delta, 0.0)
	if _missile_fire_cooldown_sec > 0.0:
		return
	var missile_muzzles := get_missile_muzzle_world_positions()
	if missile_muzzles.is_empty():
		return
	var muzzle_index := _missile_fire_index % missile_muzzles.size()
	var origin := missile_muzzles[muzzle_index] as Vector3
	var aim_target := _target.global_position + Vector3.UP * target_aim_height_m
	var direction := (aim_target - origin).normalized()
	if direction.length_squared() <= 0.0001:
		direction = -global_transform.basis.z
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	_missile_fire_index += 1
	_missile_fire_cooldown_sec = missile_fire_interval_sec
	_play_missile_fire_audio()
	missile_fire_requested.emit(origin, direction)

func _face_target() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var look_target := _target.global_position
	look_target.y = global_position.y
	if global_position.distance_to(look_target) <= 0.001:
		return
	look_at(look_target, Vector3.UP, true)

func _enter_destroyed_state() -> void:
	if _destroyed:
		return
	_destroyed = true
	_completion_count += 1
	remove_from_group("city_enemy")
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	defeated.emit()
	var collision_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	_start_crash_sequence()

func _compute_altitude_weave_offset_m() -> float:
	if altitude_weave_amplitude_m <= 0.0 or altitude_weave_cycle_sec <= 0.001:
		return 0.0
	var cycle_progress := fposmod(_altitude_weave_elapsed_sec / altitude_weave_cycle_sec, 1.0)
	var pulse := 0.5 - 0.5 * cos(cycle_progress * TAU)
	return pulse * altitude_weave_amplitude_m

func _play_missile_fire_audio() -> void:
	if _missile_fire_audio == null or _missile_fire_audio.stream == null:
		return
	_missile_fire_audio_trigger_count += 1
	_missile_fire_audio.play()

func _apply_ambient_camera_shake() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	if ambient_camera_shake_radius_m <= 0.0 or ambient_camera_shake_duration_sec <= 0.0 or ambient_camera_shake_amplitude_m <= 0.0:
		return
	if not _target.has_method("trigger_camera_shake"):
		return
	var target_body := _target as Node3D
	if target_body == null:
		return
	var distance_to_target := target_body.global_position.distance_to(global_position)
	if distance_to_target > ambient_camera_shake_radius_m:
		return
	var falloff := clampf(1.0 - distance_to_target / ambient_camera_shake_radius_m, 0.35, 1.0)
	_target.trigger_camera_shake(
		ambient_camera_shake_duration_sec,
		ambient_camera_shake_amplitude_m * falloff,
		ambient_aim_disturbance_deg * falloff
	)

func _start_crash_sequence() -> void:
	_crash_state = "airburst"
	_crash_elapsed_sec = 0.0
	_crash_fall_speed_mps = maxf(death_fall_initial_speed_mps, 0.0)
	_crash_horizontal_velocity = velocity * 0.42
	_crash_horizontal_velocity.y = 0.0
	_death_fx_visible = true
	if rotor_audio != null and rotor_audio.playing:
		rotor_audio.stop()
	if _rotor_blur_root != null:
		_rotor_blur_root.visible = false
	_set_death_fx_visible(true)
	if _death_explosion_ring != null:
		_death_explosion_ring.scale = Vector3(0.8, 1.0, 0.8)
	if _death_explosion_sphere != null:
		_death_explosion_sphere.scale = Vector3.ONE * 0.8

func _update_crash_sequence(delta: float) -> void:
	velocity = Vector3.ZERO
	_crash_elapsed_sec += maxf(delta, 0.0)
	_update_death_fx()
	if _crash_state == "airburst":
		if _crash_elapsed_sec >= death_airburst_duration_sec:
			_crash_state = "falling"
		return
	if _crash_state != "falling":
		_finalize_destroyed_state()
		return
	_crash_fall_speed_mps += death_fall_accel_mps2 * maxf(delta, 0.0)
	global_position += _crash_horizontal_velocity * maxf(delta, 0.0)
	global_position += Vector3.DOWN * _crash_fall_speed_mps * maxf(delta, 0.0)
	rotation.x = move_toward(rotation.x, deg_to_rad(death_target_pitch_deg), maxf(delta, 0.0) * 1.85)
	rotation.z += deg_to_rad(death_spin_rate_deg) * maxf(delta, 0.0)
	if _crash_elapsed_sec >= death_fall_duration_sec or _has_reached_crash_ground():
		_finalize_destroyed_state()

func _update_death_fx() -> void:
	if not _death_fx_visible:
		return
	var fx_progress := clampf(_crash_elapsed_sec / maxf(death_fx_duration_sec, 0.001), 0.0, 1.0)
	if _death_explosion_ring != null:
		var ring_scale := lerpf(0.8, 10.5, fx_progress)
		_death_explosion_ring.scale = Vector3(ring_scale, 1.0, ring_scale)
		var ring_material := _death_explosion_ring.material_override as StandardMaterial3D
		if ring_material != null:
			ring_material.albedo_color.a = lerpf(0.78, 0.0, fx_progress)
			ring_material.emission_energy_multiplier = lerpf(3.0, 0.0, fx_progress)
	if _death_explosion_sphere != null:
		var sphere_scale := lerpf(0.8, 5.2, fx_progress)
		_death_explosion_sphere.scale = Vector3.ONE * sphere_scale
		var sphere_material := _death_explosion_sphere.material_override as StandardMaterial3D
		if sphere_material != null:
			sphere_material.albedo_color.a = lerpf(0.5, 0.0, fx_progress)
			sphere_material.emission_energy_multiplier = lerpf(3.4, 0.0, fx_progress)
	if fx_progress >= 1.0:
		_set_death_fx_visible(false)

func _has_reached_crash_ground() -> bool:
	if get_world_3d() == null or get_world_3d().direct_space_state == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 0.4,
		global_position + Vector3.DOWN * 2.2
	)
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty()

func _finalize_destroyed_state() -> void:
	if _destroyed_signal_emitted:
		return
	_destroyed_signal_emitted = true
	_crash_state = "resolved"
	_set_death_fx_visible(false)
	destroyed.emit()

func _set_death_fx_visible(visible: bool) -> void:
	_death_fx_visible = visible
	if _death_fx_root != null:
		_death_fx_root.visible = visible
	if _death_explosion_ring != null:
		_death_explosion_ring.visible = visible
	if _death_explosion_sphere != null:
		_death_explosion_sphere.visible = visible
