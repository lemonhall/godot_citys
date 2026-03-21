extends SceneTree

const T := preload("res://tests/_test_util.gd")

const GUNSHIP_TASK_ID := "task_helicopter_gunship_v37"
const GUNSHIP_ICON_ID := "helicopter"
const GUNSHIP_ICON_GLYPH := "🚁"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Helicopter gunship pin contract requires CityPrototype.tscn")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	for required_method in [
		"get_task_runtime",
		"set_full_map_open",
		"get_map_screen_state",
		"select_task_for_tracking",
		"get_active_route_result",
	]:
		if not T.require_true(self, world.has_method(required_method), "Helicopter gunship pin contract requires %s()" % required_method):
			return

	var task_runtime = world.get_task_runtime()
	var task_snapshot: Dictionary = task_runtime.get_task_snapshot(GUNSHIP_TASK_ID)
	if not T.require_true(self, str(task_snapshot.get("task_id", "")) == GUNSHIP_TASK_ID, "Gunship pin contract requires the formal v37 gunship task in runtime"):
		return
	if not T.require_true(self, str(task_snapshot.get("icon_id", "")) == GUNSHIP_ICON_ID, "Gunship task definition must freeze icon_id = helicopter for the formal full-map pin"):
		return

	world.set_full_map_open(true)
	await process_frame

	var map_state: Dictionary = world.get_map_screen_state()
	var marker := _find_marker_by_task_id(map_state.get("pin_markers", []), GUNSHIP_TASK_ID)
	if not T.require_true(self, not marker.is_empty(), "Full map render state must expose the gunship task pin through the shared task pin projection"):
		return
	if not T.require_true(self, str(marker.get("pin_type", "")) == "task_available", "Available gunship task pin must keep the formal task_available pin_type in the full-map render state"):
		return
	if not T.require_true(self, str(marker.get("icon_id", "")) == GUNSHIP_ICON_ID, "Gunship task pin must carry the helicopter icon_id through the shared pin registry"):
		return
	if not T.require_true(self, str(marker.get("icon_glyph", "")) == GUNSHIP_ICON_GLYPH, "Gunship task pin must resolve the helicopter glyph from icon_id in CityMapScreen"):
		return

	var selected: Dictionary = world.select_task_for_tracking(GUNSHIP_TASK_ID)
	if not T.require_true(self, str(selected.get("task_id", "")) == GUNSHIP_TASK_ID, "Gunship pin contract must allow the helicopter task to be tracked for minimap pin coverage"):
		return
	if not T.require_true(self, str(world.get_active_route_result().get("route_style_id", "")) == "task_available", "Tracking the gunship task pin must still drive the shared green task_available route style"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _find_marker_by_task_id(markers: Array, task_id: String) -> Dictionary:
	for marker_variant in markers:
		var marker: Dictionary = marker_variant
		if str(marker.get("task_id", "")) == task_id:
			return marker
	return {}
