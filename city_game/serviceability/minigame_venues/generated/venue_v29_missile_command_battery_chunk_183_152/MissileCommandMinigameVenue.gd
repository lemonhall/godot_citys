extends Node3D

const CityWorldRingMarker := preload("res://city_game/world/navigation/CityWorldRingMarker.gd")

const GAMEPLAY_PLANE_HALF_WIDTH_M := 36.0
const GAMEPLAY_PLANE_HEIGHT_M := 54.0
const RELEASE_BUFFER_M := 30.0
const PLAY_SURFACE_SIZE := Vector3(72.0, 0.42, 68.0)
const START_RING_RADIUS_M := 4.4
const PLAY_SURFACE_COLLISION_LAYER_VALUE := 1 << 8
const SCOREBOARD_PANEL_SIZE := Vector3(8.6, 4.6, 0.24)
const SCOREBOARD_POST_SIZE := Vector3(0.26, 6.0, 0.26)
const TRACK_VISUAL_RADIUS_M := 1.35
const INTERCEPTOR_VISUAL_RADIUS_M := 0.72
const BACKDROP_DEPTH_OFFSET_M := 2.8

const PLATFORM_COLOR := Color(0.41, 0.42, 0.45, 1.0)
const DECK_COLOR := Color(0.16, 0.21, 0.24, 1.0)
const APRON_COLOR := Color(0.27, 0.3, 0.34, 1.0)
const BACKDROP_COLOR := Color(0.05, 0.12, 0.16, 0.34)
const BACKDROP_FRAME_COLOR := Color(0.18, 0.56, 0.68, 0.52)
const SILO_COLOR := Color(0.16, 0.19, 0.22, 1.0)
const SILO_SELECTED_COLOR := Color(0.18, 0.66, 0.94, 1.0)
const SILO_DESTROYED_COLOR := Color(0.29, 0.11, 0.12, 1.0)
const CITY_COLOR := Color(0.28, 0.62, 0.38, 1.0)
const CITY_DESTROYED_COLOR := Color(0.25, 0.11, 0.12, 1.0)
const SCOREBOARD_COLOR := Color(0.04, 0.06, 0.08, 1.0)
const SCOREBOARD_TEXT_COLOR := Color(0.93, 0.95, 0.88, 1.0)

static var _shared_box_mesh_cache: Dictionary = {}
static var _shared_box_shape_cache: Dictionary = {}
static var _shared_sphere_mesh_cache: Dictionary = {}
static var _shared_material_cache: Dictionary = {}

var _entry: Dictionary = {}
var _missile_command_contract: Dictionary = {}
var _match_start_contract: Dictionary = {}
var _scoreboard_contract: Dictionary = {}
var _scoreboard_state := {
	"wave_index": 0,
	"wave_total": 3,
	"wave_state": "idle",
	"selected_silo_id": "",
	"selected_silo_missiles_remaining": 0,
	"cities_alive_count": 3,
	"enemy_remaining_count": 0,
	"feedback_event_text": "",
}
var _layout_initialized := false
var _match_start_ring: Node3D = null
var _city_visual_nodes: Dictionary = {}
var _silo_visual_nodes: Dictionary = {}
var _enemy_track_nodes: Dictionary = {}
var _interceptor_track_nodes: Dictionary = {}
var _explosion_track_nodes: Dictionary = {}

func _ready() -> void:
	_ensure_venue_layout_built()

func _process(delta: float) -> void:
	if _match_start_ring != null and is_instance_valid(_match_start_ring) and _match_start_ring.has_method("tick"):
		_match_start_ring.tick(delta)

func configure_minigame_venue(entry: Dictionary) -> void:
	_entry = entry.duplicate(true)
	_refresh_contracts()
	_layout_initialized = false
	if is_inside_tree():
		_ensure_venue_layout_built()

func get_venue_contract() -> Dictionary:
	return _entry.duplicate(true)

func get_missile_command_contract() -> Dictionary:
	_ensure_venue_layout_built()
	return _missile_command_contract.duplicate(true)

