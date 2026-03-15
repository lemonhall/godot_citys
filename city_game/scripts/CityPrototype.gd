extends Node3D

const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityChunkKey := preload("res://city_game/world/streaming/CityChunkKey.gd")
const CityChunkNavRuntime := preload("res://city_game/world/navigation/CityChunkNavRuntime.gd")
const CityChunkProfileBuilder := preload("res://city_game/world/rendering/CityChunkProfileBuilder.gd")
const CityChunkGroundSampler := preload("res://city_game/world/rendering/CityChunkGroundSampler.gd")
const CityMinimapProjector := preload("res://city_game/world/map/CityMinimapProjector.gd")
const CityVehicleVisualCatalog := preload("res://city_game/world/vehicles/rendering/CityVehicleVisualCatalog.gd")
const CityProjectile := preload("res://city_game/combat/CityProjectile.gd")
const CityGrenade := preload("res://city_game/combat/CityGrenade.gd")
const CityTraumaEnemy := preload("res://city_game/combat/CityTraumaEnemy.gd")

const CONTROL_MODE_PLAYER := "player"
const CONTROL_MODE_INSPECTION := "inspection"
const MINIMAP_POSITION_REFRESH_M := 256.0
const HUD_REFRESH_INTERVAL_USEC := 50000
const HUD_REFRESH_INTERVAL_FAST_USEC := 120000
const MINIMAP_HUD_REFRESH_INTERVAL_USEC := 120000
const MINIMAP_HUD_REFRESH_INTERVAL_FAST_USEC := 320000
const HEADLESS_HUD_REFRESH_INTERVAL_USEC := 200000
const HEADLESS_HUD_REFRESH_INTERVAL_FAST_USEC := 400000
const HEADLESS_MINIMAP_HUD_REFRESH_INTERVAL_USEC := 400000
const HEADLESS_MINIMAP_HUD_REFRESH_INTERVAL_FAST_USEC := 800000
const ACTOR_PAGE_PREWARM_RING_RADIUS_CHUNKS := 2
const CHUNK_PAGE_PREWARM_RING_RADIUS_CHUNKS := 4
const ABANDONED_HIJACK_VEHICLE_LIFETIME_SEC := 15.0

@onready var generated_city: Node = $GeneratedCity
@onready var hud: CanvasLayer = $Hud
@onready var player: Node3D = $Player
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var debug_overlay: CanvasLayer = $DebugOverlay
@onready var chunk_renderer: Node3D = $ChunkRenderer

var _world_config
var _world_data: Dictionary = {}
var _chunk_streamer
var _navigation_runtime
var _control_mode := CONTROL_MODE_PLAYER
var _minimap_projector
var _minimap_route_world_positions: Array[Vector3] = []
var _minimap_snapshot_cache: Dictionary = {}
var _minimap_cache_key := ""
var _minimap_cache_hits := 0
var _minimap_cache_misses := 0
var _minimap_rebuild_count := 0
var _world_generation_usec := 0
var _world_generation_profile: Dictionary = {}
var _update_streaming_sample_count := 0
var _update_streaming_total_usec := 0
var _update_streaming_max_usec := 0
var _update_streaming_last_usec := 0
var _hud_refresh_sample_count := 0
var _hud_refresh_total_usec := 0
var _hud_refresh_max_usec := 0
var _hud_refresh_last_usec := 0
var _frame_step_sample_count := 0
var _frame_step_total_usec := 0
var _frame_step_max_usec := 0
var _frame_step_last_usec := 0
var _minimap_request_count := 0
var _minimap_build_total_usec := 0
var _minimap_build_max_usec := 0
var _minimap_build_last_usec := 0
var _combat_root: Node3D = null
var _projectile_root: Node3D = null
var _grenade_root: Node3D = null
var _enemy_projectile_root: Node3D = null
var _enemy_root: Node3D = null
var _pedestrians_visible := true
var _fps_overlay_visible := false
var _last_fps_sample := 0.0
var _last_hud_refresh_tick_usec := -HUD_REFRESH_INTERVAL_USEC
var _last_minimap_hud_refresh_tick_usec := -MINIMAP_HUD_REFRESH_INTERVAL_USEC
var _vehicle_visual_catalog: CityVehicleVisualCatalog = null
var _abandoned_vehicle_visual_root: Node3D = null
var _abandoned_vehicle_visuals: Array = []
var _pending_player_vehicle_impact_result: Dictionary = {}

func _ready() -> void:
	_configure_environment()
	_ensure_combat_roots()
	_world_config = CityWorldConfig.new()
	var world_generator := CityWorldGenerator.new()
	var generation_started_usec := Time.get_ticks_usec()
	_world_data = world_generator.generate_world(_world_config)
	_world_generation_usec = Time.get_ticks_usec() - generation_started_usec
	_world_generation_profile = (_world_data.get("generation_profile", {}) as Dictionary).duplicate(true)
	_chunk_streamer = CityChunkStreamer.new(_world_config, _world_data)
	_navigation_runtime = CityChunkNavRuntime.new(_world_config, _world_data)
	_minimap_projector = CityMinimapProjector.new(_world_config, _world_data)
	_vehicle_visual_catalog = CityVehicleVisualCatalog.new()
	if chunk_renderer != null and chunk_renderer.has_method("setup"):
		chunk_renderer.setup(_world_config, _world_data)
		if chunk_renderer.has_method("set_pedestrians_visible"):
			chunk_renderer.set_pedestrians_visible(_pedestrians_visible)
	if debug_overlay != null:
		debug_overlay.visible = false
	_align_player_to_streamed_ground()
	if player != null and player.has_method("suspend_ground_stabilization"):
		player.suspend_ground_stabilization(24)
	_connect_player_combat()
	if player != null:
		player.add_to_group("city_player")

	set_control_mode(CONTROL_MODE_PLAYER)
	update_streaming_for_position(_get_active_anchor_position())
	_prewarm_actor_pages_around_spawn()
	if hud != null and hud.has_method("set_fps_overlay_visible"):
		hud.set_fps_overlay_visible(_fps_overlay_visible)
	_refresh_hud_status()

func _process(delta: float) -> void:
	_update_abandoned_vehicle_visuals(delta)
	if player == null:
		return
	var frame_started_usec := Time.get_ticks_usec()
	update_streaming_for_position(player.global_position, delta)
	var impact_result := _resolve_player_vehicle_pedestrian_impact_impl()
	if not impact_result.is_empty():
		_pending_player_vehicle_impact_result = impact_result.duplicate(true)
	var frame_duration_usec := Time.get_ticks_usec() - frame_started_usec
	_record_frame_step_sample(frame_duration_usec)
	if delta > 0.0:
		_last_fps_sample = 1.0 / delta
	elif frame_duration_usec > 0:
		_last_fps_sample = 1000000.0 / float(frame_duration_usec)
	if DisplayServer.get_name() != "headless" and hud != null and hud.has_method("set_fps_overlay_sample"):
		hud.set_fps_overlay_sample(_last_fps_sample)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F:
			handle_vehicle_interaction()
			return
		if key_event.pressed and not key_event.echo and handle_debug_keypress(key_event.keycode, key_event.physical_keycode):
			return
	if DisplayServer.get_name() == "headless":
		return

func handle_debug_keypress(keycode: int, physical_keycode: int = 0) -> bool:
	if keycode == KEY_C:
		set_control_mode(CONTROL_MODE_INSPECTION if _control_mode == CONTROL_MODE_PLAYER else CONTROL_MODE_PLAYER)
		return true
	if keycode == KEY_KP_MULTIPLY or physical_keycode == KEY_KP_MULTIPLY:
		toggle_pedestrians_visible()
		return true
	if keycode == KEY_KP_SUBTRACT or physical_keycode == KEY_KP_SUBTRACT:
		toggle_fps_overlay()
		return true
	if keycode == KEY_KP_DIVIDE or physical_keycode == KEY_KP_DIVIDE:
		spawn_trauma_enemy()
		return true
	return false

func _refresh_hud_status(snapshot_override: Dictionary = {}, force: bool = false) -> void:
	if not force and not _should_refresh_hud():
		return
	var refresh_started_usec := Time.get_ticks_usec()
	if not generated_city.has_method("get_city_summary"):
		return
	if hud == null:
		return
	var is_headless := DisplayServer.get_name() == "headless"
	if is_headless:
		var minimap_refresh_interval_usec := _resolve_minimap_refresh_interval_usec(true)
		var should_refresh_minimap := (_minimap_request_count == 0) or (Time.get_ticks_usec() - _last_minimap_hud_refresh_tick_usec >= minimap_refresh_interval_usec)
		if should_refresh_minimap:
			build_minimap_snapshot()
			_last_minimap_hud_refresh_tick_usec = Time.get_ticks_usec()
		_last_hud_refresh_tick_usec = Time.get_ticks_usec()
		_record_hud_refresh_sample(Time.get_ticks_usec() - refresh_started_usec)
		return
	var hud_debug_expanded := hud.has_method("is_debug_expanded") and bool(hud.is_debug_expanded())
	var snapshot: Dictionary = snapshot_override.duplicate(false) if not snapshot_override.is_empty() else _build_hud_snapshot(not hud_debug_expanded)
	if hud_debug_expanded and hud.has_method("set_status"):
		var world_summary := str(_world_data.get("summary", "World data unavailable"))
		var active_speed_text := ""
		if player != null and player.has_method("get_walk_speed_mps") and player.has_method("get_sprint_speed_mps"):
			active_speed_text = "move_speed=%.1f / %.1f m/s" % [float(player.get_walk_speed_mps()), float(player.get_sprint_speed_mps())]
		var lines := PackedStringArray([
			"City sandbox skeleton",
			"WASD / arrows move",
			"Shift sprint  Space jump",
			"Mouse rotates player camera  Esc releases cursor",
			"Press C to toggle normal / inspection speed",
			"1 rifle  2 grenade  Left click fires / throws  Right click ADS / hold grenade",
			"Numpad / spawns trauma squad enemy",
			"Numpad * toggles pedestrians  Numpad - toggles FPS overlay",
			"control_mode=%s" % _control_mode,
			"pedestrian_visible=%s fps_overlay_visible=%s" % [str(are_pedestrians_visible()), str(_fps_overlay_visible)],
			"tracked_position=%s" % str(_vector3_to_dict(player.global_position if player != null else Vector3.ZERO)),
			generated_city.get_city_summary(),
			world_summary,
			"current_chunk_id=%s | active_chunk_count=%d" % [
				str(snapshot.get("current_chunk_id", "")),
				int(snapshot.get("active_chunk_count", 0))
			],
			"current_chunk_lod=%s" % str(snapshot.get("current_chunk_lod_mode", "")),
			"visual_variant=%s" % str(snapshot.get("current_chunk_visual_variant_id", "")),
			"combat=player_projectiles:%d grenades:%d enemy_projectiles:%d enemies:%d" % [
				get_active_projectile_count(),
				get_active_grenade_count(),
				get_active_enemy_projectile_count(),
				get_active_enemy_count()
			],
			_weapon_status_text(),
			active_speed_text,
		])
		hud.set_status("\n".join(lines))
	if hud_debug_expanded and hud.has_method("set_debug_text") and debug_overlay != null and debug_overlay.has_method("get_debug_text"):
		hud.set_debug_text(debug_overlay.get_debug_text())
	if hud.has_method("set_minimap_snapshot"):
		hud.set_minimap_snapshot(build_minimap_snapshot())
		_last_minimap_hud_refresh_tick_usec = Time.get_ticks_usec()
	if hud.has_method("set_crosshair_state"):
		hud.set_crosshair_state(_build_crosshair_state())
	if hud.has_method("set_fps_overlay_visible"):
		hud.set_fps_overlay_visible(_fps_overlay_visible)
	_last_hud_refresh_tick_usec = Time.get_ticks_usec()
	_record_hud_refresh_sample(Time.get_ticks_usec() - refresh_started_usec)

