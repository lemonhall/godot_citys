extends Node3D

const CityMissileScene := preload("res://city_game/combat/CityMissile.tscn")
const TargetBuildingScene := preload("res://city_game/scenes/labs/BuildingCollapseLabTarget.tscn")

@onready var player = $Player
@onready var hud = $Hud
@onready var missile_root = $CombatRoot/Missiles
@onready var target_building_runtime = $TargetBuildingRoot

var _last_missile_explosion_result: Dictionary = {}
var _initial_player_position := Vector3.ZERO
var _initial_player_rotation := Vector3.ZERO
var _initial_camera_rig_rotation := Vector3.ZERO

func _ready() -> void:
	_capture_initial_state()
	if player != null and player.has_signal("missile_launcher_requested"):
		var callable := Callable(self, "_on_player_missile_launcher_requested")
		if not player.missile_launcher_requested.is_connected(callable):
			player.missile_launcher_requested.connect(callable)
	if player != null and player.has_method("set_weapon_mode"):
		player.set_weapon_mode("missile_launcher")
	_refresh_hud()

func _process(_delta: float) -> void:
	_refresh_hud()

func get_target_building_runtime():
	return target_building_runtime

func fire_player_missile_launcher() -> Node3D:
	if player == null or missile_root == null:
		return null
	if not player.has_method("get_projectile_spawn_transform") or not player.has_method("get_projectile_direction"):
		return null
	return _spawn_missile(player.get_projectile_spawn_transform().origin, player.get_projectile_direction())

func fire_missile_at_world_position(target_world_position: Vector3) -> Node3D:
	if player == null or not player.has_method("get_projectile_spawn_transform"):
		return null
	var spawn_transform: Transform3D = player.get_projectile_spawn_transform()
	var direction := (target_world_position - spawn_transform.origin).normalized()
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	return _spawn_missile(spawn_transform.origin, direction)

func _spawn_missile(origin: Vector3, direction: Vector3) -> Node3D:
	if missile_root == null:
		return null
	var missile := CityMissileScene.instantiate() as Node3D
	if missile == null:
		return null
	missile_root.add_child(missile)
	if missile.has_method("configure"):
		missile.configure(origin, direction, player, player)
	if missile.has_signal("exploded"):
		var exploded_callable := Callable(self, "_on_player_missile_exploded")
		if not missile.exploded.is_connected(exploded_callable):
			missile.exploded.connect(exploded_callable)
	return missile

func get_active_missile_count() -> int:
	return 0 if missile_root == null else missile_root.get_child_count()

func get_last_missile_explosion_result() -> Dictionary:
	return _last_missile_explosion_result.duplicate(true)

func reset_lab_state() -> void:
	_last_missile_explosion_result.clear()
	_clear_missiles()
	_restore_target_building()
	_restore_player_state()
	_refresh_hud()

func aim_player_at_world_position(target_world_position: Vector3) -> void:
	if player == null:
		return
	var camera := player.get_node_or_null("CameraRig/Camera3D") as Camera3D
	var camera_rig := player.get_node_or_null("CameraRig") as Node3D
	if camera_rig == null:
		return
	var aim_origin: Vector3 = camera.global_position if camera != null else player.global_position + Vector3.UP * 1.4
	var delta := target_world_position - aim_origin
	var planar_length := maxf(Vector2(delta.x, delta.z).length(), 0.001)
	player.rotation.y = atan2(-delta.x, -delta.z)
	if player.has_method("get_pitch_limits_degrees"):
		var pitch_limits: Dictionary = player.get_pitch_limits_degrees()
		var min_pitch := deg_to_rad(float(pitch_limits.get("min", -68.0)))
		var max_pitch := deg_to_rad(float(pitch_limits.get("max", 35.0)))
		camera_rig.rotation.x = clampf(-atan2(delta.y, planar_length), min_pitch, max_pitch)
	if camera != null:
		camera.look_at(target_world_position, Vector3.UP, true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F5:
			reset_lab_state()

func _on_player_missile_launcher_requested() -> void:
	fire_player_missile_launcher()

func _on_player_missile_exploded(result: Dictionary) -> void:
	_last_missile_explosion_result = result.duplicate(true)

func _refresh_hud() -> void:
	if hud == null:
		return
	if hud.has_method("set_fps_overlay_visible"):
		hud.set_fps_overlay_visible(true)
	if hud.has_method("set_fps_overlay_sample"):
		hud.set_fps_overlay_sample(Engine.get_frames_per_second())
	if hud.has_method("set_crosshair_state"):
		var viewport_size := get_viewport().get_visible_rect().size
		var aim_target: Vector3 = player.get_aim_target_world_position() if player != null and player.has_method("get_aim_target_world_position") else Vector3.ZERO
		var ads_active: bool = player.is_aim_down_sights_active() if player != null and player.has_method("is_aim_down_sights_active") else false
		hud.set_crosshair_state({
			"visible": true,
			"screen_position": viewport_size * 0.5,
			"viewport_size": viewport_size,
			"world_target": aim_target,
			"aim_down_sights_active": ads_active,
		})
	if hud.has_method("set_status") and target_building_runtime != null and target_building_runtime.has_method("get_state"):
		var state: Dictionary = target_building_runtime.get_state()
		hud.set_status(
			"v33 Building Collapse Lab\n8 RPG  Left Click Fire  Right Click ADS  F5 Reset\nbuilding=%s  hp=%.0f / %.0f  state=%s" % [
				str(state.get("building_id", "")),
				float(state.get("current_health", 0.0)),
				float(state.get("max_health", 0.0)),
				str(state.get("damage_state", "")),
			]
		)

func _capture_initial_state() -> void:
	if player == null:
		return
	_initial_player_position = player.global_position
	_initial_player_rotation = player.rotation
	var camera_rig := player.get_node_or_null("CameraRig") as Node3D
	if camera_rig != null:
		_initial_camera_rig_rotation = camera_rig.rotation

func _restore_player_state() -> void:
	if player == null:
		return
	player.global_position = _initial_player_position
	player.rotation = _initial_player_rotation
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	var camera_rig := player.get_node_or_null("CameraRig") as Node3D
	if camera_rig != null:
		camera_rig.rotation = _initial_camera_rig_rotation
	if player.has_method("set_aim_down_sights_active"):
		player.set_aim_down_sights_active(false)
	if player.has_method("set_weapon_mode"):
		player.set_weapon_mode("missile_launcher")

func _clear_missiles() -> void:
	if missile_root == null:
		return
	for child in missile_root.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		missile_root.remove_child(child_node)
		child_node.free()

func _restore_target_building() -> void:
	if target_building_runtime != null and is_instance_valid(target_building_runtime):
		remove_child(target_building_runtime)
		target_building_runtime.free()
	var restored_target := TargetBuildingScene.instantiate() as Node3D
	add_child(restored_target)
	target_building_runtime = restored_target
