extends Node3D

signal encounter_completed(result: Dictionary)

@export var gunship_scene: PackedScene = preload("res://city_game/combat/helicopter/CityHelicopterGunship.tscn")
@export_node_path("Node3D") var player_path: NodePath
@export_node_path("Node3D") var player_missile_root_path: NodePath
@export_node_path("Node3D") var enemy_missile_root_path: NodePath
@export var enemy_missile_scene: PackedScene = preload("res://city_game/combat/CityMissile.tscn")
@export var use_internal_start_trigger := true
@export var use_internal_start_ring := true

@onready var _start_trigger := $StartTrigger as Area3D
@onready var _start_ring := $StartRing as Node3D
@onready var _gunship_spawn_anchor := $GunshipSpawnAnchor as Marker3D
@onready var _active_gunship_root := $ActiveGunshipRoot as Node3D

var _player: Node3D = null
var _player_missile_root: Node3D = null
var _enemy_missile_root: Node3D = null
var _phase := "idle"
var _activation_count := 0
var _completion_count := 0
var _active_completion_emitted := false

func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D if player_path != NodePath("") else null
	_player_missile_root = get_node_or_null(player_missile_root_path) as Node3D if player_missile_root_path != NodePath("") else null
	_enemy_missile_root = get_node_or_null(enemy_missile_root_path) as Node3D if enemy_missile_root_path != NodePath("") else null
	if use_internal_start_trigger and _start_trigger != null:
		var callable := Callable(self, "_on_start_trigger_body_entered")
		if not _start_trigger.body_entered.is_connected(callable):
			_start_trigger.body_entered.connect(callable)
	if use_internal_start_ring:
		_configure_start_ring()
	else:
		_set_start_ring_visible(false)

func start_encounter() -> Node3D:
	var existing := get_active_gunship()
	if existing != null:
		_phase = "active"
		return existing
	if gunship_scene == null or _active_gunship_root == null or _gunship_spawn_anchor == null:
		return null
	var gunship := gunship_scene.instantiate() as Node3D
	if gunship == null:
		return null
	_active_gunship_root.add_child(gunship)
	_place_gunship_at_spawn(gunship)
	_connect_gunship(gunship)
	if gunship.has_method("configure_combat"):
		gunship.configure_combat(_player, _gunship_spawn_anchor.global_position)
	call_deferred("_finalize_gunship_spawn", gunship)
	_phase = "active"
	_activation_count += 1
	_active_completion_emitted = false
	_set_start_ring_visible(false)
	return gunship

func reset_encounter() -> void:
	_clear_active_gunship()
	_clear_player_missiles()
	_clear_enemy_missiles()
	_phase = "idle"
	_active_completion_emitted = false
	_set_start_ring_visible(use_internal_start_ring)

func get_active_gunship() -> Node3D:
	if _active_gunship_root == null or _active_gunship_root.get_child_count() <= 0:
		return null
	return _active_gunship_root.get_child(0) as Node3D

func get_state() -> Dictionary:
	return {
		"phase": _phase,
		"activation_count": _activation_count,
		"completion_count": _completion_count,
		"active_gunship_present": get_active_gunship() != null,
		"trigger_radius_m": _resolve_trigger_radius_m(),
		"start_ring_visible": _start_ring != null and _start_ring.visible,
		"player_missile_count": 0 if _player_missile_root == null else _player_missile_root.get_child_count(),
		"enemy_missile_count": 0 if _enemy_missile_root == null else _enemy_missile_root.get_child_count(),
	}

func _configure_start_ring() -> void:
	if not use_internal_start_ring or _start_ring == null:
		return
	if _start_ring.has_method("set_marker_theme"):
		_start_ring.set_marker_theme("task_available_start")
	if _start_ring.has_method("set_marker_radius"):
		_start_ring.set_marker_radius(_resolve_trigger_radius_m())
	if _start_ring.has_method("set_marker_world_position"):
		_start_ring.set_marker_world_position(_start_trigger.global_position if _start_trigger != null else global_position)
	_set_start_ring_visible(true)

func _set_start_ring_visible(visible: bool) -> void:
	if _start_ring == null:
		return
	if _start_ring.has_method("set_marker_visible"):
		_start_ring.set_marker_visible(visible)
	else:
		_start_ring.visible = visible

