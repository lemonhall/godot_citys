extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SOCCER_CHUNK_ID := "chunk_129_139"
const SOCCER_VENUE_ID := "venue:v26:soccer_pitch:chunk_129_139"
const SOCCER_WORLD_POSITION := Vector3(-1877.94, 2.52, 618.57)
const PLAYER_SURFACE_TOLERANCE_M := 0.35
const PLAYER_GROUNDING_OFFSET := Vector3(-6.0, 3.0, 0.0)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for soccer player surface grounding contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player") as CharacterBody3D
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Soccer player surface grounding contract requires Player teleport API"):
		return

	player.teleport_to_world_position(SOCCER_WORLD_POSITION + Vector3(0.0, 8.0, 0.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null, "Soccer player surface grounding contract must mount the venue before grounding checks"):
		return

	var play_surface: Dictionary = mounted_venue.get_play_surface_contract()
	var kickoff_anchor: Vector3 = play_surface.get("kickoff_anchor", Vector3.ZERO)
	var surface_top_y := float(play_surface.get("surface_top_y", 0.0))
	var floor_node := mounted_venue.get_node_or_null("PlayableFloor") as StaticBody3D
	player.teleport_to_world_position(kickoff_anchor + PLAYER_GROUNDING_OFFSET)
	await _wait_for_player_grounded(player, 96)

	var standing_height := _resolve_standing_height(player)
	var grounding_debug := "player_y=%.3f surface_top_y=%.3f standing_height=%.3f floor_layer=%d player_mask=%d" % [
		player.global_position.y,
		surface_top_y,
		standing_height,
		floor_node.collision_layer if floor_node != null else -1,
		player.collision_mask,
	]
	if not T.require_true(self, player.is_on_floor(), "Soccer player surface grounding contract requires the player controller to actually detect the raised pitch floor (%s)" % grounding_debug):
		return
	if not T.require_true(
		self,
		absf(player.global_position.y - (surface_top_y + standing_height)) <= PLAYER_SURFACE_TOLERANCE_M,
		"Soccer player surface grounding contract requires the player capsule to settle on top of the pitch instead of sinking through it (%s)" % grounding_debug
	):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _wait_for_mounted_venue(world) -> Variant:
	var chunk_renderer: Variant = world.get_chunk_renderer() if world.has_method("get_chunk_renderer") else null
	if chunk_renderer == null or not chunk_renderer.has_method("get_chunk_scene"):
		return null
	for _frame in range(180):
		await process_frame
		var chunk_scene: Variant = chunk_renderer.get_chunk_scene(SOCCER_CHUNK_ID)
		if chunk_scene == null or not chunk_scene.has_method("find_scene_minigame_venue_node"):
			continue
		var mounted_venue: Variant = chunk_scene.find_scene_minigame_venue_node(SOCCER_VENUE_ID)
		if mounted_venue != null:
			return mounted_venue
	return null

func _settle_frames(frame_count: int = 8) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame

func _wait_for_player_grounded(player: CharacterBody3D, max_frames: int = 96) -> void:
	for _frame_index in range(max_frames):
		await physics_frame
		await process_frame
		if player.is_on_floor():
			return

func _resolve_standing_height(player: CharacterBody3D) -> float:
	var collision_shape := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		return 1.0
	if collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		return capsule.height * 0.5
	if collision_shape.shape is BoxShape3D:
		var box := collision_shape.shape as BoxShape3D
		return box.size.y * 0.5
	return 1.0
