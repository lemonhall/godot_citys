extends Node3D

const CityWorldRingMarker := preload("res://city_game/world/navigation/CityWorldRingMarker.gd")
const SoccerMatchPlayer := preload("res://city_game/serviceability/minigame_venues/generated/venue_v26_soccer_pitch_chunk_129_139/SoccerMatchPlayer.gd")

const PLAY_SURFACE_SIZE := Vector3(74.0, 0.36, 118.0)
const PLAY_SURFACE_COLOR := Color(0.227451, 0.521569, 0.215686, 1.0)
const PODIUM_COLOR := Color(0.47451, 0.454902, 0.427451, 1.0)
const APRON_COLOR := Color(0.666667, 0.643137, 0.603922, 1.0)
const PODIUM_MARGIN_X_M := 14.0
const PODIUM_MARGIN_Z_M := 16.0
const PODIUM_BASE_DEPTH_M := 3.4
const PODIUM_EMBED_EXTENSION_M := 4.0
const PODIUM_DEPTH_M := PODIUM_BASE_DEPTH_M + PODIUM_EMBED_EXTENSION_M
const PODIUM_TOP_REVEAL_M := 0.08
const APRON_THICKNESS_M := 0.16
const BOUNDARY_LINE_COLOR := Color(0.92, 0.94, 0.88, 1.0)
const BOUNDARY_LINE_THICKNESS_M := 0.18
const BOUNDARY_LINE_HEIGHT_M := 0.03
const CENTER_CIRCLE_RADIUS_M := 9.15
const CENTER_SPOT_RADIUS_M := 0.28
const CENTER_SPOT_HEIGHT_M := 0.03
const PENALTY_AREA_DEPTH_M := 16.5
const PENALTY_AREA_WIDTH_M := 40.32
const GOAL_BOX_DEPTH_M := 5.5
const GOAL_BOX_WIDTH_M := 18.32
const PENALTY_SPOT_DISTANCE_M := 11.0
const RELEASE_BUFFER_M := 24.0
const GOAL_WIDTH_M := 7.32
const GOAL_HEIGHT_M := 2.44
const GOAL_DEPTH_M := 3.0
const GOAL_FRAME_THICKNESS_M := 0.14
const GOAL_VISUAL_COLOR := Color(0.95, 0.96, 0.98, 1.0)
const SCOREBOARD_PANEL_SIZE := Vector3(6.4, 3.6, 0.18)
const SCOREBOARD_POST_SIZE := Vector3(0.26, 5.4, 0.26)
const SCOREBOARD_PANEL_COLOR := Color(0.08, 0.1, 0.12, 1.0)
const SCOREBOARD_TEXT_COLOR := Color(0.96, 0.98, 0.9, 1.0)
const PLAY_SURFACE_COLLISION_LAYER_VALUE := 1 << 8
const MATCH_START_RING_RADIUS_M := 3.25
const MATCH_START_RING_LOCAL_POSITION := Vector3(PLAY_SURFACE_SIZE.x * 0.5 + 7.6, 0.05, 8.0)
const MATCH_HOME_TEAM_COLOR_ID := "red"
const MATCH_AWAY_TEAM_COLOR_ID := "blue"
const MATCH_WINNER_HIGHLIGHT_COLOR := Color(0.92, 0.14, 0.12, 1.0)
const MATCH_WINNER_HIGHLIGHT_PANEL_Z := SCOREBOARD_PANEL_SIZE.z * 0.9

static var _shared_box_mesh_cache: Dictionary = {}
static var _shared_box_shape_cache: Dictionary = {}
static var _shared_material_cache: Dictionary = {}

var _entry: Dictionary = {}
var _play_surface_contract: Dictionary = {}
var _pitch_markings_contract: Dictionary = {}
var _goal_contracts: Dictionary = {}
var _match_start_contract: Dictionary = {}
var _match_roster_state: Dictionary = {}
var _match_player_contracts: Array = []
var _match_player_runtime_states: Dictionary = {}
var _match_player_nodes: Dictionary = {}
var _match_start_ring: Node3D = null
var _layout_initialized := false
var _scoreboard_state := {
	"home_score": 0,
	"away_score": 0,
	"game_state": "idle",
	"game_state_label": "READY",
	"last_scored_side": "",
	"winner_highlight_visible": false,
	"winner_highlight_side": "",
}

func _ready() -> void:
	_ensure_venue_layout_built()

func _process(delta: float) -> void:
	if _match_start_ring != null and is_instance_valid(_match_start_ring) and _match_start_ring.has_method("tick"):
		_match_start_ring.tick(delta)

func configure_minigame_venue(entry: Dictionary) -> void:
	_entry = entry.duplicate(true)
	_refresh_play_surface_contract()
	_rebuild_goal_contracts()
	_match_player_runtime_states.clear()
	_match_player_nodes.clear()
	_layout_initialized = false
	if is_inside_tree():
		_ensure_venue_layout_built()

func get_venue_contract() -> Dictionary:
	return _entry.duplicate(true)

func get_play_surface_contract() -> Dictionary:
	_ensure_venue_layout_built()
	return _play_surface_contract.duplicate(true)

func get_pitch_markings_contract() -> Dictionary:
	_ensure_venue_layout_built()
	return _pitch_markings_contract.duplicate(true)

func get_goal_contracts() -> Dictionary:
	_ensure_venue_layout_built()
	return _goal_contracts.duplicate(true)

func get_match_start_contract() -> Dictionary:
	_ensure_venue_layout_built()
	return _match_start_contract.duplicate(true)

func get_match_roster_state() -> Dictionary:
	_ensure_venue_layout_built()
	return _match_roster_state.duplicate(true)

