extends Node3D

const SOURCE_ASSET_PATH := "res://city_game/assets/environment/source/artillery/m777/m777_3_parts.glb"
const FIRE_AUDIO_PATH := "res://city_game/combat/helicopter/audio/rockt-explosions.wav"

const LOWER_BASE_NODE_NAME := "m777_lower_base"
const UPPER_CARRIAGE_NODE_NAME := "m777_upper_carriage"
const GUN_ASSEMBLY_NODE_NAME := "m777_gun_assembly"

@export var initial_yaw_deg := 0.0
@export var initial_pitch_deg := 0.0
@export_range(-180.0, 180.0, 0.1) var pitch_zero_offset_deg := 14.7
@export_range(-180.0, 180.0, 0.1) var min_pitch_deg := 0.0
@export_range(-180.0, 180.0, 0.1) var max_pitch_deg := 71.0

@export var fire_cooldown_sec := 2.0
@export var muzzle_flash_duration_sec := 0.14
@export var muzzle_smoke_duration_sec := 1.25
@export var recoil_duration_sec := 0.26
@export var lanyard_pull_duration_sec := 0.18
@export var recoil_local_offset := Vector3(0.0, 0.0, -0.018)
@export var smoke_idle_scale := Vector3.ONE * 0.72
@export var smoke_peak_scale := Vector3.ONE * 2.35
@export var lanyard_idle_scale := Vector3(1.0, 0.9, 1.0)
@export var lanyard_tension_scale := Vector3(1.0, 1.18, 1.0)
@export var lanyard_handle_idle_local_offset := Vector3(0.018, -0.024, 0.006)
@export var lanyard_pull_local_offset := Vector3(0.022, -0.014, 0.004)

@onready var _model_root := $ModelRoot as Node3D
@onready var _lower_base_mount := $ModelRoot/LowerBaseMount as Node3D
@onready var _yaw_pivot := $ModelRoot/YawPivot as Node3D
@onready var _pitch_pivot := $ModelRoot/YawPivot/PitchPivot as Node3D
@onready var _source_asset := $ModelRoot/SourceAsset as Node3D
@onready var _yaw_anchor := $Anchors/YawPivotAnchor as Marker3D
@onready var _pitch_anchor := $Anchors/PitchPivotAnchor as Marker3D
@onready var _muzzle_anchor := $Anchors/MuzzleFxAnchor as Marker3D
@onready var _lanyard_anchor := $Anchors/LanyardAnchor as Marker3D
@onready var _fire_root := $ModelRoot/YawPivot/PitchPivot/FirePresentationRoot as Node3D
@onready var _muzzle_flash := $ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/MuzzleFlash as Node3D
@onready var _muzzle_smoke := $ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/MuzzleSmoke as Node3D
@onready var _lanyard := $ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/Lanyard as MeshInstance3D
@onready var _lanyard_line := $ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/LanyardLine as Node3D
@onready var _fire_audio := $ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/FireAudio as AudioStreamPlayer3D

var _yaw_deg := 0.0
var _pitch_deg := 0.0
var _mounted_segment_count := 0
var _fire_count := 0
var _fire_audio_trigger_count := 0
var _fire_cooldown_remaining_sec := 0.0
var _muzzle_flash_remaining_sec := 0.0
var _muzzle_smoke_remaining_sec := 0.0
var _recoil_remaining_sec := 0.0
var _lanyard_pull_remaining_sec := 0.0
var _gun_assembly: Node3D = null
var _flash_materials: Array[ShaderMaterial] = []
var _smoke_materials: Array[ShaderMaterial] = []
var _authored_gun_assembly_position := Vector3.ZERO
var _authored_muzzle_flash_scale := Vector3.ONE
var _authored_muzzle_smoke_scale := Vector3.ONE
var _authored_lanyard_scale := Vector3.ONE
var _authored_lanyard_position := Vector3.ZERO
var _operator_lanyard_target_active := false
var _operator_lanyard_target_world_position := Vector3.ZERO

func _ready() -> void:
	_mount_segments()
	_cache_fire_nodes()
	_sync_fire_presentation_from_anchors()
	_capture_fire_authored_state()
	_reset_fire_presentation_visuals()
	set_axis_angles_degrees(initial_yaw_deg, initial_pitch_deg)

