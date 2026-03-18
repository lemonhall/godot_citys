#include "CityRadioNativeBackend.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <string>
#include <thread>
#include <vector>

#ifdef CITY_RADIO_USE_FFMPEG
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/dict.h>
#include <libavutil/error.h>
#include <libavutil/samplefmt.h>
#include <libswresample/swresample.h>
}
#endif

using namespace godot;

namespace {

#ifdef CITY_RADIO_USE_FFMPEG
std::string utf8_string(const String &value) {
	CharString utf8 = value.utf8();
	return std::string(utf8.get_data());
}

String ffmpeg_error_string(int error_code) {
	char buffer[AV_ERROR_MAX_STRING_SIZE] = {};
	av_strerror(error_code, buffer, AV_ERROR_MAX_STRING_SIZE);
	return String::utf8(buffer);
}

String metadata_value(AVDictionary *metadata, const char *key) {
	if (metadata == nullptr || key == nullptr) {
		return "";
	}
	AVDictionaryEntry *entry = av_dict_get(metadata, key, nullptr, 0);
	if (entry == nullptr || entry->value == nullptr) {
		return "";
	}
	return String::utf8(entry->value);
}

int ffmpeg_interrupt_callback(void *opaque) {
	CityRadioNativeBackend *backend = reinterpret_cast<CityRadioNativeBackend *>(opaque);
	return backend != nullptr && backend->is_stop_requested() ? 1 : 0;
}
#endif

} // namespace

CityRadioNativeBackend::CityRadioNativeBackend() {
#ifdef CITY_RADIO_USE_FFMPEG
	avformat_network_init();
	av_log_set_level(AV_LOG_QUIET);
#endif
}

CityRadioNativeBackend::~CityRadioNativeBackend() {
	stop_stream("shutdown");
#ifdef CITY_RADIO_USE_FFMPEG
	avformat_network_deinit();
#endif
}

String CityRadioNativeBackend::ping() const {
	return "pong";
}

bool CityRadioNativeBackend::is_available() const {
#ifdef CITY_RADIO_USE_FFMPEG
	return true;
#else
	return false;
#endif
}

String CityRadioNativeBackend::get_build_summary() const {
#ifdef CITY_RADIO_USE_FFMPEG
	return "ffmpeg_enabled";
#else
	return "ffmpeg_not_configured";
#endif
}

bool CityRadioNativeBackend::is_stop_requested() const {
	return _stop_requested.load();
}

bool CityRadioNativeBackend::open_stream(const String &station_id, const String &station_name, const String &resolved_url, const String &classification) {
	stop_stream("switch");

	{
		std::lock_guard<std::mutex> state_lock(_state_mutex);
		_station_id = station_id;
		_station_name = station_name;
		_classification = classification;
		_resolved_url = resolved_url;
		_playback_state = "playing";
		_buffer_state = "connecting";
		_error_code = "";
		_error_message = "";
		_codec_name = "";
		_stream_title = "";
		_source_sample_rate = 0;
		_source_channels = 0;
		_latency_ms = 0;
	}
	_clear_frame_queue();

	if (resolved_url.strip_edges().is_empty()) {
		std::lock_guard<std::mutex> state_lock(_state_mutex);
		_playback_state = "error";
		_buffer_state = "error";
		_error_code = "invalid_url";
		_error_message = "resolved_url_is_empty";
		return false;
	}
	if (!is_available()) {
		std::lock_guard<std::mutex> state_lock(_state_mutex);
		_playback_state = "error";
		_buffer_state = "error";
		_error_code = "ffmpeg_unavailable";
		_error_message = "ffmpeg_not_configured";
		return false;
	}

	_stop_requested.store(false);
	_worker_thread = new std::thread(&CityRadioNativeBackend::_worker_loop, this, station_id, station_name, resolved_url, classification);
	return true;
}

void CityRadioNativeBackend::stop_stream(const String &reason) {
	_stop_requested.store(true);
	_join_worker();
	_clear_frame_queue();

	std::lock_guard<std::mutex> state_lock(_state_mutex);
	_playback_state = "stopped";
	_buffer_state = "idle";
	_error_code = "";
	_error_message = "";
	_latency_ms = 0;
	if (reason == "switch") {
		return;
	}
}

