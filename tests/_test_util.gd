extends RefCounted

const RADIO_CATALOG_STORE_PATH := "res://city_game/world/radio/CityRadioCatalogStore.gd"
const RADIO_USER_STATE_STORE_PATH := "res://city_game/world/radio/CityRadioUserStateStore.gd"

static func require_true(tree: SceneTree, cond: bool, msg: String) -> bool:
	if not cond:
		fail_and_quit(tree, msg)
		return false
	return true

static func install_vehicle_radio_test_scope(scope_name: String) -> String:
	var resolved_scope := "%s_%d" % [_sanitize_vehicle_radio_test_scope_name(scope_name), OS.get_process_id()]
	var catalog_store_script = load(RADIO_CATALOG_STORE_PATH)
	var user_state_store_script = load(RADIO_USER_STATE_STORE_PATH)
	if _script_has_method(catalog_store_script, "install_test_scope"):
		catalog_store_script.call("install_test_scope", resolved_scope)
	if _script_has_method(user_state_store_script, "install_test_scope"):
		user_state_store_script.call("install_test_scope", resolved_scope)
	return resolved_scope

static func clear_vehicle_radio_test_scope() -> void:
	var catalog_store_script = load(RADIO_CATALOG_STORE_PATH)
	var user_state_store_script = load(RADIO_USER_STATE_STORE_PATH)
	if _script_has_method(catalog_store_script, "clear_test_scope"):
		catalog_store_script.call("clear_test_scope")
	if _script_has_method(user_state_store_script, "clear_test_scope"):
		user_state_store_script.call("clear_test_scope")

static func pass_and_quit(tree: SceneTree) -> void:
	print("PASS")
	tree.quit(0)

static func fail_and_quit(tree: SceneTree, msg: String) -> void:
	push_error(msg)
	print("FAIL: " + msg)
	tree.quit(1)

static func _sanitize_vehicle_radio_test_scope_name(scope_name: String) -> String:
	var raw_scope := scope_name.strip_edges().to_lower()
	if raw_scope == "":
		raw_scope = "default"
	var resolved_scope := ""
	var previous_was_separator := false
	for index in raw_scope.length():
		var codepoint := raw_scope.unicode_at(index)
		var is_ascii_letter := codepoint >= 97 and codepoint <= 122
		var is_ascii_digit := codepoint >= 48 and codepoint <= 57
		if is_ascii_letter or is_ascii_digit:
			resolved_scope += char(codepoint)
			previous_was_separator = false
			continue
		if previous_was_separator:
			continue
		resolved_scope += "_"
		previous_was_separator = true
	while resolved_scope.begins_with("_"):
		resolved_scope = resolved_scope.trim_prefix("_")
	while resolved_scope.ends_with("_"):
		resolved_scope = resolved_scope.trim_suffix("_")
	return resolved_scope if resolved_scope != "" else "default"

static func _script_has_method(script: Variant, method_name: String) -> bool:
	if script == null or method_name.strip_edges() == "":
		return false
	var methods: Array = script.get_script_method_list()
	for method_variant in methods:
		if not (method_variant is Dictionary):
			continue
		if str((method_variant as Dictionary).get("name", "")) == method_name:
			return true
	return false