func _process(delta: float) -> void:
	_update_fire_presentation(delta)

func _exit_tree() -> void:
	if _fire_audio != null and is_instance_valid(_fire_audio) and _fire_audio.playing:
		_fire_audio.stop()

func get_visual_root() -> Node3D:
	return _model_root

func set_yaw_degrees(value: float) -> void:
	_yaw_deg = _normalize_yaw_degrees(value)
	_apply_axis_angles()

func set_pitch_degrees(value: float) -> void:
	_pitch_deg = _clamp_pitch_degrees(value)
	_apply_axis_angles()

func set_axis_angles_degrees(yaw_deg: float, pitch_deg: float) -> void:
	_yaw_deg = _normalize_yaw_degrees(yaw_deg)
	_pitch_deg = _clamp_pitch_degrees(pitch_deg)
	_apply_axis_angles()

func get_yaw_degrees() -> float:
	return _yaw_deg

func get_pitch_degrees() -> float:
	return _pitch_deg

func set_operator_lanyard_target_world_position(world_position: Vector3) -> void:
	_operator_lanyard_target_active = true
	_operator_lanyard_target_world_position = world_position

func clear_operator_lanyard_target_world_position() -> void:
	_operator_lanyard_target_active = false
	_operator_lanyard_target_world_position = Vector3.ZERO

func can_fire() -> bool:
	return _fire_cooldown_remaining_sec <= 0.0

func request_fire() -> Dictionary:
	if not can_fire():
		return {
			"accepted": false,
			"error": "cooldown_active",
			"cooldown_sec": _fire_cooldown_remaining_sec,
			"fire_count": _fire_count,
		}
	_fire_count += 1
	_fire_cooldown_remaining_sec = maxf(fire_cooldown_sec, 0.001)
	_muzzle_flash_remaining_sec = maxf(muzzle_flash_duration_sec, 0.01)
	_muzzle_smoke_remaining_sec = maxf(muzzle_smoke_duration_sec, 0.01)
	_recoil_remaining_sec = maxf(recoil_duration_sec, 0.01)
	_lanyard_pull_remaining_sec = maxf(lanyard_pull_duration_sec, 0.01)
	_set_muzzle_flash_strength(1.0)
	_set_muzzle_smoke_state(1.0, 1.0, 0.0)
	_set_recoil_envelope(1.0)
	_set_lanyard_tension(1.0)
	_play_fire_audio()
	return {
		"accepted": true,
		"cooldown_sec": _fire_cooldown_remaining_sec,
		"fire_count": _fire_count,
	}

func get_fire_state() -> Dictionary:
	return {
		"can_fire": can_fire(),
		"cooldown_sec": _fire_cooldown_remaining_sec,
		"cooldown_duration_sec": maxf(fire_cooldown_sec, 0.0),
		"fire_count": _fire_count,
		"muzzle_flash_active": _muzzle_flash_remaining_sec > 0.0,
		"smoke_active": _muzzle_smoke_remaining_sec > 0.0,
		"lanyard_tension_active": _lanyard_pull_remaining_sec > 0.0,
		"recoil_active": _recoil_remaining_sec > 0.0,
		"audio_trigger_count": _fire_audio_trigger_count,
		"audio_playing": _fire_audio.playing if _fire_audio != null else false,
		"lanyard_visible": _lanyard.visible if _lanyard != null else false,
		"lanyard_line_visible": bool((_lanyard_line.get_debug_state() as Dictionary).get("visible", false)) if _lanyard_line != null and _lanyard_line.has_method("get_debug_state") else false,
	}

func get_anchor_state() -> Dictionary:
	return {
		"yaw_anchor_local_position": _yaw_anchor.position if _yaw_anchor != null else Vector3.ZERO,
		"pitch_anchor_local_position": _pitch_anchor.position if _pitch_anchor != null else Vector3.ZERO,
		"muzzle_anchor_local_position": _muzzle_anchor.position if _muzzle_anchor != null else Vector3.ZERO,
		"lanyard_anchor_local_position": _lanyard_anchor.position if _lanyard_anchor != null else Vector3.ZERO,
		"yaw_pivot_local_position": _yaw_pivot.position if _yaw_pivot != null else Vector3.ZERO,
		"pitch_pivot_local_position": _pitch_pivot.position if _pitch_pivot != null else Vector3.ZERO,
		"muzzle_presentation_local_position": _muzzle_flash.position if _muzzle_flash != null else Vector3.ZERO,
		"lanyard_presentation_local_position": _lanyard.position if _lanyard != null else Vector3.ZERO,
	}

