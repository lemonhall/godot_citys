extends Node3D

const CityWorldRingMarker := preload("res://city_game/world/navigation/CityWorldRingMarker.gd")
const TennisOpponent := preload("res://city_game/serviceability/minigame_venues/generated/venue_v28_tennis_court_chunk_158_140/TennisOpponent.gd")

const BASE_COURT_LENGTH_M := 23.77
const BASE_SINGLES_WIDTH_M := 8.23
const BASE_SERVICE_LINE_DISTANCE_M := 6.40
const COURT_SCALE_FACTOR := 7.5
const COURT_LENGTH_M := BASE_COURT_LENGTH_M * COURT_SCALE_FACTOR
const SINGLES_WIDTH_M := BASE_SINGLES_WIDTH_M * COURT_SCALE_FACTOR
const SERVICE_LINE_DISTANCE_M := BASE_SERVICE_LINE_DISTANCE_M * COURT_SCALE_FACTOR
const NET_CENTER_HEIGHT_M := 0.914
const NET_POST_HEIGHT_M := 1.07
const BASE_COURT_HALF_LENGTH_M := BASE_COURT_LENGTH_M * 0.5
const BASE_COURT_HALF_WIDTH_M := BASE_SINGLES_WIDTH_M * 0.5
const COURT_HALF_LENGTH_M := COURT_LENGTH_M * 0.5
const COURT_HALF_WIDTH_M := SINGLES_WIDTH_M * 0.5
const PLAY_SURFACE_THICKNESS_M := 0.18
const PODIUM_MARGIN_X_M := 8.0
const PODIUM_MARGIN_Z_M := 12.0
const PODIUM_DEPTH_M := 2.8
const PODIUM_TOP_RECESS_M := PLAY_SURFACE_THICKNESS_M
const APRON_THICKNESS_M := 0.12
const RELEASE_BUFFER_M := 28.0
const NET_COLLISION_THICKNESS_M := 0.10
const PLAY_SURFACE_COLLISION_LAYER_VALUE := 1 << 8
const MATCH_START_RING_RADIUS_M := 11.0
const MATCH_START_RING_LOCAL_POSITION := Vector3(0.0, 0.06, (BASE_COURT_HALF_LENGTH_M - 1.25) * COURT_SCALE_FACTOR)
const HOME_BASELINE_ANCHOR_LOCAL := Vector3(0.0, 0.0, (BASE_COURT_HALF_LENGTH_M - 2.35) * COURT_SCALE_FACTOR)
const AWAY_BASELINE_ANCHOR_LOCAL := Vector3(0.0, 0.0, (-BASE_COURT_HALF_LENGTH_M + 2.35) * COURT_SCALE_FACTOR)
const HOME_DEUCE_SERVER_LOCAL := Vector3(1.32 * COURT_SCALE_FACTOR, 0.0, (BASE_COURT_HALF_LENGTH_M - 1.25) * COURT_SCALE_FACTOR)
const HOME_AD_SERVER_LOCAL := Vector3(-1.32 * COURT_SCALE_FACTOR, 0.0, (BASE_COURT_HALF_LENGTH_M - 1.25) * COURT_SCALE_FACTOR)
const AWAY_DEUCE_SERVER_LOCAL := Vector3(-1.32 * COURT_SCALE_FACTOR, 0.0, (-BASE_COURT_HALF_LENGTH_M + 1.25) * COURT_SCALE_FACTOR)
const AWAY_AD_SERVER_LOCAL := Vector3(1.32 * COURT_SCALE_FACTOR, 0.0, (-BASE_COURT_HALF_LENGTH_M + 1.25) * COURT_SCALE_FACTOR)
const HOME_DEUCE_RECEIVER_LOCAL := Vector3(1.2 * COURT_SCALE_FACTOR, 0.0, (BASE_COURT_HALF_LENGTH_M - 2.8) * COURT_SCALE_FACTOR)
const HOME_AD_RECEIVER_LOCAL := Vector3(-1.2 * COURT_SCALE_FACTOR, 0.0, (BASE_COURT_HALF_LENGTH_M - 2.8) * COURT_SCALE_FACTOR)
const AWAY_DEUCE_RECEIVER_LOCAL := Vector3(-1.2 * COURT_SCALE_FACTOR, 0.0, (-BASE_COURT_HALF_LENGTH_M + 2.8) * COURT_SCALE_FACTOR)
const AWAY_AD_RECEIVER_LOCAL := Vector3(1.2 * COURT_SCALE_FACTOR, 0.0, (-BASE_COURT_HALF_LENGTH_M + 2.8) * COURT_SCALE_FACTOR)
const COURT_COLOR := Color(0.176471, 0.403922, 0.721569, 1.0)
const APRON_COLOR := Color(0.278431, 0.321569, 0.356863, 1.0)
const PODIUM_COLOR := Color(0.47451, 0.447059, 0.407843, 1.0)
const LINE_COLOR := Color(0.96, 0.96, 0.94, 1.0)
const NET_COLOR := Color(0.102, 0.122, 0.141, 1.0)
const NET_POST_COLOR := Color(0.88, 0.92, 0.94, 1.0)
const LINE_THICKNESS_M := 0.28
const LINE_HEIGHT_M := 0.028
const SCOREBOARD_PANEL_SIZE := Vector3(5.6, 3.0, 0.16)
const SCOREBOARD_POST_SIZE := Vector3(0.22, 4.4, 0.22)
const SCOREBOARD_COLOR := Color(0.05, 0.07, 0.09, 1.0)
const SCOREBOARD_TEXT_COLOR := Color(0.94, 0.96, 0.9, 1.0)
const SCOREBOARD_HIGHLIGHT_COLOR := Color(0.98, 0.8, 0.22, 1.0)

