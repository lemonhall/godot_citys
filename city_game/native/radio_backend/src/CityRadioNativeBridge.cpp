#include "CityRadioNativeBridge.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/memory.hpp>

using namespace godot;

CityRadioNativeBridge::CityRadioNativeBridge() {
	_backend = memnew(CityRadioNativeBackend);
}

CityRadioNativeBridge::~CityRadioNativeBridge() {
	if (_backend != nullptr) {
		memdelete(_backend);
		_backend = nullptr;
	}
}

void CityRadioNativeBridge::_bind_methods() {
	ClassDB::bind_method(D_METHOD("ping"), &CityRadioNativeBridge::ping);
	ClassDB::bind_method(D_METHOD("is_backend_available"), &CityRadioNativeBridge::is_backend_available);
	ClassDB::bind_method(D_METHOD("get_build_summary"), &CityRadioNativeBridge::get_build_summary);
	ClassDB::bind_method(D_METHOD("open_stream", "station_id", "station_name", "resolved_url", "classification"), &CityRadioNativeBridge::open_stream);
	ClassDB::bind_method(D_METHOD("stop_stream", "reason"), &CityRadioNativeBridge::stop_stream, DEFVAL("stopped"));
	ClassDB::bind_method(D_METHOD("poll_state"), &CityRadioNativeBridge::poll_state);
	ClassDB::bind_method(D_METHOD("pop_audio_frames", "max_frames"), &CityRadioNativeBridge::pop_audio_frames);
}

String CityRadioNativeBridge::ping() const {
	if (_backend == nullptr) {
		return "";
	}
	return _backend->ping();
}

bool CityRadioNativeBridge::is_backend_available() const {
	if (_backend == nullptr) {
		return false;
	}
	return _backend->is_available();
}

String CityRadioNativeBridge::get_build_summary() const {
	if (_backend == nullptr) {
		return "backend_missing";
	}
	return _backend->get_build_summary();
}

bool CityRadioNativeBridge::open_stream(const String &station_id, const String &station_name, const String &resolved_url, const String &classification) {
	if (_backend == nullptr) {
		return false;
	}
	return _backend->open_stream(station_id, station_name, resolved_url, classification);
}

void CityRadioNativeBridge::stop_stream(const String &reason) {
	if (_backend == nullptr) {
		return;
	}
	_backend->stop_stream(reason);
}

Dictionary CityRadioNativeBridge::poll_state() const {
	if (_backend == nullptr) {
		return Dictionary();
	}
	return _backend->poll_state();
}

PackedVector2Array CityRadioNativeBridge::pop_audio_frames(int max_frames) {
	if (_backend == nullptr) {
		return PackedVector2Array();
	}
	return _backend->pop_audio_frames(max_frames);
}
