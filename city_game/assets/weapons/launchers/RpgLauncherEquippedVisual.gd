extends Node3D

@export var equipped_visible := false
@export var fire_fx_duration_sec := 0.12
@export var recoil_position_offset := Vector3(-0.03, -0.02, 0.16)
@export var recoil_rotation_degrees := Vector3(4.0, 0.0, 7.0)

var _mount_root: Node3D = null
var _muzzle_flash: Node3D = null
var _backblast_flash: Node3D = null
var _flash_materials: Array[StandardMaterial3D] = []
var _authored_mount_position := Vector3.ZERO
var _authored_mount_rotation_degrees := Vector3.ZERO
var _authored_muzzle_flash_scale := Vector3.ONE
var _authored_backblast_flash_scale := Vector3.ONE
var _fire_fx_remaining_sec := 0.0
var _fire_count := 0

func _ready() -> void:
	_cache_nodes()
	_capture_authored_transforms()
	_reset_mount_pose()
	_set_flash_strength(0.0)
	_apply_equipped_visibility()

func _process(delta: float) -> void:
	if _fire_fx_remaining_sec <= 0.0:
		if _mount_root != null and is_instance_valid(_mount_root):
			_reset_mount_pose()
		_set_flash_strength(0.0)
		return
	_fire_fx_remaining_sec = maxf(_fire_fx_remaining_sec - maxf(delta, 0.0), 0.0)
	var duration_sec := maxf(fire_fx_duration_sec, 0.01)
	var progress := 1.0 - (_fire_fx_remaining_sec / duration_sec)
	var recoil_envelope := sin(progress * PI)
	if _mount_root != null and is_instance_valid(_mount_root):
		_mount_root.position = _authored_mount_position + recoil_position_offset * recoil_envelope
		_mount_root.rotation_degrees = _authored_mount_rotation_degrees + recoil_rotation_degrees * recoil_envelope
	var flash_strength := clampf(1.0 - progress, 0.0, 1.0)
	_set_flash_strength(flash_strength)

func set_equipped_visible(should_show: bool) -> void:
	equipped_visible = should_show
	_apply_equipped_visibility()

func play_fire_fx() -> void:
	_fire_count += 1
	_fire_fx_remaining_sec = maxf(fire_fx_duration_sec, 0.01)
	_reset_mount_pose()
	_set_flash_strength(1.0)

func get_visual_state() -> Dictionary:
	return {
		"equipped_visible": visible,
		"fire_fx_active": _fire_fx_remaining_sec > 0.0,
		"fire_count": _fire_count,
		"mount_position": _mount_root.position if _mount_root != null and is_instance_valid(_mount_root) else Vector3.ZERO,
		"mount_rotation_degrees": _mount_root.rotation_degrees if _mount_root != null and is_instance_valid(_mount_root) else Vector3.ZERO,
	}

func _cache_nodes() -> void:
	_mount_root = get_node_or_null("MountRoot") as Node3D
	_muzzle_flash = get_node_or_null("MountRoot/LauncherPivot/MuzzleFlash") as Node3D
	_backblast_flash = get_node_or_null("MountRoot/LauncherPivot/BackblastFlash") as Node3D
	_flash_materials.clear()
	for flash_root in [_muzzle_flash, _backblast_flash]:
		if flash_root == null or not is_instance_valid(flash_root):
			continue
		for mesh_node in flash_root.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := mesh_node as MeshInstance3D
			if mesh_instance == null:
				continue
			var material := mesh_instance.material_override as StandardMaterial3D
			if material == null:
				continue
			_flash_materials.append(material)

func _capture_authored_transforms() -> void:
	if _mount_root != null and is_instance_valid(_mount_root):
		_authored_mount_position = _mount_root.position
		_authored_mount_rotation_degrees = _mount_root.rotation_degrees
	if _muzzle_flash != null and is_instance_valid(_muzzle_flash):
		_authored_muzzle_flash_scale = _muzzle_flash.scale
	if _backblast_flash != null and is_instance_valid(_backblast_flash):
		_authored_backblast_flash_scale = _backblast_flash.scale

func _apply_equipped_visibility() -> void:
	visible = equipped_visible
	if not visible:
		_set_flash_strength(0.0)

func _reset_mount_pose() -> void:
	if _mount_root == null or not is_instance_valid(_mount_root):
		return
	_mount_root.position = _authored_mount_position
	_mount_root.rotation_degrees = _authored_mount_rotation_degrees

func _set_flash_strength(flash_strength: float) -> void:
	var active := visible and flash_strength > 0.01
	if _muzzle_flash != null and is_instance_valid(_muzzle_flash):
		_muzzle_flash.visible = active
		_muzzle_flash.scale = _authored_muzzle_flash_scale * lerpf(0.55, 1.25, flash_strength)
	if _backblast_flash != null and is_instance_valid(_backblast_flash):
		_backblast_flash.visible = active
		_backblast_flash.scale = _authored_backblast_flash_scale * lerpf(0.52, 1.5, flash_strength)
	for material in _flash_materials:
		if material == null:
			continue
		var albedo := material.albedo_color
		albedo.a = flash_strength * 0.9
		material.albedo_color = albedo
		material.emission_energy_multiplier = lerpf(0.0, 3.8, flash_strength)