Dictionary CityRadioNativeBackend::poll_state() const {
	Dictionary metadata;
	std::lock_guard<std::mutex> state_lock(_state_mutex);
	metadata.set(String("station_id"), _station_id);
	metadata.set(String("station_name"), _station_name);
	metadata.set(String("classification"), _classification);
	if (!_codec_name.is_empty()) {
		metadata.set(String("codec"), _codec_name);
	}
	if (!_stream_title.is_empty()) {
		metadata.set(String("stream_title"), _stream_title);
	}
	if (_source_sample_rate > 0) {
		metadata.set(String("sample_rate_hz"), _source_sample_rate);
	}
	if (_source_channels > 0) {
		metadata.set(String("channel_count"), _source_channels);
	}
	Dictionary state;
	state.set(String("backend_id"), String("native"));
	state.set(String("playback_state"), _playback_state);
	state.set(String("buffer_state"), _buffer_state);
	state.set(String("resolved_url"), _resolved_url);
	state.set(String("metadata"), metadata);
	state.set(String("latency_ms"), _latency_ms);
	state.set(String("underflow_count"), _underflow_count);
	state.set(String("error_code"), _error_code);
	state.set(String("error_message"), _error_message);
	return state;
}

PackedVector2Array CityRadioNativeBackend::pop_audio_frames(int max_frames) {
	PackedVector2Array frames;
	if (max_frames <= 0) {
		return frames;
	}

	int frames_to_pop = 0;
	size_t queued_frames_after_pop = 0;
	{
		std::lock_guard<std::mutex> frame_lock(_frame_mutex);
		frames_to_pop = std::min(max_frames, static_cast<int>(_frame_queue.size()));
		if (frames_to_pop > 0) {
			frames.resize(frames_to_pop);
			Vector2 *write_ptr = frames.ptrw();
			for (int frame_index = 0; frame_index < frames_to_pop; frame_index++) {
				write_ptr[frame_index] = _frame_queue.front();
				_frame_queue.pop_front();
			}
		}
		queued_frames_after_pop = _frame_queue.size();
	}

	std::lock_guard<std::mutex> state_lock(_state_mutex);
	_update_latency_locked(queued_frames_after_pop);
	if (frames_to_pop <= 0 && _playback_state == "playing" && _buffer_state != "connecting" && _buffer_state != "buffering") {
		_underflow_count += 1;
		_buffer_state = "stalled";
	} else if (frames_to_pop > 0 && (_buffer_state == "stalled" || _buffer_state == "buffering")) {
		_buffer_state = "ready";
	}
	return frames;
}

void CityRadioNativeBackend::_clear_frame_queue() {
	std::lock_guard<std::mutex> frame_lock(_frame_mutex);
	_frame_queue.clear();
}

void CityRadioNativeBackend::_join_worker() {
	if (_worker_thread == nullptr) {
		return;
	}
	if (_worker_thread->joinable()) {
		_worker_thread->join();
	}
	delete _worker_thread;
	_worker_thread = nullptr;
}

void CityRadioNativeBackend::_update_latency_locked(size_t queued_frames) {
	_latency_ms = static_cast<int>(std::round(static_cast<double>(queued_frames) * 1000.0 / static_cast<double>(TARGET_MIX_RATE)));
}

void CityRadioNativeBackend::_worker_loop(String station_id, String station_name, String resolved_url, String classification) {
#ifdef CITY_RADIO_USE_FFMPEG
	for (int attempt = 0; attempt <= MAX_RETRY_COUNT && !_stop_requested.load(); attempt++) {
		if (attempt > 0) {
			std::lock_guard<std::mutex> state_lock(_state_mutex);
			_buffer_state = "reconnecting";
			_error_code = "";
			_error_message = "";
		}
		if (_decode_stream(station_id, station_name, resolved_url, classification, attempt)) {
			return;
		}
		if (_stop_requested.load()) {
			return;
		}
		if (attempt < MAX_RETRY_COUNT) {
			std::this_thread::sleep_for(std::chrono::milliseconds(500 * (attempt + 1)));
		}
	}
#else
	std::lock_guard<std::mutex> state_lock(_state_mutex);
	_playback_state = "error";
	_buffer_state = "error";
	_error_code = "ffmpeg_unavailable";
	_error_message = "ffmpeg_not_configured";
#endif
}