func get_match_player_contracts() -> Array:
	_ensure_venue_layout_built()
	return _match_player_contracts.duplicate(true)

func get_scoreboard_contract() -> Dictionary:
	_ensure_venue_layout_built()
	var scoreboard_root := get_node_or_null("Scoreboard") as Node3D
	return {
		"world_position": scoreboard_root.global_position if scoreboard_root != null else global_position,
		"panel_size": SCOREBOARD_PANEL_SIZE,
		"state": _scoreboard_state.duplicate(true),
	}

func get_scoreboard_state() -> Dictionary:
	_ensure_venue_layout_built()
	return _scoreboard_state.duplicate(true)

func get_play_surface_collision_layer_value() -> int:
	return PLAY_SURFACE_COLLISION_LAYER_VALUE

func set_scoreboard_state(scoreboard_state: Dictionary) -> void:
	_ensure_venue_layout_built()
	_scoreboard_state = {
		"home_score": int(scoreboard_state.get("home_score", 0)),
		"away_score": int(scoreboard_state.get("away_score", 0)),
		"game_state": str(scoreboard_state.get("game_state", "idle")),
		"game_state_label": str(scoreboard_state.get("game_state_label", "READY")),
		"last_scored_side": str(scoreboard_state.get("last_scored_side", "")),
		"winner_highlight_visible": bool(scoreboard_state.get("winner_highlight_visible", false)),
		"winner_highlight_side": str(scoreboard_state.get("winner_highlight_side", "")),
	}
	_apply_scoreboard_state()

func sync_match_state(match_state: Dictionary) -> void:
	_ensure_venue_layout_built()
	_match_player_runtime_states = (match_state.get("player_states", {}) as Dictionary).duplicate(true)
	var start_ring_visible := bool(match_state.get("start_ring_visible", _match_start_contract.get("visible", true)))
	_match_start_contract["visible"] = start_ring_visible
	if _match_start_ring != null and is_instance_valid(_match_start_ring):
		_match_start_ring.set_marker_visible(start_ring_visible)
		_match_start_ring.set_marker_world_position(_match_start_contract.get("world_position", global_position))
	for player_contract_variant in _match_player_contracts:
		var player_contract: Dictionary = player_contract_variant
		var player_id := str(player_contract.get("player_id", ""))
		var player_node: Node3D = _match_player_nodes.get(player_id, null) as Node3D
		if player_node == null or not is_instance_valid(player_node):
			continue
		var player_state: Dictionary = (_match_player_runtime_states.get(player_id, _build_default_player_runtime_state(player_contract)) as Dictionary).duplicate(true)
		if player_node.has_method("apply_runtime_state"):
			player_node.apply_runtime_state(player_state)
	_refresh_match_roster_state(str(match_state.get("match_state", "idle")))

func is_world_point_in_match_start_ring(world_position: Vector3) -> bool:
	_ensure_venue_layout_built()
	var start_world_position: Vector3 = _match_start_contract.get("world_position", global_position)
	return world_position.distance_squared_to(start_world_position) <= pow(float(_match_start_contract.get("trigger_radius_m", MATCH_START_RING_RADIUS_M)), 2.0)

func is_world_point_in_play_bounds(world_position: Vector3) -> bool:
	_ensure_venue_layout_built()
	var local_position := to_local(world_position)
	var half_width := PLAY_SURFACE_SIZE.x * 0.5
	var half_length := PLAY_SURFACE_SIZE.z * 0.5
	return absf(local_position.x) <= half_width and absf(local_position.z) <= half_length

func is_world_point_in_release_bounds(world_position: Vector3) -> bool:
	_ensure_venue_layout_built()
	var local_position := to_local(world_position)
	var half_width := PLAY_SURFACE_SIZE.x * 0.5 + RELEASE_BUFFER_M
	var half_length := PLAY_SURFACE_SIZE.z * 0.5 + RELEASE_BUFFER_M
	return absf(local_position.x) <= half_width and absf(local_position.z) <= half_length

func evaluate_goal_hit(ball_world_position: Vector3, ball_linear_velocity: Vector3) -> Dictionary:
	_ensure_venue_layout_built()
	var local_ball_position := to_local(ball_world_position)
	var local_ball_velocity := global_basis.inverse() * ball_linear_velocity
	for goal_id_variant in _goal_contracts.keys():
		var goal_id := str(goal_id_variant)
		var goal_contract: Dictionary = (_goal_contracts.get(goal_id, {}) as Dictionary).duplicate(true)
		if _is_local_point_inside_goal(local_ball_position, goal_contract) and _is_goal_approach_valid(local_ball_velocity, goal_contract):
			return {
				"goal_id": goal_id,
				"scoring_side": str(goal_contract.get("scoring_side", "")),
				"goal_side": str(goal_contract.get("goal_side", "")),
			}
	return {}

func _ensure_venue_layout_built() -> void:
	if _layout_initialized:
		return
	_refresh_play_surface_contract()
	_refresh_pitch_markings_contract()
	_rebuild_goal_contracts()
	_refresh_match_start_contract()
	_rebuild_match_player_contracts()
	_ensure_pitch_podium()
	_ensure_pitch_apron()
	_ensure_playable_floor()
	_ensure_boundary_cues()
	_ensure_pitch_markings()
	_ensure_goals()
	_ensure_scoreboard()
	_ensure_match_start_ring()
	_ensure_match_players()
	_layout_initialized = true
	_refresh_match_roster_state("idle")
	_apply_scoreboard_state()