func get_match_start_contract() -> Dictionary:
	_ensure_venue_layout_built()
	return _match_start_contract.duplicate(true)

func get_scoreboard_contract() -> Dictionary:
	_ensure_venue_layout_built()
	return _scoreboard_contract.duplicate(true)

func get_scoreboard_state() -> Dictionary:
	_ensure_venue_layout_built()
	return _scoreboard_state.duplicate(true)

func get_battery_camera() -> Camera3D:
	return get_node_or_null("BatteryCameraPivot/BatteryCamera") as Camera3D

func get_play_surface_collision_layer_value() -> int:
	return PLAY_SURFACE_COLLISION_LAYER_VALUE

func is_world_point_in_match_start_ring(world_position: Vector3) -> bool:
	_ensure_venue_layout_built()
	var start_world_position: Vector3 = _match_start_contract.get("world_position", global_position)
	return world_position.distance_squared_to(start_world_position) <= pow(float(_match_start_contract.get("trigger_radius_m", START_RING_RADIUS_M)), 2.0)

func is_world_point_in_release_bounds(world_position: Vector3) -> bool:
	_ensure_venue_layout_built()
	var local_position := to_local(world_position)
	return absf(local_position.x) <= PLAY_SURFACE_SIZE.x * 0.5 + RELEASE_BUFFER_M \
		and local_position.z >= -PLAY_SURFACE_SIZE.z * 0.7 - RELEASE_BUFFER_M \
		and local_position.z <= PLAY_SURFACE_SIZE.z * 0.5 + RELEASE_BUFFER_M

func sync_battery_state(state: Dictionary) -> void:
	_ensure_venue_layout_built()
	_scoreboard_state = {
		"wave_index": int(state.get("wave_index", 0)),
		"wave_total": int(state.get("wave_total", 3)),
		"wave_state": str(state.get("wave_state", "idle")),
		"selected_silo_id": str(state.get("selected_silo_id", "")),
		"selected_silo_missiles_remaining": int(state.get("selected_silo_missiles_remaining", 0)),
		"cities_alive_count": int(state.get("cities_alive_count", 0)),
		"enemy_remaining_count": int(state.get("enemy_remaining_count", 0)),
		"feedback_event_text": str(state.get("feedback_event_text", "")),
	}
	var start_ring_visible := bool(state.get("start_ring_visible", true))
	_match_start_contract["visible"] = start_ring_visible
	if _match_start_ring != null and is_instance_valid(_match_start_ring):
		_match_start_ring.set_marker_visible(start_ring_visible)
		_match_start_ring.set_marker_world_position(_match_start_contract.get("world_position", global_position))
	_apply_scoreboard_state()
	_apply_city_states((state.get("city_states", {}) as Dictionary).duplicate(true))
	_apply_silo_states(
		(state.get("silo_states", {}) as Dictionary).duplicate(true),
		str(state.get("selected_silo_id", ""))
	)
	_sync_enemy_visuals((state.get("enemy_tracks", []) as Array).duplicate(true))
	_sync_interceptor_visuals((state.get("interceptor_tracks", []) as Array).duplicate(true))
	_sync_explosion_visuals((state.get("explosion_tracks", []) as Array).duplicate(true))

func _ensure_venue_layout_built() -> void:
	if _layout_initialized:
		return
	_refresh_contracts()
	_apply_camera_pose()
	_ensure_platform()
	_ensure_gameplay_backdrop()
	_ensure_silos()
	_ensure_cities()
	_ensure_scoreboard()
	_ensure_match_start_ring()
	_ensure_runtime_roots()
	_layout_initialized = true
	_apply_scoreboard_state()