func _resolve_trigger_radius_m() -> float:
	if _start_trigger == null:
		return 10.0
	var collision_shape := _start_trigger.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		return 10.0
	if collision_shape.shape is CylinderShape3D:
		return maxf((collision_shape.shape as CylinderShape3D).radius, 1.5)
	if collision_shape.shape is SphereShape3D:
		return maxf((collision_shape.shape as SphereShape3D).radius, 1.5)
	if collision_shape.shape is BoxShape3D:
		var box := collision_shape.shape as BoxShape3D
		return maxf(maxf(box.size.x, box.size.z) * 0.5, 1.5)
	return 10.0

func _on_start_trigger_body_entered(body: Node3D) -> void:
	if not use_internal_start_trigger:
		return
	if body == null or body != _player:
		return
	if _phase != "idle":
		return
	start_encounter()

func _finalize_gunship_spawn(gunship: Node3D) -> void:
	if gunship == null or not is_instance_valid(gunship) or _gunship_spawn_anchor == null:
		return
	_place_gunship_at_spawn(gunship)
	if gunship.has_method("configure_combat"):
		gunship.configure_combat(_player, _gunship_spawn_anchor.global_position)
	if _player != null and is_instance_valid(_player):
		var look_target := _player.global_position
		look_target.y = gunship.global_position.y
		if gunship.global_position.distance_to(look_target) > 0.001:
			gunship.look_at(look_target, Vector3.UP, true)

func _place_gunship_at_spawn(gunship: Node3D) -> void:
	if gunship == null or not is_instance_valid(gunship) or _gunship_spawn_anchor == null:
		return
	gunship.global_position = _gunship_spawn_anchor.global_position

func _connect_gunship(gunship: Node3D) -> void:
	if gunship == null or not is_instance_valid(gunship):
		return
	if gunship.has_signal("missile_fire_requested"):
		var missile_callable := Callable(self, "_on_gunship_missile_fire_requested")
		if not gunship.missile_fire_requested.is_connected(missile_callable):
			gunship.missile_fire_requested.connect(missile_callable)
	if gunship.has_signal("defeated"):
		var defeated_callable := Callable(self, "_on_gunship_defeated")
		if not gunship.defeated.is_connected(defeated_callable):
			gunship.defeated.connect(defeated_callable)
	if gunship.has_signal("destroyed"):
		var destroyed_callable := Callable(self, "_on_gunship_destroyed")
		if not gunship.destroyed.is_connected(destroyed_callable):
			gunship.destroyed.connect(destroyed_callable)

func _on_gunship_missile_fire_requested(origin: Vector3, direction: Vector3) -> void:
	_spawn_enemy_missile(origin, direction)

func _spawn_enemy_missile(origin: Vector3, direction: Vector3) -> Node3D:
	if enemy_missile_scene == null or _enemy_missile_root == null:
		return null
	var missile := enemy_missile_scene.instantiate() as Node3D
	if missile == null:
		return null
	if missile.has_method("set"):
		missile.set("explosion_damage", 0.0)
		missile.set("explosion_camera_shake_duration_sec", 0.28)
		missile.set("explosion_camera_shake_amplitude_m", 0.18)
		missile.set("explosion_aim_disturbance_deg", 1.45)
		missile.set("launch_audio_enabled", false)
		missile.set("speed_mps", 185.0)
		missile.set("max_distance_m", 280.0)
		missile.set("max_lifetime_sec", 2.8)
	_enemy_missile_root.add_child(missile)
	if missile.has_method("configure"):
		missile.configure(origin, direction, get_active_gunship(), _player)
	return missile

func _on_gunship_defeated() -> void:
	if _phase != "active":
		return
	if _active_completion_emitted:
		return
	_active_completion_emitted = true
	encounter_completed.emit({
		"phase": "completed",
		"activation_count": _activation_count,
		"completion_count": _completion_count + 1,
		"active_gunship_present": get_active_gunship() != null,
	})

func _on_gunship_destroyed() -> void:
	if _phase != "active":
		return
	call_deferred("_complete_active_encounter")

func _complete_active_encounter() -> void:
	if _phase != "active":
		return
	_completion_count += 1
	_clear_active_gunship()
	_clear_player_missiles()
	_clear_enemy_missiles()
	_phase = "idle"
	_set_start_ring_visible(true)

func _clear_active_gunship() -> void:
	if _active_gunship_root == null:
		return
	for child in _active_gunship_root.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		_active_gunship_root.remove_child(child_node)
		child_node.free()

func _clear_enemy_missiles() -> void:
	if _enemy_missile_root == null:
		return
	for child in _enemy_missile_root.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		_enemy_missile_root.remove_child(child_node)
		child_node.free()

func _clear_player_missiles() -> void:
	if _player_missile_root == null:
		return
	for child in _player_missile_root.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		_player_missile_root.remove_child(child_node)
		child_node.free()