func _refresh_play_surface_contract() -> void:
	var kickoff_anchor := _resolve_kickoff_anchor()
	var surface_normal_variant: Variant = _entry.get("surface_normal", Vector3.UP)
	var surface_normal := Vector3.UP
	if surface_normal_variant is Vector3:
		surface_normal = surface_normal_variant as Vector3
	_play_surface_contract = {
		"venue_id": str(_entry.get("venue_id", "")),
		"game_kind": str(_entry.get("game_kind", "soccer_pitch")),
		"surface_top_y": kickoff_anchor.y,
		"surface_size": PLAY_SURFACE_SIZE,
		"kickoff_anchor": kickoff_anchor,
		"surface_normal": surface_normal,
		"podium_height_m": maxf(kickoff_anchor.y - _resolve_entry_world_position().y, 0.0),
		"podium_footprint_size": _get_podium_size(),
		"release_buffer_m": RELEASE_BUFFER_M,
	}

func _refresh_pitch_markings_contract() -> void:
	_pitch_markings_contract = {
		"line_thickness_m": BOUNDARY_LINE_THICKNESS_M,
		"line_height_m": BOUNDARY_LINE_HEIGHT_M,
		"halfway_line_length_m": PLAY_SURFACE_SIZE.x,
		"center_circle_radius_m": CENTER_CIRCLE_RADIUS_M,
		"penalty_area_depth_m": PENALTY_AREA_DEPTH_M,
		"penalty_area_width_m": PENALTY_AREA_WIDTH_M,
		"goal_box_depth_m": GOAL_BOX_DEPTH_M,
		"goal_box_width_m": GOAL_BOX_WIDTH_M,
		"penalty_spot_distance_m": PENALTY_SPOT_DISTANCE_M,
	}

func _refresh_match_start_contract() -> void:
	var local_position := MATCH_START_RING_LOCAL_POSITION
	_match_start_contract = {
		"theme_id": "task_available_start",
		"family_id": "city_world_ring_marker",
		"trigger_radius_m": MATCH_START_RING_RADIUS_M,
		"local_position": local_position,
		"world_position": to_global(local_position) if is_inside_tree() else _resolve_kickoff_anchor() + local_position,
		"visible": true,
	}

func _rebuild_match_player_contracts() -> void:
	var half_length := PLAY_SURFACE_SIZE.z * 0.5
	_match_player_contracts = [
		_build_match_player_contract("home_goalkeeper_1", "home", MATCH_HOME_TEAM_COLOR_ID, "goalkeeper", Vector3(0.0, 0.0, half_length - 8.0), Vector3(0.0, 0.0, -1.0), 0),
		_build_match_player_contract("home_field_1", "home", MATCH_HOME_TEAM_COLOR_ID, "field_player", Vector3(-17.0, 0.0, 28.0), Vector3(0.0, 0.0, -1.0), 1),
		_build_match_player_contract("home_field_2", "home", MATCH_HOME_TEAM_COLOR_ID, "field_player", Vector3(17.0, 0.0, 28.0), Vector3(0.0, 0.0, -1.0), 2),
		_build_match_player_contract("home_field_3", "home", MATCH_HOME_TEAM_COLOR_ID, "field_player", Vector3(-9.5, 0.0, 8.0), Vector3(0.0, 0.0, -1.0), 3),
		_build_match_player_contract("home_field_4", "home", MATCH_HOME_TEAM_COLOR_ID, "field_player", Vector3(9.5, 0.0, -10.0), Vector3(0.0, 0.0, -1.0), 4),
		_build_match_player_contract("away_goalkeeper_1", "away", MATCH_AWAY_TEAM_COLOR_ID, "goalkeeper", Vector3(0.0, 0.0, -half_length + 8.0), Vector3(0.0, 0.0, 1.0), 0),
		_build_match_player_contract("away_field_1", "away", MATCH_AWAY_TEAM_COLOR_ID, "field_player", Vector3(-17.0, 0.0, -28.0), Vector3(0.0, 0.0, 1.0), 1),
		_build_match_player_contract("away_field_2", "away", MATCH_AWAY_TEAM_COLOR_ID, "field_player", Vector3(17.0, 0.0, -28.0), Vector3(0.0, 0.0, 1.0), 2),
		_build_match_player_contract("away_field_3", "away", MATCH_AWAY_TEAM_COLOR_ID, "field_player", Vector3(-9.5, 0.0, -8.0), Vector3(0.0, 0.0, 1.0), 3),
		_build_match_player_contract("away_field_4", "away", MATCH_AWAY_TEAM_COLOR_ID, "field_player", Vector3(9.5, 0.0, 10.0), Vector3(0.0, 0.0, 1.0), 4),
	]

func _build_match_player_contract(player_id: String, team_id: String, team_color_id: String, role_id: String, local_anchor_position: Vector3, idle_facing_direction: Vector3, lane_index: int) -> Dictionary:
	return {
		"player_id": player_id,
		"team_id": team_id,
		"team_color_id": team_color_id,
		"role_id": role_id,
		"lane_index": lane_index,
		"local_anchor_position": local_anchor_position,
		"world_anchor_position": to_global(local_anchor_position) if is_inside_tree() else _resolve_kickoff_anchor() + local_anchor_position,
		"idle_facing_direction": idle_facing_direction,
	}

func _build_default_player_runtime_state(player_contract: Dictionary) -> Dictionary:
	return {
		"local_position": player_contract.get("local_anchor_position", Vector3.ZERO),
		"facing_direction": player_contract.get("idle_facing_direction", Vector3.FORWARD),
		"animation_state": "idle",
	}