static var _shared_box_mesh_cache: Dictionary = {}
static var _shared_box_shape_cache: Dictionary = {}
static var _shared_material_cache: Dictionary = {}

var _entry: Dictionary = {}
var _court_contract: Dictionary = {}
var _match_start_contract: Dictionary = {}
var _scoreboard_contract: Dictionary = {}
var _scoreboard_state := {
	"home_games": 0,
	"away_games": 0,
	"home_point_label": "0",
	"away_point_label": "0",
	"server_side": "home",
	"match_state": "idle",
	"winner_side": "",
	"point_end_reason": "",
}
var _service_box_contracts: Dictionary = {}
var _match_start_ring: Node3D = null
var _receive_landing_marker: Node3D = null
var _opponent_contract: Dictionary = {}
var _opponent_state: Dictionary = {}
var _opponent_node: Node3D = null
var _receive_hint_state := {
	"landing_marker_visible": false,
	"landing_marker_world_position": Vector3.ZERO,
	"marker_radius_m": 4.2,
	"auto_footwork_assist_state": "idle",
	"strike_window_state": "idle",
	"strike_quality_feedback": "",
}
var _layout_initialized := false

func _ready() -> void:
	_ensure_venue_layout_built()

func _process(delta: float) -> void:
	if _match_start_ring != null and is_instance_valid(_match_start_ring) and _match_start_ring.has_method("tick"):
		_match_start_ring.tick(delta)
	if _receive_landing_marker != null and is_instance_valid(_receive_landing_marker) and _receive_landing_marker.has_method("tick"):
		_receive_landing_marker.tick(delta)

func configure_minigame_venue(entry: Dictionary) -> void:
	_entry = entry.duplicate(true)
	_refresh_contracts()
	_layout_initialized = false
	if is_inside_tree():
		_ensure_venue_layout_built()

func get_venue_contract() -> Dictionary:
	return _entry.duplicate(true)

func get_tennis_court_contract() -> Dictionary:
	_ensure_venue_layout_built()
	return _court_contract.duplicate(true)

func get_match_start_contract() -> Dictionary:
	_ensure_venue_layout_built()
	return _match_start_contract.duplicate(true)

func get_scoreboard_contract() -> Dictionary:
	_ensure_venue_layout_built()
	return _scoreboard_contract.duplicate(true)

func get_scoreboard_state() -> Dictionary:
	_ensure_venue_layout_built()
	return _scoreboard_state.duplicate(true)

func get_play_surface_collision_layer_value() -> int:
	return PLAY_SURFACE_COLLISION_LAYER_VALUE

func set_scoreboard_state(scoreboard_state: Dictionary) -> void:
	_ensure_venue_layout_built()
	_scoreboard_state = {
		"home_games": int(scoreboard_state.get("home_games", 0)),
		"away_games": int(scoreboard_state.get("away_games", 0)),
		"home_point_label": str(scoreboard_state.get("home_point_label", "0")),
		"away_point_label": str(scoreboard_state.get("away_point_label", "0")),
		"server_side": str(scoreboard_state.get("server_side", "home")),
		"match_state": str(scoreboard_state.get("match_state", "idle")),
		"winner_side": str(scoreboard_state.get("winner_side", "")),
		"point_end_reason": str(scoreboard_state.get("point_end_reason", "")),
	}
	_apply_scoreboard_state()

