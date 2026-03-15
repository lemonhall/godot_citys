extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config_script := load("res://city_game/world/model/CityWorldConfig.gd")
	var generator_script := load("res://city_game/world/generation/CityWorldGenerator.gd")
	if config_script == null or generator_script == null:
		T.fail_and_quit(self, "Task slot seed stability test requires CityWorldConfig and CityWorldGenerator")
		return

	var config_a = config_script.new()
	var config_b = config_script.new()
	var generator = generator_script.new()
	var world_a: Dictionary = generator.generate_world(config_a)
	var world_b: Dictionary = generator.generate_world(config_b)

	var catalog_a = world_a.get("task_catalog")
	var catalog_b = world_b.get("task_catalog")
	var slots_a = world_a.get("task_slot_index")
	var slots_b = world_b.get("task_slot_index")
	if not T.require_true(self, catalog_a != null and catalog_b != null, "Both worlds must expose task_catalog for seed stability validation"):
		return
	if not T.require_true(self, slots_a != null and slots_b != null, "Both worlds must expose task_slot_index for seed stability validation"):
		return

	var task_defs_a: Array = catalog_a.get_task_definitions()
	var task_defs_b: Array = catalog_b.get_task_definitions()
	if not T.require_true(self, task_defs_a.size() == task_defs_b.size(), "Same seed must yield identical task definition counts"):
		return
	for index in range(task_defs_a.size()):
		var a: Dictionary = task_defs_a[index]
		var b: Dictionary = task_defs_b[index]
		if not T.require_true(self, str(a.get("task_id", "")) == str(b.get("task_id", "")), "Same seed must keep task_id stable"):
			return
		if not T.require_true(self, str(a.get("start_slot", "")) == str(b.get("start_slot", "")), "Same seed must keep start_slot ids stable"):
			return
		if not T.require_true(self, JSON.stringify(a.get("objective_slots", [])) == JSON.stringify(b.get("objective_slots", [])), "Same seed must keep objective slot ids stable"):
			return

	var slot_defs_a: Array = slots_a.get_slots()
	var slot_defs_b: Array = slots_b.get_slots()
	if not T.require_true(self, slot_defs_a.size() == slot_defs_b.size(), "Same seed must yield identical task slot counts"):
		return
	for slot_index in range(slot_defs_a.size()):
		var slot_a: Dictionary = slot_defs_a[slot_index]
		var slot_b: Dictionary = slot_defs_b[slot_index]
		if not T.require_true(self, str(slot_a.get("slot_id", "")) == str(slot_b.get("slot_id", "")), "Same seed must keep slot_id stable"):
			return
		if not T.require_true(self, str(slot_a.get("task_id", "")) == str(slot_b.get("task_id", "")), "Same seed must keep slot task ownership stable"):
			return
		if not T.require_true(self, str(slot_a.get("slot_kind", "")) == str(slot_b.get("slot_kind", "")), "Same seed must keep slot kind stable"):
			return
		var anchor_a: Vector3 = slot_a.get("world_anchor", Vector3.ZERO)
		var anchor_b: Vector3 = slot_b.get("world_anchor", Vector3.ZERO)
		if not T.require_true(self, anchor_a.distance_to(anchor_b) <= 0.001, "Same seed must keep slot world_anchor stable"):
			return
		if not T.require_true(self, is_equal_approx(float(slot_a.get("trigger_radius_m", 0.0)), float(slot_b.get("trigger_radius_m", 0.0))), "Same seed must keep trigger_radius_m stable"):
			return

	T.pass_and_quit(self)