func get_world_config():
	return _world_config

func get_world_data() -> Dictionary:
	return _world_data

func get_chunk_streamer():
	return _chunk_streamer

func get_chunk_renderer():
	return chunk_renderer

func get_pedestrian_runtime_snapshot() -> Dictionary:
	if chunk_renderer == null or not chunk_renderer.has_method("get_pedestrian_runtime_snapshot"):
		return {}
	return chunk_renderer.get_pedestrian_runtime_snapshot()

func get_vehicle_runtime_snapshot() -> Dictionary:
	if chunk_renderer == null or not chunk_renderer.has_method("get_vehicle_runtime_snapshot"):
		return {}
	return chunk_renderer.get_vehicle_runtime_snapshot()

func get_navigation_runtime():
	return _navigation_runtime

func is_player_driving_vehicle() -> bool:
	return player != null and player.has_method("is_driving_vehicle") and bool(player.is_driving_vehicle())

func get_player_vehicle_state() -> Dictionary:
	if player == null or not player.has_method("get_driving_vehicle_state"):
		return {}
	return player.get_driving_vehicle_state()

func fire_player_projectile() -> Node3D:
	if player == null or not player.has_method("get_projectile_spawn_transform") or not player.has_method("get_projectile_direction"):
		return null
	var spawn_transform: Transform3D = player.get_projectile_spawn_transform()
	return _spawn_projectile(spawn_transform.origin, player.get_projectile_direction())

func fire_player_projectile_toward(target_world_position: Vector3) -> Node3D:
	if player == null or not player.has_method("get_projectile_spawn_transform"):
		return null
	var spawn_transform: Transform3D = player.get_projectile_spawn_transform()
	var direction := (target_world_position - spawn_transform.origin).normalized()
	if direction.length_squared() <= 0.0001:
		direction = player.get_projectile_direction() if player.has_method("get_projectile_direction") else -spawn_transform.basis.z
	return _spawn_projectile(spawn_transform.origin, direction)

func get_active_projectile_count() -> int:
	return 0 if _projectile_root == null else _projectile_root.get_child_count()

func get_active_grenade_count() -> int:
	return 0 if _grenade_root == null else _grenade_root.get_child_count()

func get_active_enemy_projectile_count() -> int:
	return 0 if _enemy_projectile_root == null else _enemy_projectile_root.get_child_count()

func throw_player_grenade() -> Node3D:
	if player == null or not player.has_method("get_grenade_spawn_transform") or not player.has_method("get_grenade_launch_velocity"):
		return null
	var spawn_transform: Transform3D = player.get_grenade_spawn_transform()
	return _spawn_grenade(spawn_transform.origin, player.get_grenade_launch_velocity())

func spawn_trauma_enemy() -> CharacterBody3D:
	var spawn_position := _resolve_enemy_spawn_world_position(_get_active_anchor_position())
	return spawn_trauma_enemy_at_world_position(spawn_position)

func spawn_trauma_enemy_at_world_position(world_position: Vector3) -> CharacterBody3D:
	_ensure_combat_roots()
	if _enemy_root == null:
		return null
	var enemy := CityTraumaEnemy.new()
	if enemy.has_method("configure"):
		enemy.configure(player)
	_connect_enemy_combat(enemy)
	var standing_height := enemy.get_standing_height() if enemy.has_method("get_standing_height") else 1.0
	var grounded_position := _resolve_nearby_enemy_spawn_world_position(world_position, standing_height)
	_enemy_root.add_child(enemy)
	enemy.global_position = grounded_position
	return enemy

func get_active_enemy_count() -> int:
	if _enemy_root == null:
		return 0
	var active_count := 0
	for child in _enemy_root.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if child.has_method("is_combat_active"):
			if child.is_combat_active():
				active_count += 1
			continue
		active_count += 1
	return active_count

func get_control_mode() -> String:
	return _control_mode

func set_control_mode(mode: String) -> void:
	if mode != CONTROL_MODE_PLAYER and mode != CONTROL_MODE_INSPECTION:
		return
	_control_mode = mode
	if player != null and player.has_method("set_control_enabled"):
		player.set_control_enabled(true)
	if player != null and player.has_method("set_speed_profile"):
		player.set_speed_profile(mode)
	_set_camera_current(player.get_node_or_null("CameraRig/Camera3D"), true)
	_refresh_hud_status({}, true)

func set_pedestrians_visible(is_visible: bool) -> void:
	_pedestrians_visible = is_visible
	if chunk_renderer != null and chunk_renderer.has_method("set_pedestrians_visible"):
		chunk_renderer.set_pedestrians_visible(is_visible)
	_refresh_hud_status({}, true)

func toggle_pedestrians_visible() -> void:
	set_pedestrians_visible(not _pedestrians_visible)

func are_pedestrians_visible() -> bool:
	if chunk_renderer != null and chunk_renderer.has_method("are_pedestrians_visible"):
		return bool(chunk_renderer.are_pedestrians_visible())
	return _pedestrians_visible

func set_fps_overlay_visible(is_visible: bool) -> void:
	_fps_overlay_visible = is_visible
	if hud != null and hud.has_method("set_fps_overlay_visible"):
		hud.set_fps_overlay_visible(is_visible)
	if hud != null and hud.has_method("set_fps_overlay_sample"):
		hud.set_fps_overlay_sample(_last_fps_sample)
	_refresh_hud_status({}, true)

func toggle_fps_overlay() -> void:
	set_fps_overlay_visible(not _fps_overlay_visible)

func is_fps_overlay_visible() -> bool:
	return _fps_overlay_visible

func get_streaming_snapshot() -> Dictionary:
	if _chunk_streamer == null:
		return {}
	var snapshot: Dictionary = _chunk_streamer.get_streaming_snapshot()
	if chunk_renderer != null and chunk_renderer.has_method("get_renderer_stats"):
		snapshot.merge(chunk_renderer.get_renderer_stats(), true)
	snapshot["control_mode"] = _control_mode
	snapshot["tracked_position"] = _vector3_to_dict(player.global_position if player != null else Vector3.ZERO)
	snapshot["pedestrian_visible"] = are_pedestrians_visible()
	snapshot["fps_overlay_visible"] = _fps_overlay_visible
	snapshot["pedestrian_mode"] = str(snapshot.get("pedestrian_mode", (snapshot.get("pedestrian_budget_contract", {}) as Dictionary).get("preset", "lite")))
	snapshot["vehicle_mode"] = str(snapshot.get("vehicle_mode", "lite"))
	snapshot["ped_tier0_count"] = int(snapshot.get("pedestrian_tier0_total", snapshot.get("ped_tier0_count", 0)))
	snapshot["ped_tier1_count"] = int(snapshot.get("pedestrian_tier1_total", snapshot.get("ped_tier1_count", 0)))
	snapshot["ped_tier2_count"] = int(snapshot.get("pedestrian_tier2_total", snapshot.get("ped_tier2_count", 0)))
	snapshot["ped_tier3_count"] = int(snapshot.get("pedestrian_tier3_total", snapshot.get("ped_tier3_count", 0)))
	snapshot["ped_page_cache_hit_count"] = int(snapshot.get("pedestrian_page_cache_hit_count", 0))
	snapshot["ped_page_cache_miss_count"] = int(snapshot.get("pedestrian_page_cache_miss_count", 0))
	snapshot["ped_duplicate_page_load_count"] = int(snapshot.get("pedestrian_duplicate_page_load_count", 0))
	snapshot["veh_tier0_count"] = int(snapshot.get("vehicle_tier0_total", snapshot.get("veh_tier0_count", 0)))
	snapshot["veh_tier1_count"] = int(snapshot.get("vehicle_tier1_total", snapshot.get("veh_tier1_count", 0)))
	snapshot["veh_tier2_count"] = int(snapshot.get("vehicle_tier2_total", snapshot.get("veh_tier2_count", 0)))
	snapshot["veh_tier3_count"] = int(snapshot.get("vehicle_tier3_total", snapshot.get("veh_tier3_count", 0)))
	snapshot["veh_page_cache_hit_count"] = int(snapshot.get("vehicle_page_cache_hit_count", 0))
	snapshot["veh_page_cache_miss_count"] = int(snapshot.get("vehicle_page_cache_miss_count", 0))
	snapshot["veh_duplicate_page_load_count"] = int(snapshot.get("vehicle_duplicate_page_load_count", 0))
	var current_chunk_id := str(snapshot.get("current_chunk_id", ""))
	if current_chunk_id != "" and chunk_renderer != null and chunk_renderer.has_method("get_chunk_scene_stats"):
		var current_chunk_stats: Dictionary = chunk_renderer.get_chunk_scene_stats(current_chunk_id)
		snapshot["current_chunk_multimesh_instance_count"] = int(current_chunk_stats.get("multimesh_instance_count", 0))
		snapshot["current_chunk_lod_mode"] = str(current_chunk_stats.get("lod_mode", ""))
		snapshot["current_chunk_visual_variant_id"] = str(current_chunk_stats.get("visual_variant_id", ""))
	return snapshot