func _refresh_match_roster_state(match_state: String = "idle") -> void:
	var team_counts := {
		"home": 0,
		"away": 0,
	}
	var goalkeeper_counts := {
		"home": 0,
		"away": 0,
	}
	var idle_player_count := 0
	var player_entries: Array = []
	var team_color_ids: Array = []
	for player_contract_variant in _match_player_contracts:
		var player_contract: Dictionary = player_contract_variant
		var player_id := str(player_contract.get("player_id", ""))
		var team_id := str(player_contract.get("team_id", ""))
		var role_id := str(player_contract.get("role_id", "field_player"))
		var team_color_id := str(player_contract.get("team_color_id", ""))
		if not team_color_ids.has(team_color_id):
			team_color_ids.append(team_color_id)
		team_counts[team_id] = int(team_counts.get(team_id, 0)) + 1
		if role_id == "goalkeeper":
			goalkeeper_counts[team_id] = int(goalkeeper_counts.get(team_id, 0)) + 1
		var player_state: Dictionary = (_match_player_runtime_states.get(player_id, _build_default_player_runtime_state(player_contract)) as Dictionary).duplicate(true)
		if str(player_state.get("animation_state", "idle")) == "idle":
			idle_player_count += 1
		player_entries.append({
			"player_id": player_id,
			"team_id": team_id,
			"team_color_id": team_color_id,
			"role_id": role_id,
			"state": player_state,
		})
	_match_roster_state = {
		"match_state": match_state,
		"player_count": _match_player_contracts.size(),
		"team_counts": team_counts,
		"goalkeeper_counts": goalkeeper_counts,
		"team_color_ids": team_color_ids,
		"idle_player_count": idle_player_count,
		"players": player_entries,
	}

func _rebuild_goal_contracts() -> void:
	var goal_center_z := PLAY_SURFACE_SIZE.z * 0.5 + GOAL_DEPTH_M * 0.5
	_goal_contracts = {
		"goal_a": _build_goal_contract("goal_a", Vector3(0.0, GOAL_HEIGHT_M * 0.5, -goal_center_z), "home", "away", -1.0),
		"goal_b": _build_goal_contract("goal_b", Vector3(0.0, GOAL_HEIGHT_M * 0.5, goal_center_z), "away", "home", 1.0),
	}

func _build_goal_contract(goal_id: String, local_center: Vector3, scoring_side: String, goal_side: String, approach_sign: float) -> Dictionary:
	var world_center := to_global(local_center) if is_inside_tree() else local_center
	return {
		"goal_id": goal_id,
		"scoring_side": scoring_side,
		"goal_side": goal_side,
		"local_center": local_center,
		"world_center": world_center,
		"volume_size": Vector3(GOAL_WIDTH_M, GOAL_HEIGHT_M, GOAL_DEPTH_M),
		"approach_sign_z": approach_sign,
	}

func _ensure_pitch_podium() -> void:
	var podium_root := _ensure_static_body_root("PitchPodium")
	podium_root.collision_layer = PLAY_SURFACE_COLLISION_LAYER_VALUE | 1
	podium_root.collision_mask = PLAY_SURFACE_COLLISION_LAYER_VALUE | 1
	var podium_size := _get_podium_size()
	var foundation_center_y := -PODIUM_DEPTH_M * 0.5 - PODIUM_TOP_REVEAL_M
	_ensure_visual_box(
		podium_root,
		"Foundation",
		Vector3(0.0, foundation_center_y, 0.0),
		Vector3(podium_size.x, PODIUM_DEPTH_M, podium_size.z),
		PODIUM_COLOR
	)
	var collision_shape := podium_root.get_node_or_null("FoundationCollision") as CollisionShape3D
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "FoundationCollision"
		podium_root.add_child(collision_shape)
	collision_shape.position = Vector3(0.0, -PODIUM_DEPTH_M * 0.5, 0.0)
	collision_shape.shape = _get_shared_box_shape(Vector3(podium_size.x, PODIUM_DEPTH_M, podium_size.z))

func _ensure_playable_floor() -> void:
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
	floor_shape.shape = _get_shared_box_shape(PLAY_SURFACE_SIZE)
	floor_node.position = Vector3(0.0, -PLAY_SURFACE_SIZE.y * 0.5, 0.0)
	var mesh_instance := floor_node.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		floor_node.add_child(mesh_instance)
	mesh_instance.mesh = _get_shared_box_mesh(PLAY_SURFACE_SIZE)
	mesh_instance.material_override = _get_shared_box_material(PLAY_SURFACE_COLOR, 1.0)

func _ensure_pitch_apron() -> void:
	var apron_root := get_node_or_null("PitchApron") as StaticBody3D
	if apron_root == null:
		apron_root = StaticBody3D.new()
		apron_root.name = "PitchApron"
		add_child(apron_root)
	apron_root.collision_layer = PLAY_SURFACE_COLLISION_LAYER_VALUE | 1
	apron_root.collision_mask = PLAY_SURFACE_COLLISION_LAYER_VALUE | 1
	var podium_size := _get_podium_size()
	var half_field_width := PLAY_SURFACE_SIZE.x * 0.5
	var half_field_length := PLAY_SURFACE_SIZE.z * 0.5
	var apron_y := -APRON_THICKNESS_M * 0.5
	_ensure_apron_segment(
		apron_root,
		"NorthApron",
		Vector3(0.0, apron_y, -half_field_length - PODIUM_MARGIN_Z_M * 0.5),
		Vector3(podium_size.x, APRON_THICKNESS_M, PODIUM_MARGIN_Z_M),
		APRON_COLOR
	)
	_ensure_apron_segment(
		apron_root,
		"SouthApron",
		Vector3(0.0, apron_y, half_field_length + PODIUM_MARGIN_Z_M * 0.5),
		Vector3(podium_size.x, APRON_THICKNESS_M, PODIUM_MARGIN_Z_M),
		APRON_COLOR
	)
	_ensure_apron_segment(
		apron_root,
		"WestApron",
		Vector3(-half_field_width - PODIUM_MARGIN_X_M * 0.5, apron_y, 0.0),
		Vector3(PODIUM_MARGIN_X_M, APRON_THICKNESS_M, PLAY_SURFACE_SIZE.z),
		APRON_COLOR
	)
	_ensure_apron_segment(
		apron_root,
		"EastApron",
		Vector3(half_field_width + PODIUM_MARGIN_X_M * 0.5, apron_y, 0.0),
		Vector3(PODIUM_MARGIN_X_M, APRON_THICKNESS_M, PLAY_SURFACE_SIZE.z),
		APRON_COLOR
	)