func _refresh_contracts() -> void:
	var plane_anchor := get_node_or_null("GameplayPlaneAnchor") as Node3D
	var camera := get_battery_camera()
	var camera_pivot := get_node_or_null("BatteryCameraPivot") as Node3D
	var look_target := get_node_or_null("BatteryCameraLookTarget") as Node3D
	var silo_contracts := _build_silo_contracts()
	var city_contracts := _build_city_contracts()
	var silo_ids: Array[String] = []
	var city_ids: Array[String] = []
	for key_variant in silo_contracts.keys():
		silo_ids.append(str(key_variant))
	for key_variant in city_contracts.keys():
		city_ids.append(str(key_variant))
	silo_ids.sort()
	city_ids.sort()
	_missile_command_contract = {
		"venue_id": str(_entry.get("venue_id", "")),
		"game_kind": str(_entry.get("game_kind", "missile_command_battery")),
		"gameplay_plane_origin": _world_from_node(plane_anchor),
		"gameplay_plane_half_width_m": GAMEPLAY_PLANE_HALF_WIDTH_M,
		"gameplay_plane_height_m": GAMEPLAY_PLANE_HEIGHT_M,
		"gameplay_plane_normal": plane_anchor.global_basis.z if plane_anchor != null and is_inside_tree() else Vector3.BACK,
		"gameplay_plane_right": plane_anchor.global_basis.x if plane_anchor != null and is_inside_tree() else Vector3.RIGHT,
		"gameplay_plane_up": plane_anchor.global_basis.y if plane_anchor != null and is_inside_tree() else Vector3.UP,
		"camera_world_position": _world_from_node(camera if camera != null else camera_pivot),
		"camera_look_target": _world_from_node(look_target),
		"silo_ids": silo_ids,
		"city_ids": city_ids,
		"silos": silo_contracts.duplicate(true),
		"cities": city_contracts.duplicate(true),
		"release_buffer_m": RELEASE_BUFFER_M,
	}
	_match_start_contract = {
		"theme_id": "task_available_start",
		"family_id": "city_world_ring_marker",
		"trigger_radius_m": START_RING_RADIUS_M,
		"world_position": _world_from_node(get_node_or_null("StartRingAnchor") as Node3D),
		"visible": true,
	}
	_scoreboard_contract = {
		"panel_size": SCOREBOARD_PANEL_SIZE,
		"world_position": _world_from_node(get_node_or_null("ScoreboardAnchor") as Node3D),
		"state": _scoreboard_state.duplicate(true),
	}

func _apply_camera_pose() -> void:
	var pivot := get_node_or_null("BatteryCameraPivot") as Node3D
	var look_target := get_node_or_null("BatteryCameraLookTarget") as Node3D
	if pivot == null or look_target == null:
		return
	if pivot.global_position.distance_squared_to(look_target.global_position) > 0.001:
		pivot.look_at(look_target.global_position, Vector3.UP, true)

func _build_silo_contracts() -> Dictionary:
	var result := {}
	var root := get_node_or_null("LaunchSilos") as Node3D
	if root == null:
		return result
	for node_name in ["Left", "Center", "Right"]:
		var anchor := root.get_node_or_null(node_name) as Node3D
		if anchor == null:
			continue
		var silo_id := "silo_%s" % node_name.to_lower()
		result[silo_id] = {
			"silo_id": silo_id,
			"label": node_name,
			"local_position": anchor.position,
			"world_position": _world_from_node(anchor),
			"launch_world_position": _world_from_node(anchor) + Vector3.UP * 3.6,
		}
	return result

func _build_city_contracts() -> Dictionary:
	var result := {}
	var root := get_node_or_null("CityTargets") as Node3D
	if root == null:
		return result
	for node_name in ["Left", "Center", "Right"]:
		var anchor := root.get_node_or_null(node_name) as Node3D
		if anchor == null:
			continue
		var city_id := "city_%s" % node_name.to_lower()
		result[city_id] = {
			"city_id": city_id,
			"label": node_name,
			"local_position": anchor.position,
			"world_position": _world_from_node(anchor),
			"impact_world_position": _world_from_node(anchor) + Vector3.UP * 1.4,
		}
	return result

