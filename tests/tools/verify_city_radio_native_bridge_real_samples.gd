extends SceneTree

const GDEXTENSION_PATH := "res://city_game/native/radio_backend/radio_backend.gdextension"
const BRIDGE_CLASS_NAME := "CityRadioNativeBridge"
const SAMPLE_TIMEOUT_MSEC := 30000
const POLL_INTERVAL_SEC := 0.05
const POP_FRAMES_PER_TICK := 4096
const SUCCESS_FRAME_THRESHOLD := 4096
const SAMPLES := [
	{
		"sample_id": "direct",
		"station_id": "sample:direct",
		"station_name": "SomaFM Direct",
		"url": "https://ice1.somafm.com/groovesalad-128-mp3",
		"classification": "direct",
	},
	{
		"sample_id": "playlist",
		"station_id": "sample:playlist",
		"station_name": "SomaFM Playlist",
		"url": "https://ice6.somafm.com/groovesalad-128-mp3",
		"classification": "pls",
	},
	{
		"sample_id": "hls",
		"station_id": "sample:hls",
		"station_name": "SomaFM HLS FLAC",
		"url": "https://hls.somafm.com/hls/groovesalad/FLAC/program.m3u8",
		"classification": "hls",
	},
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var extension_resource: Resource = load(GDEXTENSION_PATH)
	if extension_resource == null:
		push_error("Missing radio_backend.gdextension for native real-sample verification")
		quit(2)
		return
	if not ClassDB.class_exists(BRIDGE_CLASS_NAME):
		push_error("Missing CityRadioNativeBridge class for native real-sample verification")
		quit(3)
		return

	var results: Array = []
	var all_success := true
	for sample_variant in SAMPLES:
		var sample: Dictionary = (sample_variant as Dictionary).duplicate(true)
		var bridge: Object = ClassDB.instantiate(BRIDGE_CLASS_NAME) as Object
		if bridge == null:
			push_error("Failed to instantiate CityRadioNativeBridge for native real-sample verification")
			quit(4)
			return
		var result := await _verify_sample(bridge, sample)
		results.append(result)
		if not bool(result.get("success", false)):
			all_success = false
		bridge = null
		await process_frame

	print(JSON.stringify({
		"verified_at_utc": Time.get_datetime_string_from_system(true, true),
		"results": results,
	}, "\t"))
	quit(0 if all_success else 1)

func _verify_sample(bridge: Object, sample: Dictionary) -> Dictionary:
	var sample_id := str(sample.get("sample_id", "sample"))
	var started_msec := Time.get_ticks_msec()
	var open_ok := bool(bridge.call(
		"open_stream",
		str(sample.get("station_id", sample_id)),
		str(sample.get("station_name", sample_id)),
		str(sample.get("url", "")),
		str(sample.get("classification", "direct")),
	))
	var first_audio_msec := -1
	var popped_frame_count := 0
	var last_state: Dictionary = {}
	while Time.get_ticks_msec() - started_msec < SAMPLE_TIMEOUT_MSEC:
		last_state = bridge.call("poll_state")
		var frames: PackedVector2Array = bridge.call("pop_audio_frames", POP_FRAMES_PER_TICK)
		if not frames.is_empty():
			popped_frame_count += frames.size()
			if first_audio_msec < 0:
				first_audio_msec = Time.get_ticks_msec() - started_msec
			if popped_frame_count >= SUCCESS_FRAME_THRESHOLD:
				break
		var playback_state := str(last_state.get("playback_state", ""))
		if playback_state == "error" and popped_frame_count <= 0:
			break
		await create_timer(POLL_INTERVAL_SEC).timeout
	bridge.call("stop_stream", "verification_complete")
	last_state = bridge.call("poll_state")
	var metadata: Dictionary = (last_state.get("metadata", {}) as Dictionary).duplicate(true)
	return {
		"sample_id": sample_id,
		"url": str(sample.get("url", "")),
		"classification": str(sample.get("classification", "")),
		"open_ok": open_ok,
		"success": open_ok and first_audio_msec >= 0 and popped_frame_count >= SUCCESS_FRAME_THRESHOLD,
		"first_audio_msec": first_audio_msec,
		"popped_frame_count": popped_frame_count,
		"playback_state": str(last_state.get("playback_state", "")),
		"buffer_state": str(last_state.get("buffer_state", "")),
		"resolved_url": str(last_state.get("resolved_url", "")),
		"latency_ms": int(last_state.get("latency_ms", 0)),
		"underflow_count": int(last_state.get("underflow_count", 0)),
		"error_code": str(last_state.get("error_code", "")),
		"error_message": str(last_state.get("error_message", "")),
		"metadata": metadata,
	}