func sync_match_state(match_state: Dictionary) -> void:
	_ensure_venue_layout_built()
	if match_state.has("scoreboard_state"):
		set_scoreboard_state((match_state.get("scoreboard_state", {}) as Dictionary).duplicate(true))
	var start_ring_visible := bool(match_state.get("start_ring_visible", _match_state_is_idle()))
	_match_start_contract["visible"] = start_ring_visible
	if _match_start_ring != null and is_instance_valid(_match_start_ring):
		_match_start_ring.set_marker_visible(start_ring_visible)
		_match_start_ring.set_marker_world_position(_match_start_contract.get("world_position", global_position))
	_receive_hint_state = (match_state.get("receive_hint_state", _receive_hint_state) as Dictionary).duplicate(true)
	_apply_receive_landing_marker_state()
	_ensure_opponent_node()
	_opponent_state = (match_state.get("opponent_state", _build_default_opponent_state()) as Dictionary).duplicate(true)
	if _opponent_node != null and is_instance_valid(_opponent_node) and _opponent_node.has_method("apply_runtime_state"):
		_opponent_node.apply_runtime_state(_opponent_state)

func is_world_point_in_match_start_ring(world_position: Vector3) -> bool:
	_ensure_venue_layout_built()
	var start_world_position: Vector3 = _match_start_contract.get("world_position", global_position)
	return world_position.distance_squared_to(start_world_position) <= pow(float(_match_start_contract.get("trigger_radius_m", MATCH_START_RING_RADIUS_M)), 2.0)

func is_world_point_in_play_bounds(world_position: Vector3) -> bool:
	_ensure_venue_layout_built()
	var local_position := to_local(world_position)
	return absf(local_position.x) <= COURT_HALF_WIDTH_M and absf(local_position.z) <= COURT_HALF_LENGTH_M

func is_world_point_in_release_bounds(world_position: Vector3) -> bool:
	_ensure_venue_layout_built()
	var local_position := to_local(world_position)
	return absf(local_position.x) <= COURT_HALF_WIDTH_M + RELEASE_BUFFER_M and absf(local_position.z) <= COURT_HALF_LENGTH_M + RELEASE_BUFFER_M

func get_service_box_id_for_world_point(world_position: Vector3) -> String:
	_ensure_venue_layout_built()
	var local_position := to_local(world_position)
	if absf(local_position.z) > SERVICE_LINE_DISTANCE_M or absf(local_position.x) > COURT_HALF_WIDTH_M:
		return ""
	if local_position.z >= 0.0:
		return "service_box_deuce_home" if local_position.x >= 0.0 else "service_box_ad_home"
	return "service_box_deuce_away" if local_position.x <= 0.0 else "service_box_ad_away"

func _ensure_venue_layout_built() -> void:
	if _layout_initialized:
		return
	_refresh_contracts()
	_ensure_podium()
	_ensure_apron()
	_ensure_play_surface()
	_ensure_court_markings()
	_ensure_net()
	_ensure_scoreboard()
	_ensure_match_start_ring()
	_ensure_receive_landing_marker()
	_ensure_opponent_node()
	_layout_initialized = true
	_apply_scoreboard_state()

func _refresh_contracts() -> void:
	_service_box_contracts = _build_service_box_contracts()
	_court_contract = {
		"venue_id": str(_entry.get("venue_id", "")),
		"game_kind": str(_entry.get("game_kind", "tennis_court")),
		"base_court_length_m": BASE_COURT_LENGTH_M,
		"base_singles_width_m": BASE_SINGLES_WIDTH_M,
		"base_service_line_distance_m": BASE_SERVICE_LINE_DISTANCE_M,
		"court_scale_factor": COURT_SCALE_FACTOR,
		"court_length_m": COURT_LENGTH_M,
		"singles_width_m": SINGLES_WIDTH_M,
		"service_line_distance_m": SERVICE_LINE_DISTANCE_M,
		"net_center_height_m": NET_CENTER_HEIGHT_M,
		"net_post_height_m": NET_POST_HEIGHT_M,
		"release_buffer_m": RELEASE_BUFFER_M,
		"surface_top_y": global_position.y if is_inside_tree() else _resolve_entry_world_position().y + _resolve_scene_root_offset().y,
		"world_position": global_position if is_inside_tree() else _resolve_entry_world_position() + _resolve_scene_root_offset(),
		"court_bounds": {
			"half_width_m": COURT_HALF_WIDTH_M,
			"half_length_m": COURT_HALF_LENGTH_M,
		},
		"service_box_ids": [
			"service_box_deuce_home",
			"service_box_ad_home",
			"service_box_deuce_away",
			"service_box_ad_away",
		],
		"service_boxes": _service_box_contracts.duplicate(true),
		"home_baseline_anchor": _to_world_contract_point(HOME_BASELINE_ANCHOR_LOCAL),
		"away_baseline_anchor": _to_world_contract_point(AWAY_BASELINE_ANCHOR_LOCAL),
		"home_deuce_server_anchor": _to_world_contract_point(HOME_DEUCE_SERVER_LOCAL),
		"home_ad_server_anchor": _to_world_contract_point(HOME_AD_SERVER_LOCAL),
		"away_deuce_server_anchor": _to_world_contract_point(AWAY_DEUCE_SERVER_LOCAL),
		"away_ad_server_anchor": _to_world_contract_point(AWAY_AD_SERVER_LOCAL),
		"home_deuce_receiver_anchor": _to_world_contract_point(HOME_DEUCE_RECEIVER_LOCAL),
		"home_ad_receiver_anchor": _to_world_contract_point(HOME_AD_RECEIVER_LOCAL),
		"away_deuce_receiver_anchor": _to_world_contract_point(AWAY_DEUCE_RECEIVER_LOCAL),
		"away_ad_receiver_anchor": _to_world_contract_point(AWAY_AD_RECEIVER_LOCAL),
	}
	_match_start_contract = {
		"theme_id": "task_available_start",
		"family_id": "city_world_ring_marker",
		"trigger_radius_m": MATCH_START_RING_RADIUS_M,
		"local_position": MATCH_START_RING_LOCAL_POSITION,
		"world_position": _to_world_point(MATCH_START_RING_LOCAL_POSITION),
		"visible": _match_state_is_idle(),
	}
	_scoreboard_contract = {
		"panel_size": SCOREBOARD_PANEL_SIZE,
		"world_position": _to_world_point(Vector3(COURT_HALF_WIDTH_M + 9.6, SCOREBOARD_POST_SIZE.y, 0.0)),
	}
	_opponent_contract = {
		"player_id": "away_opponent_1",
		"team_id": "away",
		"team_color_id": "away",
		"role_id": "baseline_opponent",
		"local_anchor_position": AWAY_BASELINE_ANCHOR_LOCAL,
		"idle_facing_direction": Vector3(0.0, 0.0, 1.0),
	}
	if _opponent_state.is_empty():
		_opponent_state = _build_default_opponent_state()