func _build_hud_snapshot(collapsed: bool = false) -> Dictionary:
	if not collapsed:
		return get_streaming_snapshot()
	var snapshot: Dictionary = _chunk_streamer.get_streaming_snapshot() if _chunk_streamer != null else {}
	snapshot["control_mode"] = _control_mode
	snapshot["tracked_position"] = _vector3_to_dict(player.global_position if player != null else Vector3.ZERO)
	snapshot["pedestrian_visible"] = are_pedestrians_visible()
	snapshot["fps_overlay_visible"] = _fps_overlay_visible
	if chunk_renderer != null:
		if chunk_renderer.has_method("get_streaming_budget_stats"):
			snapshot.merge(chunk_renderer.get_streaming_budget_stats(), true)
		if chunk_renderer.has_method("get_streaming_profile_stats"):
			var streaming_profile: Dictionary = chunk_renderer.get_streaming_profile_stats()
			snapshot["crowd_update_avg_usec"] = int(streaming_profile.get("crowd_update_avg_usec", 0))
			snapshot["crowd_spawn_avg_usec"] = int(streaming_profile.get("crowd_spawn_avg_usec", 0))
			snapshot["crowd_render_commit_avg_usec"] = int(streaming_profile.get("crowd_render_commit_avg_usec", 0))
			snapshot["crowd_active_state_count"] = int(streaming_profile.get("crowd_active_state_count", 0))
			snapshot["crowd_step_usec"] = int(streaming_profile.get("crowd_step_usec", 0))
			snapshot["crowd_reaction_usec"] = int(streaming_profile.get("crowd_reaction_usec", 0))
			snapshot["crowd_rank_usec"] = int(streaming_profile.get("crowd_rank_usec", 0))
			snapshot["crowd_snapshot_rebuild_usec"] = int(streaming_profile.get("crowd_snapshot_rebuild_usec", 0))
			snapshot["crowd_farfield_count"] = int(streaming_profile.get("crowd_farfield_count", 0))
			snapshot["crowd_midfield_count"] = int(streaming_profile.get("crowd_midfield_count", 0))
			snapshot["crowd_nearfield_count"] = int(streaming_profile.get("crowd_nearfield_count", 0))
			snapshot["crowd_farfield_step_usec"] = int(streaming_profile.get("crowd_farfield_step_usec", 0))
			snapshot["crowd_midfield_step_usec"] = int(streaming_profile.get("crowd_midfield_step_usec", 0))
			snapshot["crowd_nearfield_step_usec"] = int(streaming_profile.get("crowd_nearfield_step_usec", 0))
			snapshot["crowd_assignment_rebuild_usec"] = int(streaming_profile.get("crowd_assignment_rebuild_usec", 0))
			snapshot["crowd_assignment_candidate_count"] = int(streaming_profile.get("crowd_assignment_candidate_count", 0))
			snapshot["crowd_threat_broadcast_usec"] = int(streaming_profile.get("crowd_threat_broadcast_usec", 0))
			snapshot["crowd_threat_candidate_count"] = int(streaming_profile.get("crowd_threat_candidate_count", 0))
			snapshot["crowd_chunk_commit_usec"] = int(streaming_profile.get("crowd_chunk_commit_usec", 0))
			snapshot["crowd_tier1_transform_writes"] = int(streaming_profile.get("crowd_tier1_transform_writes", 0))
			snapshot["traffic_update_avg_usec"] = int(streaming_profile.get("traffic_update_avg_usec", 0))
			snapshot["traffic_spawn_avg_usec"] = int(streaming_profile.get("traffic_spawn_avg_usec", 0))
			snapshot["traffic_render_commit_avg_usec"] = int(streaming_profile.get("traffic_render_commit_avg_usec", 0))
			snapshot["traffic_active_state_count"] = int(streaming_profile.get("traffic_active_state_count", 0))
			snapshot["traffic_step_usec"] = int(streaming_profile.get("traffic_step_usec", 0))
			snapshot["traffic_rank_usec"] = int(streaming_profile.get("traffic_rank_usec", 0))
			snapshot["traffic_snapshot_rebuild_usec"] = int(streaming_profile.get("traffic_snapshot_rebuild_usec", 0))
			snapshot["traffic_tier1_count"] = int(streaming_profile.get("traffic_tier1_count", 0))
			snapshot["traffic_tier2_count"] = int(streaming_profile.get("traffic_tier2_count", 0))
			snapshot["traffic_tier3_count"] = int(streaming_profile.get("traffic_tier3_count", 0))
			snapshot["traffic_chunk_commit_usec"] = int(streaming_profile.get("traffic_chunk_commit_usec", 0))
			snapshot["traffic_tier1_transform_writes"] = int(streaming_profile.get("traffic_tier1_transform_writes", 0))
		if chunk_renderer.has_method("get_pedestrian_runtime_summary"):
			snapshot.merge(chunk_renderer.get_pedestrian_runtime_summary(), true)
		if chunk_renderer.has_method("get_vehicle_runtime_summary"):
			snapshot.merge(chunk_renderer.get_vehicle_runtime_summary(), true)
	return snapshot

func _prewarm_actor_pages_around_spawn() -> void:
	if _chunk_streamer == null or chunk_renderer == null or not chunk_renderer.has_method("prewarm_actor_pages"):
		return
	var active_entries: Array = _chunk_streamer.get_active_chunk_entries()
	if active_entries.is_empty():
		return
	var min_key := Vector2i(2147483647, 2147483647)
	var max_key := Vector2i(-2147483648, -2147483648)
	for entry_variant in active_entries:
		var entry: Dictionary = entry_variant
		var chunk_key: Vector2i = entry.get("chunk_key", Vector2i.ZERO)
		min_key.x = mini(min_key.x, chunk_key.x)
		min_key.y = mini(min_key.y, chunk_key.y)
		max_key.x = maxi(max_key.x, chunk_key.x)
		max_key.y = maxi(max_key.y, chunk_key.y)
	var prewarm_entries: Array[Dictionary] = []
	for chunk_x in range(min_key.x - ACTOR_PAGE_PREWARM_RING_RADIUS_CHUNKS, max_key.x + ACTOR_PAGE_PREWARM_RING_RADIUS_CHUNKS + 1):
		for chunk_y in range(min_key.y - ACTOR_PAGE_PREWARM_RING_RADIUS_CHUNKS, max_key.y + ACTOR_PAGE_PREWARM_RING_RADIUS_CHUNKS + 1):
			var chunk_key := Vector2i(chunk_x, chunk_y)
			prewarm_entries.append({
				"chunk_key": chunk_key,
				"chunk_id": _world_config.format_chunk_id(chunk_key),
			})
	chunk_renderer.prewarm_actor_pages(prewarm_entries)
	if chunk_renderer.has_method("prewarm_chunk_pages"):
		var page_prewarm_entries: Array[Dictionary] = []
		for chunk_x in range(min_key.x - CHUNK_PAGE_PREWARM_RING_RADIUS_CHUNKS, max_key.x + CHUNK_PAGE_PREWARM_RING_RADIUS_CHUNKS + 1):
			for chunk_y in range(min_key.y - CHUNK_PAGE_PREWARM_RING_RADIUS_CHUNKS, max_key.y + CHUNK_PAGE_PREWARM_RING_RADIUS_CHUNKS + 1):
				var page_chunk_key := Vector2i(chunk_x, chunk_y)
				page_prewarm_entries.append({
					"chunk_key": page_chunk_key,
					"chunk_id": _world_config.format_chunk_id(page_chunk_key),
				})
		chunk_renderer.prewarm_chunk_pages(page_prewarm_entries, false, true)

func _ensure_combat_roots() -> void:
	if _combat_root == null:
		_combat_root = get_node_or_null("CombatRoot") as Node3D
		if _combat_root == null:
			_combat_root = Node3D.new()
			_combat_root.name = "CombatRoot"
			add_child(_combat_root)
	if _projectile_root == null:
		_projectile_root = _combat_root.get_node_or_null("Projectiles") as Node3D
		if _projectile_root == null:
			_projectile_root = Node3D.new()
			_projectile_root.name = "Projectiles"
			_combat_root.add_child(_projectile_root)
	if _grenade_root == null:
		_grenade_root = _combat_root.get_node_or_null("Grenades") as Node3D
		if _grenade_root == null:
			_grenade_root = Node3D.new()
			_grenade_root.name = "Grenades"
			_combat_root.add_child(_grenade_root)
	if _enemy_projectile_root == null:
		_enemy_projectile_root = _combat_root.get_node_or_null("EnemyProjectiles") as Node3D
		if _enemy_projectile_root == null:
			_enemy_projectile_root = Node3D.new()
			_enemy_projectile_root.name = "EnemyProjectiles"
			_combat_root.add_child(_enemy_projectile_root)
	if _enemy_root == null:
		_enemy_root = _combat_root.get_node_or_null("Enemies") as Node3D
		if _enemy_root == null:
			_enemy_root = Node3D.new()
			_enemy_root.name = "Enemies"
			_combat_root.add_child(_enemy_root)

func _connect_player_combat() -> void:
	if player == null:
		return
	if player.has_signal("primary_fire_requested"):
		var primary_fire_callable := Callable(self, "_on_player_primary_fire_requested")
		if not player.primary_fire_requested.is_connected(primary_fire_callable):
			player.primary_fire_requested.connect(primary_fire_callable)
	if player.has_signal("grenade_throw_requested"):
		var grenade_throw_callable := Callable(self, "_on_player_grenade_throw_requested")
		if not player.grenade_throw_requested.is_connected(grenade_throw_callable):
			player.grenade_throw_requested.connect(grenade_throw_callable)

