extends SceneTree

const T := preload("res://tests/_test_util.gd")

const VENUE_CHUNK_ID := "chunk_147_181"
const VENUE_ID := "venue:v38:lakeside_fishing:chunk_147_181"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for lake main-world port contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Lake main-world port contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("get_fishing_venue_runtime_state"), "Lake main-world port contract requires fishing runtime introspection"):
		return
	if not T.require_true(self, world.has_method("get_fishing_hud_state"), "Lake main-world port contract requires fishing HUD introspection"):
		return
	if not T.require_true(self, world.has_method("get_fishing_primary_interaction_state"), "Lake main-world port contract requires fishing prompt introspection"):
		return
	if not T.require_true(self, world.has_method("handle_primary_interaction"), "Lake main-world port contract requires the shared primary interaction entrypoint"):
		return

	player.teleport_to_world_position(Vector3(2834.0, 1.2, 11546.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null and mounted_venue.has_method("get_fishing_contract") and mounted_venue.has_method("get_pole_anchor"), "Lake main-world port contract must mount the fishing venue in chunk_147_181 with the formal pole anchor API"):
		return
	var fishing_contract: Dictionary = mounted_venue.get_fishing_contract()
	if not T.require_true(self, str(fishing_contract.get("venue_id", "")) == VENUE_ID, "Lake main-world port contract must preserve the formal fishing venue_id on the mounted node"):
		return
	if not T.require_true(self, str(fishing_contract.get("linked_region_id", "")) == "region:v38:fishing_lake:chunk_147_181", "Lake main-world port contract must keep the mounted fishing venue bound to the formal lake region"):
		return
	var prompt_state: Dictionary = await _wait_for_visible_prompt(world)
	if not T.require_true(self, bool(prompt_state.get("visible", false)), "Lake main-world port contract must surface a visible E prompt near the authored fishing pole"):
		return
	if not T.require_true(self, str(prompt_state.get("prompt_text", "")).contains("E"), "Lake main-world port contract must resolve the fishing interaction prompt through the shared E prompt family"):
		return

	var equip_result: Dictionary = world.handle_primary_interaction()
	if not T.require_true(self, bool(equip_result.get("success", false)), "Lake main-world port contract must allow the player to pick up the authored fishing pole through the shared primary interaction entrypoint"):
		return
	var runtime_state: Dictionary = world.get_fishing_venue_runtime_state()
	if not T.require_true(self, bool(runtime_state.get("fishing_mode_active", false)), "Lake main-world port contract must expose fishing_mode_active through the world runtime snapshot"):
		return
	if not T.require_true(self, bool(runtime_state.get("pole_equipped", false)), "Lake main-world port contract must expose pole_equipped through the world runtime snapshot after pickup"):
		return
	var hud_state: Dictionary = world.get_fishing_hud_state()
	if not T.require_true(self, bool(hud_state.get("visible", false)), "Lake main-world port contract must surface a visible fishing HUD after the player picks up the pole"):
		return
	if not T.require_true(self, str(hud_state.get("cast_state", "")) == "equipped", "Lake main-world port contract must propagate the equipped cast state to the fishing HUD after pickup"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _wait_for_mounted_venue(world) -> Variant:
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

func _wait_for_visible_prompt(world) -> Dictionary:
	for _frame in range(180):
		await physics_frame
		await process_frame
		var prompt_state: Dictionary = world.get_fishing_primary_interaction_state()
		if bool(prompt_state.get("visible", false)):
			return prompt_state
	return world.get_fishing_primary_interaction_state()