#ifdef CITY_RADIO_USE_FFMPEG
bool CityRadioNativeBackend::_decode_stream(const String &station_id, const String &station_name, const String &resolved_url, const String &classification, int attempt_index) {
	(void)attempt_index;

	AVFormatContext *format_context = avformat_alloc_context();
	if (format_context == nullptr) {
		std::lock_guard<std::mutex> state_lock(_state_mutex);
		_playback_state = "error";
		_buffer_state = "error";
		_error_code = "format_alloc_failed";
		_error_message = "avformat_alloc_context_failed";
		return false;
	}
	format_context->interrupt_callback.callback = ffmpeg_interrupt_callback;
	format_context->interrupt_callback.opaque = this;

	AVDictionary *open_options = nullptr;
	// Conservative reconnect and socket timeouts keep stop/switch responsive during both automated tests and live playback.
	av_dict_set(&open_options, "reconnect", "1", 0);
	av_dict_set(&open_options, "reconnect_streamed", "1", 0);
	av_dict_set(&open_options, "reconnect_on_network_error", "1", 0);
	av_dict_set(&open_options, "reconnect_delay_max", "5", 0);
	av_dict_set(&open_options, "rw_timeout", "3000000", 0);
	av_dict_set(&open_options, "timeout", "3000000", 0);
	av_dict_set(&open_options, "icy", "1", 0);

	std::string resolved_url_utf8 = utf8_string(resolved_url);
	int open_result = avformat_open_input(&format_context, resolved_url_utf8.c_str(), nullptr, &open_options);
	av_dict_free(&open_options);
	if (open_result < 0) {
		std::lock_guard<std::mutex> state_lock(_state_mutex);
		_playback_state = "error";
		_buffer_state = "error";
		_error_code = "connect_failed";
		_error_message = ffmpeg_error_string(open_result);
		avformat_free_context(format_context);
		return false;
	}

	int stream_info_result = avformat_find_stream_info(format_context, nullptr);
	if (stream_info_result < 0) {
		std::lock_guard<std::mutex> state_lock(_state_mutex);
		_playback_state = "error";
		_buffer_state = "error";
		_error_code = "stream_info_failed";
		_error_message = ffmpeg_error_string(stream_info_result);
		avformat_close_input(&format_context);
		return false;
	}

	int audio_stream_index = av_find_best_stream(format_context, AVMEDIA_TYPE_AUDIO, -1, -1, nullptr, 0);
	if (audio_stream_index < 0) {
		std::lock_guard<std::mutex> state_lock(_state_mutex);
		_playback_state = "error";
		_buffer_state = "error";
		_error_code = "audio_stream_missing";
		_error_message = ffmpeg_error_string(audio_stream_index);
		avformat_close_input(&format_context);
		return false;
	}

	AVStream *audio_stream = format_context->streams[audio_stream_index];
	const AVCodec *codec = avcodec_find_decoder(audio_stream->codecpar->codec_id);
	if (codec == nullptr) {
		std::lock_guard<std::mutex> state_lock(_state_mutex);
		_playback_state = "error";
		_buffer_state = "error";
		_error_code = "unsupported_codec";
		_error_message = "avcodec_find_decoder_failed";
		avformat_close_input(&format_context);
		return false;
	}

	AVCodecContext *codec_context = avcodec_alloc_context3(codec);
	if (codec_context == nullptr) {
		std::lock_guard<std::mutex> state_lock(_state_mutex);
		_playback_state = "error";
		_buffer_state = "error";
		_error_code = "codec_alloc_failed";
		_error_message = "avcodec_alloc_context3_failed";
		avformat_close_input(&format_context);
		return false;
	}

	int codec_param_result = avcodec_parameters_to_context(codec_context, audio_stream->codecpar);
	if (codec_param_result < 0) {
		std::lock_guard<std::mutex> state_lock(_state_mutex);
		_playback_state = "error";
		_buffer_state = "error";
		_error_code = "codec_parameters_failed";
		_error_message = ffmpeg_error_string(codec_param_result);
		avcodec_free_context(&codec_context);
		avformat_close_input(&format_context);
		return false;
	}

	int codec_open_result = avcodec_open2(codec_context, codec, nullptr);
	if (codec_open_result < 0) {
		std::lock_guard<std::mutex> state_lock(_state_mutex);
		_playback_state = "error";
		_buffer_state = "error";
		_error_code = "codec_open_failed";
		_error_message = ffmpeg_error_string(codec_open_result);
		avcodec_free_context(&codec_context);
		avformat_close_input(&format_context);
		return false;
	}

	AVChannelLayout output_layout;
	av_channel_layout_default(&output_layout, CHANNEL_COUNT);
	AVChannelLayout fallback_input_layout;
	memset(&fallback_input_layout, 0, sizeof(fallback_input_layout));
	const AVChannelLayout *input_layout = &codec_context->ch_layout;
	if (codec_context->ch_layout.nb_channels <= 0) {
		av_channel_layout_default(&fallback_input_layout, audio_stream->codecpar->ch_layout.nb_channels > 0 ? audio_stream->codecpar->ch_layout.nb_channels : CHANNEL_COUNT);
		input_layout = &fallback_input_layout;
	}

	SwrContext *resample_context = nullptr;
	int resample_alloc_result = swr_alloc_set_opts2(
			&resample_context,
			&output_layout,
			AV_SAMPLE_FMT_FLT,
			TARGET_MIX_RATE,
			input_layout,
			codec_context->sample_fmt,
			codec_context->sample_rate,
			0,
			nullptr);
	if (fallback_input_layout.nb_channels > 0) {
		av_channel_layout_uninit(&fallback_input_layout);
	}
	if (resample_alloc_result < 0 || resample_context == nullptr) {
		std::lock_guard<std::mutex> state_lock(_state_mutex);
		_playback_state = "error";
		_buffer_state = "error";
		_error_code = "resampler_alloc_failed";
		_error_message = ffmpeg_error_string(resample_alloc_result);
		av_channel_layout_uninit(&output_layout);
		avcodec_free_context(&codec_context);
		avformat_close_input(&format_context);
		return false;
	}

	int resample_init_result = swr_init(resample_context);
	if (resample_init_result < 0) {
		std::lock_guard<std::mutex> state_lock(_state_mutex);
		_playback_state = "error";
		_buffer_state = "error";
		_error_code = "resampler_init_failed";
		_error_message = ffmpeg_error_string(resample_init_result);
		swr_free(&resample_context);
		av_channel_layout_uninit(&output_layout);
		avcodec_free_context(&codec_context);
		avformat_close_input(&format_context);
		return false;
	}

	{
		std::lock_guard<std::mutex> state_lock(_state_mutex);
		_station_id = station_id;
		_station_name = station_name;
		_classification = classification;
		_resolved_url = resolved_url;
		_playback_state = "playing";
		_buffer_state = "buffering";
		_error_code = "";
		_error_message = "";
		_codec_name = codec->name != nullptr ? String::utf8(codec->name) : "";
		_source_sample_rate = codec_context->sample_rate;
		_source_channels = codec_context->ch_layout.nb_channels > 0 ? codec_context->ch_layout.nb_channels : CHANNEL_COUNT;
		String stream_title = metadata_value(format_context->metadata, "StreamTitle");
		if (stream_title.is_empty()) {
			stream_title = metadata_value(format_context->metadata, "icy-name");
		}
		if (stream_title.is_empty()) {
			stream_title = metadata_value(format_context->metadata, "title");
		}
		_stream_title = stream_title;
	}

	AVPacket *packet = av_packet_alloc();
	AVFrame *frame = av_frame_alloc();
	if (packet == nullptr || frame == nullptr) {
		std::lock_guard<std::mutex> state_lock(_state_mutex);
		_playback_state = "error";
		_buffer_state = "error";
		_error_code = "frame_alloc_failed";
		_error_message = "av_packet_or_frame_alloc_failed";
		if (packet != nullptr) {
			av_packet_free(&packet);
		}
		if (frame != nullptr) {
			av_frame_free(&frame);
		}
		swr_free(&resample_context);
		av_channel_layout_uninit(&output_layout);
		avcodec_free_context(&codec_context);
		avformat_close_input(&format_context);
		return false;
	}

	bool stopped_by_request = false;
	while (!_stop_requested.load()) {
		int read_result = av_read_frame(format_context, packet);
		if (read_result == AVERROR(EAGAIN)) {
			av_packet_unref(packet);
			continue;
		}
		if (read_result == AVERROR_EOF) {
			std::lock_guard<std::mutex> state_lock(_state_mutex);
			_playback_state = "error";
			_buffer_state = "error";
			_error_code = "stream_ended";
			_error_message = "stream_ended";
			break;
		}
		if (read_result < 0) {
			std::lock_guard<std::mutex> state_lock(_state_mutex);
			_playback_state = "error";
			_buffer_state = "error";
			_error_code = "read_failed";
			_error_message = ffmpeg_error_string(read_result);
			break;
		}
		if (packet->stream_index != audio_stream_index) {
			av_packet_unref(packet);
			continue;
		}

		int send_result = avcodec_send_packet(codec_context, packet);
		av_packet_unref(packet);
		if (send_result < 0) {
			std::lock_guard<std::mutex> state_lock(_state_mutex);
			_playback_state = "error";
			_buffer_state = "error";
			_error_code = "decode_send_failed";
			_error_message = ffmpeg_error_string(send_result);
			break;
		}

		while (!_stop_requested.load()) {
			int receive_result = avcodec_receive_frame(codec_context, frame);
			if (receive_result == AVERROR(EAGAIN) || receive_result == AVERROR_EOF) {
				break;
			}
			if (receive_result < 0) {
				std::lock_guard<std::mutex> state_lock(_state_mutex);
				_playback_state = "error";
				_buffer_state = "error";
				_error_code = "decode_receive_failed";
				_error_message = ffmpeg_error_string(receive_result);
				av_frame_unref(frame);
				goto decode_cleanup;
			}

			int dst_sample_count = av_rescale_rnd(
					swr_get_delay(resample_context, codec_context->sample_rate) + frame->nb_samples,
					TARGET_MIX_RATE,
					codec_context->sample_rate,
					AV_ROUND_UP);
			std::vector<float> interleaved_frames(static_cast<size_t>(dst_sample_count) * CHANNEL_COUNT);
			uint8_t *output_buffers[1] = {
				reinterpret_cast<uint8_t *>(interleaved_frames.data()),
			};
			const uint8_t **input_buffers = const_cast<const uint8_t **>(frame->extended_data);
			int converted_samples = swr_convert(resample_context, output_buffers, dst_sample_count, input_buffers, frame->nb_samples);
			av_frame_unref(frame);
			if (converted_samples < 0) {
				std::lock_guard<std::mutex> state_lock(_state_mutex);
				_playback_state = "error";
				_buffer_state = "error";
				_error_code = "resample_failed";
				_error_message = ffmpeg_error_string(converted_samples);
				goto decode_cleanup;
			}
			if (converted_samples > 0) {
				_append_frames(interleaved_frames.data(), converted_samples);
			}
		}
	}

	stopped_by_request = _stop_requested.load();

decode_cleanup:
	av_packet_free(&packet);
	av_frame_free(&frame);
	swr_free(&resample_context);
	av_channel_layout_uninit(&output_layout);
	avcodec_free_context(&codec_context);
	avformat_close_input(&format_context);
	return stopped_by_request;
}