func _on_player_primary_fire_requested() -> void:
	fire_player_projectile()

func _on_player_grenade_throw_requested() -> void:
	throw_player_grenade()

func _spawn_projectile(origin: Vector3, direction: Vector3) -> Node3D:
	_ensure_combat_roots()
	if _projectile_root == null:
		return
	var projectile := CityProjectile.new()
	projectile.configure(
		origin,
		direction,
		player,
		1.0,
		"city_projectile",
		"city_enemy",
		Color(0.65098, 0.85098, 1.0, 1.0),
		Color(0.360784, 0.713725, 1.0, 1.0),
		chunk_renderer if chunk_renderer != null and chunk_renderer.has_method("resolve_projectile_hit") else null,
		chunk_renderer if chunk_renderer != null and chunk_renderer.has_method("resolve_vehicle_projectile_hit") else null
	)
	_projectile_root.add_child(projectile)
	if chunk_renderer != null and chunk_renderer.has_method("notify_projectile_event"):
		chunk_renderer.notify_projectile_event(origin, direction, projectile.max_distance_m if projectile != null else 36.0)
	return projectile

func _spawn_grenade(origin: Vector3, launch_velocity: Vector3) -> Node3D:
	_ensure_combat_roots()
	if _grenade_root == null:
		return null
	var grenade := CityGrenade.new()
	grenade.configure(origin, launch_velocity, player, player)
	if grenade.has_signal("exploded"):
		grenade.exploded.connect(_on_player_grenade_exploded)
	_grenade_root.add_child(grenade)
	return grenade

func _on_player_grenade_exploded(world_position: Vector3, radius_m: float) -> void:
	if chunk_renderer != null and chunk_renderer.has_method("resolve_explosion_impact"):
		chunk_renderer.resolve_explosion_impact(world_position, maxf(radius_m * 0.35, 4.0), radius_m)
	if chunk_renderer != null and chunk_renderer.has_method("resolve_vehicle_explosion"):
		chunk_renderer.resolve_vehicle_explosion(world_position, radius_m)

func resolve_pedestrian_explosion(world_position: Vector3, lethal_radius_m: float, threat_radius_m: float = -1.0) -> Dictionary:
	if chunk_renderer == null or not chunk_renderer.has_method("resolve_explosion_impact"):
		return {}
	return chunk_renderer.resolve_explosion_impact(world_position, lethal_radius_m, threat_radius_m)

func resolve_vehicle_projectile_hit(start_position: Vector3, end_position: Vector3, damage: float = 1.0, velocity: Vector3 = Vector3.ZERO) -> Dictionary:
	if chunk_renderer == null or not chunk_renderer.has_method("resolve_vehicle_projectile_hit"):
		return {}
	return chunk_renderer.resolve_vehicle_projectile_hit(start_position, end_position, damage, velocity)

func resolve_vehicle_explosion(world_position: Vector3, radius_m: float) -> Dictionary:
	if chunk_renderer == null or not chunk_renderer.has_method("resolve_vehicle_explosion"):
		return {}
	return chunk_renderer.resolve_vehicle_explosion(world_position, radius_m)

func resolve_player_vehicle_pedestrian_impact() -> Dictionary:
	if not _pending_player_vehicle_impact_result.is_empty():
		var cached_result := _pending_player_vehicle_impact_result.duplicate(true)
		_pending_player_vehicle_impact_result.clear()
		return cached_result
	return _resolve_player_vehicle_pedestrian_impact_impl()

func find_hijackable_vehicle_candidate(max_distance_m: float = 6.5) -> Dictionary:
	if chunk_renderer == null or not chunk_renderer.has_method("find_hijackable_vehicle_candidate"):
		return {}
	return chunk_renderer.find_hijackable_vehicle_candidate(_get_active_anchor_position(), max_distance_m)

func handle_vehicle_interaction(max_distance_m: float = 6.5, abandoned_vehicle_lifetime_sec: float = ABANDONED_HIJACK_VEHICLE_LIFETIME_SEC) -> Dictionary:
	if player != null and player.has_method("is_driving_vehicle") and bool(player.is_driving_vehicle()):
		return try_exit_player_vehicle(abandoned_vehicle_lifetime_sec)
	var abandoned_candidate := _find_abandoned_vehicle_candidate(_get_active_anchor_position(), max_distance_m)
	if not abandoned_candidate.is_empty():
		return try_reenter_abandoned_vehicle(str(abandoned_candidate.get("vehicle_id", "")))
	return try_hijack_nearby_vehicle(max_distance_m)

func try_hijack_nearby_vehicle(max_distance_m: float = 6.5) -> Dictionary:
	if player == null or chunk_renderer == null:
		return {
			"success": false,
		}
	if player.has_method("is_driving_vehicle") and bool(player.is_driving_vehicle()):
		return {
			"success": false,
		}
	if not chunk_renderer.has_method("find_hijackable_vehicle_candidate") or not chunk_renderer.has_method("claim_vehicle_for_player"):
		return {
			"success": false,
		}
	var candidate: Dictionary = chunk_renderer.find_hijackable_vehicle_candidate(_get_active_anchor_position(), max_distance_m)
	if candidate.is_empty():
		return {
			"success": false,
		}
	var hijack_result: Dictionary = chunk_renderer.claim_vehicle_for_player(str(candidate.get("vehicle_id", "")))
	if hijack_result.is_empty():
		return {
			"success": false,
		}
	if player.has_method("enter_vehicle_drive_mode"):
		player.enter_vehicle_drive_mode(hijack_result)
	update_streaming_for_position(_get_active_anchor_position(), 0.0)
	_refresh_hud_status({}, true)
	hijack_result["success"] = true
	return hijack_result

func try_exit_player_vehicle(abandoned_vehicle_lifetime_sec: float = ABANDONED_HIJACK_VEHICLE_LIFETIME_SEC) -> Dictionary:
	if player == null or not player.has_method("is_driving_vehicle") or not bool(player.is_driving_vehicle()):
		return {
			"success": false,
		}
	if not player.has_method("exit_vehicle_drive_mode"):
		return {
			"success": false,
		}
	var exit_result: Dictionary = player.exit_vehicle_drive_mode()
	if exit_result.is_empty():
		return {
			"success": false,
		}
	var abandoned_spawned := _spawn_abandoned_vehicle_visual(exit_result, abandoned_vehicle_lifetime_sec)
	update_streaming_for_position(_get_active_anchor_position(), 0.0)
	_refresh_hud_status({}, true)
	exit_result["success"] = true
	exit_result["abandoned_vehicle_spawned"] = abandoned_spawned
	return exit_result

func try_reenter_abandoned_vehicle(vehicle_id: String) -> Dictionary:
	if player == null or vehicle_id.is_empty():
		return {
			"success": false,
		}
	if not player.has_method("enter_vehicle_drive_mode"):
		return {
			"success": false,
		}
	_prune_abandoned_vehicle_visuals()
	for entry_index in range(_abandoned_vehicle_visuals.size()):
		var entry: Dictionary = _abandoned_vehicle_visuals[entry_index]
		if str(entry.get("vehicle_id", "")) != vehicle_id:
			continue
		var vehicle_state: Dictionary = (entry.get("vehicle_state", {}) as Dictionary).duplicate(true)
		_free_abandoned_vehicle_visual(entry)
		_abandoned_vehicle_visuals.remove_at(entry_index)
		player.enter_vehicle_drive_mode(vehicle_state)
		update_streaming_for_position(_get_active_anchor_position(), 0.0)
		_refresh_hud_status({}, true)
		vehicle_state["success"] = true
		vehicle_state["reentered"] = true
		return vehicle_state
	return {
		"success": false,
	}

func get_abandoned_vehicle_visual_count() -> int:
	_prune_abandoned_vehicle_visuals()
	return _abandoned_vehicle_visuals.size()

func _spawn_abandoned_vehicle_visual(vehicle_state: Dictionary, lifetime_sec: float) -> bool:
	_ensure_abandoned_vehicle_visual_root()
	if _abandoned_vehicle_visual_root == null:
		return false
	var model_root := _instantiate_vehicle_visual_model(vehicle_state)
	if model_root == null:
		return false
	var vehicle_root := Node3D.new()
	vehicle_root.name = "AbandonedHijackedVehicle"
	var world_position: Vector3 = vehicle_state.get("world_position", Vector3.ZERO)
	var heading: Vector3 = vehicle_state.get("heading", Vector3.FORWARD)
	heading.y = 0.0
	if heading.length_squared() <= 0.0001:
		heading = Vector3.FORWARD
	vehicle_root.position = world_position
	vehicle_root.rotation.y = _yaw_from_vehicle_heading(heading.normalized()) + PI
	vehicle_root.add_child(model_root)
	_abandoned_vehicle_visual_root.add_child(vehicle_root)
	_remove_abandoned_vehicle_visual(str(vehicle_state.get("vehicle_id", "")))
	_prune_abandoned_vehicle_visuals()
	_abandoned_vehicle_visuals.append({
		"vehicle_id": str(vehicle_state.get("vehicle_id", "")),
		"vehicle_state": vehicle_state.duplicate(true),
		"visual_root": vehicle_root,
		"remaining_sec": maxf(lifetime_sec, 0.1),
	})
	return true

func _ensure_abandoned_vehicle_visual_root() -> void:
	if _abandoned_vehicle_visual_root != null and is_instance_valid(_abandoned_vehicle_visual_root):
		return
	var root := Node3D.new()
	root.name = "AbandonedHijackedVehicles"
	add_child(root)
	_abandoned_vehicle_visual_root = root

