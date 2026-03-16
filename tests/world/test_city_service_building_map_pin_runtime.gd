extends SceneTree

const T := preload("res://tests/_test_util.gd")
const RUNTIME_PATH := "res://city_game/world/serviceability/CityServiceBuildingMapPinRuntime.gd"
const REGISTRY_PATH := "res://city_game/serviceability/buildings/generated/building_override_registry.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var runtime_script := load(RUNTIME_PATH)
	if runtime_script == null:
		T.fail_and_quit(self, "Service building map pin runtime test requires CityServiceBuildingMapPinRuntime.gd")
		return
	var runtime = runtime_script.new()
	if not T.require_true(self, runtime.has_method("configure"), "Service building map pin runtime must expose configure()"):
		return
	if not T.require_true(self, runtime.has_method("advance"), "Service building map pin runtime must expose advance() for lazy batches"):
		return
	if not T.require_true(self, runtime.has_method("get_state"), "Service building map pin runtime must expose get_state()"):
		return
	if not T.require_true(self, runtime.has_method("get_pins"), "Service building map pin runtime must expose get_pins()"):
		return

	var registry_variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(REGISTRY_PATH)))
	if not T.require_true(self, registry_variant is Dictionary, "Service building map pin runtime test requires a valid generated building override registry"):
		return
	var entries: Dictionary = (registry_variant as Dictionary).get("entries", {})
	if not T.require_true(self, entries.size() >= 2, "Service building map pin runtime test requires at least two generated building registry entries"):
		return

	runtime.configure(entries)
	var initial_state: Dictionary = runtime.get_state()
	if not T.require_true(self, bool(initial_state.get("loading", false)), "Configuring service building map pin runtime must enqueue lazy loading work"):
		return
	if not T.require_true(self, int(initial_state.get("pending_entry_count", -1)) == entries.size(), "Service building map pin runtime must expose every registry entry as pending before the first batch advance"):
		return
	if not T.require_true(self, int(initial_state.get("manifest_read_count", -1)) == 0, "Service building map pin runtime must not read manifest files before the first lazy advance"):
		return

	var batch_one_result: Dictionary = runtime.advance(1, 1000000)
	var batch_one_state: Dictionary = runtime.get_state()
	if not T.require_true(self, int(batch_one_state.get("loaded_entry_count", -1)) == 1, "Advancing one lazy batch must only consume one manifest entry"):
		return
	if not T.require_true(self, int(batch_one_state.get("pending_entry_count", -1)) == entries.size() - 1, "Advancing one lazy batch must leave the remaining entries pending"):
		return
	if not T.require_true(self, int(batch_one_state.get("pin_count", -1)) == 0, "The first generated building manifest must not create a pin unless it explicitly declares full_map_pin metadata"):
		return
	if not T.require_true(self, not bool(batch_one_result.get("did_pin_delta", true)), "Reading a non-pinned manifest entry must not force a pin registry delta"):
		return
	if not T.require_true(self, (batch_one_result.get("pin_upserts", []) as Array).is_empty(), "A non-pinned manifest entry must not emit service-building pin upserts"):
		return
	if not T.require_true(self, (batch_one_result.get("pin_remove_ids", []) as Array).is_empty(), "A non-pinned manifest entry must not emit service-building pin removals"):
		return

	var batch_two_result: Dictionary = runtime.advance(1, 1000000)
	var completed_state: Dictionary = runtime.get_state()
	if not T.require_true(self, not bool(completed_state.get("loading", true)), "Service building map pin runtime must leave loading state once all queued entries are processed"):
		return
	if not T.require_true(self, int(completed_state.get("loaded_entry_count", -1)) == entries.size(), "Service building map pin runtime must eventually process every queued registry entry"):
		return
	if not T.require_true(self, int(completed_state.get("pin_count", -1)) == 1, "Exactly one generated building manifest should currently opt into a full-map icon pin"):
		return
	if not T.require_true(self, bool(batch_two_result.get("did_pin_delta", false)), "Reading a pinned manifest entry must emit a service-building pin delta"):
		return
	var batch_two_upserts: Array = batch_two_result.get("pin_upserts", [])
	if not T.require_true(self, batch_two_upserts.size() == 1, "The current fixtures must emit exactly one service-building pin upsert when the cafe manifest is read"):
		return
	if not T.require_true(self, str((batch_two_upserts[0] as Dictionary).get("icon_id", "")) == "cafe", "The service-building pin delta must carry the cafe icon contract"):
		return
	if not T.require_true(self, (batch_two_result.get("pin_remove_ids", []) as Array).is_empty(), "The current fixtures must not emit service-building pin removals while the registry only grows"):
		return

	var pins: Array = runtime.get_pins()
	if not T.require_true(self, pins.size() == 1, "Service building map pin runtime must emit exactly one custom-building full-map pin from the current fixtures"):
		return
	var cafe_pin: Dictionary = pins[0]
	for required_key in ["pin_id", "pin_type", "pin_source", "visibility_scope", "building_id", "world_position", "title", "subtitle", "priority", "icon_id"]:
		if not T.require_true(self, cafe_pin.has(required_key), "Service building map pin runtime must publish %s" % required_key):
			return
	if not T.require_true(self, str(cafe_pin.get("pin_type", "")) == "service_building", "Custom building full-map pins must publish the formal service_building pin_type"):
		return
	if not T.require_true(self, str(cafe_pin.get("visibility_scope", "")) == "full_map", "Custom building full-map pins must stay out of minimap scope"):
		return
	if not T.require_true(self, str(cafe_pin.get("icon_id", "")) == "cafe", "Cafe manifest must resolve to the formal cafe icon_id"):
		return
	if not T.require_true(self, str(cafe_pin.get("building_id", "")) == "bld:v15-building-id-1:seed424242:chunk_137_136:003", "Cafe full-map pin must keep the stable building_id owner"):
		return
	if not T.require_true(self, cafe_pin.get("world_position", Vector3.ZERO) is Vector3, "Custom building full-map pin must decode a formal Vector3 world_position from the manifest sidecar"):
		return

	var manifest_read_count_before_reconfigure := int(completed_state.get("manifest_read_count", -1))
	runtime.configure(entries)
	var reconfigured_state: Dictionary = runtime.get_state()
	if not T.require_true(self, int(reconfigured_state.get("pending_entry_count", -1)) == 0, "Reconfiguring the same service building entries must reuse cached manifest results instead of requeueing all entries"):
		return
	var reused_result: Dictionary = runtime.advance(4, 1000000)
	var reused_state: Dictionary = runtime.get_state()
	if not T.require_true(self, int(reused_state.get("manifest_read_count", -1)) == manifest_read_count_before_reconfigure, "Reconfiguring identical service building entries must not reread manifest files from disk"):
		return
	if not T.require_true(self, not bool(reused_result.get("did_pin_delta", true)), "Reusing identical service building entries must not emit pin deltas"):
		return

	T.pass_and_quit(self)