func _ensure_platform() -> void:
	var body := _ensure_static_body("BatteryPlatform")
	body.collision_layer = PLAY_SURFACE_COLLISION_LAYER_VALUE | 1
	body.collision_mask = PLAY_SURFACE_COLLISION_LAYER_VALUE | 1
	_ensure_visual_box(body, "Base", Vector3(0.0, -1.85, -6.0), Vector3(PLAY_SURFACE_SIZE.x + 12.0, 4.3, PLAY_SURFACE_SIZE.z + 18.0), PLATFORM_COLOR)
	_ensure_collision_box(body, "BaseCollision", Vector3(0.0, -1.85, -6.0), Vector3(PLAY_SURFACE_SIZE.x + 12.0, 4.3, PLAY_SURFACE_SIZE.z + 18.0))
	_ensure_visual_box(body, "Deck", Vector3(0.0, -0.2, -6.0), PLAY_SURFACE_SIZE, DECK_COLOR)
	_ensure_collision_box(body, "DeckCollision", Vector3(0.0, -0.2, -6.0), PLAY_SURFACE_SIZE)
	_ensure_visual_box(body, "Apron", Vector3(0.0, -0.2, 25.5), Vector3(28.0, 0.5, 12.0), APRON_COLOR)
	_ensure_collision_box(body, "ApronCollision", Vector3(0.0, -0.2, 25.5), Vector3(28.0, 0.5, 12.0))
	_ensure_visual_box(body, "RearTower", Vector3(0.0, 4.5, 12.0), Vector3(10.0, 7.0, 9.4), PLATFORM_COLOR.darkened(0.08))

func _ensure_gameplay_backdrop() -> void:
	var plane_anchor := get_node_or_null("GameplayPlaneAnchor") as Node3D
	if plane_anchor == null:
		return
	var root := get_node_or_null("GameplayBackdrop") as Node3D
	if root == null:
		root = Node3D.new()
		root.name = "GameplayBackdrop"
		add_child(root)
	root.transform = plane_anchor.transform
	root.position += Vector3(0.0, 0.0, -BACKDROP_DEPTH_OFFSET_M)
	var panel_size := Vector3(GAMEPLAY_PLANE_HALF_WIDTH_M * 2.0 + 4.0, GAMEPLAY_PLANE_HEIGHT_M + 4.0, 0.28)
	_ensure_visual_box(root, "Panel", Vector3.ZERO, panel_size, BACKDROP_COLOR)
	_ensure_visual_box(root, "TopFrame", Vector3(0.0, panel_size.y * 0.5 + 0.4, 0.0), Vector3(panel_size.x + 1.6, 0.8, 0.34), BACKDROP_FRAME_COLOR)
	_ensure_visual_box(root, "BottomFrame", Vector3(0.0, -panel_size.y * 0.5 - 0.4, 0.0), Vector3(panel_size.x + 1.6, 0.8, 0.34), BACKDROP_FRAME_COLOR)
	_ensure_visual_box(root, "LeftFrame", Vector3(-panel_size.x * 0.5 - 0.4, 0.0, 0.0), Vector3(0.8, panel_size.y + 1.6, 0.34), BACKDROP_FRAME_COLOR)
	_ensure_visual_box(root, "RightFrame", Vector3(panel_size.x * 0.5 + 0.4, 0.0, 0.0), Vector3(0.8, panel_size.y + 1.6, 0.34), BACKDROP_FRAME_COLOR)

func _ensure_silos() -> void:
	_silo_visual_nodes.clear()
	var root := get_node_or_null("LaunchSilos") as Node3D
	if root == null:
		return
	for node_name in ["Left", "Center", "Right"]:
		var anchor := root.get_node_or_null(node_name) as Node3D
		if anchor == null:
			continue
		var visual_root := anchor.get_node_or_null("Visual") as Node3D
		if visual_root == null:
			visual_root = Node3D.new()
			visual_root.name = "Visual"
			anchor.add_child(visual_root)
		_ensure_visual_box(visual_root, "Base", Vector3(0.0, 0.95, 0.0), Vector3(5.0, 1.9, 5.0), SILO_COLOR)
		_ensure_visual_box(visual_root, "Tube", Vector3(0.0, 3.1, 0.0), Vector3(2.4, 4.4, 2.4), SILO_COLOR)
		_ensure_visual_box(visual_root, "Cap", Vector3(0.0, 5.6, 0.0), Vector3(3.0, 0.5, 3.0), SILO_SELECTED_COLOR)
		_silo_visual_nodes["silo_%s" % node_name.to_lower()] = visual_root

