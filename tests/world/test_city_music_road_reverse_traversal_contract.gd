extends SceneTree

const T := preload("res://tests/_test_util.gd")

const DEFINITION_SCRIPT_PATH := "res://city_game/world/features/music_road/CityMusicRoadDefinition.gd"
const RUN_STATE_SCRIPT_PATH := "res://city_game/world/features/music_road/CityMusicRoadRunState.gd"
const DEFINITION_PATH := "res://city_game/serviceability/landmarks/generated/landmark_v23_music_road_chunk_136_136/music_road_definition.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var definition_script = load(DEFINITION_SCRIPT_PATH)
	if not T.require_true(self, definition_script != null and definition_script.has_method("load_from_path"), "Music road reverse traversal contract requires definition loading support"):
		return
	var run_state_script = load(RUN_STATE_SCRIPT_PATH)
	if not T.require_true(self, run_state_script != null, "Music road reverse traversal contract requires CityMusicRoadRunState.gd"):
		return

	var definition = definition_script.load_from_path(DEFINITION_PATH)
	if not T.require_true(self, definition != null, "Music road reverse traversal contract requires a decodable definition"):
		return

	var run_state = run_state_script.new()
	run_state.setup(definition)
	var road_length_m := float(definition.get_value("road_length_m", 0.0))
	var target_speed_mps := float(definition.get_value("target_speed_mps", 0.0))
	var step_sec := 0.1
	var time_sec := 0.0
	var z := road_length_m + 4.0
	run_state.advance_local_vehicle_state({
		"driving": true,
		"local_position": Vector3(0.0, 0.0, z),
	}, time_sec)
	while z > -2.0:
		time_sec += step_sec
		z -= target_speed_mps * step_sec
		run_state.advance_local_vehicle_state({
			"driving": true,
			"local_position": Vector3(0.0, 0.0, z),
		}, time_sec)

	var state: Dictionary = run_state.get_state()
	var events: Array = state.get("triggered_note_events", [])
	if not T.require_true(self, events.size() == int(state.get("strip_count", 0)), "Music road reverse traversal contract must audition every strip in reverse traversal mode"):
		return
	if not T.require_true(self, not bool(state.get("song_success", false)), "Music road reverse traversal contract must not treat reverse traversal as canonical song_success"):
		return
	if not T.require_true(self, str(state.get("last_completed_direction", "")) == "reverse", "Music road reverse traversal contract must report reverse completion direction"):
		return
	if not T.require_true(self, int((events[0] as Dictionary).get("order_index", -1)) == events.size() - 1, "Music road reverse traversal contract must start audition from the last strip order_index"):
		return
	if not T.require_true(self, int((events[events.size() - 1] as Dictionary).get("order_index", -1)) == 0, "Music road reverse traversal contract must finish audition on strip order_index 0"):
		return

	T.pass_and_quit(self)
