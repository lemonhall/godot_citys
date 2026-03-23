extends Node3D

const CityProjectile := preload("res://city_game/combat/CityProjectile.gd")
const CityGrenade := preload("res://city_game/combat/CityGrenade.gd")
const CityLaserDesignatorBeam := preload("res://city_game/combat/CityLaserDesignatorBeam.gd")
const CityMissileScene := preload("res://city_game/combat/CityMissile.tscn")
const SpiderCrawlerScene := preload("res://city_game/world/creatures/arthropods/CitySpiderCrawler.tscn")
const DEMO_MOTION_SPEED_MPS := 6.0
const DEMO_STOP_DISTANCE_M := 2.8
const DEMO_SWARM_RING_RADIUS_M := 3.2
const SWARM_SPAWN_SEED_BASE := 424242
const SWARM_BEHAVIOR_SEED_BASE := 6100
const SWARM_SPAWN_RADIAL_SCALE_MIN := 0.34
const SWARM_SPAWN_RADIAL_SCALE_MAX := 1.18
const SWARM_SPAWN_TANGENT_JITTER_M := 8.5
const SWARM_SPAWN_POSITION_JITTER_M := 5.0
const SWARM_MIN_SEPARATION_M := 5.2
const DEMO_TOGGLE_KEY := KEY_SPACE
const RESET_KEY := KEY_F5
const LASER_DAMAGE := 1.0
const LASER_TRACE_OVERSHOOT_M := 3.0
const SPIDER_LASER_FALLBACK_RADIUS_M := 1.35

@export var lab_title := "v39 spider crawler lab"
@export var lab_hint := "1 Rifle  2 Grenade  0 Laser  8 RPG  Left Fire  Right ADS/Prep  Space Pause/Run  F5 Reset"

@onready var player := $Player
@onready var hud := $Hud
@onready var spider_crawler := $CrawlerRoot
@onready var swarm_root := $SwarmRoot
@onready var swarm_spawn_root := $SwarmSpawnRoot
@onready var projectile_root := $CombatRoot/Projectiles
@onready var grenade_root := $CombatRoot/Grenades
@onready var laser_beam_root := $CombatRoot/LaserBeams
@onready var missile_root := $CombatRoot/Missiles

var _initial_player_position := Vector3.ZERO
var _initial_player_rotation := Vector3.ZERO
var _initial_camera_rig_rotation := Vector3.ZERO
var _demo_motion_active := false
var _spider_swarm: Array[Node3D] = []
var _scripted_aim_target_world_position := Vector3.INF

func _ready() -> void:
	_capture_initial_state()
	_rebuild_spider_swarm()
	_connect_player_combat_signals()
	if player != null and player.has_method("set_weapon_mode"):
		player.set_weapon_mode("rifle")
	if _is_rendered_demo_session():
		start_demo_motion()
	_refresh_hud()

func _process(_delta: float) -> void:
	if _demo_motion_active:
		_update_demo_motion_velocity()
	_refresh_hud()

func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == RESET_KEY:
		reset_lab_state()
		if _is_rendered_demo_session():
			start_demo_motion()
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode == DEMO_TOGGLE_KEY:
		toggle_demo_motion()
		get_viewport().set_input_as_handled()

func get_spider_crawler() -> Node3D:
	return spider_crawler

func get_spider_crawlers() -> Array:
	var crawlers: Array = []
	for spider in _spider_swarm:
		if spider == null or not is_instance_valid(spider):
			continue
		crawlers.append(spider)
	return crawlers

func get_live_spider_crawlers() -> Array:
	var crawlers: Array = []
	for spider in _spider_swarm:
		if spider == null or not is_instance_valid(spider):
			continue
		if spider.has_method("is_alive") and not spider.is_alive():
			continue
		crawlers.append(spider)
	return crawlers

func get_active_spider_count() -> int:
	return get_live_spider_crawlers().size()

func get_defeated_spider_count() -> int:
	var defeated_count := 0
	for spider in _spider_swarm:
		if spider == null or not is_instance_valid(spider):
			continue
		if spider.has_method("is_alive") and not spider.is_alive():
			defeated_count += 1
	return defeated_count