func _ensure_cities() -> void:
	_city_visual_nodes.clear()
	var root := get_node_or_null("CityTargets") as Node3D
	if root == null:
		return
	for node_name in ["Left", "Center", "Right"]:
		var anchor := root.get_node_or_null(node_name) as Node3D
		if anchor == null:
			continue
		var visual_root := anchor.get_node_or_null("Visual") as Node3D
		if visual_root == null:
			visual_root = Node3D.new()
			visual_root.name = "Visual"
			anchor.add_child(visual_root)
		_ensure_visual_box(visual_root, "Base", Vector3(0.0, 1.0, 0.0), Vector3(6.3, 2.0, 4.7), CITY_COLOR)
		_ensure_visual_box(visual_root, "TowerA", Vector3(-1.25, 2.7, -0.55), Vector3(1.7, 3.4, 1.6), CITY_COLOR)
		_ensure_visual_box(visual_root, "TowerB", Vector3(1.35, 3.2, 0.25), Vector3(1.8, 4.3, 1.8), CITY_COLOR)
		_ensure_visual_box(visual_root, "TowerC", Vector3(0.2, 4.2, 1.15), Vector3(1.4, 2.4, 1.3), CITY_COLOR)
		_city_visual_nodes["city_%s" % node_name.to_lower()] = visual_root

func _ensure_scoreboard() -> void:
	var anchor := get_node_or_null("ScoreboardAnchor") as Node3D
	var root := get_node_or_null("Scoreboard") as Node3D
	if root == null:
		root = Node3D.new()
		root.name = "Scoreboard"
		add_child(root)
	root.position = anchor.position if anchor != null else Vector3(26.0, 6.8, -3.0)
	root.rotation.y = -PI * 0.5
	_ensure_visual_box(root, "Panel", Vector3.ZERO, SCOREBOARD_PANEL_SIZE, SCOREBOARD_COLOR)
	_ensure_visual_box(root, "LeftPost", Vector3(-SCOREBOARD_PANEL_SIZE.x * 0.38, -SCOREBOARD_POST_SIZE.y * 0.5, 0.0), SCOREBOARD_POST_SIZE, SCOREBOARD_COLOR)
	_ensure_visual_box(root, "RightPost", Vector3(SCOREBOARD_PANEL_SIZE.x * 0.38, -SCOREBOARD_POST_SIZE.y * 0.5, 0.0), SCOREBOARD_POST_SIZE, SCOREBOARD_COLOR)
	_ensure_label(root, "WaveLabel", Vector3(0.0, 1.12, SCOREBOARD_PANEL_SIZE.z * 0.56), 42)
	_ensure_label(root, "TargetsLabel", Vector3(0.0, 0.36, SCOREBOARD_PANEL_SIZE.z * 0.56), 26)
	_ensure_label(root, "SiloLabel", Vector3(0.0, -0.36, SCOREBOARD_PANEL_SIZE.z * 0.56), 24)
	_ensure_label(root, "FeedbackLabel", Vector3(0.0, -1.1, SCOREBOARD_PANEL_SIZE.z * 0.56), 18)

func _ensure_match_start_ring() -> void:
	if _match_start_ring == null or not is_instance_valid(_match_start_ring):
		_match_start_ring = CityWorldRingMarker.new()
		_match_start_ring.name = "MatchStartRing"
		add_child(_match_start_ring)
	_match_start_ring.set_marker_theme(str(_match_start_contract.get("theme_id", "task_available_start")))
	_match_start_ring.set_marker_radius(float(_match_start_contract.get("trigger_radius_m", START_RING_RADIUS_M)))
	_match_start_ring.set_marker_world_position(_match_start_contract.get("world_position", global_position))
	_match_start_ring.set_marker_visible(bool(_match_start_contract.get("visible", true)))

