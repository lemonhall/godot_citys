extends SceneTree

const T := preload("res://tests/_test_util.gd")
const EARLY_IDLE_FRAMES := 64
const MANIFEST_READ_WAIT_FRAMES := 24

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for service building startup-delay contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_service_building_map_pin_state"), "Service building startup-delay contract requires runtime state introspection"):
		return
	if not T.require_true(self, world.has_method("set_full_map_open"), "Service building startup-delay contract requires full-map visibility control"):
		return

	var initial_state: Dictionary = world.get_service_building_map_pin_state()
	if not T.require_true(self, bool(initial_state.get("loading", false)), "Service building startup-delay contract requires queued lazy work after override registry sync"):
		return
	if not T.require_true(self, int(initial_state.get("manifest_read_count", -1)) == 0, "Service building startup-delay contract must not read manifests before any lazy advance runs"):
		return

	for _frame in range(EARLY_IDLE_FRAMES):
		await process_frame
	var delayed_state: Dictionary = world.get_service_building_map_pin_state()
	if not T.require_true(self, int(delayed_state.get("manifest_read_count", -1)) == 0, "Keeping the full map closed must preserve the startup delay and avoid manifest IO during the early traversal window"):
		return
	if not T.require_true(self, int(delayed_state.get("pin_count", -1)) == 0, "Keeping the full map closed must not preload service-building pins into the shared registry during the startup delay window"):
		return

	world.set_full_map_open(true)
	var activated_state := await _wait_for_manifest_read(world)
	if not T.require_true(self, int(activated_state.get("manifest_read_count", 0)) > 0, "Opening the full map must allow the lazy loader to start manifest IO immediately instead of waiting for the startup delay to expire"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _wait_for_manifest_read(world) -> Dictionary:
	for _frame in range(MANIFEST_READ_WAIT_FRAMES):
		await process_frame
		var state: Dictionary = world.get_service_building_map_pin_state()
		if int(state.get("manifest_read_count", 0)) > 0:
			return state
	return world.get_service_building_map_pin_state()