func _instantiate_vehicle_visual_model(vehicle_state: Dictionary) -> Node3D:
	if _vehicle_visual_catalog == null:
		_vehicle_visual_catalog = CityVehicleVisualCatalog.new()
	var model_id := str(vehicle_state.get("model_id", ""))
	var entry := _vehicle_visual_catalog.get_entry(model_id)
	if entry.is_empty():
		entry = _vehicle_visual_catalog.select_entry_for_state(vehicle_state)
	if entry.is_empty():
		return null
	var model_root := _vehicle_visual_catalog.instantiate_scene_for_entry(entry)
	if model_root == null:
		return null
	var runtime_scale := _vehicle_visual_catalog.resolve_runtime_scale(entry)
	model_root.scale = Vector3.ONE * runtime_scale
	model_root.position = Vector3(0.0, _vehicle_visual_catalog.resolve_ground_offset_m(entry) * runtime_scale, 0.0)
	return model_root

func _yaw_from_vehicle_heading(heading: Vector3) -> float:
	return atan2(-heading.x, -heading.z)

func _prune_abandoned_vehicle_visuals() -> void:
	var survivors: Array = []
	for entry_variant in _abandoned_vehicle_visuals:
		var entry: Dictionary = entry_variant
		var visual_root = entry.get("visual_root", null)
		if visual_root != null and is_instance_valid(visual_root):
			survivors.append(entry)
	_abandoned_vehicle_visuals = survivors

func _resolve_player_vehicle_pedestrian_impact_impl() -> Dictionary:
	if player == null or not player.has_method("is_driving_vehicle") or not bool(player.is_driving_vehicle()):
		return {}
	if chunk_renderer == null or not chunk_renderer.has_method("resolve_player_vehicle_pedestrian_impact"):
		return {}
	var vehicle_state := get_player_vehicle_state()
	if vehicle_state.is_empty():
		return {}
	var impact_result: Dictionary = chunk_renderer.resolve_player_vehicle_pedestrian_impact(vehicle_state)
	if impact_result.is_empty():
		return {}
	var speed_after_mps := float(vehicle_state.get("speed_mps", 0.0))
	if player.has_method("apply_vehicle_impact_slowdown"):
		speed_after_mps = float(player.apply_vehicle_impact_slowdown())
	if player.has_method("trigger_camera_shake"):
		player.trigger_camera_shake(
			float(player.get("vehicle_impact_camera_shake_duration_sec")),
			float(player.get("vehicle_impact_camera_shake_amplitude_m"))
		)
	impact_result["vehicle_speed_after_mps"] = speed_after_mps
	return impact_result

func _update_abandoned_vehicle_visuals(delta: float) -> void:
	if _abandoned_vehicle_visuals.is_empty():
		return
	var survivors: Array = []
	for entry_variant in _abandoned_vehicle_visuals:
		var entry: Dictionary = entry_variant
		var visual_root = entry.get("visual_root", null)
		if visual_root == null or not is_instance_valid(visual_root):
			continue
		var remaining_sec := maxf(float(entry.get("remaining_sec", 0.0)) - maxf(delta, 0.0), 0.0)
		if remaining_sec <= 0.0:
			_free_abandoned_vehicle_visual(entry)
			continue
		entry["remaining_sec"] = remaining_sec
		survivors.append(entry)
	_abandoned_vehicle_visuals = survivors

func _remove_abandoned_vehicle_visual(vehicle_id: String) -> void:
	if vehicle_id.is_empty():
		return
	var survivors: Array = []
	for entry_variant in _abandoned_vehicle_visuals:
		var entry: Dictionary = entry_variant
		if str(entry.get("vehicle_id", "")) == vehicle_id:
			_free_abandoned_vehicle_visual(entry)
			continue
		var visual_root = entry.get("visual_root", null)
		if visual_root != null and is_instance_valid(visual_root):
			survivors.append(entry)
	_abandoned_vehicle_visuals = survivors

func _find_abandoned_vehicle_candidate(player_position: Vector3, max_distance_m: float = 6.5) -> Dictionary:
	_prune_abandoned_vehicle_visuals()
	var best_candidate := {}
	var best_distance_m := max_distance_m
	for entry_variant in _abandoned_vehicle_visuals:
		var entry: Dictionary = entry_variant
		var vehicle_state: Dictionary = entry.get("vehicle_state", {})
		if vehicle_state.is_empty():
			continue
		var distance_m := player_position.distance_to(vehicle_state.get("world_position", Vector3.ZERO))
		if distance_m > best_distance_m:
			continue
		best_distance_m = distance_m
		best_candidate = vehicle_state.duplicate(true)
		best_candidate["distance_m"] = distance_m
		best_candidate["remaining_sec"] = float(entry.get("remaining_sec", 0.0))
	if best_candidate.is_empty():
		return {}
	return best_candidate

func _free_abandoned_vehicle_visual(entry: Dictionary) -> void:
	var visual_root = entry.get("visual_root", null)
	if visual_root != null and is_instance_valid(visual_root):
		visual_root.queue_free()

func _connect_enemy_combat(enemy: Node) -> void:
	if enemy == null or not enemy.has_signal("projectile_fire_requested"):
		return
	var callable := Callable(self, "_on_enemy_projectile_fire_requested")
	if not enemy.projectile_fire_requested.is_connected(callable):
		enemy.projectile_fire_requested.connect(callable)

func _on_enemy_projectile_fire_requested(origin: Vector3, direction: Vector3) -> void:
	_spawn_enemy_projectile(origin, direction)

func _spawn_enemy_projectile(origin: Vector3, direction: Vector3) -> Node3D:
	_ensure_combat_roots()
	if _enemy_projectile_root == null:
		return null
	var projectile := CityProjectile.new()
	projectile.speed_mps = 120.0
	projectile.max_distance_m = 240.0
	projectile.max_lifetime_sec = 2.4
	projectile.configure(
		origin,
		direction,
		null,
		1.0,
		"city_enemy_projectile",
		"city_player",
		Color(1.0, 0.403922, 0.360784, 1.0),
		Color(1.0, 0.25098, 0.188235, 1.0)
	)
	_enemy_projectile_root.add_child(projectile)
	return projectile

func update_streaming_for_position(world_position: Vector3, delta: float = 0.0) -> Array:
	var started_usec := Time.get_ticks_usec()
	if _chunk_streamer == null:
		return []
	var events: Array = _chunk_streamer.update_for_world_position(world_position)
	if chunk_renderer != null and chunk_renderer.has_method("sync_streaming"):
		chunk_renderer.sync_streaming(
			_chunk_streamer.get_active_chunk_entries(),
			world_position,
			delta,
			_build_pedestrian_player_context()
		)
	var is_headless := DisplayServer.get_name() == "headless"
	var hud_debug_expanded := hud != null and hud.has_method("is_debug_expanded") and bool(hud.is_debug_expanded())
	var debug_expanded := debug_overlay != null and debug_overlay.has_method("is_expanded") and bool(debug_overlay.is_expanded())
	var should_refresh_hud := _should_refresh_hud()
	var allow_headless_hud_refresh := should_refresh_hud and (
		not is_headless
		or (not _has_streaming_backpressure() and _update_streaming_sample_count == 0)
	)
	var needs_snapshot := debug_expanded or (allow_headless_hud_refresh and not is_headless)
	var hud_snapshot := {}
	if needs_snapshot:
		hud_snapshot = _build_hud_snapshot(not hud_debug_expanded and not debug_expanded)
	if debug_overlay != null:
		if needs_snapshot and debug_overlay.has_method("set_snapshot"):
			debug_overlay.set_snapshot(hud_snapshot)
		debug_overlay.visible = debug_expanded
	if allow_headless_hud_refresh:
		_refresh_hud_status(hud_snapshot, true)
	_record_update_streaming_sample(Time.get_ticks_usec() - started_usec)
	return events

func plan_macro_route(start_position: Vector3, goal_position: Vector3) -> Array:
	if _navigation_runtime == null:
		return []
	return _navigation_runtime.plan_route(start_position, goal_position)

func build_runtime_report(subject_position = null) -> Dictionary:
	var snapshot: Dictionary = get_streaming_snapshot()
	var resolved_position := _get_active_anchor_position()
	if subject_position is Vector3:
		resolved_position = subject_position
	var transition_count := 0
	if _chunk_streamer != null:
		transition_count = _chunk_streamer.get_transition_log().size()
	return {
		"control_mode": _control_mode,
		"current_chunk_id": str(snapshot.get("current_chunk_id", "")),
		"active_chunk_count": int(snapshot.get("active_chunk_count", 0)),
		"last_prepare_usec": int(snapshot.get("last_prepare_usec", 0)),
		"last_mount_usec": int(snapshot.get("last_mount_usec", 0)),
		"last_retire_usec": int(snapshot.get("last_retire_usec", 0)),
		"transition_count": transition_count,
		"final_position": _vector3_to_dict(resolved_position),
		"lod_mode_counts": snapshot.get("lod_mode_counts", {}),
		"multimesh_instance_total": int(snapshot.get("multimesh_instance_total", 0)),
	}

func build_minimap_snapshot() -> Dictionary:
	if _minimap_projector == null:
		return {}
	_minimap_request_count += 1
	var center_world_position := _get_minimap_center_world_position(_get_active_anchor_position())
	var player_world_position := player.global_position if player != null else Vector3.ZERO
	var player_heading := player.rotation.y if player != null else 0.0
	var crowd_debug_enabled := _is_minimap_crowd_debug_enabled()
	var cache_key := _build_minimap_cache_key(center_world_position, 1600.0)
	if cache_key == _minimap_cache_key and not _minimap_snapshot_cache.is_empty():
		_minimap_cache_hits += 1
		var cached_snapshot := _minimap_snapshot_cache.duplicate(false)
		cached_snapshot["player_marker"] = _minimap_projector.build_player_marker(center_world_position, player_world_position, player_heading, 1600.0)
		cached_snapshot["route_overlay"] = _build_current_minimap_route_overlay(center_world_position, 1600.0)
		cached_snapshot["crowd_debug_layer"] = _minimap_projector.build_pedestrian_debug_layer(center_world_position, 1600.0, crowd_debug_enabled)
		return cached_snapshot

	_minimap_cache_misses += 1
	_minimap_rebuild_count += 1
	var minimap_started_usec := Time.get_ticks_usec()
	var snapshot: Dictionary = _minimap_projector.build_road_snapshot(center_world_position, 1600.0)
	_minimap_cache_key = cache_key
	_minimap_snapshot_cache = snapshot.duplicate(false)
	_record_minimap_build_sample(Time.get_ticks_usec() - minimap_started_usec)
	snapshot["player_marker"] = _minimap_projector.build_player_marker(center_world_position, player_world_position, player_heading, 1600.0)
	snapshot["route_overlay"] = _build_current_minimap_route_overlay(center_world_position, 1600.0)
	snapshot["crowd_debug_layer"] = _minimap_projector.build_pedestrian_debug_layer(center_world_position, 1600.0, crowd_debug_enabled)
	return snapshot