func _ensure_runtime_roots() -> void:
	for path in ["RuntimeVisuals", "RuntimeVisuals/EnemyTracks", "RuntimeVisuals/InterceptorTracks", "RuntimeVisuals/ExplosionTracks"]:
		if get_node_or_null(path) != null:
			continue
		var node := Node3D.new()
		node.name = path.get_file()
		if path == "RuntimeVisuals":
			add_child(node)
		else:
			(get_node_or_null("RuntimeVisuals") as Node3D).add_child(node)

func _apply_scoreboard_state() -> void:
	var root := get_node_or_null("Scoreboard") as Node3D
	if root == null:
		return
	var wave_label := root.get_node_or_null("WaveLabel") as Label3D
	if wave_label != null:
		wave_label.text = "WAVE %d / %d  %s" % [
			maxi(int(_scoreboard_state.get("wave_index", 0)), 0),
			maxi(int(_scoreboard_state.get("wave_total", 3)), 1),
			str(_scoreboard_state.get("wave_state", "idle")).to_upper()
		]
	var targets_label := root.get_node_or_null("TargetsLabel") as Label3D
	if targets_label != null:
		targets_label.text = "CITIES %d   THREATS %d" % [
			int(_scoreboard_state.get("cities_alive_count", 0)),
			int(_scoreboard_state.get("enemy_remaining_count", 0))
		]
	var silo_label := root.get_node_or_null("SiloLabel") as Label3D
	if silo_label != null:
		silo_label.text = "%s  MISSILES %d" % [
			str(_scoreboard_state.get("selected_silo_id", "")).to_upper(),
			int(_scoreboard_state.get("selected_silo_missiles_remaining", 0))
		]
	var feedback_label := root.get_node_or_null("FeedbackLabel") as Label3D
	if feedback_label != null:
		var feedback_text := str(_scoreboard_state.get("feedback_event_text", ""))
		feedback_label.text = feedback_text if feedback_text != "" else "STEP INTO THE RING"

func _apply_city_states(city_states: Dictionary) -> void:
	for city_id_variant in _city_visual_nodes.keys():
		var city_id := str(city_id_variant)
		var visual_root := _city_visual_nodes.get(city_id) as Node3D
		if visual_root == null:
			continue
		var destroyed := bool((city_states.get(city_id, {}) as Dictionary).get("destroyed", false))
		var color := CITY_DESTROYED_COLOR if destroyed else CITY_COLOR
		for node_name in ["Base", "TowerA", "TowerB", "TowerC"]:
			_set_mesh_color(visual_root.get_node_or_null(node_name) as MeshInstance3D, color)

func _apply_silo_states(silo_states: Dictionary, selected_silo_id: String) -> void:
	for silo_id_variant in _silo_visual_nodes.keys():
		var silo_id := str(silo_id_variant)
		var visual_root := _silo_visual_nodes.get(silo_id) as Node3D
		if visual_root == null:
			continue
		var destroyed := bool((silo_states.get(silo_id, {}) as Dictionary).get("destroyed", false))
		var base_color := SILO_DESTROYED_COLOR if destroyed else SILO_COLOR
		var cap_color := SILO_DESTROYED_COLOR if destroyed else (SILO_SELECTED_COLOR if silo_id == selected_silo_id else SILO_COLOR.lightened(0.08))
		_set_mesh_color(visual_root.get_node_or_null("Base") as MeshInstance3D, base_color)
		_set_mesh_color(visual_root.get_node_or_null("Tube") as MeshInstance3D, base_color)
		_set_mesh_color(visual_root.get_node_or_null("Cap") as MeshInstance3D, cap_color)