func _ensure_boundary_cues() -> void:
	var boundary_root := get_node_or_null("BoundaryCues") as Node3D
	if boundary_root == null:
		boundary_root = Node3D.new()
		boundary_root.name = "BoundaryCues"
		add_child(boundary_root)
	var half_width := PLAY_SURFACE_SIZE.x * 0.5
	var half_length := PLAY_SURFACE_SIZE.z * 0.5
	var line_y := BOUNDARY_LINE_HEIGHT_M * 0.5
	_ensure_boundary_line(boundary_root, "NorthLine", Vector3(0.0, line_y, -half_length + BOUNDARY_LINE_THICKNESS_M * 0.5), Vector3(PLAY_SURFACE_SIZE.x, BOUNDARY_LINE_HEIGHT_M, BOUNDARY_LINE_THICKNESS_M))
	_ensure_boundary_line(boundary_root, "SouthLine", Vector3(0.0, line_y, half_length - BOUNDARY_LINE_THICKNESS_M * 0.5), Vector3(PLAY_SURFACE_SIZE.x, BOUNDARY_LINE_HEIGHT_M, BOUNDARY_LINE_THICKNESS_M))
	_ensure_boundary_line(boundary_root, "WestLine", Vector3(-half_width + BOUNDARY_LINE_THICKNESS_M * 0.5, line_y, 0.0), Vector3(BOUNDARY_LINE_THICKNESS_M, BOUNDARY_LINE_HEIGHT_M, PLAY_SURFACE_SIZE.z))
	_ensure_boundary_line(boundary_root, "EastLine", Vector3(half_width - BOUNDARY_LINE_THICKNESS_M * 0.5, line_y, 0.0), Vector3(BOUNDARY_LINE_THICKNESS_M, BOUNDARY_LINE_HEIGHT_M, PLAY_SURFACE_SIZE.z))

func _ensure_pitch_markings() -> void:
	var markings_root := get_node_or_null("PitchMarkings") as Node3D
	if markings_root == null:
		markings_root = Node3D.new()
		markings_root.name = "PitchMarkings"
		add_child(markings_root)
	var line_y := BOUNDARY_LINE_HEIGHT_M * 0.5
	var half_length := PLAY_SURFACE_SIZE.z * 0.5
	_ensure_visual_box(
		markings_root,
		"HalfwayLine",
		Vector3(0.0, line_y, 0.0),
		Vector3(PLAY_SURFACE_SIZE.x, BOUNDARY_LINE_HEIGHT_M, BOUNDARY_LINE_THICKNESS_M),
		BOUNDARY_LINE_COLOR
	)
	_ensure_center_circle(markings_root, line_y)
	_ensure_disc_marker(markings_root, "CenterSpot", Vector3(0.0, line_y, 0.0), CENTER_SPOT_RADIUS_M, CENTER_SPOT_HEIGHT_M)
	_ensure_open_box_outline(
		markings_root,
		"PenaltyAreaA",
		Vector3(0.0, line_y, -half_length + PENALTY_AREA_DEPTH_M * 0.5),
		PENALTY_AREA_WIDTH_M,
		PENALTY_AREA_DEPTH_M,
		"north"
	)
	_ensure_open_box_outline(
		markings_root,
		"PenaltyAreaB",
		Vector3(0.0, line_y, half_length - PENALTY_AREA_DEPTH_M * 0.5),
		PENALTY_AREA_WIDTH_M,
		PENALTY_AREA_DEPTH_M,
		"south"
	)
	_ensure_open_box_outline(
		markings_root,
		"GoalBoxA",
		Vector3(0.0, line_y, -half_length + GOAL_BOX_DEPTH_M * 0.5),
		GOAL_BOX_WIDTH_M,
		GOAL_BOX_DEPTH_M,
		"north"
	)
	_ensure_open_box_outline(
		markings_root,
		"GoalBoxB",
		Vector3(0.0, line_y, half_length - GOAL_BOX_DEPTH_M * 0.5),
		GOAL_BOX_WIDTH_M,
		GOAL_BOX_DEPTH_M,
		"south"
	)
	_ensure_disc_marker(
		markings_root,
		"PenaltySpotA",
		Vector3(0.0, line_y, -half_length + PENALTY_SPOT_DISTANCE_M),
		CENTER_SPOT_RADIUS_M,
		CENTER_SPOT_HEIGHT_M
	)
	_ensure_disc_marker(
		markings_root,
		"PenaltySpotB",
		Vector3(0.0, line_y, half_length - PENALTY_SPOT_DISTANCE_M),
		CENTER_SPOT_RADIUS_M,
		CENTER_SPOT_HEIGHT_M
	)

func _ensure_goals() -> void:
	var goals_root := get_node_or_null("Goals") as Node3D
	if goals_root == null:
		goals_root = Node3D.new()
		goals_root.name = "Goals"
		add_child(goals_root)
	for goal_id_variant in _goal_contracts.keys():
		var goal_id := str(goal_id_variant)
		var goal_contract: Dictionary = _goal_contracts.get(goal_id, {})
		_ensure_goal_root(goals_root, goal_id, goal_contract)