func get_nearest_live_spider_to_player() -> Node3D:
	var origin: Vector3 = player.global_position if player != null else Vector3.ZERO
	var best_spider: Node3D = null
	var best_distance_sq := INF
	for spider_variant in get_live_spider_crawlers():
		var spider := spider_variant as Node3D
		if spider == null:
			continue
		var distance_sq := spider.global_position.distance_squared_to(origin)
		if distance_sq >= best_distance_sq:
			continue
		best_distance_sq = distance_sq
		best_spider = spider
	return best_spider

func get_crawler_debug_state() -> Dictionary:
	if spider_crawler == null or not spider_crawler.has_method("get_debug_state"):
		return {}
	return spider_crawler.get_debug_state()

func get_swarm_state() -> Dictionary:
	var nearest_target := get_nearest_live_spider_to_player()
	var nearest_health: Dictionary = nearest_target.get_health_state() if nearest_target != null and nearest_target.has_method("get_health_state") else {}
	return {
		"total_spiders": get_spider_crawlers().size(),
		"live_spiders": get_active_spider_count(),
		"defeated_spiders": get_defeated_spider_count(),
		"nearest_target_health": nearest_health.duplicate(true),
	}

func step_spider(delta: float = 0.16, steps: int = 1) -> void:
	if spider_crawler == null or not spider_crawler.has_method("tick_crawler"):
		return
	for _step_index in range(maxi(steps, 1)):
		spider_crawler.tick_crawler(delta)
	_refresh_hud()

func set_spider_motion_velocity(velocity: Vector3) -> void:
	if spider_crawler != null and spider_crawler.has_method("set_debug_motion_velocity"):
		spider_crawler.set_debug_motion_velocity(velocity)

func set_spider_auto_step_enabled(enabled: bool) -> void:
	if spider_crawler != null and spider_crawler.has_method("set_auto_step_enabled"):
		spider_crawler.set_auto_step_enabled(enabled)

func teleport_spider_to_world_position(world_position: Vector3) -> void:
	if spider_crawler != null and spider_crawler.has_method("teleport_body_to_world_position"):
		spider_crawler.teleport_body_to_world_position(world_position)
	_refresh_hud()

func force_spider_replan() -> void:
	if spider_crawler != null and spider_crawler.has_method("debug_force_replan_all_legs"):
		spider_crawler.debug_force_replan_all_legs()
	_refresh_hud()

func aim_player_at_world_position(target_world_position: Vector3) -> void:
	_scripted_aim_target_world_position = target_world_position
	if player == null:
		return
	var camera := player.get_node_or_null("CameraRig/Camera3D") as Camera3D
	var camera_rig := player.get_node_or_null("CameraRig") as Node3D
	if camera_rig == null:
		return
	var aim_origin: Vector3 = camera.global_position if camera != null else player.global_position + Vector3.UP * 1.4
	var delta := target_world_position - aim_origin
	var planar_length := maxf(Vector2(delta.x, delta.z).length(), 0.001)
	var planar_target := target_world_position
	planar_target.y = player.global_position.y
	if player.global_position.distance_to(planar_target) > 0.001:
		player.look_at(planar_target, Vector3.UP, true)
	if player.has_method("get_pitch_limits_degrees"):
		var pitch_limits: Dictionary = player.get_pitch_limits_degrees()
		var min_pitch := deg_to_rad(float(pitch_limits.get("min", -68.0)))
		var max_pitch := deg_to_rad(float(pitch_limits.get("max", 35.0)))
		camera_rig.rotation.x = clampf(-atan2(delta.y, planar_length), min_pitch, max_pitch)
	if camera != null:
		camera.look_at(target_world_position, Vector3.UP, true)

func fire_player_projectile() -> Node3D:
	if player == null or not player.has_method("get_projectile_spawn_transform"):
		return null
	var spawn_transform: Transform3D = player.get_projectile_spawn_transform()
	if _has_scripted_aim_target():
		return fire_player_projectile_toward(_scripted_aim_target_world_position)
	if not player.has_method("get_projectile_direction"):
		return null
	return _spawn_projectile(spawn_transform.origin, player.get_projectile_direction())

func fire_player_projectile_toward(target_world_position: Vector3) -> Node3D:
	if player == null or not player.has_method("get_projectile_spawn_transform"):
		return null
	var spawn_transform: Transform3D = player.get_projectile_spawn_transform()
	var direction := (target_world_position - spawn_transform.origin).normalized()
	if direction.length_squared() <= 0.0001:
		direction = player.get_projectile_direction() if player.has_method("get_projectile_direction") else Vector3.FORWARD
	return _spawn_projectile(spawn_transform.origin, direction)