void CityRadioNativeBackend::_append_frames(const float *interleaved_frames, int frame_count) {
	if (interleaved_frames == nullptr || frame_count <= 0) {
		return;
	}

	size_t queued_frames_after_append = 0;
	{
		std::lock_guard<std::mutex> frame_lock(_frame_mutex);
		size_t incoming_frames = static_cast<size_t>(frame_count);
		if (_frame_queue.size() + incoming_frames > MAX_BUFFERED_FRAMES) {
			size_t frames_to_drop = (_frame_queue.size() + incoming_frames) - MAX_BUFFERED_FRAMES;
			for (size_t frame_index = 0; frame_index < frames_to_drop && !_frame_queue.empty(); frame_index++) {
				_frame_queue.pop_front();
			}
		}
		for (int frame_index = 0; frame_index < frame_count; frame_index++) {
			const float left = interleaved_frames[frame_index * CHANNEL_COUNT];
			const float right = interleaved_frames[frame_index * CHANNEL_COUNT + 1];
			_frame_queue.emplace_back(left, right);
		}
		queued_frames_after_append = _frame_queue.size();
	}

	std::lock_guard<std::mutex> state_lock(_state_mutex);
	_buffer_state = queued_frames_after_append >= 1024 ? "ready" : "buffering";
	_update_latency_locked(queued_frames_after_append);
}
#endif