func _ensure_goal_root(goals_root: Node3D, goal_id: String, goal_contract: Dictionary) -> void:
	var goal_root := goals_root.get_node_or_null(goal_id.capitalize()) as Node3D
	if goal_root == null:
		goal_root = Node3D.new()
		goal_root.name = goal_id.capitalize()
		goals_root.add_child(goal_root)
	var local_center: Vector3 = goal_contract.get("local_center", Vector3.ZERO)
	goal_root.position = local_center
	goal_root.set_meta("city_soccer_goal", true)
	goal_root.set_meta("city_soccer_goal_id", goal_id)
	goal_root.set_meta("city_soccer_goal_side", str(goal_contract.get("goal_side", "")))
	goal_root.set_meta("city_soccer_goal_scoring_side", str(goal_contract.get("scoring_side", "")))
	_ensure_goal_volume(goal_root, goal_contract)
	_ensure_goal_frame(goal_root)

func _ensure_goal_volume(goal_root: Node3D, goal_contract: Dictionary) -> void:
	var area := goal_root.get_node_or_null("GoalVolume") as Area3D
	if area == null:
		area = Area3D.new()
		area.name = "GoalVolume"
		goal_root.add_child(area)
	var collision_shape := area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		area.add_child(collision_shape)
	var volume_size: Vector3 = goal_contract.get("volume_size", Vector3(GOAL_WIDTH_M, GOAL_HEIGHT_M, GOAL_DEPTH_M))
	collision_shape.shape = _get_shared_box_shape(volume_size)

func _ensure_goal_frame(goal_root: Node3D) -> void:
	var frame_root := goal_root.get_node_or_null("Frame") as Node3D
	if frame_root == null:
		frame_root = Node3D.new()
		frame_root.name = "Frame"
		goal_root.add_child(frame_root)
	var half_width := GOAL_WIDTH_M * 0.5
	var half_height := GOAL_HEIGHT_M * 0.5
	var half_depth := GOAL_DEPTH_M * 0.5
	_ensure_visual_box(frame_root, "LeftPost", Vector3(-half_width + GOAL_FRAME_THICKNESS_M * 0.5, 0.0, 0.0), Vector3(GOAL_FRAME_THICKNESS_M, GOAL_HEIGHT_M, GOAL_FRAME_THICKNESS_M))
	_ensure_visual_box(frame_root, "RightPost", Vector3(half_width - GOAL_FRAME_THICKNESS_M * 0.5, 0.0, 0.0), Vector3(GOAL_FRAME_THICKNESS_M, GOAL_HEIGHT_M, GOAL_FRAME_THICKNESS_M))
	_ensure_visual_box(frame_root, "Crossbar", Vector3(0.0, half_height - GOAL_FRAME_THICKNESS_M * 0.5, 0.0), Vector3(GOAL_WIDTH_M, GOAL_FRAME_THICKNESS_M, GOAL_FRAME_THICKNESS_M))
	_ensure_visual_box(frame_root, "Backbar", Vector3(0.0, half_height - GOAL_FRAME_THICKNESS_M * 0.5, half_depth - GOAL_FRAME_THICKNESS_M * 0.5), Vector3(GOAL_WIDTH_M, GOAL_FRAME_THICKNESS_M, GOAL_FRAME_THICKNESS_M))
	_ensure_visual_box(frame_root, "LeftRearPost", Vector3(-half_width + GOAL_FRAME_THICKNESS_M * 0.5, 0.0, half_depth - GOAL_FRAME_THICKNESS_M * 0.5), Vector3(GOAL_FRAME_THICKNESS_M, GOAL_HEIGHT_M, GOAL_FRAME_THICKNESS_M))
	_ensure_visual_box(frame_root, "RightRearPost", Vector3(half_width - GOAL_FRAME_THICKNESS_M * 0.5, 0.0, half_depth - GOAL_FRAME_THICKNESS_M * 0.5), Vector3(GOAL_FRAME_THICKNESS_M, GOAL_HEIGHT_M, GOAL_FRAME_THICKNESS_M))

func _ensure_match_start_ring() -> void:
	if _match_start_ring == null or not is_instance_valid(_match_start_ring):
		_match_start_ring = CityWorldRingMarker.new()
		_match_start_ring.name = "MatchStartRing"
		add_child(_match_start_ring)
	_match_start_ring.set_marker_theme(str(_match_start_contract.get("theme_id", "task_available_start")))
	_match_start_ring.set_marker_radius(float(_match_start_contract.get("trigger_radius_m", MATCH_START_RING_RADIUS_M)))
	_match_start_ring.set_marker_world_position(_match_start_contract.get("world_position", global_position))
	_match_start_ring.set_marker_visible(bool(_match_start_contract.get("visible", true)))

func _ensure_match_players() -> void:
	var player_root := get_node_or_null("MatchPlayers") as Node3D
	if player_root == null:
		player_root = Node3D.new()
		player_root.name = "MatchPlayers"
		add_child(player_root)
	var seen_ids: Dictionary = {}
	_match_player_nodes.clear()
	for player_contract_variant in _match_player_contracts:
		var player_contract: Dictionary = player_contract_variant
		var player_id := str(player_contract.get("player_id", ""))
		seen_ids[player_id] = true
		var player_node := player_root.get_node_or_null(player_id) as Node3D
		if player_node == null:
			player_node = SoccerMatchPlayer.new()
			player_node.name = player_id
			player_root.add_child(player_node)
		_match_player_nodes[player_id] = player_node
		if player_node.has_method("configure_player"):
			player_node.configure_player(player_contract)
		if player_node.has_method("apply_runtime_state"):
			player_node.apply_runtime_state((_match_player_runtime_states.get(player_id, _build_default_player_runtime_state(player_contract)) as Dictionary).duplicate(true))
	for child in player_root.get_children():
		if not seen_ids.has(child.name):
			child.queue_free()