func throw_player_grenade() -> Node3D:
	if player == null or not player.has_method("get_grenade_spawn_transform"):
		return null
	var spawn_transform: Transform3D = player.get_grenade_spawn_transform()
	if _has_scripted_aim_target():
		return _spawn_grenade(spawn_transform.origin, _build_grenade_launch_velocity_toward(_scripted_aim_target_world_position))
	if not player.has_method("get_grenade_launch_velocity"):
		return null
	return _spawn_grenade(spawn_transform.origin, player.get_grenade_launch_velocity())

func throw_grenade_toward(target_world_position: Vector3) -> Node3D:
	aim_player_at_world_position(target_world_position)
	if player != null and player.has_method("set_weapon_mode"):
		player.set_weapon_mode("grenade")
	if player != null and player.has_method("set_grenade_ready_active"):
		player.set_grenade_ready_active(true)
	return throw_player_grenade()

func fire_player_laser_designator() -> Dictionary:
	if _has_scripted_aim_target() and player != null and player.has_method("get_projectile_spawn_transform"):
		return fire_laser_at_world_position(_scripted_aim_target_world_position)
	if player == null or not player.has_method("get_aim_trace_segment"):
		return {}
	var trace_segment: Dictionary = player.get_aim_trace_segment()
	return _fire_laser_segment(
		trace_segment.get("origin", Vector3.ZERO),
		trace_segment.get("target", Vector3.ZERO)
	)

func fire_laser_at_world_position(target_world_position: Vector3) -> Dictionary:
	if player == null or not player.has_method("get_projectile_spawn_transform"):
		return {}
	var origin: Vector3 = player.get_projectile_spawn_transform().origin
	return _fire_laser_segment(origin, target_world_position)

func fire_player_missile_launcher() -> Node3D:
	if player == null or not player.has_method("get_projectile_spawn_transform"):
		return null
	var spawn_transform: Transform3D = player.get_projectile_spawn_transform()
	if _has_scripted_aim_target():
		return fire_missile_at_world_position(_scripted_aim_target_world_position)
	if not player.has_method("get_projectile_direction"):
		return null
	return _spawn_missile(spawn_transform.origin, player.get_projectile_direction())

func fire_missile_at_world_position(target_world_position: Vector3) -> Node3D:
	if player == null or not player.has_method("get_projectile_spawn_transform"):
		return null
	var spawn_transform: Transform3D = player.get_projectile_spawn_transform()
	var direction := (target_world_position - spawn_transform.origin).normalized()
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	return _spawn_missile(spawn_transform.origin, direction, target_world_position)

func get_active_projectile_count() -> int:
	return 0 if projectile_root == null else projectile_root.get_child_count()

func get_active_grenade_count() -> int:
	return 0 if grenade_root == null else grenade_root.get_child_count()

func get_active_laser_beam_count() -> int:
	return 0 if laser_beam_root == null else laser_beam_root.get_child_count()

func get_active_missile_count() -> int:
	return 0 if missile_root == null else missile_root.get_child_count()

func reset_lab_state() -> void:
	_clear_projectiles(projectile_root)
	_clear_projectiles(grenade_root)
	_clear_projectiles(laser_beam_root)
	_clear_projectiles(missile_root)
	_restore_player_state()
	_reset_spider_swarm_state()
	_refresh_hud()

func start_demo_motion() -> void:
	_demo_motion_active = true
	_set_swarm_auto_step_enabled(true)
	_update_demo_motion_velocity()
	_refresh_hud()

func pause_demo_motion() -> void:
	_demo_motion_active = false
	_set_swarm_auto_step_enabled(false)
	_set_swarm_motion_velocity(Vector3.ZERO)
	_refresh_hud()

func toggle_demo_motion() -> void:
	if _demo_motion_active:
		pause_demo_motion()
	else:
		start_demo_motion()

func _on_player_primary_fire_requested() -> void:
	fire_player_projectile()

func _on_player_grenade_throw_requested() -> void:
	throw_player_grenade()

func _on_player_laser_designator_requested() -> void:
	fire_player_laser_designator()

func _on_player_missile_launcher_requested() -> void:
	fire_player_missile_launcher()