func build_minimap_route_overlay(start_position: Vector3, goal_position: Vector3) -> Dictionary:
	if _minimap_projector == null:
		return {}
	var route: Array = plan_macro_route(start_position, goal_position)
	_minimap_route_world_positions = [start_position]
	for step in route:
		_minimap_route_world_positions.append((step as Dictionary).get("target_position", goal_position))
	var overlay := _build_current_minimap_route_overlay(_get_minimap_center_world_position(_get_active_anchor_position()), 1600.0)
	if hud != null and hud.has_method("set_minimap_snapshot"):
		hud.set_minimap_snapshot(build_minimap_snapshot())
	return overlay.duplicate(true)

func get_minimap_cache_stats() -> Dictionary:
	return {
		"cache_key": _minimap_cache_key,
		"hit_count": _minimap_cache_hits,
		"miss_count": _minimap_cache_misses,
		"rebuild_count": _minimap_rebuild_count,
	}

func _build_crosshair_state() -> Dictionary:
	var viewport_size := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	)
	if get_viewport() != null:
		var visible_rect := get_viewport().get_visible_rect()
		if visible_rect.size.x > 0.0 and visible_rect.size.y > 0.0:
			viewport_size = visible_rect.size
	if player == null or not player.has_method("get_aim_target_world_position"):
		return {
			"visible": false,
			"screen_position": viewport_size * 0.5,
			"viewport_size": viewport_size,
			"world_target": Vector3.ZERO,
			"aim_down_sights_active": false,
		}
	var camera := player.get_node_or_null("CameraRig/Camera3D") as Camera3D
	var world_target: Vector3 = player.get_aim_target_world_position()
	var screen_position := viewport_size * 0.5
	if camera != null:
		screen_position = camera.unproject_position(world_target)
	var weapon_mode: String = player.get_weapon_mode() if player.has_method("get_weapon_mode") else "rifle"
	var driving_vehicle := player.has_method("is_driving_vehicle") and bool(player.is_driving_vehicle())
	return {
		"visible": weapon_mode != "grenade" and not driving_vehicle,
		"screen_position": screen_position,
		"viewport_size": viewport_size,
		"world_target": world_target,
		"aim_down_sights_active": player.is_aim_down_sights_active() if player.has_method("is_aim_down_sights_active") else false,
	}

func _weapon_status_text() -> String:
	if player == null or not player.has_method("get_weapon_state"):
		return ""
	if player.has_method("is_driving_vehicle") and bool(player.is_driving_vehicle()):
		var driving_state: Dictionary = get_player_vehicle_state()
		return "vehicle=driving model=%s speed=%.1f exit_prompt=F:exit" % [
			str(driving_state.get("model_id", "")),
			float(driving_state.get("speed_mps", 0.0))
		]
	var weapon_state: Dictionary = player.get_weapon_state()
	var mode := str(weapon_state.get("mode", "rifle"))
	var grenade_ready := bool(weapon_state.get("grenade_ready", false))
	var hijack_candidate: Dictionary = find_hijackable_vehicle_candidate()
	var abandoned_candidate := _find_abandoned_vehicle_candidate(_get_active_anchor_position())
	var prompt_text := ""
	if not abandoned_candidate.is_empty():
		prompt_text = " resume_prompt=F:%s" % str(abandoned_candidate.get("model_id", "vehicle"))
	elif not hijack_candidate.is_empty():
		prompt_text = " hijack_prompt=F:%s" % str(hijack_candidate.get("model_id", "vehicle"))
	return "weapon=%s grenade_ready=%s%s" % [mode, str(grenade_ready), prompt_text]

func reset_performance_profile() -> void:
	_update_streaming_sample_count = 0
	_update_streaming_total_usec = 0
	_update_streaming_max_usec = 0
	_update_streaming_last_usec = 0
	_hud_refresh_sample_count = 0
	_hud_refresh_total_usec = 0
	_hud_refresh_max_usec = 0
	_hud_refresh_last_usec = 0
	_last_hud_refresh_tick_usec = -HUD_REFRESH_INTERVAL_USEC
	_last_minimap_hud_refresh_tick_usec = -MINIMAP_HUD_REFRESH_INTERVAL_USEC
	_frame_step_sample_count = 0
	_frame_step_total_usec = 0
	_frame_step_max_usec = 0
	_frame_step_last_usec = 0
	_minimap_request_count = 0
	_minimap_build_total_usec = 0
	_minimap_build_max_usec = 0
	_minimap_build_last_usec = 0
	_minimap_cache_hits = 0
	_minimap_cache_misses = 0
	_minimap_rebuild_count = 0
	if chunk_renderer != null and chunk_renderer.has_method("reset_streaming_profile_stats"):
		chunk_renderer.reset_streaming_profile_stats()

