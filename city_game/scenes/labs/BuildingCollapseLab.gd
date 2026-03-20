extends Node3D

const CityMissileScene := preload("res://city_game/combat/CityMissile.tscn")

@onready var player = $Player
@onready var hud = $Hud
@onready var missile_root = $CombatRoot/Missiles
@onready var target_building_runtime = $TargetBuildingRoot

var _last_missile_explosion_result: Dictionary = {}

func _ready() -> void:
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
			"v33 Building Collapse Lab\n8 RPG  Left Click Fire  Right Click ADS\nbuilding=%s  hp=%.0f / %.0f  state=%s" % [
				str(state.get("building_id", "")),
				float(state.get("current_health", 0.0)),
				float(state.get("max_health", 0.0)),
				str(state.get("damage_state", "")),
			]
		)