func _on_player_weapon_mode_changed(_weapon_mode: String) -> void:
	_refresh_hud()

func _on_player_aim_down_sights_changed(_is_active: bool) -> void:
	_refresh_hud()

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
		var camera := player.get_node_or_null("CameraRig/Camera3D") as Camera3D if player != null else null
		var screen_position := viewport_size * 0.5
		if camera != null:
			screen_position = camera.unproject_position(aim_target)
		hud.set_crosshair_state({
			"visible": true,
			"screen_position": screen_position,
			"viewport_size": viewport_size,
			"world_target": aim_target,
			"aim_down_sights_active": ads_active,
		})
	if hud.has_method("set_status"):
		var spider_state: Dictionary = get_crawler_debug_state()
		var swarm_state: Dictionary = get_swarm_state()
		var nearest_health: Dictionary = swarm_state.get("nearest_target_health", {})
		var weapon_mode: String = player.get_weapon_mode() if player != null and player.has_method("get_weapon_mode") else ""
		hud.set_status(
			"%s\n%s\nweapon=%s  live=%d/%d  defeated=%d  target_hp=%.0f/%.0f  gait=%s" % [
				lab_title,
				lab_hint,
				weapon_mode,
				int(swarm_state.get("live_spiders", 0)),
				int(swarm_state.get("total_spiders", 0)),
				int(swarm_state.get("defeated_spiders", 0)),
				float(nearest_health.get("current", 0.0)),
				float(nearest_health.get("max", 0.0)),
				str(spider_state.get("gait_profile_id", "")),
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
	_scripted_aim_target_world_position = Vector3.INF
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
	if player.has_method("set_grenade_ready_active"):
		player.set_grenade_ready_active(false)
	if player.has_method("set_weapon_mode"):
		player.set_weapon_mode("rifle")

func _connect_player_combat_signals() -> void:
	if player == null:
		return
	_connect_player_signal("primary_fire_requested", "_on_player_primary_fire_requested")
	_connect_player_signal("grenade_throw_requested", "_on_player_grenade_throw_requested")
	_connect_player_signal("laser_designator_requested", "_on_player_laser_designator_requested")
	_connect_player_signal("missile_launcher_requested", "_on_player_missile_launcher_requested")
	_connect_player_signal("weapon_mode_changed", "_on_player_weapon_mode_changed")
	_connect_player_signal("aim_down_sights_changed", "_on_player_aim_down_sights_changed")

func _connect_player_signal(signal_name: String, method_name: String) -> void:
	if player == null or not player.has_signal(signal_name):
		return
	var callable := Callable(self, method_name)
	if player.is_connected(signal_name, callable):
		return
	player.connect(signal_name, callable)

func _rebuild_spider_swarm() -> void:
	_spider_swarm.clear()
	if spider_crawler != null:
		_prepare_spider_for_lab(spider_crawler, 0)
		_spider_swarm.append(spider_crawler)
	if swarm_root == null or swarm_spawn_root == null:
		return
	var spawn_markers: Array[Marker3D] = []
	for child in swarm_spawn_root.get_children():
		var marker := child as Marker3D
		if marker != null:
			spawn_markers.append(marker)
	spawn_markers.sort_custom(func(a: Marker3D, b: Marker3D) -> bool: return a.name < b.name)
	var spawn_positions := _build_swarm_spawn_positions(spawn_markers)
	var swarm_index := 1
	for marker_index in range(spawn_markers.size()):
		var marker := spawn_markers[marker_index]
		var spider := SpiderCrawlerScene.instantiate() as Node3D
		if spider == null:
			continue
		spider.position = spawn_positions[marker_index] if marker_index < spawn_positions.size() else marker.position
		swarm_root.add_child(spider)
		_prepare_spider_for_lab(spider, swarm_index)
		_spider_swarm.append(spider)
		swarm_index += 1

func _prepare_spider_for_lab(spider: Node3D, swarm_index: int) -> void:
	if spider == null:
		return
	spider.set_meta("swarm_slot_index", swarm_index)
	var behavior_seed := _compute_swarm_behavior_seed(swarm_index)
	spider.set_meta("swarm_behavior_seed", behavior_seed)
	spider.set_meta("swarm_attack_signature", _build_swarm_attack_signature(swarm_index))
	if spider.has_method("set_behavior_seed"):
		spider.set_behavior_seed(behavior_seed)
	if spider.has_method("set_auto_step_enabled"):
		spider.set_auto_step_enabled(false)
	if spider.has_method("set_debug_motion_velocity"):
		spider.set_debug_motion_velocity(Vector3.ZERO)
	if spider.has_method("reset_health_state"):
		spider.reset_health_state()

func _reset_spider_swarm_state() -> void:
	for spider in _spider_swarm:
		if spider == null or not is_instance_valid(spider):
			continue
		if spider.has_method("reset_health_state"):
			spider.reset_health_state()
		if spider.has_method("reset_crawler_state"):
			spider.reset_crawler_state()
		if spider.has_method("set_auto_step_enabled"):
			spider.set_auto_step_enabled(false)
		if spider.has_method("set_debug_motion_velocity"):
			spider.set_debug_motion_velocity(Vector3.ZERO)

func _set_swarm_auto_step_enabled(enabled: bool) -> void:
	for spider in _spider_swarm:
		if spider == null or not is_instance_valid(spider):
			continue
		if spider.has_method("is_alive") and not spider.is_alive():
			continue
		if spider.has_method("set_auto_step_enabled"):
			spider.set_auto_step_enabled(enabled)

func _set_swarm_motion_velocity(velocity: Vector3) -> void:
	for spider in _spider_swarm:
		if spider == null or not is_instance_valid(spider):
			continue
		if spider.has_method("set_debug_motion_velocity"):
			spider.set_debug_motion_velocity(velocity)

func _build_swarm_spawn_positions(spawn_markers: Array[Marker3D]) -> Array[Vector3]:
	var spawn_positions: Array[Vector3] = []
	if spawn_markers.is_empty():
		return spawn_positions
	var centroid := Vector3.ZERO
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for marker in spawn_markers:
		centroid += marker.position
		min_x = minf(min_x, marker.position.x)
		max_x = maxf(max_x, marker.position.x)
		min_z = minf(min_z, marker.position.z)
		max_z = maxf(max_z, marker.position.z)
	centroid /= float(spawn_markers.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = SWARM_SPAWN_SEED_BASE
	for marker in spawn_markers:
		var base_position := marker.position
		var radial := Vector3(base_position.x - centroid.x, 0.0, base_position.z - centroid.z)
		var tangent := Vector3(-radial.z, 0.0, radial.x)
		if tangent.length_squared() <= 0.0001:
			tangent = Vector3.RIGHT
		tangent = tangent.normalized()
		var accepted_position := base_position
		for _attempt in range(8):
			var candidate := centroid + radial * rng.randf_range(SWARM_SPAWN_RADIAL_SCALE_MIN, SWARM_SPAWN_RADIAL_SCALE_MAX)
			candidate += tangent * rng.randf_range(-SWARM_SPAWN_TANGENT_JITTER_M, SWARM_SPAWN_TANGENT_JITTER_M)
			candidate += Vector3(
				rng.randf_range(-SWARM_SPAWN_POSITION_JITTER_M, SWARM_SPAWN_POSITION_JITTER_M),
				0.0,
				rng.randf_range(-SWARM_SPAWN_POSITION_JITTER_M, SWARM_SPAWN_POSITION_JITTER_M)
			)
			candidate.x = clampf(candidate.x, min_x - 6.0, max_x + 6.0)
			candidate.z = clampf(candidate.z, min_z - 6.0, max_z + 6.0)
			if not _is_swarm_spawn_position_valid(candidate, spawn_positions):
				continue
			accepted_position = candidate
			break
		spawn_positions.append(accepted_position)
	return spawn_positions

func _is_swarm_spawn_position_valid(candidate: Vector3, existing_positions: Array[Vector3]) -> bool:
	for existing_position in existing_positions:
		var planar_delta := Vector2(candidate.x - existing_position.x, candidate.z - existing_position.z)
		if planar_delta.length() < SWARM_MIN_SEPARATION_M:
			return false
	return true

func _compute_swarm_behavior_seed(swarm_index: int) -> int:
	return 0 if swarm_index <= 0 else SWARM_BEHAVIOR_SEED_BASE + swarm_index * 977

func _build_swarm_attack_signature(swarm_index: int) -> Dictionary:
	if swarm_index <= 0:
		return {
			"lateral_offset_m": 0.0,
			"backoff_distance_m": DEMO_STOP_DISTANCE_M,
		}
	var rng := RandomNumberGenerator.new()
	rng.seed = SWARM_BEHAVIOR_SEED_BASE + swarm_index * 1481 + 31
	return {
		"lateral_offset_m": rng.randf_range(-3.2, 3.2),
		"backoff_distance_m": rng.randf_range(1.4, 3.8),
	}

func _spawn_projectile(origin: Vector3, direction: Vector3) -> Node3D:
	if projectile_root == null:
		return null
	var projectile := CityProjectile.new()
	projectile.configure(
		origin,
		direction,
		player,
		1.0,
		"city_projectile",
		"city_enemy"
	)
	projectile_root.add_child(projectile)
	return projectile

func _spawn_grenade(origin: Vector3, launch_velocity: Vector3) -> Node3D:
	if grenade_root == null:
		return null
	var grenade := CityGrenade.new()
	grenade.configure(origin, launch_velocity, player, player)
	grenade_root.add_child(grenade)
	return grenade

func _spawn_missile(origin: Vector3, direction: Vector3, target_world_position: Variant = null) -> Node3D:
	if missile_root == null:
		return null
	var missile := CityMissileScene.instantiate() as Node3D
	if missile == null:
		return null
	missile_root.add_child(missile)
	var target_vector: Vector3 = target_world_position as Vector3 if target_world_position is Vector3 else Vector3.INF
	if target_vector != Vector3.INF:
		var target_distance_m := maxf(origin.distance_to(target_vector), 1.0)
		missile.set("sway_primary_amplitude_m", 0.0)
		missile.set("sway_secondary_amplitude_m", 0.0)
		missile.set("max_distance_m", target_distance_m)
		missile.set("max_lifetime_sec", maxf(target_distance_m / maxf(float(missile.get("speed_mps")), 1.0) + 0.25, 0.35))
	if missile.has_method("configure"):
		missile.configure(origin, direction, player, player)
	return missile

func _fire_laser_segment(origin: Vector3, target: Vector3) -> Dictionary:
	if laser_beam_root == null or player == null:
		return {}
	var hit: Dictionary = _perform_laser_trace(origin, target)
	if hit.is_empty():
		return {}
	var hit_position: Vector3 = hit.get("position", target)
	var beam := CityLaserDesignatorBeam.new()
	beam.configure(origin, hit_position)
	laser_beam_root.add_child(beam)
	var collider: Object = hit.get("collider", null)
	if collider != null and collider is Object and (collider as Object).has_method("apply_projectile_hit"):
		(collider as Object).apply_projectile_hit(LASER_DAMAGE, hit_position, Vector3.ZERO)
	return {
		"hit": true,
		"world_position": hit_position,
	}

func _perform_laser_trace(origin: Vector3, target: Vector3) -> Dictionary:
	if get_world_3d() == null or get_world_3d().direct_space_state == null:
		return {}
	var resolved_target := target
	var direction := target - origin
	if direction.length_squared() > 0.0001:
		resolved_target += direction.normalized() * LASER_TRACE_OVERSHOOT_M
	var query := PhysicsRayQueryParameters3D.create(origin, resolved_target)
	query.collide_with_areas = false
	query.exclude = [player.get_rid()] if player is CollisionObject3D else []
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit
	return _resolve_spider_laser_fallback(origin, resolved_target)

func _resolve_spider_laser_fallback(origin: Vector3, target: Vector3) -> Dictionary:
	var segment: Vector3 = target - origin
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.0001:
		return {}
	var best_hit: Dictionary = {}
	var best_progress := INF
	var best_distance_squared := INF
	for spider_variant in get_live_spider_crawlers():
		var spider := spider_variant as Node3D
		if spider == null or not spider.has_method("apply_projectile_hit"):
			continue
		var spider_target: Vector3 = spider.get_combat_target_world_position() if spider.has_method("get_combat_target_world_position") else spider.global_position
		var progress := clampf((spider_target - origin).dot(segment) / segment_length_squared, 0.0, 1.0)
		var closest_point := origin + segment * progress
		var distance_squared := spider_target.distance_squared_to(closest_point)
		if distance_squared > SPIDER_LASER_FALLBACK_RADIUS_M * SPIDER_LASER_FALLBACK_RADIUS_M:
			continue
		if progress > best_progress:
			continue
		if is_equal_approx(progress, best_progress) and distance_squared >= best_distance_squared:
			continue
		best_progress = progress
		best_distance_squared = distance_squared
		best_hit = {
			"position": closest_point,
			"collider": spider,
		}
	return best_hit

func _has_scripted_aim_target() -> bool:
	return _scripted_aim_target_world_position != Vector3.INF

func _build_grenade_launch_velocity_toward(target_world_position: Vector3) -> Vector3:
	var spawn_origin: Vector3 = player.get_grenade_spawn_transform().origin if player != null and player.has_method("get_grenade_spawn_transform") else Vector3.ZERO
	var planar_delta := Vector3(target_world_position.x - spawn_origin.x, 0.0, target_world_position.z - spawn_origin.z)
	var planar_distance_m := maxf(planar_delta.length(), 0.001)
	var distance_ratio := clampf(planar_distance_m / 36.0, 0.0, 1.0)
	var min_flight_time := float(player.get("grenade_min_flight_time_sec")) if player != null else 0.26
	var max_flight_time := float(player.get("grenade_max_flight_time_sec")) if player != null else 2.1
	var gravity_mps2 := float(player.get("grenade_gravity_mps2")) if player != null else 24.0
	var flight_time_sec := lerpf(min_flight_time, max_flight_time, distance_ratio)
	flight_time_sec = maxf(flight_time_sec, 0.12)
	var horizontal_speed_mps := planar_distance_m / flight_time_sec
	var vertical_delta_m: float = target_world_position.y - spawn_origin.y
	var vertical_speed_mps: float = (vertical_delta_m + 0.5 * gravity_mps2 * flight_time_sec * flight_time_sec) / flight_time_sec
	var direction := planar_delta.normalized() if planar_delta.length_squared() > 0.0001 else Vector3.FORWARD
	var launch_velocity := direction * horizontal_speed_mps
	launch_velocity.y = vertical_speed_mps
	return launch_velocity

func _clear_projectiles(projectile_parent: Node3D) -> void:
	if projectile_parent == null:
		return
	for child in projectile_parent.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		projectile_parent.remove_child(child_node)
		child_node.free()

func _is_rendered_demo_session() -> bool:
	return DisplayServer.get_name() != "headless"

func _update_demo_motion_velocity() -> void:
	if player == null:
		return
	var player_origin: Vector3 = player.global_position
	var live_spiders: Array = get_live_spider_crawlers()
	for spider_variant in live_spiders:
		var spider := spider_variant as Node3D
		if spider == null:
			continue
		var to_player := player_origin - spider.global_position
		to_player.y = 0.0
		var approach_direction := to_player.normalized() if to_player.length_squared() > 0.0001 else Vector3.BACK
		var lateral_direction := Vector3(-approach_direction.z, 0.0, approach_direction.x)
		if lateral_direction.length_squared() <= 0.0001:
			lateral_direction = Vector3.RIGHT
		lateral_direction = lateral_direction.normalized()
		var spider_debug_state: Dictionary = spider.get_debug_state() if spider.has_method("get_debug_state") else {}
		var pounce_active := bool(spider_debug_state.get("pounce_active", false))
		var attack_signature: Dictionary = spider.get_meta("swarm_attack_signature", {}) as Dictionary
		var desired_target := player_origin \
			- approach_direction * float(attack_signature.get("backoff_distance_m", DEMO_STOP_DISTANCE_M)) \
			+ lateral_direction * float(attack_signature.get("lateral_offset_m", 0.0))
		if pounce_active:
			desired_target = player_origin
		var to_target: Vector3 = desired_target - spider.global_position
		to_target.y = 0.0
		if to_target.length() <= DEMO_STOP_DISTANCE_M * 0.35 and not pounce_active:
			if spider.has_method("set_debug_motion_velocity"):
				spider.set_debug_motion_velocity(Vector3.ZERO)
			continue
		var planar_direction: Vector3 = to_target.normalized()
		if spider.has_method("set_debug_motion_velocity"):
			var motion_speed_mps := DEMO_MOTION_SPEED_MPS * 1.15 if pounce_active else DEMO_MOTION_SPEED_MPS
			spider.set_debug_motion_velocity(planar_direction * motion_speed_mps)
		spider.look_at(spider.global_position + planar_direction, Vector3.UP)
