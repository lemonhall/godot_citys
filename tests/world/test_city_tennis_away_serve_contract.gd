extends SceneTree

const T := preload("res://tests/_test_util.gd")

const TENNIS_CHUNK_ID := "chunk_158_140"
const TENNIS_VENUE_ID := "venue:v28:tennis_court:chunk_158_140"
const TENNIS_PROP_ID := "prop:v28:tennis_ball:chunk_158_140"
const TENNIS_WORLD_POSITION := Vector3(5489.46, 20.62, 1029.73)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for tennis away serve contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Tennis away serve contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("get_tennis_venue_runtime_state"), "Tennis away serve contract requires get_tennis_venue_runtime_state()"):
		return
	if not T.require_true(self, world.has_method("debug_award_tennis_point"), "Tennis away serve contract requires deterministic point award API"):
		return
	if not T.require_true(self, world.has_method("get_interactive_prop_interaction_state"), "Tennis away serve contract requires prompt introspection"):
		return

	player.teleport_to_world_position(TENNIS_WORLD_POSITION + Vector3(0.0, 2.0, 10.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null and mounted_venue.has_method("get_tennis_court_contract"), "Tennis away serve contract requires mounted tennis court metadata"):
		return
	var mounted_ball: Node3D = await _wait_for_mounted_ball(world)
	if not T.require_true(self, mounted_ball != null, "Tennis away serve contract requires the mounted tennis ball"):
		return
	var opponent_node := mounted_venue.get_node_or_null("OpponentRoot/away_opponent_1")
	if not T.require_true(self, opponent_node != null and opponent_node.has_method("get_tennis_visual_state"), "Tennis away serve contract requires opponent tennis visual introspection"):
		return
	var opponent_racket_node := opponent_node.find_child("TennisRacketVisual", true, false)
	if not T.require_true(self, opponent_racket_node != null, "Tennis away serve contract requires a mounted opponent racket visual node"):
		return
	var expected_racket_path := "Visual/RootNode/Human Armature/Skeleton3D/TennisRacketHandAnchor/TennisRacketVisual"
	if not T.require_true(self, str(opponent_node.get_path_to(opponent_racket_node)) == expected_racket_path, "Tennis away serve contract must mount the opponent racket under the RightHand attachment instead of leaving it on the body root"):
		return
	var racket_hand_anchor := opponent_racket_node.get_parent()
	if not T.require_true(self, racket_hand_anchor is BoneAttachment3D, "Tennis away serve contract opponent racket parent must be a BoneAttachment3D hand anchor"):
		return
	var hand_anchor := racket_hand_anchor as BoneAttachment3D
	if not T.require_true(self, str(hand_anchor.bone_name) == "RightHand", "Tennis away serve contract opponent racket hand anchor must target the RightHand bone"):
		return
	var initial_opponent_visual_state: Dictionary = opponent_node.get_tennis_visual_state()
	var grip_anchor_variant: Variant = initial_opponent_visual_state.get("grip_anchor_world_position", null)
	if not T.require_true(self, grip_anchor_variant is Vector3, "Tennis away serve contract opponent racket visual introspection must expose grip_anchor_world_position for hand-hold alignment checks"):
		return
	var grip_anchor_world_position := grip_anchor_variant as Vector3
	if not T.require_true(self, grip_anchor_world_position.distance_to(hand_anchor.global_position) <= 0.18, "Tennis away serve contract opponent grip anchor must stay close to the RightHand anchor instead of leaving the hand threaded through the string bed"):
		return
	var head_center_variant: Variant = initial_opponent_visual_state.get("head_center_world_position", null)
	if not T.require_true(self, head_center_variant is Vector3, "Tennis away serve contract opponent racket visual introspection must expose head_center_world_position for torso-overlap checks"):
		return
	var head_center_world_position := head_center_variant as Vector3
	var torso_probe_world_position: Vector3 = opponent_node.to_global(Vector3(0.0, 1.0, 0.0))
	var hand_to_torso: Vector3 = (torso_probe_world_position - hand_anchor.global_position).normalized()
	var hand_to_head: Vector3 = (head_center_world_position - hand_anchor.global_position).normalized()
	if not T.require_true(self, hand_to_head.dot(hand_to_torso) <= 0.2, "Tennis away serve contract idle racket orientation must not keep the racket head pointed into the torso/kidney side after hand attachment"):
		return
	var opponent_racket_frame_mesh := opponent_racket_node.find_child("frame", true, false) as MeshInstance3D
	if not T.require_true(self, opponent_racket_frame_mesh != null, "Tennis away serve contract requires the opponent racket frame mesh for material preservation checks"):
		return
	if not T.require_true(self, opponent_racket_frame_mesh.material_override == null, "Tennis away serve contract opponent racket must preserve its own embedded material colors instead of inheriting the player tint material"):
		return

	await _start_match(world, mounted_venue, player)
	var player_racket_node := player.find_child("TennisRacketVisual", true, false) as Node3D
	if not T.require_true(self, player_racket_node != null, "Tennis away serve contract requires the player racket visual after match start for scale comparison"):
		return
	var player_racket_visual_root := player_racket_node.get_node_or_null("MountRoot/Visual") as Node3D
	var opponent_racket_visual_root := opponent_racket_node.get_node_or_null("MountRoot/Visual") as Node3D
	if not T.require_true(self, player_racket_visual_root != null and opponent_racket_visual_root != null, "Tennis away serve contract requires both player and opponent racket visual roots for scale comparison"):
		return
	var player_racket_scale := player_racket_visual_root.global_basis.get_scale().length()
	var opponent_racket_scale := opponent_racket_visual_root.global_basis.get_scale().length()
	if not T.require_true(self, absf(opponent_racket_scale - player_racket_scale) <= player_racket_scale * 0.35, "Tennis away serve contract opponent hand-mounted racket must stay in the same global scale range as the player racket instead of inheriting the oversized skeleton import scale"):
		return
	for _point in range(4):
		var point_result: Dictionary = world.debug_award_tennis_point("home", "test_rotate_server_to_away")
		if not T.require_true(self, bool(point_result.get("success", false)), "Tennis away serve contract must allow deterministic home scoring to rotate server order"):
			return
		await _pump_frames()

	var away_pre_serve_state: Dictionary = await _wait_for_pre_serve_server(world, "away")
	if not T.require_true(self, str(away_pre_serve_state.get("server_side", "")) == "away", "Tennis away serve contract must rotate the next server to away after one completed game"):
		return
	var standing_height := _estimate_standing_height(player)
	player.teleport_to_world_position(mounted_ball.global_position + Vector3(-1.2, standing_height - mounted_ball.global_position.y + 0.2, 0.0))
	await _pump_frames(8)
	var interaction_state: Dictionary = world.get_interactive_prop_interaction_state()
	if not T.require_true(self, not bool(interaction_state.get("visible", false)), "Tennis away serve contract must not show a player-controlled '按 E 发球' prompt when the away side is serving"):
		return

	var court_contract: Dictionary = mounted_venue.get_tennis_court_contract()
	var home_receive_anchor: Dictionary = court_contract.get("home_deuce_receiver_anchor", {})
	var home_receive_world_position: Vector3 = home_receive_anchor.get("world_position", TENNIS_WORLD_POSITION)
	player.teleport_to_world_position(home_receive_world_position + Vector3.UP * standing_height)
	var away_serve_state: Dictionary = await _wait_for_away_serve_started(world)
	if not T.require_true(self, str(away_serve_state.get("last_hitter_side", "")) == "away", "Tennis away serve contract must let the away side actually launch the next serve instead of idling forever"):
		return
	if not T.require_true(self, str(away_serve_state.get("match_state", "")) == "serve_in_flight", "Tennis away serve contract must expose the away serve while it is still in flight so the player has time to read it early"):
		return
	if not T.require_true(self, str(away_serve_state.get("planned_target_side", "")) == "home", "Tennis away serve contract away serves must target the home/player side"):
		return
	if not T.require_true(self, bool(away_serve_state.get("landing_marker_visible", false)), "Tennis away serve contract must surface the receive ring as soon as the away serve is launched, not only after the bounce is already late"):
		return
	var serve_target_variant: Variant = away_serve_state.get("planned_target_world_position", null)
	if not T.require_true(self, serve_target_variant is Vector3, "Tennis away serve contract must expose the away serve target as Vector3"):
		return
	var serve_target := serve_target_variant as Vector3
	if not T.require_true(self, mounted_venue.get_service_box_id_for_world_point(serve_target) == str(away_serve_state.get("expected_service_box_id", "")), "Tennis away serve contract must land the AI serve in the formally expected home service box"):
		return
	var expected_service_box_id := str(away_serve_state.get("expected_service_box_id", ""))
	var receiver_anchor_key := "home_deuce_receiver_anchor" if expected_service_box_id == "service_box_deuce_home" else "home_ad_receiver_anchor"
	var receiver_anchor_contract: Dictionary = court_contract.get(receiver_anchor_key, {})
	var receiver_anchor_world_position: Vector3 = receiver_anchor_contract.get("world_position", home_receive_world_position)
	var serve_target_local := mounted_venue.to_local(serve_target)
	var receiver_anchor_local := mounted_venue.to_local(receiver_anchor_world_position)
	var service_line_distance_m := float(court_contract.get("service_line_distance_m", 48.0))
	if not T.require_true(self, absf(serve_target_local.x - receiver_anchor_local.x) <= 4.5, "Tennis away serve contract AI serves must not drag the player into a too-wide receive sprint before the rally even starts"):
		return
	if not T.require_true(self, serve_target_local.z >= service_line_distance_m * 0.72, "Tennis away serve contract AI serves must land in the deeper player-reachable part of the home service box instead of a too-short drop shot"):
		return
	var opponent_visual_state: Dictionary = opponent_node.get_tennis_visual_state()
	if not T.require_true(self, int(opponent_visual_state.get("swing_count", 0)) >= 1, "Tennis away serve contract must trigger an opponent swing when the away serve starts"):
		return
	if not T.require_true(self, str(opponent_visual_state.get("last_swing_style", "")) == "serve", "Tennis away serve contract must tag the away opening swing as serve style"):
		return
	var receive_landing_variant: Variant = away_serve_state.get("landing_marker_world_position", Vector3.ZERO)
	if not T.require_true(self, receive_landing_variant is Vector3, "Tennis away serve contract must expose the away serve receive marker as Vector3 while the ball is still traveling"):
		return
	var receive_landing_world_position := receive_landing_variant as Vector3
	player.teleport_to_world_position(receive_landing_world_position + Vector3.UP * standing_height)
	await _pump_frames(8)
	var home_receive_state: Dictionary = await _wait_for_ready_receive_window_or_terminal(world)
	if not T.require_true(self, str(home_receive_state.get("match_state", "")) == "rally", "Tennis away serve contract must keep the point alive long enough for the player to receive the away serve | %s" % _build_runtime_summary(home_receive_state)):
		return
	if not T.require_true(self, str(home_receive_state.get("strike_window_state", "")) == "ready", "Tennis away serve contract must reopen the same READY receive window on an away serve that it already uses for AI rally returns | %s" % _build_runtime_summary(home_receive_state)):
		return
	var player_return_result: Dictionary = world.handle_primary_interaction()
	if not T.require_true(self, bool(player_return_result.get("success", false)), "Tennis away serve contract must let the player convert an away serve receive window into a legal return | %s" % str(player_return_result)):
		return
	var home_return_state: Dictionary = await _wait_for_last_hitter(world, "home")
	if not T.require_true(self, str(home_return_state.get("last_hitter_side", "")) == "home", "Tennis away serve contract must actually register the player return after a received away serve | %s" % _build_runtime_summary(home_return_state)):
		return
	if not T.require_true(self, bool(home_receive_state.get("landing_marker_visible", false)) or int(home_receive_state.get("ball_bounce_count_home", 0)) >= 1, "Tennis away serve contract must open a live receive chain after a legal away serve lands on the home side"):
		return
	if not T.require_true(self, str(home_receive_state.get("target_side", "")) == "home", "Tennis away serve contract must hand the live serve receive state to the home/player side"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _start_match(world, mounted_venue: Node3D, player) -> void:
	var start_contract: Dictionary = mounted_venue.get_match_start_contract()
	var start_anchor: Vector3 = start_contract.get("world_position", TENNIS_WORLD_POSITION)
	var standing_height := _estimate_standing_height(player)
	player.teleport_to_world_position(start_anchor + Vector3.UP * standing_height)
	await _wait_for_pre_serve_server(world, "home")

func _wait_for_mounted_venue(world) -> Variant:
	var chunk_renderer: Variant = world.get_chunk_renderer() if world.has_method("get_chunk_renderer") else null
	if chunk_renderer == null or not chunk_renderer.has_method("get_chunk_scene"):
		return null
	for _frame in range(180):
		await process_frame
		var chunk_scene: Variant = chunk_renderer.get_chunk_scene(TENNIS_CHUNK_ID)
		if chunk_scene == null or not chunk_scene.has_method("find_scene_minigame_venue_node"):
			continue
		var mounted_venue: Variant = chunk_scene.find_scene_minigame_venue_node(TENNIS_VENUE_ID)
		if mounted_venue != null:
			return mounted_venue
	return null

func _wait_for_mounted_ball(world) -> Variant:
	var chunk_renderer: Variant = world.get_chunk_renderer() if world.has_method("get_chunk_renderer") else null
	if chunk_renderer == null or not chunk_renderer.has_method("get_chunk_scene"):
		return null
	for _frame in range(180):
		await process_frame
		var chunk_scene: Variant = chunk_renderer.get_chunk_scene(TENNIS_CHUNK_ID)
		if chunk_scene == null or not chunk_scene.has_method("find_scene_interactive_prop_node"):
			continue
		var mounted_ball: Variant = chunk_scene.find_scene_interactive_prop_node(TENNIS_PROP_ID)
		if mounted_ball != null:
			return mounted_ball
	return null

func _wait_for_pre_serve_server(world, expected_server_side: String) -> Dictionary:
	for _frame in range(480):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
		if str(runtime_state.get("match_state", "")) == "pre_serve" and str(runtime_state.get("server_side", "")) == expected_server_side:
			return runtime_state
	return world.get_tennis_venue_runtime_state()

func _wait_for_away_serve_started(world) -> Dictionary:
	for _frame in range(480):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
		if str(runtime_state.get("last_hitter_side", "")) == "away" and str(runtime_state.get("server_side", "")) == "away" and str(runtime_state.get("match_state", "")) == "serve_in_flight":
			return runtime_state
	return world.get_tennis_venue_runtime_state()

func _wait_for_home_receive_chain(world) -> Dictionary:
	for _frame in range(480):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
		if str(runtime_state.get("match_state", "")) == "rally" and str(runtime_state.get("target_side", "")) == "home" and bool(runtime_state.get("landing_marker_visible", false)):
			return runtime_state
	return world.get_tennis_venue_runtime_state()

func _wait_for_ready_receive_window_or_terminal(world) -> Dictionary:
	for _frame in range(480):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
		var match_state := str(runtime_state.get("match_state", ""))
		if match_state == "point_result" or match_state == "game_break" or match_state == "final":
			return runtime_state
		if str(runtime_state.get("strike_window_state", "")) == "ready":
			return runtime_state
	return world.get_tennis_venue_runtime_state()

func _wait_for_last_hitter(world, expected_side: String) -> Dictionary:
	for _frame in range(240):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_tennis_venue_runtime_state()
		if str(runtime_state.get("last_hitter_side", "")) == expected_side:
			return runtime_state
	return world.get_tennis_venue_runtime_state()

func _build_runtime_summary(runtime_state: Dictionary) -> String:
	return "match=%s last=%s winner=%s reason=%s target=%s bounces_home=%s strike=%s landing_visible=%s planned=%s" % [
		str(runtime_state.get("match_state", "")),
		str(runtime_state.get("last_hitter_side", "")),
		str(runtime_state.get("point_winner_side", "")),
		str(runtime_state.get("point_end_reason", "")),
		str(runtime_state.get("target_side", "")),
		str(runtime_state.get("ball_bounce_count_home", 0)),
		str(runtime_state.get("strike_window_state", "")),
		str(runtime_state.get("landing_marker_visible", false)),
		str(runtime_state.get("planned_target_world_position", Vector3.ZERO)),
	]

func _pump_frames(frame_count: int = 4) -> void:
	for _frame in range(frame_count):
		await physics_frame
		await process_frame

func _estimate_standing_height(player) -> float:
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
