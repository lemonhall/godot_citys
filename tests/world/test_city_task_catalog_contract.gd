extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config_script := load("res://city_game/world/model/CityWorldConfig.gd")
	var generator_script := load("res://city_game/world/generation/CityWorldGenerator.gd")
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if config_script == null or generator_script == null or scene == null:
		T.fail_and_quit(self, "Task catalog contract requires CityWorldConfig, CityWorldGenerator, and CityPrototype.tscn")
		return

	var config = config_script.new()
	var generator = generator_script.new()
	var world_data: Dictionary = generator.generate_world(config)

	if not T.require_true(self, world_data.has("task_catalog"), "World generation must expose task_catalog for v14 M1"):
		return
	if not T.require_true(self, world_data.has("task_slot_index"), "World generation must expose task_slot_index for v14 M1"):
		return
	if not T.require_true(self, world_data.has("task_runtime"), "World generation must expose task_runtime for v14 M1"):
		return

	var task_catalog = world_data.get("task_catalog")
	var task_slot_index = world_data.get("task_slot_index")
	var task_runtime = world_data.get("task_runtime")
	if not T.require_true(self, task_catalog != null and task_catalog.has_method("get_task_definitions"), "task_catalog must expose get_task_definitions()"):
		return
	if not T.require_true(self, task_catalog.has_method("get_task_definition"), "task_catalog must expose get_task_definition()"):
		return
	if not T.require_true(self, task_slot_index != null and task_slot_index.has_method("get_slot_by_id"), "task_slot_index must expose get_slot_by_id()"):
		return
	if not T.require_true(self, task_slot_index.has_method("get_slots_intersecting_rect"), "task_slot_index must expose get_slots_intersecting_rect()"):
		return
	if not T.require_true(self, task_slot_index.has_method("get_slots_for_chunk"), "task_slot_index must expose get_slots_for_chunk()"):
		return
	if not T.require_true(self, task_runtime != null and task_runtime.has_method("get_task_snapshot"), "task_runtime must expose get_task_snapshot()"):
		return
	if not T.require_true(self, task_runtime.has_method("get_tracked_task_id"), "task_runtime must expose get_tracked_task_id()"):
		return

	var task_definitions: Array = task_catalog.get_task_definitions()
	if not T.require_true(self, task_definitions.size() >= 3, "task_catalog must contain at least three sample tasks for v14 validation"):
		return

	var first_definition: Dictionary = task_definitions[0]
	for required_key in ["task_id", "title", "summary", "icon_id", "initial_status", "start_slot", "objective_slots"]:
		if not T.require_true(self, first_definition.has(required_key), "Task definition must expose %s" % required_key):
			return

	var start_slot_id := str(first_definition.get("start_slot", ""))
	var objective_slots: Array = first_definition.get("objective_slots", [])
	if not T.require_true(self, start_slot_id != "", "Task definition must expose a non-empty start_slot id"):
		return
	if not T.require_true(self, objective_slots.size() >= 1, "Task definition must expose at least one objective slot id"):
		return

	var start_slot: Dictionary = task_slot_index.get_slot_by_id(start_slot_id)
	if not T.require_true(self, not start_slot.is_empty(), "task_slot_index must resolve the formal start_slot id"):
		return
	for required_slot_key in ["slot_id", "task_id", "slot_kind", "world_anchor", "trigger_radius_m", "marker_theme", "route_target_override", "chunk_key", "chunk_id"]:
		if not T.require_true(self, start_slot.has(required_slot_key), "Task slot must expose %s" % required_slot_key):
			return

	var first_snapshot: Dictionary = task_runtime.get_task_snapshot(str(first_definition.get("task_id", "")))
	if not T.require_true(self, str(first_snapshot.get("status", "")) == "available", "Initial task snapshot must stay in available state before gameplay triggers"):
		return

	var start_anchor: Vector3 = start_slot.get("world_anchor", Vector3.ZERO)
	var query_rect := Rect2(Vector2(start_anchor.x - 2.0, start_anchor.z - 2.0), Vector2.ONE * 4.0)
	var rect_hits: Array = task_slot_index.get_slots_intersecting_rect(query_rect, ["start"])
	if not T.require_true(self, _array_has_slot(rect_hits, start_slot_id), "task_slot_index rect query must return the matching start slot"):
		return

	var chunk_hits: Array = task_slot_index.get_slots_for_chunk(start_slot.get("chunk_key", Vector2i.ZERO), ["start"])
	if not T.require_true(self, _array_has_slot(chunk_hits, start_slot_id), "task_slot_index chunk query must return the matching start slot"):
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_task_catalog"), "CityPrototype must expose get_task_catalog() for v14 M1"):
		return
	if not T.require_true(self, world.has_method("get_task_slot_index"), "CityPrototype must expose get_task_slot_index() for v14 M1"):
		return
	if not T.require_true(self, world.has_method("get_task_runtime"), "CityPrototype must expose get_task_runtime() for v14 M1"):
		return
	if not T.require_true(self, world.get_task_catalog() != null, "CityPrototype get_task_catalog() must return a live catalog instance"):
		return
	if not T.require_true(self, world.get_task_slot_index() != null, "CityPrototype get_task_slot_index() must return a live slot index instance"):
		return
	if not T.require_true(self, world.get_task_runtime() != null, "CityPrototype get_task_runtime() must return a live runtime instance"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _array_has_slot(slots: Array, slot_id: String) -> bool:
	for slot_variant in slots:
		var slot: Dictionary = slot_variant
		if str(slot.get("slot_id", "")) == slot_id:
			return true
	return false
