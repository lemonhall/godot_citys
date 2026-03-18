#pragma once

#include "CityRadioNativeBackend.h"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

class CityRadioNativeBridge : public RefCounted {
	GDCLASS(CityRadioNativeBridge, RefCounted)

protected:
	static void _bind_methods();

public:
	CityRadioNativeBridge();
	~CityRadioNativeBridge();

	String ping() const;
	bool is_backend_available() const;
	String get_build_summary() const;
	bool open_stream(const String &station_id, const String &station_name, const String &resolved_url, const String &classification);
	void stop_stream(const String &reason = "stopped");
	Dictionary poll_state() const;
	PackedVector2Array pop_audio_frames(int max_frames);

private:
	CityRadioNativeBackend *_backend = nullptr;
};

} // namespace godot
