#pragma once

#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <atomic>
#include <cstddef>
#include <deque>
#include <mutex>
#include <thread>

namespace godot {

class CityRadioNativeBackend {
public:
	CityRadioNativeBackend();
	~CityRadioNativeBackend();

	String ping() const;
	bool is_available() const;
	String get_build_summary() const;
	bool is_stop_requested() const;

	bool open_stream(const String &station_id, const String &station_name, const String &resolved_url, const String &classification);
	void stop_stream(const String &reason = "stopped");
	Dictionary poll_state() const;
	PackedVector2Array pop_audio_frames(int max_frames);

private:
	static constexpr int TARGET_MIX_RATE = 48000;
	static constexpr int CHANNEL_COUNT = 2;
	static constexpr size_t MAX_BUFFERED_FRAMES = 48000 * 6;
	static constexpr int MAX_RETRY_COUNT = 3;

	mutable std::mutex _state_mutex;
	std::mutex _frame_mutex;
	std::deque<Vector2> _frame_queue;
	std::thread *_worker_thread = nullptr;
	std::atomic<bool> _stop_requested = false;

	String _station_id = "";
	String _station_name = "";
	String _classification = "";
	String _resolved_url = "";
	String _playback_state = "stopped";
	String _buffer_state = "idle";
	String _error_code = "";
	String _error_message = "";
	String _codec_name = "";
	String _stream_title = "";
	int _source_sample_rate = 0;
	int _source_channels = 0;
	int _latency_ms = 0;
	int _underflow_count = 0;

	void _clear_frame_queue();
	void _join_worker();
	void _update_latency_locked(size_t queued_frames);
	void _worker_loop(String station_id, String station_name, String resolved_url, String classification);

#ifdef CITY_RADIO_USE_FFMPEG
	bool _decode_stream(const String &station_id, const String &station_name, const String &resolved_url, const String &classification, int attempt_index);
	void _append_frames(const float *interleaved_frames, int frame_count);
#endif
};

} // namespace godot
