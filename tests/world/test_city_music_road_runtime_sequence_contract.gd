extends SceneTree

const T := preload("res://tests/_test_util.gd")

const DEFINITION_SCRIPT_PATH := "res://city_game/world/features/music_road/CityMusicRoadDefinition.gd"
const RUN_STATE_SCRIPT_PATH := "res://city_game/world/features/music_road/CityMusicRoadRunState.gd"
const DEFINITION_PATH := "res://city_game/serviceability/landmarks/generated/landmark_v23_music_road_chunk_136_136/music_road_definition.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var definition_script = load(DEFINITION_SCRIPT_PATH)
	if not T.require_true(self, definition_script != null, "Music road runtime sequence contract requires CityMusicRoadDefinition.gd"):
		return
	var run_state_script = load(RUN_STATE_SCRIPT_PATH)
	if not T.require_true(self, run_state_script != null, "Music road runtime sequence contract requires CityMusicRoadRunState.gd"):
		return
	if not T.require_true(self, definition_script.has_method("load_from_path"), "Music road definition script must expose load_from_path()"):
		return

	var definition = definition_script.load_from_path(DEFINITION_PATH)
	if not T.require_true(self, definition != null, "Music road runtime sequence contract requires a decodable music_road_definition"):
		return

	var run_state = run_state_script.new()
	if not T.require_true(self, run_state != null and run_state.has_method("setup"), "Music road runtime sequence contract requires run-state setup()"):
		return
	if not T.require_true(self, run_state.has_method("advance_local_vehicle_state"), "Music road runtime sequence contract requires advance_local_vehicle_state()"):
		return
	if not T.require_true(self, run_state.has_method("get_state"), "Music road runtime sequence contract requires get_state()"):
		return

	run_state.setup(definition)
	var road_length_m := float(definition.get_value("road_length_m", 0.0))
	var lead_in_m := float(definition.get_value("lead_in_m", 0.0))
	var target_speed_mps := float(definition.get_value("target_speed_mps", 0.0))
	if not T.require_true(self, road_length_m > 0.0 and target_speed_mps > 0.0, "Music road runtime sequence contract requires positive road_length_m and target_speed_mps"):
		return

	_simulate_run(run_state, -2.0, road_length_m + 8.0, target_speed_mps, lead_in_m)
	var state: Dictionary = run_state.get_state()
	var triggered_events: Array = state.get("triggered_note_events", [])
	if not T.require_true(self, bool(state.get("song_success", false)), "Music road runtime sequence contract must mark the canonical positive-direction run as song_success"):
		return
	if not T.require_true(self, triggered_events.size() == int(state.get("strip_count", 0)), "Music road runtime sequence contract must trigger exactly one event per strip during a canonical run"):
		return
	if not T.require_true(self, str(state.get("last_completed_direction", "")) == "forward", "Music road runtime sequence contract must preserve forward completion direction for canonical success"):
		return
	if not T.require_true(self, int(state.get("double_fire_count", -1)) == 0, "Music road runtime sequence contract must prevent strip double-fire inside a single run"):
		return
	if not T.require_true(self, int((triggered_events[0] as Dictionary).get("order_index", -1)) == 0, "Music road runtime sequence contract must start with order_index 0 on the canonical run"):
		return
	if not T.require_true(self, int((triggered_events[triggered_events.size() - 1] as Dictionary).get("order_index", -1)) == triggered_events.size() - 1, "Music road runtime sequence contract must finish on the last formal strip order_index"):
		return

	T.pass_and_quit(self)

func _simulate_run(run_state, start_z: float, end_z: float, speed_mps: float, lead_in_m: float) -> void:
	var step_sec := 0.1
	var time_sec := 0.0
	var z := start_z
	var direction := 1.0 if end_z >= start_z else -1.0
	var total_distance := absf(end_z - start_z)
	var travelled := 0.0
	run_state.advance_local_vehicle_state({
		"driving": true,
		"local_position": Vector3(0.0, 0.0, z),
	}, time_sec)
	while travelled < total_distance:
		time_sec += step_sec
		var step_distance := minf(speed_mps * step_sec, total_distance - travelled)
		travelled += step_distance
		z += step_distance * direction
		var x := 0.0
		if z > lead_in_m + 2.0:
			x = 0.35
		run_state.advance_local_vehicle_state({
			"driving": true,
			"local_position": Vector3(x, 0.0, z),
		}, time_sec)