func get_debug_state() -> Dictionary:
	return {
		"source_asset_path": SOURCE_ASSET_PATH,
		"yaw_deg": _yaw_deg,
		"pitch_deg": _pitch_deg,
		"applied_pitch_pivot_deg": pitch_zero_offset_deg - _pitch_deg,
		"pitch_zero_offset_deg": pitch_zero_offset_deg,
		"pitch_limits_deg": {
			"min": min_pitch_deg,
			"max": max_pitch_deg,
		},
		"mounted_segment_count": _mounted_segment_count,
		"lower_base_present": get_node_or_null("ModelRoot/LowerBaseMount/%s" % LOWER_BASE_NODE_NAME) != null,
		"upper_carriage_present": get_node_or_null("ModelRoot/YawPivot/%s" % UPPER_CARRIAGE_NODE_NAME) != null,
		"gun_assembly_present": get_node_or_null("ModelRoot/YawPivot/PitchPivot/%s" % GUN_ASSEMBLY_NODE_NAME) != null,
		"anchor_state": get_anchor_state(),
		"fire_state": get_fire_state(),
		"weapon_fire_audio": {
			"stream_path": _fire_audio.stream.resource_path if _fire_audio != null and _fire_audio.stream != null else "",
			"stream_bound": _fire_audio != null and _fire_audio.stream != null,
			"playing": _fire_audio.playing if _fire_audio != null else false,
			"trigger_count": _fire_audio_trigger_count,
			"expected_stream_path": FIRE_AUDIO_PATH,
		},
	}

func _mount_segments() -> void:
	_sync_pivots_from_anchors()
	if _yaw_pivot != null:
		_yaw_pivot.rotation = Vector3.ZERO
	if _pitch_pivot != null:
		_pitch_pivot.rotation = Vector3.ZERO
	_mounted_segment_count = 0
	if _reparent_segment(LOWER_BASE_NODE_NAME, _lower_base_mount):
		_mounted_segment_count += 1
	if _reparent_segment(UPPER_CARRIAGE_NODE_NAME, _yaw_pivot):
		_mounted_segment_count += 1
	if _reparent_segment(GUN_ASSEMBLY_NODE_NAME, _pitch_pivot):
		_mounted_segment_count += 1

func _sync_pivots_from_anchors() -> void:
	if _yaw_pivot != null and _yaw_anchor != null:
		_yaw_pivot.position = _yaw_anchor.position
	if _pitch_pivot != null and _yaw_anchor != null and _pitch_anchor != null:
		_pitch_pivot.position = _pitch_anchor.position - _yaw_anchor.position

func _cache_fire_nodes() -> void:
	_gun_assembly = get_node_or_null("ModelRoot/YawPivot/PitchPivot/%s" % GUN_ASSEMBLY_NODE_NAME) as Node3D
	_flash_materials = _collect_shader_materials(_muzzle_flash)
	_smoke_materials = _collect_shader_materials(_muzzle_smoke)

func _sync_fire_presentation_from_anchors() -> void:
	if _pitch_pivot == null:
		return
	_apply_fire_anchor_transform(_muzzle_flash, _muzzle_anchor)
	_apply_fire_anchor_transform(_muzzle_smoke, _muzzle_anchor)
	_apply_fire_anchor_transform(_lanyard, _lanyard_anchor)
	_apply_fire_anchor_transform(_fire_audio, _lanyard_anchor)
	if _muzzle_flash_remaining_sec <= 0.0 and _muzzle_smoke_remaining_sec <= 0.0 and _lanyard_pull_remaining_sec <= 0.0 and _recoil_remaining_sec <= 0.0:
		_capture_fire_authored_state()

func _apply_fire_anchor_transform(target: Node3D, anchor: Marker3D) -> void:
	if _pitch_pivot == null or target == null or anchor == null:
		return
	target.transform = _pitch_pivot.global_transform.affine_inverse() * anchor.global_transform

