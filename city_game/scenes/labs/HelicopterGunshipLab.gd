extends Node3D

const CityMissileScene := preload("res://city_game/combat/CityMissile.tscn")

@onready var player := $Player
@onready var missile_root := $CombatRoot/Missiles as Node3D
@onready var enemy_missile_root := $CombatRoot/EnemyMissiles as Node3D
@onready var encounter_root := $EncounterRoot

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

func get_active_gunship() -> Node3D:
	if encounter_root == null or not encounter_root.has_method("get_active_gunship"):
		return null
	return encounter_root.get_active_gunship()

func get_encounter_state() -> Dictionary:
	if encounter_root == null or not encounter_root.has_method("get_state"):
		return {}
	return encounter_root.get_state()

func start_encounter() -> Node3D:
	if encounter_root == null or not encounter_root.has_method("start_encounter"):
		return null
	return encounter_root.start_encounter()

func fire_player_missile_launcher() -> Node3D:
	if player == null or missile_root == null:
		return null
	if not player.has_method("get_projectile_spawn_transform") or not player.has_method("get_projectile_direction"):
		return null
	var spawn_transform: Transform3D = player.get_projectile_spawn_transform()
	return _spawn_player_missile(spawn_transform.origin, player.get_projectile_direction())

func fire_missile_at_world_position(target_world_position: Vector3) -> Node3D:
	if player == null or not player.has_method("get_projectile_spawn_transform"):
		return null
	var spawn_transform: Transform3D = player.get_projectile_spawn_transform()
	var direction := (target_world_position - spawn_transform.origin).normalized()
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	return _spawn_player_missile(spawn_transform.origin, direction)

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

func get_active_player_missile_count() -> int:
	return 0 if missile_root == null else missile_root.get_child_count()

func get_active_enemy_missile_count() -> int:
	return 0 if enemy_missile_root == null else enemy_missile_root.get_child_count()

func reset_lab_state() -> void:
	_clear_projectiles(missile_root)
	_clear_projectiles(enemy_missile_root)
	if encounter_root != null and encounter_root.has_method("reset_encounter"):
		encounter_root.reset_encounter()
	_restore_player_state()

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

func _clear_projectiles(projectile_root: Node3D) -> void:
	if projectile_root == null:
		return
	for child in projectile_root.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		projectile_root.remove_child(child_node)
		child_node.free()

func _spawn_player_missile(origin: Vector3, direction: Vector3) -> Node3D:
	if missile_root == null:
		return null
	var missile := CityMissileScene.instantiate() as Node3D
	if missile == null:
		return null
	missile_root.add_child(missile)
	if missile.has_method("configure"):
		missile.configure(origin, direction, player, player)
	return missile

func _on_player_missile_launcher_requested() -> void:
	fire_player_missile_launcher()
