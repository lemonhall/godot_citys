extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SEARCH_POSITIONS := [
	Vector3(-1280.0, 1.1, -1024.0),
	Vector3(-2048.0, 1.1, 0.0),
	Vector3(-1200.0, 1.1, 26.0),
	Vector3(-600.0, 1.1, 26.0),
	Vector3(300.0, 1.1, 26.0),
	Vector3(768.0, 1.1, 26.0),
	Vector3(1536.0, 1.1, 26.0),
	Vector3(2048.0, 1.1, 768.0),
	Vector3.ZERO,
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for pedestrian character visual presence")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_pedestrian_runtime_snapshot"), "CityPrototype must expose get_pedestrian_runtime_snapshot() for M8 visual validation"):
		return
	if not T.require_true(self, world.has_method("get_chunk_renderer"), "CityPrototype must expose get_chunk_renderer() for live visual validation"):
		return
	if not T.require_true(self, world.has_method("fire_player_projectile_toward"), "CityPrototype must expose fire_player_projectile_toward() for live death visual validation"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "PlayerController must expose teleport_to_world_position() for M8 visual validation"):
		return

	var live_target := await _find_tier2_target(world, player)
	if not T.require_true(self, not live_target.is_empty(), "Live world must surface at least one Tier2 pedestrian for M8 nearfield visual validation"):
		return

	var chunk_scene = live_target.get("chunk_scene") as Node
	var visual_node := live_target.get("visual_node") as Node
	if not T.require_true(self, visual_node != null, "Mounted chunk scene must expose a real visual node for the live Tier2 pedestrian target"):
		return
	if not T.require_true(self, visual_node.has_method("get_current_animation_name"), "Live Tier2 visual node must expose get_current_animation_name() for M8 validation"):
		return
	if not T.require_true(self, visual_node.has_method("uses_placeholder_box_mesh"), "Live Tier2 visual node must expose uses_placeholder_box_mesh() for M8 anti-placeholder validation"):
		return
	if not T.require_true(self, not bool(visual_node.call("uses_placeholder_box_mesh")), "Live Tier2 pedestrian must not render as a BoxMesh placeholder in M8"):
		return
	if not T.require_true(self, _has_any_token(str(visual_node.call("get_current_animation_name")), ["walk"]), "Live ambient Tier2 pedestrian must play a walk clip in M8"):
		return

	var aim_position: Vector3 = live_target.get("aim_position", Vector3.ZERO)
	var target_position: Vector3 = live_target.get("target_position", Vector3.ZERO)
	player.teleport_to_world_position(target_position + Vector3(-4.0, 1.1, -4.0))
	world.update_streaming_for_position(player.global_position, 0.1)
	await process_frame
	var projectile = world.fire_player_projectile_toward(aim_position)
	if not T.require_true(self, projectile != null, "Live M8 visual validation must be able to fire a real projectile at the mounted Tier2 target"):
		return
	for _frame_index in range(10):
		await physics_frame
		world.update_streaming_for_position(player.global_position, 1.0 / 60.0)
		await process_frame
	var death_visual := _find_death_visual(chunk_scene)
	if not T.require_true(self, death_visual != null, "Live M8 visual validation must leave a transient death visual after projectile casualty"):
		return
	if not T.require_true(self, death_visual.has_method("get_current_animation_name"), "Live death visual must expose get_current_animation_name() for death clip validation"):
		return
	if not T.require_true(self, _has_any_token(str(death_visual.call("get_current_animation_name")), ["death", "dead"]), "Live death visual must route into a death/dead animation clip after casualty"):
		return

	T.pass_and_quit(self)

func _find_tier2_target(world, player) -> Dictionary:
	var chunk_renderer = world.get_chunk_renderer()
	for search_position_variant in SEARCH_POSITIONS:
		var search_position: Vector3 = search_position_variant
		player.teleport_to_world_position(search_position)
		world.update_streaming_for_position(search_position, 0.25)
		for _guard_index in range(12):
			await process_frame
			world.update_streaming_for_position(search_position, 0.1)
			var snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
			for state_variant in snapshot.get("tier2_states", []):
				var state: Dictionary = state_variant
				var chunk_scene = chunk_renderer.get_chunk_scene(str(state.get("chunk_id", ""))) if chunk_renderer != null and chunk_renderer.has_method("get_chunk_scene") else null
				if chunk_scene == null:
					continue
				var visual_node := _find_visual_node(chunk_scene, str(state.get("pedestrian_id", "")))
				if visual_node == null:
					continue
				return {
					"pedestrian_id": str(state.get("pedestrian_id", "")),
					"chunk_id": str(state.get("chunk_id", "")),
					"chunk_scene": chunk_scene,
					"visual_node": visual_node,
					"target_position": state.get("world_position", Vector3.ZERO),
					"aim_position": _resolve_projectile_aim_position(state),
				}
	return {}

func _find_visual_node(chunk_scene: Node, pedestrian_id: String) -> Node:
	var crowd_root := chunk_scene.get_node_or_null("PedestrianCrowd") as Node
	if crowd_root == null:
		return null
	var tier2_root := crowd_root.get_node_or_null("Tier2Agents") as Node
	if tier2_root == null:
		return null
	var expected_name := pedestrian_id.replace(":", "_")
	return tier2_root.get_node_or_null(expected_name)

func _find_death_visual(chunk_scene: Node) -> Node:
	var crowd_root := chunk_scene.get_node_or_null("PedestrianCrowd") as Node
	if crowd_root == null:
		return null
	var death_root := crowd_root.get_node_or_null("DeathVisuals") as Node
	if death_root == null or death_root.get_child_count() == 0:
		return null
	return death_root.get_child(0) as Node

func _resolve_projectile_aim_position(state: Dictionary) -> Vector3:
	var world_position: Vector3 = state.get("world_position", Vector3.ZERO)
	var height_m := float(state.get("height_m", 1.75))
	return world_position + Vector3.UP * maxf(height_m * 0.5, 0.9)

func _has_any_token(animation_name: String, tokens: Array[String]) -> bool:
	var normalized_animation := animation_name.to_lower()
	for token in tokens:
		if normalized_animation.find(token) >= 0:
			return true
	return false