func _build_service_box_contracts() -> Dictionary:
	return {
		"service_box_deuce_home": _build_service_box_contract("service_box_deuce_home", Rect2(Vector2(0.0, 0.0), Vector2(COURT_HALF_WIDTH_M, SERVICE_LINE_DISTANCE_M))),
		"service_box_ad_home": _build_service_box_contract("service_box_ad_home", Rect2(Vector2(-COURT_HALF_WIDTH_M, 0.0), Vector2(COURT_HALF_WIDTH_M, SERVICE_LINE_DISTANCE_M))),
		"service_box_deuce_away": _build_service_box_contract("service_box_deuce_away", Rect2(Vector2(-COURT_HALF_WIDTH_M, -SERVICE_LINE_DISTANCE_M), Vector2(COURT_HALF_WIDTH_M, SERVICE_LINE_DISTANCE_M))),
		"service_box_ad_away": _build_service_box_contract("service_box_ad_away", Rect2(Vector2(0.0, -SERVICE_LINE_DISTANCE_M), Vector2(COURT_HALF_WIDTH_M, SERVICE_LINE_DISTANCE_M))),
	}

func _build_service_box_contract(service_box_id: String, rect: Rect2) -> Dictionary:
	var local_center := Vector3(rect.get_center().x, 0.0, rect.get_center().y)
	return {
		"service_box_id": service_box_id,
		"local_center": local_center,
		"world_center": _to_world_point(local_center),
		"rect": {
			"position": rect.position,
			"size": rect.size,
		},
	}

func _ensure_podium() -> void:
	var podium_root := _ensure_static_body_root("CourtPodium")
	podium_root.collision_layer = PLAY_SURFACE_COLLISION_LAYER_VALUE | 1
	podium_root.collision_mask = PLAY_SURFACE_COLLISION_LAYER_VALUE | 1
	var podium_size := _get_podium_size()
	var foundation_size := Vector3(podium_size.x, PODIUM_DEPTH_M - PODIUM_TOP_RECESS_M, podium_size.z)
	var foundation_position := Vector3(0.0, -PODIUM_DEPTH_M * 0.5 - PODIUM_TOP_RECESS_M * 0.5, 0.0)
	_ensure_visual_box(
		podium_root,
		"Foundation",
		foundation_position,
		foundation_size,
		PODIUM_COLOR
	)
	var collision_shape := podium_root.get_node_or_null("FoundationCollision") as CollisionShape3D
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "FoundationCollision"
		podium_root.add_child(collision_shape)
	collision_shape.position = foundation_position
	collision_shape.shape = _get_shared_box_shape(foundation_size)

