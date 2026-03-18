#include "register_types.h"

#include "CityRadioNativeBridge.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_city_radio_native_backend_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE || ClassDB::class_exists("CityRadioNativeBridge")) {
		return;
	}
	ClassDB::register_class<CityRadioNativeBridge>();
}

void uninitialize_city_radio_native_backend_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE || !ClassDB::class_exists("CityRadioNativeBridge")) {
		return;
	}
}

extern "C" {
GDExtensionBool GDE_EXPORT
city_radio_native_backend_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address,
		const GDExtensionClassLibraryPtr p_library,
		GDExtensionInitialization *r_initialization) {
	godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_city_radio_native_backend_module);
	init_obj.register_terminator(uninitialize_city_radio_native_backend_module);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
