extends SceneTree

const T := preload("res://tests/_test_util.gd")

const VENUE_CHUNK_ID := "chunk_147_181"
const VENUE_ID := "venue:v38:lakeside_fishing:chunk_147_181"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for lake fishing flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Lake fishing flow requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("set_fishing_cast_preview_active"), "Lake fishing flow requires shared cast-preview control on CityPrototype"):
		return
	if not T.require_true(self, world.has_method("request_fishing_cast_action"), "Lake fishing flow requires shared cast-action control on CityPrototype"):
		return
	if not T.require_true(self, world.has_method("debug_set_fishing_bite_delay_override"), "Lake fishing flow requires deterministic bite-delay override on CityPrototype"):
		return
	var mounted_venue: Node3D = await _wait_for_mounted_venue_after_teleport(world, player)
	if not T.require_true(self, mounted_venue != null and mounted_venue.has_method("get_pole_anchor"), "Lake fishing flow requires the mounted fishing venue"):
		return

	var pole_anchor: Dictionary = mounted_venue.get_pole_anchor()
	player.teleport_to_world_position(pole_anchor.get("world_position", Vector3.ZERO) + Vector3.UP * 1.2)
	if not T.require_true(self, bool(world.handle_primary_interaction().get("success", false)), "Lake fishing flow must let the player pick up the pole through the shared interaction entrypoint"):
		return
	world.debug_set_fishing_bite_delay_override(0.05)
	if not T.require_true(self, bool(world.set_fishing_cast_preview_active(true).get("success", false)), "Lake fishing flow must let the player enter cast preview before throwing the bobber"):
		return
	if not T.require_true(self, bool(world.request_fishing_cast_action().get("success", false)), "Lake fishing flow must start a cast through the dedicated cast action entrypoint"):
		return
	var runtime_state: Dictionary = await _wait_for_cast_state(world, "bite_ready")
	if not T.require_true(self, str(runtime_state.get("cast_state", "")) == "bite_ready", "Lake fishing flow must reach bite_ready in the main world"):
		return
	if not T.require_true(self, bool(world.request_fishing_cast_action().get("success", false)), "Lake fishing flow must resolve the catch through the dedicated cast action entrypoint"):
		return
	runtime_state = world.get_fishing_venue_runtime_state()
	if not T.require_true(self, str(runtime_state.get("last_catch_result", {}).get("result", "")) == "caught", "Lake fishing flow must preserve the caught result in the world runtime snapshot"):
		return
	if not T.require_true(self, bool(world.handle_primary_interaction().get("success", false)), "Lake fishing flow must allow the player to put the pole back with E in the main world"):
		return
	runtime_state = world.get_fishing_venue_runtime_state()
	if not T.require_true(self, str(runtime_state.get("cast_state", "")) == "idle", "Lake fishing flow must return the main-world fishing runtime to idle after reset"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _wait_for_mounted_venue_after_teleport(world, player) -> Variant:
	player.teleport_to_world_position(Vector3(2834.0, 1.2, 11546.0))
	var chunk_renderer: Variant = world.get_chunk_renderer() if world.has_method("get_chunk_renderer") else null
	if chunk_renderer == null or not chunk_renderer.has_method("get_chunk_scene"):
		return null
	for _frame in range(180):
		await process_frame
		var chunk_scene: Variant = chunk_renderer.get_chunk_scene(VENUE_CHUNK_ID)
		if chunk_scene == null or not chunk_scene.has_method("find_scene_minigame_venue_node"):
			continue
		var mounted_venue: Variant = chunk_scene.find_scene_minigame_venue_node(VENUE_ID)
		if mounted_venue != null:
			return mounted_venue
	return null

func _wait_for_cast_state(world, expected_state: String) -> Dictionary:
	for _frame in range(180):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_fishing_venue_runtime_state()
		if str(runtime_state.get("cast_state", "")) == expected_state:
			return runtime_state
	return world.get_fishing_venue_runtime_state()