func _capture_fire_authored_state() -> void:
	if _gun_assembly != null:
		_authored_gun_assembly_position = _gun_assembly.position
	if _muzzle_flash != null:
		_authored_muzzle_flash_scale = _muzzle_flash.scale
	if _muzzle_smoke != null:
		_authored_muzzle_smoke_scale = _muzzle_smoke.scale
	if _lanyard != null:
		_authored_lanyard_scale = _lanyard.scale
		_authored_lanyard_position = _lanyard.position

func _reset_fire_presentation_visuals() -> void:
	_fire_cooldown_remaining_sec = 0.0
	_muzzle_flash_remaining_sec = 0.0
	_muzzle_smoke_remaining_sec = 0.0
	_recoil_remaining_sec = 0.0
	_lanyard_pull_remaining_sec = 0.0
	_set_muzzle_flash_strength(0.0)
	_set_muzzle_smoke_state(0.0, 0.0, 0.0)
	_set_recoil_envelope(0.0)
	_set_lanyard_tension(0.0)

func _collect_shader_materials(root_node: Node) -> Array[ShaderMaterial]:
	var materials: Array[ShaderMaterial] = []
	if root_node == null:
		return materials
	for mesh_node in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance == null:
			continue
		var material := mesh_instance.material_override as ShaderMaterial
		if material == null:
			continue
		materials.append(material)
	return materials

func _reparent_segment(segment_name: String, target_parent: Node3D) -> bool:
	if target_parent == null:
		return false
	var segment := find_child(segment_name, true, false) as Node3D
	if segment == null:
		return false
	if segment.get_parent() != target_parent:
		segment.reparent(target_parent, true)
	return true

func _apply_axis_angles() -> void:
	if _yaw_pivot != null:
		_yaw_pivot.rotation.y = deg_to_rad(_yaw_deg)
	if _pitch_pivot != null:
		_pitch_pivot.rotation.x = deg_to_rad(pitch_zero_offset_deg - _pitch_deg)

func _update_fire_presentation(delta: float) -> void:
	var resolved_delta := maxf(delta, 0.0)
	_fire_cooldown_remaining_sec = maxf(_fire_cooldown_remaining_sec - resolved_delta, 0.0)
	_update_muzzle_flash(resolved_delta)
	_update_muzzle_smoke(resolved_delta)
	_update_recoil(resolved_delta)
	_update_lanyard(resolved_delta)

func _update_muzzle_flash(delta: float) -> void:
	if _muzzle_flash_remaining_sec <= 0.0:
		_muzzle_flash_remaining_sec = 0.0
		_set_muzzle_flash_strength(0.0)
		return
	_muzzle_flash_remaining_sec = maxf(_muzzle_flash_remaining_sec - delta, 0.0)
	var duration_sec := maxf(muzzle_flash_duration_sec, 0.01)
	var progress := 1.0 - (_muzzle_flash_remaining_sec / duration_sec)
	var strength := clampf(1.0 - progress, 0.0, 1.0)
	_set_muzzle_flash_strength(strength)

func _update_muzzle_smoke(delta: float) -> void:
	if _muzzle_smoke_remaining_sec <= 0.0:
		_muzzle_smoke_remaining_sec = 0.0
		_set_muzzle_smoke_state(0.0, 0.0, 1.0)
		return
	_muzzle_smoke_remaining_sec = maxf(_muzzle_smoke_remaining_sec - delta, 0.0)
	var duration_sec := maxf(muzzle_smoke_duration_sec, 0.01)
	var progress := 1.0 - (_muzzle_smoke_remaining_sec / duration_sec)
	var strength := clampf(1.0 - progress * 0.72, 0.0, 1.0)
	var heat := clampf(1.0 - progress, 0.0, 1.0)
	_set_muzzle_smoke_state(strength, heat, progress)

func _update_recoil(delta: float) -> void:
	if _recoil_remaining_sec <= 0.0:
		_recoil_remaining_sec = 0.0
		_set_recoil_envelope(0.0)
		return
	_recoil_remaining_sec = maxf(_recoil_remaining_sec - delta, 0.0)
	var duration_sec := maxf(recoil_duration_sec, 0.01)
	var progress := 1.0 - (_recoil_remaining_sec / duration_sec)
	_set_recoil_envelope(sin(progress * PI))