func _ensure_apron() -> void:
	var apron_root := _ensure_static_body_root("CourtApron")
	apron_root.collision_layer = PLAY_SURFACE_COLLISION_LAYER_VALUE | 1
	apron_root.collision_mask = PLAY_SURFACE_COLLISION_LAYER_VALUE | 1
	var podium_size := _get_podium_size()
	var apron_y := -APRON_THICKNESS_M * 0.5
	_ensure_apron_segment(apron_root, "NorthApron", Vector3(0.0, apron_y, -COURT_HALF_LENGTH_M - PODIUM_MARGIN_Z_M * 0.5), Vector3(podium_size.x, APRON_THICKNESS_M, PODIUM_MARGIN_Z_M), APRON_COLOR)
	_ensure_apron_segment(apron_root, "SouthApron", Vector3(0.0, apron_y, COURT_HALF_LENGTH_M + PODIUM_MARGIN_Z_M * 0.5), Vector3(podium_size.x, APRON_THICKNESS_M, PODIUM_MARGIN_Z_M), APRON_COLOR)
	_ensure_apron_segment(apron_root, "WestApron", Vector3(-COURT_HALF_WIDTH_M - PODIUM_MARGIN_X_M * 0.5, apron_y, 0.0), Vector3(PODIUM_MARGIN_X_M, APRON_THICKNESS_M, COURT_LENGTH_M), APRON_COLOR)
	_ensure_apron_segment(apron_root, "EastApron", Vector3(COURT_HALF_WIDTH_M + PODIUM_MARGIN_X_M * 0.5, apron_y, 0.0), Vector3(PODIUM_MARGIN_X_M, APRON_THICKNESS_M, COURT_LENGTH_M), APRON_COLOR)

func _ensure_play_surface() -> void:
	var floor_node := get_node_or_null("PlayableFloor") as StaticBody3D
	if floor_node == null:
		floor_node = StaticBody3D.new()
		floor_node.name = "PlayableFloor"
		add_child(floor_node)
	floor_node.collision_layer = PLAY_SURFACE_COLLISION_LAYER_VALUE | 1
	floor_node.collision_mask = PLAY_SURFACE_COLLISION_LAYER_VALUE | 1
	var floor_shape := floor_node.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if floor_shape == null:
		floor_shape = CollisionShape3D.new()
		floor_shape.name = "CollisionShape3D"
		floor_node.add_child(floor_shape)
	floor_shape.shape = _get_shared_box_shape(Vector3(SINGLES_WIDTH_M, PLAY_SURFACE_THICKNESS_M, COURT_LENGTH_M))
	floor_node.position = Vector3(0.0, -PLAY_SURFACE_THICKNESS_M * 0.5, 0.0)
	var mesh_instance := floor_node.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		floor_node.add_child(mesh_instance)
	mesh_instance.mesh = _get_shared_box_mesh(Vector3(SINGLES_WIDTH_M, PLAY_SURFACE_THICKNESS_M, COURT_LENGTH_M))
	mesh_instance.material_override = _get_shared_box_material(COURT_COLOR, 0.92)

func _ensure_court_markings() -> void:
	var markings_root := get_node_or_null("CourtMarkings") as Node3D
	if markings_root == null:
		markings_root = Node3D.new()
		markings_root.name = "CourtMarkings"
		add_child(markings_root)
	var line_y := LINE_HEIGHT_M * 0.5
	_ensure_visual_box(markings_root, "NorthBaseline", Vector3(0.0, line_y, -COURT_HALF_LENGTH_M + LINE_THICKNESS_M * 0.5), Vector3(SINGLES_WIDTH_M, LINE_HEIGHT_M, LINE_THICKNESS_M), LINE_COLOR)
	_ensure_visual_box(markings_root, "SouthBaseline", Vector3(0.0, line_y, COURT_HALF_LENGTH_M - LINE_THICKNESS_M * 0.5), Vector3(SINGLES_WIDTH_M, LINE_HEIGHT_M, LINE_THICKNESS_M), LINE_COLOR)
	_ensure_visual_box(markings_root, "WestSingles", Vector3(-COURT_HALF_WIDTH_M + LINE_THICKNESS_M * 0.5, line_y, 0.0), Vector3(LINE_THICKNESS_M, LINE_HEIGHT_M, COURT_LENGTH_M), LINE_COLOR)
	_ensure_visual_box(markings_root, "EastSingles", Vector3(COURT_HALF_WIDTH_M - LINE_THICKNESS_M * 0.5, line_y, 0.0), Vector3(LINE_THICKNESS_M, LINE_HEIGHT_M, COURT_LENGTH_M), LINE_COLOR)
	_ensure_visual_box(markings_root, "CenterServiceLine", Vector3(0.0, line_y, 0.0), Vector3(LINE_THICKNESS_M, LINE_HEIGHT_M, SERVICE_LINE_DISTANCE_M * 2.0), LINE_COLOR)
	_ensure_visual_box(markings_root, "NorthServiceLine", Vector3(0.0, line_y, -SERVICE_LINE_DISTANCE_M + LINE_THICKNESS_M * 0.5), Vector3(SINGLES_WIDTH_M, LINE_HEIGHT_M, LINE_THICKNESS_M), LINE_COLOR)
	_ensure_visual_box(markings_root, "SouthServiceLine", Vector3(0.0, line_y, SERVICE_LINE_DISTANCE_M - LINE_THICKNESS_M * 0.5), Vector3(SINGLES_WIDTH_M, LINE_HEIGHT_M, LINE_THICKNESS_M), LINE_COLOR)
	_ensure_visual_box(markings_root, "HomeCenterMark", Vector3(0.0, line_y, COURT_HALF_LENGTH_M - 0.36), Vector3(LINE_THICKNESS_M, LINE_HEIGHT_M, 0.72), LINE_COLOR)
	_ensure_visual_box(markings_root, "AwayCenterMark", Vector3(0.0, line_y, -COURT_HALF_LENGTH_M + 0.36), Vector3(LINE_THICKNESS_M, LINE_HEIGHT_M, 0.72), LINE_COLOR)

