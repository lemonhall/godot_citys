extends SceneTree

const T := preload("res://tests/_test_util.gd")
const SHORTCUT_AIR_DROP_HEIGHT_M := 10.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for fast-travel shortcut contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Fast-travel shortcut contract requires Player node access"):
		return
	if not T.require_true(self, world.has_method("set_full_map_open"), "Fast-travel shortcut contract requires full-map open control"):
		return
	if not T.require_true(self, world.has_method("is_full_map_open"), "Fast-travel shortcut contract requires full-map open state introspection"):
		return
	if not T.require_true(self, world.has_method("select_map_destination_from_world_point"), "Fast-travel shortcut contract requires destination selection support"):
		return
	if not T.require_true(self, world.has_method("resolve_fast_travel_target"), "Fast-travel shortcut contract requires fast-travel target resolution support"):
		return
	if not T.require_true(self, world.has_method("get_active_route_result"), "Fast-travel shortcut contract requires active route introspection"):
		return

	world.set_full_map_open(true)
	await process_frame

	var selection_contract: Dictionary = world.select_map_destination_from_world_point(Vector3(1400.0, 0.0, 26.0))
	if not T.require_true(self, not selection_contract.is_empty(), "Fast-travel shortcut contract requires an active destination before pressing T"):
		return

	var resolved_target: Dictionary = selection_contract.get("resolved_target", {})
	var travel_target: Dictionary = world.resolve_fast_travel_target(resolved_target)
	if not T.require_true(self, not travel_target.is_empty(), "Fast-travel shortcut contract requires a resolvable fast-travel target"):
		return
	var safe_drop_anchor: Vector3 = travel_target.get("safe_drop_anchor", Vector3.ZERO)

	_press_key(world, KEY_T)
	await process_frame

	if not T.require_true(self, not world.is_full_map_open(), "Pressing T with an active destination must close the full map after teleporting"):
		return
	var expected_position := safe_drop_anchor + Vector3.UP * SHORTCUT_AIR_DROP_HEIGHT_M
	if not T.require_true(self, player.global_position.distance_to(expected_position) <= 1.5, "Pressing T must teleport the player to roughly 10 meters above the resolved safe drop anchor"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _press_key(world: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.echo = false
	event.keycode = keycode
	event.physical_keycode = keycode
	world._unhandled_input(event)
