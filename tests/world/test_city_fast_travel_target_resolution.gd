extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for fast travel target resolution")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("resolve_fast_travel_target"), "CityPrototype must expose resolve_fast_travel_target() for v12 M5"):
		return
	if not T.require_true(self, world.has_method("fast_travel_to_active_destination"), "CityPrototype must expose fast_travel_to_active_destination() for v12 M5"):
		return

	var selection_contract: Dictionary = world.select_map_destination_from_world_point(Vector3(1400.0, 0.0, 26.0))
	if not T.require_true(self, not selection_contract.is_empty(), "Fast travel target resolution requires an active destination target from the shared map flow"):
		return

	var resolved_target: Dictionary = selection_contract.get("resolved_target", {})
	var travel_target: Dictionary = world.resolve_fast_travel_target(resolved_target)
	if not T.require_true(self, not travel_target.is_empty(), "Fast travel target resolution must return a non-empty fast-travel contract"):
		return
	for required_key in ["safe_drop_anchor", "arrival_heading", "source_target_id"]:
		if not T.require_true(self, travel_target.has(required_key), "Fast travel target contract must expose %s" % required_key):
			return

	var safe_drop_anchor: Vector3 = travel_target.get("safe_drop_anchor", Vector3.ZERO)
	if not T.require_true(self, safe_drop_anchor.distance_to(resolved_target.get("routable_anchor", Vector3.ZERO)) <= 18.0, "Fast travel must drop near the routable anchor instead of the raw clicked point"):
		return

	var player := world.get_node_or_null("Player")
	var origin_position: Vector3 = player.global_position if player != null else Vector3.ZERO
	var fast_travel_result: Dictionary = world.fast_travel_to_active_destination()
	if not T.require_true(self, bool(fast_travel_result.get("success", false)), "Fast travel must complete successfully for the active destination target"):
		return
	if not T.require_true(self, player != null and player.global_position.distance_to(safe_drop_anchor) <= 1.5, "Fast travel must place the player at the resolved safe_drop_anchor"):
		return
	if not T.require_true(self, origin_position.distance_to(player.global_position) >= 400.0, "Fast travel must materially move the player across the city when the target is far away"):
		return

	world.queue_free()
	T.pass_and_quit(self)