func _sync_enemy_visuals(enemy_tracks: Array) -> void:
	_sync_orb_group(
		get_node_or_null("RuntimeVisuals/EnemyTracks") as Node3D,
		enemy_tracks,
		_enemy_track_nodes,
		Color(0.97, 0.44, 0.24, 1.0),
		TRACK_VISUAL_RADIUS_M,
		"current_position"
	)

func _sync_interceptor_visuals(interceptor_tracks: Array) -> void:
	_sync_orb_group(
		get_node_or_null("RuntimeVisuals/InterceptorTracks") as Node3D,
		interceptor_tracks,
		_interceptor_track_nodes,
		Color(0.26, 0.82, 0.96, 1.0),
		INTERCEPTOR_VISUAL_RADIUS_M,
		"current_position"
	)

func _sync_explosion_visuals(explosion_tracks: Array) -> void:
	var root := get_node_or_null("RuntimeVisuals/ExplosionTracks") as Node3D
	if root == null:
		return
	var live_ids: Dictionary = {}
	for track_variant in explosion_tracks:
		var track: Dictionary = track_variant
		var track_id := str(track.get("track_id", ""))
		if track_id == "":
			continue
		live_ids[track_id] = true
		var node := _explosion_track_nodes.get(track_id, null) as MeshInstance3D
		if node == null or not is_instance_valid(node):
			node = MeshInstance3D.new()
			node.name = track_id
			root.add_child(node)
			_explosion_track_nodes[track_id] = node
		var radius_m := maxf(float(track.get("radius_m", 0.0)), 1.0)
		node.mesh = _get_shared_sphere_mesh(radius_m)
		node.global_position = track.get("world_position", global_position)
		var progress := clampf(float(track.get("progress", 0.0)), 0.0, 1.0)
		node.material_override = _get_shared_material(Color(0.98, 0.82, 0.18, lerpf(0.42, 0.14, progress)), 0.05)
	for node_id_variant in _explosion_track_nodes.keys():
		var node_id := str(node_id_variant)
		if live_ids.has(node_id):
			continue
		var old_node := _explosion_track_nodes.get(node_id) as Node
		if old_node != null and is_instance_valid(old_node):
			old_node.queue_free()
		_explosion_track_nodes.erase(node_id)

func _sync_orb_group(root: Node3D, tracks: Array, cache: Dictionary, color: Color, radius_m: float, position_key: String) -> void:
	if root == null:
		return
	var live_ids: Dictionary = {}
	for track_variant in tracks:
		var track: Dictionary = track_variant
		var track_id := str(track.get("track_id", ""))
		if track_id == "":
			continue
		live_ids[track_id] = true
		var node := cache.get(track_id, null) as MeshInstance3D
		if node == null or not is_instance_valid(node):
			node = MeshInstance3D.new()
			node.name = track_id
			root.add_child(node)
			cache[track_id] = node
		node.mesh = _get_shared_sphere_mesh(radius_m)
		node.global_position = track.get(position_key, global_position)
		node.material_override = _get_shared_material(color, 0.18)
	for node_id_variant in cache.keys():
		var node_id := str(node_id_variant)
		if live_ids.has(node_id):
			continue
		var old_node := cache.get(node_id) as Node
		if old_node != null and is_instance_valid(old_node):
			old_node.queue_free()
		cache.erase(node_id)

func _ensure_static_body(node_name: String) -> StaticBody3D:
	var existing := get_node_or_null(node_name)
	if existing is StaticBody3D:
		return existing as StaticBody3D
	if existing != null:
		remove_child(existing)
		existing.queue_free()
	var body := StaticBody3D.new()
	body.name = node_name
	add_child(body)
	return body

func _ensure_visual_box(root: Node3D, node_name: String, local_position: Vector3, size: Vector3, color: Color) -> void:
	var node := root.get_node_or_null(node_name) as MeshInstance3D
	if node == null:
		node = MeshInstance3D.new()
		node.name = node_name
		root.add_child(node)
	node.position = local_position
	node.mesh = _get_shared_box_mesh(size)
	node.material_override = _get_shared_material(color, 0.9)