func _ensure_net() -> void:
	var net_root := _ensure_static_body_root("Net")
	net_root.collision_layer = PLAY_SURFACE_COLLISION_LAYER_VALUE | 1
	net_root.collision_mask = PLAY_SURFACE_COLLISION_LAYER_VALUE | 1
	var collision_shape := net_root.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		net_root.add_child(collision_shape)
	collision_shape.position = Vector3(0.0, NET_CENTER_HEIGHT_M * 0.5, 0.0)
	collision_shape.shape = _get_shared_box_shape(Vector3(SINGLES_WIDTH_M + 0.22, NET_CENTER_HEIGHT_M, NET_COLLISION_THICKNESS_M))
	_ensure_visual_box(net_root, "NetMesh", Vector3(0.0, NET_CENTER_HEIGHT_M * 0.5, 0.0), Vector3(SINGLES_WIDTH_M + 0.18, NET_CENTER_HEIGHT_M, 0.05), NET_COLOR)
	_ensure_visual_box(net_root, "TopTape", Vector3(0.0, NET_CENTER_HEIGHT_M, 0.0), Vector3(SINGLES_WIDTH_M + 0.28, 0.05, 0.08), NET_POST_COLOR)
	_ensure_visual_box(net_root, "WestPost", Vector3(-COURT_HALF_WIDTH_M - 0.06, NET_POST_HEIGHT_M * 0.5, 0.0), Vector3(0.12, NET_POST_HEIGHT_M, 0.12), NET_POST_COLOR)
	_ensure_visual_box(net_root, "EastPost", Vector3(COURT_HALF_WIDTH_M + 0.06, NET_POST_HEIGHT_M * 0.5, 0.0), Vector3(0.12, NET_POST_HEIGHT_M, 0.12), NET_POST_COLOR)

func _ensure_scoreboard() -> void:
	var scoreboard_root := get_node_or_null("Scoreboard") as Node3D
	if scoreboard_root == null:
		scoreboard_root = Node3D.new()
		scoreboard_root.name = "Scoreboard"
		add_child(scoreboard_root)
	scoreboard_root.position = Vector3(COURT_HALF_WIDTH_M + 9.6, SCOREBOARD_POST_SIZE.y, 0.0)
	scoreboard_root.rotation.y = -PI * 0.5
	_ensure_visual_box(scoreboard_root, "Panel", Vector3.ZERO, SCOREBOARD_PANEL_SIZE, SCOREBOARD_COLOR)
	_ensure_visual_box(scoreboard_root, "LeftPost", Vector3(-SCOREBOARD_PANEL_SIZE.x * 0.36, -SCOREBOARD_POST_SIZE.y * 0.5, 0.0), SCOREBOARD_POST_SIZE, SCOREBOARD_COLOR)
	_ensure_visual_box(scoreboard_root, "RightPost", Vector3(SCOREBOARD_PANEL_SIZE.x * 0.36, -SCOREBOARD_POST_SIZE.y * 0.5, 0.0), SCOREBOARD_POST_SIZE, SCOREBOARD_COLOR)
	_ensure_scoreboard_label(scoreboard_root, "GamesLabel", Vector3(0.0, 0.72, SCOREBOARD_PANEL_SIZE.z * 0.56), 38)
	_ensure_scoreboard_label(scoreboard_root, "PointsLabel", Vector3(0.0, 0.08, SCOREBOARD_PANEL_SIZE.z * 0.56), 32)
	_ensure_scoreboard_label(scoreboard_root, "StateLabel", Vector3(0.0, -0.64, SCOREBOARD_PANEL_SIZE.z * 0.56), 18)
	_ensure_winner_highlight(scoreboard_root)