func get_performance_profile() -> Dictionary:
	var streaming_profile: Dictionary = {}
	var renderer_stats: Dictionary = {}
	if chunk_renderer != null and chunk_renderer.has_method("get_streaming_profile_stats"):
		streaming_profile = chunk_renderer.get_streaming_profile_stats()
	if chunk_renderer != null and chunk_renderer.has_method("get_renderer_stats"):
		renderer_stats = chunk_renderer.get_renderer_stats()
	return {
		"world_generation_usec": _world_generation_usec,
		"world_generation_profile": _world_generation_profile.duplicate(true),
		"update_streaming_sample_count": _update_streaming_sample_count,
		"update_streaming_avg_usec": _average_usec(_update_streaming_total_usec, _update_streaming_sample_count),
		"update_streaming_max_usec": _update_streaming_max_usec,
		"update_streaming_last_usec": _update_streaming_last_usec,
		"hud_refresh_sample_count": _hud_refresh_sample_count,
		"hud_refresh_avg_usec": _average_usec(_hud_refresh_total_usec, _hud_refresh_sample_count),
		"hud_refresh_max_usec": _hud_refresh_max_usec,
		"frame_step_sample_count": _frame_step_sample_count,
		"frame_step_avg_usec": _average_usec(_frame_step_total_usec, _frame_step_sample_count),
		"frame_step_max_usec": _frame_step_max_usec,
		"minimap_request_count": _minimap_request_count,
		"minimap_build_avg_usec": _average_usec(_minimap_build_total_usec, _minimap_rebuild_count),
		"minimap_build_max_usec": _minimap_build_max_usec,
		"minimap_cache_hits": _minimap_cache_hits,
		"minimap_cache_misses": _minimap_cache_misses,
		"minimap_rebuild_count": _minimap_rebuild_count,
		"pedestrian_mode": str(renderer_stats.get("pedestrian_mode", "lite")),
		"vehicle_mode": str(renderer_stats.get("vehicle_mode", "lite")),
		"crowd_update_max_usec": int(streaming_profile.get("crowd_update_max_usec", 0)),
		"crowd_update_avg_usec": int(streaming_profile.get("crowd_update_avg_usec", 0)),
		"crowd_update_sample_count": int(streaming_profile.get("crowd_update_sample_count", 0)),
		"crowd_spawn_max_usec": int(streaming_profile.get("crowd_spawn_max_usec", 0)),
		"crowd_spawn_avg_usec": int(streaming_profile.get("crowd_spawn_avg_usec", 0)),
		"crowd_spawn_sample_count": int(streaming_profile.get("crowd_spawn_sample_count", 0)),
		"crowd_render_commit_max_usec": int(streaming_profile.get("crowd_render_commit_max_usec", 0)),
		"crowd_render_commit_avg_usec": int(streaming_profile.get("crowd_render_commit_avg_usec", 0)),
		"crowd_render_commit_sample_count": int(streaming_profile.get("crowd_render_commit_sample_count", 0)),
		"crowd_active_state_count": int(streaming_profile.get("crowd_active_state_count", 0)),
		"crowd_step_usec": int(streaming_profile.get("crowd_step_usec", 0)),
		"crowd_reaction_usec": int(streaming_profile.get("crowd_reaction_usec", 0)),
		"crowd_rank_usec": int(streaming_profile.get("crowd_rank_usec", 0)),
		"crowd_snapshot_rebuild_usec": int(streaming_profile.get("crowd_snapshot_rebuild_usec", 0)),
		"crowd_farfield_count": int(streaming_profile.get("crowd_farfield_count", 0)),
		"crowd_midfield_count": int(streaming_profile.get("crowd_midfield_count", 0)),
		"crowd_nearfield_count": int(streaming_profile.get("crowd_nearfield_count", 0)),
		"crowd_farfield_step_usec": int(streaming_profile.get("crowd_farfield_step_usec", 0)),
		"crowd_midfield_step_usec": int(streaming_profile.get("crowd_midfield_step_usec", 0)),
		"crowd_nearfield_step_usec": int(streaming_profile.get("crowd_nearfield_step_usec", 0)),
		"crowd_assignment_rebuild_usec": int(streaming_profile.get("crowd_assignment_rebuild_usec", 0)),
		"crowd_assignment_candidate_count": int(streaming_profile.get("crowd_assignment_candidate_count", 0)),
		"crowd_threat_broadcast_usec": int(streaming_profile.get("crowd_threat_broadcast_usec", 0)),
		"crowd_threat_candidate_count": int(streaming_profile.get("crowd_threat_candidate_count", 0)),
		"crowd_chunk_commit_usec": int(streaming_profile.get("crowd_chunk_commit_usec", 0)),
		"crowd_tier1_transform_writes": int(streaming_profile.get("crowd_tier1_transform_writes", 0)),
		"ped_tier0_count": int(renderer_stats.get("pedestrian_tier0_total", 0)),
		"ped_tier1_count": int(renderer_stats.get("pedestrian_tier1_total", 0)),
		"ped_tier2_count": int(renderer_stats.get("pedestrian_tier2_total", 0)),
		"ped_tier3_count": int(renderer_stats.get("pedestrian_tier3_total", 0)),
		"ped_page_cache_hit_count": int(renderer_stats.get("pedestrian_page_cache_hit_count", 0)),
		"ped_page_cache_miss_count": int(renderer_stats.get("pedestrian_page_cache_miss_count", 0)),
		"ped_duplicate_page_load_count": int(renderer_stats.get("pedestrian_duplicate_page_load_count", 0)),
		"traffic_update_max_usec": int(streaming_profile.get("traffic_update_max_usec", 0)),
		"traffic_update_avg_usec": int(streaming_profile.get("traffic_update_avg_usec", 0)),
		"traffic_update_sample_count": int(streaming_profile.get("traffic_update_sample_count", 0)),
		"traffic_spawn_max_usec": int(streaming_profile.get("traffic_spawn_max_usec", 0)),
		"traffic_spawn_avg_usec": int(streaming_profile.get("traffic_spawn_avg_usec", 0)),
		"traffic_spawn_sample_count": int(streaming_profile.get("traffic_spawn_sample_count", 0)),
		"traffic_render_commit_max_usec": int(streaming_profile.get("traffic_render_commit_max_usec", 0)),
		"traffic_render_commit_avg_usec": int(streaming_profile.get("traffic_render_commit_avg_usec", 0)),
		"traffic_render_commit_sample_count": int(streaming_profile.get("traffic_render_commit_sample_count", 0)),
		"traffic_active_state_count": int(streaming_profile.get("traffic_active_state_count", 0)),
		"traffic_step_usec": int(streaming_profile.get("traffic_step_usec", 0)),
		"traffic_rank_usec": int(streaming_profile.get("traffic_rank_usec", 0)),
		"traffic_snapshot_rebuild_usec": int(streaming_profile.get("traffic_snapshot_rebuild_usec", 0)),
		"traffic_tier1_count": int(streaming_profile.get("traffic_tier1_count", 0)),
		"traffic_tier2_count": int(streaming_profile.get("traffic_tier2_count", 0)),
		"traffic_tier3_count": int(streaming_profile.get("traffic_tier3_count", 0)),
		"traffic_chunk_commit_usec": int(streaming_profile.get("traffic_chunk_commit_usec", 0)),
		"traffic_tier1_transform_writes": int(streaming_profile.get("traffic_tier1_transform_writes", 0)),
		"veh_tier0_count": int(renderer_stats.get("vehicle_tier0_total", 0)),
		"veh_tier1_count": int(renderer_stats.get("vehicle_tier1_total", 0)),
		"veh_tier2_count": int(renderer_stats.get("vehicle_tier2_total", 0)),
		"veh_tier3_count": int(renderer_stats.get("vehicle_tier3_total", 0)),
		"veh_page_cache_hit_count": int(renderer_stats.get("vehicle_page_cache_hit_count", 0)),
		"veh_page_cache_miss_count": int(renderer_stats.get("vehicle_page_cache_miss_count", 0)),
		"veh_duplicate_page_load_count": int(renderer_stats.get("vehicle_duplicate_page_load_count", 0)),
		"streaming_prepare_profile_max_usec": int(streaming_profile.get("prepare_profile_max_usec", 0)),
		"streaming_prepare_profile_avg_usec": int(streaming_profile.get("prepare_profile_avg_usec", 0)),
		"streaming_prepare_profile_sample_count": int(streaming_profile.get("prepare_profile_sample_count", 0)),
		"streaming_mount_setup_max_usec": int(streaming_profile.get("mount_setup_max_usec", 0)),
		"streaming_mount_setup_avg_usec": int(streaming_profile.get("mount_setup_avg_usec", 0)),
		"streaming_mount_setup_sample_count": int(streaming_profile.get("mount_setup_sample_count", 0)),
		"streaming_terrain_async_dispatch_max_usec": int(streaming_profile.get("terrain_async_dispatch_max_usec", 0)),
		"streaming_terrain_async_dispatch_avg_usec": int(streaming_profile.get("terrain_async_dispatch_avg_usec", 0)),
		"streaming_terrain_async_dispatch_sample_count": int(streaming_profile.get("terrain_async_dispatch_sample_count", 0)),
		"streaming_terrain_async_complete_max_usec": int(streaming_profile.get("terrain_async_complete_max_usec", 0)),
		"streaming_terrain_async_complete_avg_usec": int(streaming_profile.get("terrain_async_complete_avg_usec", 0)),
		"streaming_terrain_async_complete_sample_count": int(streaming_profile.get("terrain_async_complete_sample_count", 0)),
		"streaming_terrain_commit_max_usec": int(streaming_profile.get("terrain_commit_max_usec", 0)),
		"streaming_terrain_commit_avg_usec": int(streaming_profile.get("terrain_commit_avg_usec", 0)),
		"streaming_terrain_commit_sample_count": int(streaming_profile.get("terrain_commit_sample_count", 0)),
	}

func _align_player_to_streamed_ground() -> void:
	if player == null or _world_config == null:
		return
	var initial_anchor := player.global_position
	var chunk_payload := _build_chunk_payload_for_world_position(initial_anchor)
	var profile := CityChunkProfileBuilder.build_profile(chunk_payload)
	var chunk_center: Vector3 = chunk_payload.get("chunk_center", Vector3.ZERO)
	var local_point := _resolve_spawn_local_point(chunk_payload, profile)
	var standing_height := _estimate_player_standing_height()
	var target_position := Vector3(
		chunk_center.x + local_point.x,
		CityChunkGroundSampler.sample_height(local_point, chunk_payload, profile) + standing_height + 0.7,
		chunk_center.z + local_point.y
	)
	if player.has_method("teleport_to_world_position"):
		player.teleport_to_world_position(target_position)
	else:
		player.global_position = target_position

func _resolve_enemy_spawn_world_position(anchor_world_position: Vector3) -> Vector3:
	var forward := -player.global_transform.basis.z if player != null else Vector3.FORWARD
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var right := player.global_transform.basis.x if player != null else Vector3.RIGHT
	right.y = 0.0
	if right.length_squared() <= 0.0001:
		right = Vector3.RIGHT
	right = right.normalized()
	var best_position := _resolve_surface_world_position(anchor_world_position + forward * 40.0, 1.3)
	var best_score := -INF
	var directions: Array[Vector3] = [
		forward,
		(forward + right).normalized(),
		(forward - right).normalized(),
		right,
		-right,
		-forward,
	]
	for radius in [32.0, 38.0, 44.0, 50.0]:
		for direction in directions:
			if direction.length_squared() <= 0.0001:
				continue
			var candidate := _resolve_surface_world_position(anchor_world_position + direction * radius, 1.3)
			var score := _score_combat_spawn_world_position(candidate)
			if _has_clear_line_of_sight(anchor_world_position + Vector3.UP * 1.4, candidate + Vector3.UP * 1.1):
				score += 32.0
			if score > best_score:
				best_score = score
				best_position = candidate
	return best_position

func _score_combat_spawn_world_position(world_position: Vector3) -> float:
	var chunk_payload := _build_chunk_payload_for_world_position(world_position)
	var profile := CityChunkProfileBuilder.build_profile(chunk_payload)
	var chunk_center: Vector3 = chunk_payload.get("chunk_center", Vector3.ZERO)
	var local_point := Vector2(world_position.x - chunk_center.x, world_position.z - chunk_center.z)
	var road_clearance := _distance_to_profile_roads(local_point, profile)
	var building_clearance := _distance_to_profile_buildings(local_point, profile)
	var score := minf(road_clearance, 24.0) + minf(building_clearance, 24.0)
	var distance_to_anchor := world_position.distance_to(_get_active_anchor_position())
	score -= absf(distance_to_anchor - 40.0) * 0.35
	return score

func _resolve_surface_world_position(world_position: Vector3, standing_height: float) -> Vector3:
	var chunk_payload := _build_chunk_payload_for_world_position(world_position)
	var profile := CityChunkProfileBuilder.build_profile(chunk_payload)
	var chunk_center: Vector3 = chunk_payload.get("chunk_center", Vector3.ZERO)
	var local_point := Vector2(world_position.x - chunk_center.x, world_position.z - chunk_center.z)
	return Vector3(
		world_position.x,
		CityChunkGroundSampler.sample_height(local_point, chunk_payload, profile) + standing_height,
		world_position.z
	)

func _resolve_nearby_enemy_spawn_world_position(world_position: Vector3, standing_height: float) -> Vector3:
	var best_position := _resolve_surface_world_position(world_position, standing_height)
	var best_score := _score_combat_spawn_world_position(best_position)
	var offsets: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(6.0, 0.0),
		Vector2(-6.0, 0.0),
		Vector2(0.0, 6.0),
		Vector2(0.0, -6.0),
		Vector2(4.5, 4.5),
		Vector2(-4.5, 4.5),
		Vector2(4.5, -4.5),
		Vector2(-4.5, -4.5),
	]
	for offset in offsets:
		var candidate_world := Vector3(world_position.x + offset.x, world_position.y, world_position.z + offset.y)
		var candidate := _resolve_surface_world_position(candidate_world, standing_height)
		var score := _score_combat_spawn_world_position(candidate) - candidate.distance_to(world_position) * 0.2
		if _has_clear_line_of_sight(candidate + Vector3.UP * 1.1, _get_active_anchor_position() + Vector3.UP * 1.4):
			score += 16.0
		if score > best_score:
			best_score = score
			best_position = candidate
	return best_position

func _has_clear_line_of_sight(from_world_position: Vector3, to_world_position: Vector3) -> bool:
	if get_world_3d() == null or get_world_3d().direct_space_state == null:
		return true
	var query := PhysicsRayQueryParameters3D.create(from_world_position, to_world_position)
	query.collide_with_areas = false
	query.exclude = [player.get_rid()] if player != null else []
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()