func _ensure_scoreboard() -> void:
	var scoreboard_root := get_node_or_null("Scoreboard") as Node3D
	if scoreboard_root == null:
		scoreboard_root = Node3D.new()
		scoreboard_root.name = "Scoreboard"
		add_child(scoreboard_root)
	var sideline_offset_x := PLAY_SURFACE_SIZE.x * 0.5 + 10.0
	scoreboard_root.position = Vector3(sideline_offset_x, SCOREBOARD_POST_SIZE.y, 0.0)
	scoreboard_root.rotation.y = -PI * 0.5
	_ensure_visual_box(scoreboard_root, "Panel", Vector3(0.0, 0.0, 0.0), SCOREBOARD_PANEL_SIZE, SCOREBOARD_PANEL_COLOR)
	_ensure_visual_box(scoreboard_root, "LeftPost", Vector3(-SCOREBOARD_PANEL_SIZE.x * 0.35, -SCOREBOARD_POST_SIZE.y * 0.5, 0.0), SCOREBOARD_POST_SIZE, SCOREBOARD_PANEL_COLOR)
	_ensure_visual_box(scoreboard_root, "RightPost", Vector3(SCOREBOARD_PANEL_SIZE.x * 0.35, -SCOREBOARD_POST_SIZE.y * 0.5, 0.0), SCOREBOARD_POST_SIZE, SCOREBOARD_PANEL_COLOR)
	_ensure_scoreboard_label(scoreboard_root, "HomeScoreLabel", Vector3(-1.45, 0.52, SCOREBOARD_PANEL_SIZE.z * 0.55), 92)
	_ensure_scoreboard_label(scoreboard_root, "AwayScoreLabel", Vector3(1.45, 0.52, SCOREBOARD_PANEL_SIZE.z * 0.55), 92)
	_ensure_scoreboard_label(scoreboard_root, "StateLabel", Vector3(0.0, -0.78, SCOREBOARD_PANEL_SIZE.z * 0.55), 42)
	_ensure_scoreboard_winner_highlight(scoreboard_root, "HomeWinnerHighlight", Vector3(-1.45, 0.52, MATCH_WINNER_HIGHLIGHT_PANEL_Z))
	_ensure_scoreboard_winner_highlight(scoreboard_root, "AwayWinnerHighlight", Vector3(1.45, 0.52, MATCH_WINNER_HIGHLIGHT_PANEL_Z))

func _apply_scoreboard_state() -> void:
	var scoreboard_root := get_node_or_null("Scoreboard") as Node3D
	if scoreboard_root == null:
		return
	var home_label := scoreboard_root.get_node_or_null("HomeScoreLabel") as Label3D
	if home_label != null:
		home_label.text = str(int(_scoreboard_state.get("home_score", 0)))
	var away_label := scoreboard_root.get_node_or_null("AwayScoreLabel") as Label3D
	if away_label != null:
		away_label.text = str(int(_scoreboard_state.get("away_score", 0)))
	var state_label := scoreboard_root.get_node_or_null("StateLabel") as Label3D
	if state_label != null:
		state_label.text = str(_scoreboard_state.get("game_state_label", "READY"))
	var winner_highlight_side := str(_scoreboard_state.get("winner_highlight_side", ""))
	var winner_highlight_visible := bool(_scoreboard_state.get("winner_highlight_visible", false))
	var home_highlight := scoreboard_root.get_node_or_null("HomeWinnerHighlight") as MeshInstance3D
	if home_highlight != null:
		home_highlight.visible = winner_highlight_visible and winner_highlight_side == "home"
	var away_highlight := scoreboard_root.get_node_or_null("AwayWinnerHighlight") as MeshInstance3D
	if away_highlight != null:
		away_highlight.visible = winner_highlight_visible and winner_highlight_side == "away"

func _ensure_boundary_line(root: Node3D, node_name: String, local_position: Vector3, size: Vector3) -> void:
	_ensure_visual_box(root, node_name, local_position, size, BOUNDARY_LINE_COLOR)

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

func _ensure_center_circle(root: Node3D, line_y: float) -> void:
	var node := root.get_node_or_null("CenterCircle") as MeshInstance3D
	if node == null:
		node = MeshInstance3D.new()
		node.name = "CenterCircle"
		root.add_child(node)
	var torus := node.mesh as TorusMesh
	if torus == null:
		torus = TorusMesh.new()
		node.mesh = torus
	torus.inner_radius = CENTER_CIRCLE_RADIUS_M - BOUNDARY_LINE_THICKNESS_M * 0.5
	torus.outer_radius = CENTER_CIRCLE_RADIUS_M + BOUNDARY_LINE_THICKNESS_M * 0.5
	torus.ring_segments = 24
	torus.rings = 48
	node.position = Vector3(0.0, line_y, 0.0)
	node.scale = Vector3(1.0, BOUNDARY_LINE_HEIGHT_M / maxf(BOUNDARY_LINE_THICKNESS_M, 0.001), 1.0)
	node.material_override = _get_shared_box_material(BOUNDARY_LINE_COLOR, 1.0)

func _ensure_disc_marker(root: Node3D, node_name: String, local_position: Vector3, radius_m: float, height_m: float) -> void:
	var node := root.get_node_or_null(node_name) as MeshInstance3D
	if node == null:
		node = MeshInstance3D.new()
		node.name = node_name
		root.add_child(node)
	var cylinder := node.mesh as CylinderMesh
	if cylinder == null:
		cylinder = CylinderMesh.new()
		node.mesh = cylinder
	cylinder.top_radius = radius_m
	cylinder.bottom_radius = radius_m
	cylinder.height = height_m
	cylinder.radial_segments = 24
	node.position = local_position
	node.material_override = _get_shared_box_material(BOUNDARY_LINE_COLOR, 1.0)