func _ensure_match_start_ring() -> void:
	if _match_start_ring == null or not is_instance_valid(_match_start_ring):
		_match_start_ring = CityWorldRingMarker.new()
		_match_start_ring.name = "MatchStartRing"
		add_child(_match_start_ring)
	_match_start_ring.set_marker_theme(str(_match_start_contract.get("theme_id", "task_available_start")))
	_match_start_ring.set_marker_radius(float(_match_start_contract.get("trigger_radius_m", MATCH_START_RING_RADIUS_M)))
	_match_start_ring.set_marker_world_position(_match_start_contract.get("world_position", global_position))
	_match_start_ring.set_marker_visible(bool(_match_start_contract.get("visible", true)))

func _ensure_receive_landing_marker() -> void:
	if _receive_landing_marker == null or not is_instance_valid(_receive_landing_marker):
		_receive_landing_marker = CityWorldRingMarker.new()
		_receive_landing_marker.name = "ReceiveLandingMarker"
		add_child(_receive_landing_marker)
	_receive_landing_marker.set_marker_theme("task_active_objective")
	_apply_receive_landing_marker_state()

func _apply_receive_landing_marker_state() -> void:
	if _receive_landing_marker == null or not is_instance_valid(_receive_landing_marker):
		return
	_receive_landing_marker.set_marker_radius(float(_receive_hint_state.get("marker_radius_m", 4.2)))
	_receive_landing_marker.set_marker_world_position(_receive_hint_state.get("landing_marker_world_position", global_position))
	_receive_landing_marker.set_marker_visible(bool(_receive_hint_state.get("landing_marker_visible", false)))

func _ensure_opponent_node() -> void:
	var opponent_root := get_node_or_null("OpponentRoot") as Node3D
	if opponent_root == null:
		opponent_root = Node3D.new()
		opponent_root.name = "OpponentRoot"
		add_child(opponent_root)
	if _opponent_node == null or not is_instance_valid(_opponent_node):
		_opponent_node = opponent_root.get_node_or_null("away_opponent_1") as Node3D
	if _opponent_node == null:
		_opponent_node = TennisOpponent.new()
		_opponent_node.name = "away_opponent_1"
		opponent_root.add_child(_opponent_node)
	if _opponent_node.has_method("configure_opponent"):
		_opponent_node.configure_opponent(_opponent_contract)
	if _opponent_node.has_method("apply_runtime_state"):
		_opponent_node.apply_runtime_state(_opponent_state if not _opponent_state.is_empty() else _build_default_opponent_state())

func _apply_scoreboard_state() -> void:
	var scoreboard_root := get_node_or_null("Scoreboard") as Node3D
	if scoreboard_root == null:
		return
	var games_label := scoreboard_root.get_node_or_null("GamesLabel") as Label3D
	if games_label != null:
		games_label.text = "%d  |  %d" % [int(_scoreboard_state.get("home_games", 0)), int(_scoreboard_state.get("away_games", 0))]
	var points_label := scoreboard_root.get_node_or_null("PointsLabel") as Label3D
	if points_label != null:
		points_label.text = "%s  :  %s" % [str(_scoreboard_state.get("home_point_label", "0")), str(_scoreboard_state.get("away_point_label", "0"))]
	var state_label := scoreboard_root.get_node_or_null("StateLabel") as Label3D
	if state_label != null:
		var state_text := str(_scoreboard_state.get("match_state", "idle")).to_upper()
		var winner_side := str(_scoreboard_state.get("winner_side", ""))
		if winner_side != "":
			state_text = "%s WINS" % winner_side.to_upper()
		elif str(_scoreboard_state.get("point_end_reason", "")) != "":
			state_text = str(_scoreboard_state.get("point_end_reason", "")).to_upper()
		state_label.text = state_text
	var winner_highlight := scoreboard_root.get_node_or_null("WinnerHighlight") as MeshInstance3D
	if winner_highlight != null:
		winner_highlight.visible = str(_scoreboard_state.get("winner_side", "")) != ""

func _ensure_apron_segment(root: StaticBody3D, node_name: String, local_position: Vector3, size: Vector3, color: Color) -> void:
	_ensure_visual_box(root, node_name, local_position, size, color)
	var collision_shape_name := "%sCollision" % node_name
	var collision_shape := root.get_node_or_null(collision_shape_name) as CollisionShape3D
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = collision_shape_name
		root.add_child(collision_shape)
	collision_shape.position = local_position
	collision_shape.shape = _get_shared_box_shape(size)

func _ensure_visual_box(root: Node3D, node_name: String, local_position: Vector3, size: Vector3, color: Color) -> void:
	var node := root.get_node_or_null(node_name) as MeshInstance3D
	if node == null:
		node = MeshInstance3D.new()
		node.name = node_name
		root.add_child(node)
	node.mesh = _get_shared_box_mesh(size)
	node.position = local_position
	node.material_override = _get_shared_box_material(color, 0.94)