func _snap_player_to_active_surface() -> bool:
	if player == null or get_world_3d() == null:
		return false
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return false
	var from := player.global_position + Vector3.UP * 12.0
	var to := player.global_position + Vector3.DOWN * 24.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var standing_height := _estimate_player_standing_height()
	var hit_position: Vector3 = hit.get("position", player.global_position)
	var target_position := Vector3(player.global_position.x, hit_position.y + standing_height, player.global_position.z)
	if player.has_method("teleport_to_world_position"):
		player.teleport_to_world_position(target_position)
	else:
		player.global_position = target_position
	return true

func _get_active_anchor_position() -> Vector3:
	return player.global_position if player != null else Vector3.ZERO

func _build_chunk_payload_for_world_position(world_position: Vector3) -> Dictionary:
	var chunk_key := CityChunkKey.world_to_chunk_key(_world_config, world_position)
	var bounds: Rect2 = _world_config.get_world_bounds()
	var chunk_center := Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * float(_world_config.chunk_size_m),
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * float(_world_config.chunk_size_m)
	)
	return {
		"chunk_id": _world_config.format_chunk_id(chunk_key),
		"chunk_key": chunk_key,
		"chunk_center": chunk_center,
		"chunk_size_m": float(_world_config.chunk_size_m),
		"chunk_seed": _world_config.derive_seed("render_chunk", chunk_key),
		"world_seed": int(_world_config.base_seed),
		"road_graph": _world_data.get("road_graph"),
	}

func _resolve_spawn_local_point(chunk_payload: Dictionary, profile: Dictionary) -> Vector2:
	var chunk_size := float(chunk_payload.get("chunk_size_m", 256.0))
	var half_extent := chunk_size * 0.5 - 24.0
	var best_point := Vector2.ZERO
	var best_score := -INF
	for local_x in range(-96, 97, 24):
		for local_z in range(-96, 97, 24):
			var candidate := Vector2(
				clampf(float(local_x), -half_extent, half_extent),
				clampf(float(local_z), -half_extent, half_extent)
			)
			var road_clearance := _distance_to_profile_roads(candidate, profile)
			var building_clearance := _distance_to_profile_buildings(candidate, profile)
			var center_penalty := candidate.length() * 0.08
			var score := minf(road_clearance, 48.0) + minf(building_clearance, 48.0) - center_penalty
			if score > best_score:
				best_score = score
				best_point = candidate
	return best_point

func _distance_to_profile_roads(local_point: Vector2, profile: Dictionary) -> float:
	var min_distance := INF
	for road_segment in profile.get("road_segments", []):
		var segment_dict: Dictionary = road_segment
		var width := float(segment_dict.get("width", 0.0))
		var points: Array = segment_dict.get("points", [])
		for point_index in range(points.size() - 1):
			var a: Vector3 = points[point_index]
			var b: Vector3 = points[point_index + 1]
			var distance := Geometry2D.get_closest_point_to_segment(local_point, Vector2(a.x, a.z), Vector2(b.x, b.z)).distance_to(local_point) - width * 0.5
			min_distance = minf(min_distance, distance)
	return 9999.0 if min_distance == INF else min_distance

func _distance_to_profile_buildings(local_point: Vector2, profile: Dictionary) -> float:
	var min_distance := INF
	for building in profile.get("buildings", []):
		var building_dict: Dictionary = building
		var center: Vector3 = building_dict.get("center", Vector3.ZERO)
		var radius := float(building_dict.get("visual_footprint_radius_m", building_dict.get("footprint_radius_m", 0.0)))
		min_distance = minf(min_distance, local_point.distance_to(Vector2(center.x, center.z)) - radius)
	return 9999.0 if min_distance == INF else min_distance

func _estimate_player_standing_height() -> float:
	if player == null:
		return 1.0
	var collision_shape := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		return 1.0
	if collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		return capsule.radius + capsule.height * 0.5
	if collision_shape.shape is BoxShape3D:
		var box := collision_shape.shape as BoxShape3D
		return box.size.y * 0.5
	return 1.0

func _set_camera_current(camera_node: Node, current: bool) -> void:
	var camera := camera_node as Camera3D
	if camera != null:
		camera.current = current

func _vector3_to_dict(value: Vector3) -> Dictionary:
	return {
		"x": snappedf(value.x, 0.01),
		"y": snappedf(value.y, 0.01),
		"z": snappedf(value.z, 0.01),
	}

func _build_pedestrian_player_context() -> Dictionary:
	var speed_profile := _control_mode
	if player != null and player.has_method("get_speed_profile"):
		speed_profile = str(player.get_speed_profile())
	return {
		"control_mode": _control_mode,
		"speed_profile": speed_profile,
	}

func _build_minimap_cache_key(center_world_position: Vector3, world_radius_m: float) -> String:
	var center_step := maxf(MINIMAP_POSITION_REFRESH_M, 1.0)
	return "|".join([
		"center:%d:%d" % [int(floor(center_world_position.x / center_step)), int(floor(center_world_position.z / center_step))],
		"radius:%d" % int(round(world_radius_m)),
	])

func _get_minimap_center_world_position(anchor_world_position: Vector3) -> Vector3:
	var center_step := maxf(MINIMAP_POSITION_REFRESH_M, 1.0)
	return Vector3(
		float(int(floor(anchor_world_position.x / center_step))) * center_step,
		anchor_world_position.y,
		float(int(floor(anchor_world_position.z / center_step))) * center_step
	)

func _build_current_minimap_route_overlay(center_world_position: Vector3, world_radius_m: float) -> Dictionary:
	if _minimap_projector == null or _minimap_route_world_positions.is_empty():
		return {}
	return _minimap_projector.build_route_overlay_from_world_positions(center_world_position, _minimap_route_world_positions, world_radius_m)

func _is_minimap_crowd_debug_enabled() -> bool:
	return hud != null and hud.has_method("is_debug_expanded") and bool(hud.is_debug_expanded())

func _invalidate_minimap_cache() -> void:
	_minimap_cache_key = ""
	_minimap_snapshot_cache.clear()

func _should_refresh_hud() -> bool:
	var now_usec := Time.get_ticks_usec()
	var refresh_interval_usec := _resolve_hud_refresh_interval_usec(DisplayServer.get_name() == "headless")
	return _last_hud_refresh_tick_usec < 0 or now_usec - _last_hud_refresh_tick_usec >= refresh_interval_usec

func _resolve_hud_refresh_interval_usec(is_headless: bool) -> int:
	if _has_streaming_backpressure():
		return HEADLESS_HUD_REFRESH_INTERVAL_FAST_USEC if is_headless else HUD_REFRESH_INTERVAL_FAST_USEC
	return HEADLESS_HUD_REFRESH_INTERVAL_USEC if is_headless else HUD_REFRESH_INTERVAL_USEC

func _resolve_minimap_refresh_interval_usec(is_headless: bool) -> int:
	if _has_streaming_backpressure():
		return HEADLESS_MINIMAP_HUD_REFRESH_INTERVAL_FAST_USEC if is_headless else MINIMAP_HUD_REFRESH_INTERVAL_FAST_USEC
	return HEADLESS_MINIMAP_HUD_REFRESH_INTERVAL_USEC if is_headless else MINIMAP_HUD_REFRESH_INTERVAL_USEC

func _has_streaming_backpressure() -> bool:
	if chunk_renderer == null or not chunk_renderer.has_method("get_streaming_budget_stats"):
		return false
	var stats: Dictionary = chunk_renderer.get_streaming_budget_stats()
	return int(stats.get("pending_prepare_count", 0)) > 0 \
		or int(stats.get("pending_surface_async_count", 0)) > 0 \
		or int(stats.get("queued_surface_async_count", 0)) > 0 \
		or int(stats.get("pending_terrain_async_count", 0)) > 0 \
		or int(stats.get("queued_terrain_async_count", 0)) > 0 \
		or int(stats.get("pending_mount_count", 0)) > 0

func _record_update_streaming_sample(duration_usec: int) -> void:
	_update_streaming_sample_count += 1
	_update_streaming_total_usec += duration_usec
	_update_streaming_max_usec = maxi(_update_streaming_max_usec, duration_usec)
	_update_streaming_last_usec = duration_usec

func _record_hud_refresh_sample(duration_usec: int) -> void:
	_hud_refresh_sample_count += 1
	_hud_refresh_total_usec += duration_usec
	_hud_refresh_max_usec = maxi(_hud_refresh_max_usec, duration_usec)
	_hud_refresh_last_usec = duration_usec

func _record_frame_step_sample(duration_usec: int) -> void:
	_frame_step_sample_count += 1
	_frame_step_total_usec += duration_usec
	_frame_step_max_usec = maxi(_frame_step_max_usec, duration_usec)
	_frame_step_last_usec = duration_usec

func _record_minimap_build_sample(duration_usec: int) -> void:
	_minimap_build_total_usec += duration_usec
	_minimap_build_max_usec = maxi(_minimap_build_max_usec, duration_usec)
	_minimap_build_last_usec = duration_usec

func _average_usec(total_usec: int, sample_count: int) -> int:
	if sample_count <= 0:
		return 0
	return int(round(float(total_usec) / float(sample_count)))

func _configure_environment() -> void:
	if world_environment == null:
		return
	var environment := world_environment.environment
	if environment == null:
		environment = Environment.new()
		world_environment.environment = environment

	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.168627, 0.270588, 0.431373, 1.0)
	sky_material.sky_horizon_color = Color(0.580392, 0.737255, 0.839216, 1.0)
	sky_material.ground_horizon_color = Color(0.627451, 0.654902, 0.615686, 1.0)
	sky_material.ground_bottom_color = Color(0.137255, 0.164706, 0.145098, 1.0)
	sky_material.sky_curve = 0.22
	sky_material.ground_curve = 0.08
	sky_material.sun_angle_max = 18.0

	var sky := Sky.new()
	sky.sky_material = sky_material

	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.75
	environment.ambient_light_sky_contribution = 0.8
	environment.fog_enabled = true
	environment.fog_density = 0.00065
	environment.fog_aerial_perspective = 0.55
	environment.fog_light_color = Color(0.643137, 0.741176, 0.803922, 1.0)
	environment.fog_light_energy = 0.8
	environment.fog_sky_affect = 1.0
	environment.fog_sun_scatter = 0.18
