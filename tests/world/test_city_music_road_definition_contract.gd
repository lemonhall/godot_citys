extends SceneTree

const T := preload("res://tests/_test_util.gd")

const DEFINITION_PATH := "res://city_game/serviceability/landmarks/generated/landmark_v23_music_road_chunk_136_136/music_road_definition.json"
const EXPECTED_SEQUENCE_PATH := "res://city_game/serviceability/landmarks/generated/landmark_v23_music_road_chunk_136_136/jue_bie_shu_sequence.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var definition_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(DEFINITION_PATH))
	var definition_variant = JSON.parse_string(definition_text)
	if not T.require_true(self, definition_variant is Dictionary, "Music road definition contract requires music_road_definition.json to parse as Dictionary"):
		return
	var definition: Dictionary = definition_variant
	if not T.require_true(self, str(definition.get("experience_kind", "")) == "music_road", "Music road definition must freeze experience_kind = music_road"):
		return
	if not T.require_true(self, str(definition.get("song_id", "")) == "jue_bie_shu", "Music road definition must freeze song_id = jue_bie_shu"):
		return
	if not T.require_true(self, str(definition.get("display_name", "")) != "", "Music road definition must expose a non-empty display_name"):
		return
	if not T.require_true(self, float(definition.get("target_speed_mps", 0.0)) > 0.0, "Music road definition must expose target_speed_mps"):
		return
	if not T.require_true(self, float(definition.get("speed_tolerance_mps", 0.0)) > 0.0, "Music road definition must expose speed_tolerance_mps"):
		return
	if not T.require_true(self, str(definition.get("entry_direction", "")) != "", "Music road definition must expose entry_direction"):
		return
	if not T.require_true(self, definition.get("entry_gate", null) is Dictionary, "Music road definition must expose entry_gate geometry"):
		return
	if not T.require_true(self, float(definition.get("approach_glow_distance_m", 0.0)) > 0.0, "Music road definition must expose approach_glow_distance_m"):
		return
	if not T.require_true(self, float(definition.get("hit_flash_duration_sec", 0.0)) > 0.0, "Music road definition must expose hit_flash_duration_sec"):
		return
	if not T.require_true(self, float(definition.get("release_decay_duration_sec", 0.0)) > 0.0, "Music road definition must expose release_decay_duration_sec"):
		return
	if not T.require_true(self, str(definition.get("sequence_path", "")) == EXPECTED_SEQUENCE_PATH, "Music road definition must point at the shared normalized note sequence"):
		return

	var note_strips_variant = definition.get("note_strips", [])
	if not T.require_true(self, note_strips_variant is Array, "Music road definition must expose note_strips as Array"):
		return
	var note_strips: Array = note_strips_variant
	if not T.require_true(self, note_strips.size() >= 900, "Music road definition must decode the full jue_bie_shu arrangement instead of a tiny placeholder strip list"):
		return

	var previous_order_index := -1
	var strip_ids := {}
	for strip_variant in note_strips:
		if not T.require_true(self, strip_variant is Dictionary, "Each music road strip must decode as Dictionary"):
			return
		var strip: Dictionary = strip_variant
		var strip_id := str(strip.get("strip_id", ""))
		if not T.require_true(self, strip_id != "", "Each music road strip must expose strip_id"):
			return
		if not T.require_true(self, not strip_ids.has(strip_id), "Music road strip_id values must stay unique"):
			return
		strip_ids[strip_id] = true
		var order_index := int(strip.get("order_index", -1))
		if not T.require_true(self, order_index >= 0, "Each music road strip must expose a non-negative order_index"):
			return
		if not T.require_true(self, order_index > previous_order_index, "Music road strips must stay in strictly increasing order_index order"):
			return
		previous_order_index = order_index
		if not T.require_true(self, _decode_vector3(strip.get("local_center", null)) is Vector3, "Each music road strip must expose landmark-local center as Vector3"):
			return
		if not T.require_true(self, float(strip.get("trigger_width_m", 0.0)) > 0.0, "Each music road strip must expose trigger_width_m"):
			return
		if not T.require_true(self, float(strip.get("trigger_length_m", 0.0)) > 0.0, "Each music road strip must expose trigger_length_m"):
			return
		if not T.require_true(self, str(strip.get("note_id", "")) != "", "Each music road strip must expose note_id"):
			return
		if not T.require_true(self, str(strip.get("sample_id", "")) != "", "Each music road strip must expose sample_id"):
			return
		var visual_key_kind := str(strip.get("visual_key_kind", ""))
		if not T.require_true(self, visual_key_kind == "white" or visual_key_kind == "black", "Each music road strip must freeze visual_key_kind to white/black"):
			return

	var sequence_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(EXPECTED_SEQUENCE_PATH))
	var sequence_variant = JSON.parse_string(sequence_text)
	if not T.require_true(self, sequence_variant is Dictionary, "Music road definition contract requires the shared sequence json"):
		return
	var sequence: Dictionary = sequence_variant
	if not T.require_true(self, str(sequence.get("song_id", "")) == "jue_bie_shu", "Shared music road sequence must preserve song_id = jue_bie_shu"):
		return
	var note_events: Array = sequence.get("note_events", [])
	if not T.require_true(self, note_events.size() == note_strips.size(), "Music road definition must stay aligned with the shared normalized note sequence one strip per note event"):
		return

	T.pass_and_quit(self)

func _decode_vector3(value: Variant) -> Variant:
	if value is Vector3:
		return value
	if not (value is Dictionary):
		return null
	var payload: Dictionary = value
	if str(payload.get("@type", "")) != "Vector3":
		return null
	return Vector3(
		float(payload.get("x", 0.0)),
		float(payload.get("y", 0.0)),
		float(payload.get("z", 0.0))
	)
