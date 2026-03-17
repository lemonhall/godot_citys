extends SceneTree

const T := preload("res://tests/_test_util.gd")

const DEFINITION_SCRIPT_PATH := "res://city_game/world/features/music_road/CityMusicRoadDefinition.gd"
const RUN_STATE_SCRIPT_PATH := "res://city_game/world/features/music_road/CityMusicRoadRunState.gd"
const DEFINITION_PATH := "res://city_game/serviceability/landmarks/generated/landmark_v23_music_road_chunk_136_136/music_road_definition.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var definition_script = load(DEFINITION_SCRIPT_PATH)
	if not T.require_true(self, definition_script != null and definition_script.has_method("load_from_path"), "Music road speed window contract requires definition loading support"):
		return
	var run_state_script = load(RUN_STATE_SCRIPT_PATH)
	if not T.require_true(self, run_state_script != null, "Music road speed window contract requires CityMusicRoadRunState.gd"):
		return

	var definition = definition_script.load_from_path(DEFINITION_PATH)
	if not T.require_true(self, definition != null, "Music road speed window contract requires a decodable definition"):
		return
	var target_speed_mps := float(definition.get_value("target_speed_mps", 0.0))
	var slow_speed_mps := target_speed_mps * 0.55

	var fast_state := _run_simulation(run_state_script, definition, target_speed_mps)
	var slow_state := _run_simulation(run_state_script, definition, slow_speed_mps)
	if not T.require_true(self, bool(fast_state.get("song_success", false)), "Music road speed window contract must accept a target-speed canonical run"):
		return
	if not T.require_true(self, not bool(slow_state.get("song_success", false)), "Music road speed window contract must reject a too-slow canonical run as formal success"):
		return

	var fast_events: Array = fast_state.get("triggered_note_events", [])
	var slow_events: Array = slow_state.get("triggered_note_events", [])
	if not T.require_true(self, fast_events.size() >= 3 and slow_events.size() >= 3, "Music road speed window contract requires multiple triggered note events for interval comparison"):
		return
	var fast_interval_sec := _interval_between(fast_events, 0, 1)
	var slow_interval_sec := _interval_between(slow_events, 0, 1)
	if not T.require_true(self, slow_interval_sec > fast_interval_sec * 1.6, "Music road speed window contract must preserve slower real crossing intervals in triggered note timing"):
		return
	if not T.require_true(self, int(slow_state.get("triggered_note_count", 0)) == int(slow_state.get("strip_count", 0)), "Music road speed window contract must still audition the full song even when the speed window rejects success"):
		return

	T.pass_and_quit(self)

func _run_simulation(run_state_script, definition, speed_mps: float) -> Dictionary:
	var run_state = run_state_script.new()
	run_state.setup(definition)
	var road_length_m := float(definition.get_value("road_length_m", 0.0))
	var lead_in_m := float(definition.get_value("lead_in_m", 0.0))
	var step_sec := 0.1
	var time_sec := 0.0
	var z := -2.0
	run_state.advance_local_vehicle_state({
		"driving": true,
		"local_position": Vector3(0.0, 0.0, z),
	}, time_sec)
	while z < road_length_m + 8.0:
		time_sec += step_sec
		z += speed_mps * step_sec
		var x := 0.0 if z < lead_in_m + 1.0 else 0.25
		run_state.advance_local_vehicle_state({
			"driving": true,
			"local_position": Vector3(x, 0.0, z),
		}, time_sec)
	return run_state.get_state()

func _interval_between(events: Array, first_index: int, second_index: int) -> float:
	var first_event: Dictionary = events[first_index]
	var second_event: Dictionary = events[second_index]
	return float(second_event.get("event_time_sec", 0.0)) - float(first_event.get("event_time_sec", 0.0))
