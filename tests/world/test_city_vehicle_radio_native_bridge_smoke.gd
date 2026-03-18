extends SceneTree

const T := preload("res://tests/_test_util.gd")
const GDEXTENSION_PATH := "res://city_game/native/radio_backend/radio_backend.gdextension"
const BRIDGE_CLASS_NAME := "CityRadioNativeBridge"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	T.install_vehicle_radio_test_scope("vehicle_radio_native_bridge_smoke")
	var extension_resource := load(GDEXTENSION_PATH)
	if not T.require_true(self, extension_resource != null, "Vehicle radio native bridge smoke test requires radio_backend.gdextension"):
		return
	if not T.require_true(self, ClassDB.class_exists(BRIDGE_CLASS_NAME), "Vehicle radio native bridge smoke test requires ClassDB.class_exists(\"%s\")" % BRIDGE_CLASS_NAME):
		return

	var bridge = ClassDB.instantiate(BRIDGE_CLASS_NAME)
	if not T.require_true(self, bridge != null, "Vehicle radio native bridge smoke test must instantiate CityRadioNativeBridge"):
		return
	if not T.require_true(self, bridge.has_method("ping"), "Vehicle radio native bridge smoke test requires ping()"):
		return

	var ping_result: Variant = bridge.call("ping")
	if not T.require_true(self, str(ping_result) == "pong", "Vehicle radio native bridge smoke test requires ping() => pong"):
		return

	T.pass_and_quit(self)