func _ensure_collision_box(root: StaticBody3D, node_name: String, local_position: Vector3, size: Vector3) -> void:
	var node := root.get_node_or_null(node_name) as CollisionShape3D
	if node == null:
		node = CollisionShape3D.new()
		node.name = node_name
		root.add_child(node)
	node.position = local_position
	node.shape = _get_shared_box_shape(size)

func _ensure_label(root: Node3D, node_name: String, local_position: Vector3, font_size: int) -> void:
	var label := root.get_node_or_null(node_name) as Label3D
	if label == null:
		label = Label3D.new()
		label.name = node_name
		root.add_child(label)
	label.position = local_position
	label.font_size = font_size
	label.pixel_size = 0.018
	label.modulate = SCOREBOARD_TEXT_COLOR
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.76)
	label.outline_size = 4
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED

func _set_mesh_color(mesh_instance: MeshInstance3D, color: Color) -> void:
	if mesh_instance == null:
		return
	mesh_instance.material_override = _get_shared_material(color, 0.88)

func _world_from_node(node: Node3D) -> Vector3:
	if node != null and is_inside_tree():
		return node.global_position
	return _resolve_entry_world_position() + _resolve_scene_root_offset()

func _resolve_entry_world_position() -> Vector3:
	var value: Variant = _entry.get("world_position", Vector3.ZERO)
	return value as Vector3 if value is Vector3 else Vector3.ZERO

func _resolve_scene_root_offset() -> Vector3:
	var value: Variant = _entry.get("scene_root_offset", Vector3.ZERO)
	return value as Vector3 if value is Vector3 else Vector3.ZERO

func _get_shared_box_mesh(size: Vector3) -> BoxMesh:
	var key := _vector3_key(size)
	if _shared_box_mesh_cache.has(key):
		return _shared_box_mesh_cache.get(key) as BoxMesh
	var mesh := BoxMesh.new()
	mesh.size = size
	_shared_box_mesh_cache[key] = mesh
	return mesh

func _get_shared_box_shape(size: Vector3) -> BoxShape3D:
	var key := _vector3_key(size)
	if _shared_box_shape_cache.has(key):
		return _shared_box_shape_cache.get(key) as BoxShape3D
	var shape := BoxShape3D.new()
	shape.size = size
	_shared_box_shape_cache[key] = shape
	return shape

func _get_shared_sphere_mesh(radius_m: float) -> SphereMesh:
	var key := str(snappedf(radius_m, 0.01))
	if _shared_sphere_mesh_cache.has(key):
		return _shared_sphere_mesh_cache.get(key) as SphereMesh
	var mesh := SphereMesh.new()
	mesh.radius = radius_m
	mesh.height = radius_m * 2.0
	mesh.radial_segments = 18
	mesh.rings = 10
	_shared_sphere_mesh_cache[key] = mesh
	return mesh

func _get_shared_material(color: Color, roughness: float) -> StandardMaterial3D:
	var key := "%s|%s" % [_color_key(color), str(snappedf(roughness, 0.01))]
	if _shared_material_cache.has(key):
		return _shared_material_cache.get(key) as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.emission_enabled = color.a < 0.99 or color.get_luminance() > 0.55
	material.emission = Color(color.r, color.g, color.b, 1.0) * 0.55
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 0.99 else BaseMaterial3D.TRANSPARENCY_DISABLED
	_shared_material_cache[key] = material
	return material

func _vector3_key(value: Vector3) -> String:
	return "%s|%s|%s" % [str(snappedf(value.x, 0.01)), str(snappedf(value.y, 0.01)), str(snappedf(value.z, 0.01))]

func _color_key(value: Color) -> String:
	return "%s|%s|%s|%s" % [
		str(snappedf(value.r, 0.01)),
		str(snappedf(value.g, 0.01)),
		str(snappedf(value.b, 0.01)),
		str(snappedf(value.a, 0.01))
	]