func _ensure_open_box_outline(root: Node3D, node_name: String, local_center: Vector3, width_m: float, depth_m: float, goal_side: String) -> void:
	var outline_root := root.get_node_or_null(node_name) as Node3D
	if outline_root == null:
		outline_root = Node3D.new()
		outline_root.name = node_name
		root.add_child(outline_root)
	outline_root.position = local_center
	var half_width := width_m * 0.5
	match goal_side:
		"north":
			_ensure_boundary_line(outline_root, "FieldLine", Vector3(0.0, 0.0, depth_m * 0.5 - BOUNDARY_LINE_THICKNESS_M * 0.5), Vector3(width_m, BOUNDARY_LINE_HEIGHT_M, BOUNDARY_LINE_THICKNESS_M))
		"south":
			_ensure_boundary_line(outline_root, "FieldLine", Vector3(0.0, 0.0, -depth_m * 0.5 + BOUNDARY_LINE_THICKNESS_M * 0.5), Vector3(width_m, BOUNDARY_LINE_HEIGHT_M, BOUNDARY_LINE_THICKNESS_M))
		_:
			_ensure_boundary_line(outline_root, "FieldLine", Vector3(0.0, 0.0, 0.0), Vector3(width_m, BOUNDARY_LINE_HEIGHT_M, BOUNDARY_LINE_THICKNESS_M))
	_ensure_boundary_line(
		outline_root,
		"WestLine",
		Vector3(-half_width + BOUNDARY_LINE_THICKNESS_M * 0.5, 0.0, 0.0),
		Vector3(BOUNDARY_LINE_THICKNESS_M, BOUNDARY_LINE_HEIGHT_M, depth_m)
	)
	_ensure_boundary_line(
		outline_root,
		"EastLine",
		Vector3(half_width - BOUNDARY_LINE_THICKNESS_M * 0.5, 0.0, 0.0),
		Vector3(BOUNDARY_LINE_THICKNESS_M, BOUNDARY_LINE_HEIGHT_M, depth_m)
	)

func _ensure_visual_box(root: Node3D, node_name: String, local_position: Vector3, size: Vector3, color: Color = GOAL_VISUAL_COLOR) -> void:
	var node := root.get_node_or_null(node_name) as MeshInstance3D
	if node == null:
		node = MeshInstance3D.new()
		node.name = node_name
		root.add_child(node)
	node.mesh = _get_shared_box_mesh(size)
	node.position = local_position
	node.material_override = _get_shared_box_material(color, 0.92)

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
	label.pixel_size = 0.02

func _ensure_scoreboard_winner_highlight(scoreboard_root: Node3D, node_name: String, local_position: Vector3) -> void:
	var highlight := scoreboard_root.get_node_or_null(node_name) as MeshInstance3D
	if highlight == null:
		highlight = MeshInstance3D.new()
		highlight.name = node_name
		scoreboard_root.add_child(highlight)
	var torus := highlight.mesh as TorusMesh
	if torus == null:
		torus = TorusMesh.new()
		highlight.mesh = torus
	torus.inner_radius = 0.46
	torus.outer_radius = 0.58
	torus.ring_segments = 14
	torus.rings = 36
	highlight.position = local_position
	highlight.rotation.x = PI * 0.5
	highlight.visible = false
	highlight.material_override = _get_shared_box_material(MATCH_WINNER_HIGHLIGHT_COLOR, 0.28)

func _is_local_point_inside_goal(local_ball_position: Vector3, goal_contract: Dictionary) -> bool:
	var local_center: Vector3 = goal_contract.get("local_center", Vector3.ZERO)
	var volume_size: Vector3 = goal_contract.get("volume_size", Vector3(GOAL_WIDTH_M, GOAL_HEIGHT_M, GOAL_DEPTH_M))
	var half_extents := volume_size * 0.5
	return absf(local_ball_position.x - local_center.x) <= half_extents.x \
		and absf(local_ball_position.y - local_center.y) <= half_extents.y \
		and absf(local_ball_position.z - local_center.z) <= half_extents.z

func _is_goal_approach_valid(local_ball_velocity: Vector3, goal_contract: Dictionary) -> bool:
	var approach_sign := float(goal_contract.get("approach_sign_z", 0.0))
	if approach_sign == 0.0:
		return false
	return local_ball_velocity.z * approach_sign > 0.05

func _resolve_kickoff_anchor() -> Vector3:
	if is_inside_tree():
		return global_position
	return _resolve_entry_world_position() + _resolve_scene_root_offset()

func _resolve_entry_world_position() -> Vector3:
	var kickoff_anchor_variant: Variant = _entry.get("world_position", Vector3.ZERO)
	if kickoff_anchor_variant is Vector3:
		return kickoff_anchor_variant as Vector3
	return Vector3.ZERO

func _resolve_scene_root_offset() -> Vector3:
	var root_offset_variant: Variant = _entry.get("scene_root_offset", Vector3.ZERO)
	if root_offset_variant is Vector3:
		return root_offset_variant as Vector3
	return Vector3.ZERO

func _get_podium_size() -> Vector3:
	return Vector3(
		PLAY_SURFACE_SIZE.x + PODIUM_MARGIN_X_M * 2.0,
		PODIUM_DEPTH_M,
		PLAY_SURFACE_SIZE.z + PODIUM_MARGIN_Z_M * 2.0
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