func _update_lanyard(delta: float) -> void:
	if _lanyard_pull_remaining_sec <= 0.0:
		_lanyard_pull_remaining_sec = 0.0
		_set_lanyard_tension(0.0)
		return
	_lanyard_pull_remaining_sec = maxf(_lanyard_pull_remaining_sec - delta, 0.0)
	var duration_sec := maxf(lanyard_pull_duration_sec, 0.01)
	var progress := 1.0 - (_lanyard_pull_remaining_sec / duration_sec)
	_set_lanyard_tension(clampf(1.0 - progress, 0.0, 1.0))

func _set_muzzle_flash_strength(strength: float) -> void:
	var resolved_strength := clampf(strength, 0.0, 1.0)
	var active := resolved_strength > 0.01
	if _muzzle_flash != null:
		_muzzle_flash.visible = active
		_muzzle_flash.scale = _authored_muzzle_flash_scale * lerpf(0.55, 1.22, resolved_strength)
	for material in _flash_materials:
		if material == null:
			continue
		material.set_shader_parameter("flash_strength", resolved_strength)

func _set_muzzle_smoke_state(strength: float, heat: float, progress: float) -> void:
	var resolved_strength := clampf(strength, 0.0, 1.0)
	var active := resolved_strength > 0.01
	if _muzzle_smoke != null:
		_muzzle_smoke.visible = active
		_muzzle_smoke.scale = _authored_muzzle_smoke_scale * smoke_idle_scale.lerp(smoke_peak_scale, clampf(progress, 0.0, 1.0))
	for material in _smoke_materials:
		if material == null:
			continue
		material.set_shader_parameter("smoke_strength", resolved_strength)
		material.set_shader_parameter("smoke_heat", clampf(heat, 0.0, 1.0))

func _set_recoil_envelope(envelope: float) -> void:
	if _gun_assembly == null:
		return
	var resolved_envelope := clampf(envelope, 0.0, 1.0)
	_gun_assembly.position = _authored_gun_assembly_position + recoil_local_offset * resolved_envelope

func _set_lanyard_tension(tension: float) -> void:
	if _lanyard == null:
		return
	var resolved_tension := clampf(tension, 0.0, 1.0)
	_lanyard.visible = true
	var line_start_world := _pitch_pivot.to_global(_authored_lanyard_position) if _pitch_pivot != null else Vector3.ZERO
	var line_end_world := _pitch_pivot.to_global(_authored_lanyard_position + lanyard_handle_idle_local_offset + lanyard_pull_local_offset * resolved_tension) if _pitch_pivot != null else Vector3.ZERO
	if _operator_lanyard_target_active and _pitch_pivot != null:
		line_end_world = _operator_lanyard_target_world_position
		_lanyard.position = _pitch_pivot.to_local(line_end_world)
	else:
		_lanyard.position = _authored_lanyard_position + lanyard_handle_idle_local_offset + lanyard_pull_local_offset * resolved_tension
	_lanyard.scale = _authored_lanyard_scale * lanyard_idle_scale.lerp(lanyard_tension_scale, resolved_tension)
	if _lanyard_line != null and _lanyard_line.has_method("set_line_state") and _pitch_pivot != null:
		var sag_m := lerpf(0.22, 0.02, resolved_tension) if _operator_lanyard_target_active else lerpf(0.025, 0.0, resolved_tension)
		_lanyard_line.set_line_state(true, line_start_world, line_end_world, sag_m)

func _play_fire_audio() -> void:
	if _fire_audio == null or _fire_audio.stream == null:
		return
	if _fire_audio.playing:
		_fire_audio.stop()
	_fire_audio_trigger_count += 1
	_fire_audio.play()

func _clamp_pitch_degrees(value: float) -> float:
	return clampf(value, min_pitch_deg, max_pitch_deg)

func _normalize_yaw_degrees(value: float) -> float:
	var wrapped := fposmod(value, 360.0)
	if wrapped >= 359.999:
		return 0.0
	return wrapped