func _ensure_scoreboard_label(scoreboard_root: Node3D, node_name: String, local_position: Vector3, font_size: int) -> void:
	var label := scoreboard_root.get_node_or_null(node_name) as Label3D
	if label == null:
		label = Label3D.new()
		label.name = node_name
		scoreboard_root.add_child(label)
	label.position = local_position
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.modulate = SCOREBOARD_TEXT_COLOR
	label.font_size = font_size
	label.pixel_size = 0.018
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.72)
	label.outline_size = 4

func _ensure_winner_highlight(scoreboard_root: Node3D) -> void:
	var highlight := scoreboard_root.get_node_or_null("WinnerHighlight") as MeshInstance3D
	if highlight == null:
		highlight = MeshInstance3D.new()
		highlight.name = "WinnerHighlight"
		scoreboard_root.add_child(highlight)
	var torus := highlight.mesh as TorusMesh
	if torus == null:
		torus = TorusMesh.new()
		highlight.mesh = torus
	torus.inner_radius = 0.74
	torus.outer_radius = 0.9
	torus.ring_segments = 16
	torus.rings = 36
	highlight.position = Vector3(0.0, 0.08, SCOREBOARD_PANEL_SIZE.z * 0.68)
	highlight.rotation.x = PI * 0.5
	highlight.visible = false
	highlight.material_override = _get_shared_box_material(SCOREBOARD_HIGHLIGHT_COLOR, 0.18)

func _ensure_static_body_root(node_name: String) -> StaticBody3D:
	var existing_node := get_node_or_null(node_name)
	if existing_node is StaticBody3D:
		return existing_node as StaticBody3D
	if existing_node != null:
		remove_child(existing_node)
		existing_node.queue_free()
	var static_body := StaticBody3D.new()
	static_body.name = node_name
	add_child(static_body)
	return static_body

func _build_default_opponent_state() -> Dictionary:
	return {
		"local_position": AWAY_BASELINE_ANCHOR_LOCAL,
		"facing_direction": Vector3(0.0, 0.0, 1.0),
		"animation_state": "idle",
	}

func _match_state_is_idle() -> bool:
	return str(_scoreboard_state.get("match_state", "idle")) == "idle"

func _to_world_contract_point(local_point: Vector3) -> Dictionary:
	return {
		"local_position": local_point,
		"world_position": _to_world_point(local_point),
	}

func _to_world_point(local_point: Vector3) -> Vector3:
	if is_inside_tree():
		return to_global(local_point)
	return _resolve_entry_world_position() + _resolve_scene_root_offset() + local_point

func _resolve_entry_world_position() -> Vector3:
	var world_position_variant: Variant = _entry.get("world_position", Vector3.ZERO)
	if world_position_variant is Vector3:
		return world_position_variant as Vector3
	return Vector3.ZERO

func _resolve_scene_root_offset() -> Vector3:
	var root_offset_variant: Variant = _entry.get("scene_root_offset", Vector3.ZERO)
	if root_offset_variant is Vector3:
		return root_offset_variant as Vector3
	return Vector3.ZERO

func _get_podium_size() -> Vector3:
	return Vector3(
		SINGLES_WIDTH_M + PODIUM_MARGIN_X_M * 2.0,
		PODIUM_DEPTH_M,
		COURT_LENGTH_M + PODIUM_MARGIN_Z_M * 2.0
	)

func _get_shared_box_mesh(size: Vector3) -> BoxMesh:
	var cache_key := _vector3_cache_key(size)
	if _shared_box_mesh_cache.has(cache_key):
		return _shared_box_mesh_cache.get(cache_key) as BoxMesh
	var mesh := BoxMesh.new()
	mesh.size = size
	_shared_box_mesh_cache[cache_key] = mesh
	return mesh

func _get_shared_box_shape(size: Vector3) -> BoxShape3D:
	var cache_key := _vector3_cache_key(size)
	if _shared_box_shape_cache.has(cache_key):
		return _shared_box_shape_cache.get(cache_key) as BoxShape3D
	var shape := BoxShape3D.new()
	shape.size = size
	_shared_box_shape_cache[cache_key] = shape
	return shape

func _get_shared_box_material(color: Color, roughness: float) -> StandardMaterial3D:
	var cache_key := "%s|%s" % [_color_cache_key(color), str(snappedf(roughness, 0.001))]
	if _shared_material_cache.has(cache_key):
		return _shared_material_cache.get(cache_key) as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	_shared_material_cache[cache_key] = material
	return material

func _vector3_cache_key(value: Vector3) -> String:
	return "%s,%s,%s" % [str(snappedf(value.x, 0.001)), str(snappedf(value.y, 0.001)), str(snappedf(value.z, 0.001))]

func _color_cache_key(value: Color) -> String:
	return "%s,%s,%s,%s" % [
		str(snappedf(value.r, 0.001)),
		str(snappedf(value.g, 0.001)),
		str(snappedf(value.b, 0.001)),
		str(snappedf(value.a, 0.001)),
	]
