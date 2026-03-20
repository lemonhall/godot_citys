extends SceneTree

const T := preload("res://tests/_test_util.gd")

const PLUGIN_CONFIG_PATH := "res://addons/scene_preview/plugin.cfg"
const PLUGIN_SCRIPT_PATH := "res://addons/scene_preview/plugin.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, FileAccess.file_exists(PLUGIN_CONFIG_PATH), "Scene preview editor plugin manifest contract requires addons/scene_preview/plugin.cfg"):
		return
	if not T.require_true(self, ResourceLoader.exists(PLUGIN_SCRIPT_PATH, "Script"), "Scene preview editor plugin manifest contract requires addons/scene_preview/plugin.gd"):
		return

	var plugin_config := ConfigFile.new()
	if not T.require_true(self, plugin_config.load(PLUGIN_CONFIG_PATH) == OK, "Scene preview editor plugin manifest contract must load plugin.cfg"):
		return
	if not T.require_true(self, str(plugin_config.get_value("plugin", "name", "")) == "ScenePreview", "Scene preview editor plugin manifest contract must register plugin name = ScenePreview"):
		return
	if not T.require_true(self, str(plugin_config.get_value("plugin", "script", "")) == "plugin.gd", "Scene preview editor plugin manifest contract must point script=plugin.gd from plugin.cfg"):
		return

	var plugin_script := load(PLUGIN_SCRIPT_PATH)
	if not T.require_true(self, plugin_script != null, "Scene preview editor plugin manifest contract must load the plugin script resource"):
		return
	if not T.require_true(self, _script_has_method(plugin_script, "_enter_tree"), "Scene preview editor plugin manifest contract requires _enter_tree() on plugin.gd"):
		return
	if not T.require_true(self, _script_has_method(plugin_script, "_exit_tree"), "Scene preview editor plugin manifest contract requires _exit_tree() on plugin.gd"):
		return
	if not T.require_true(self, _script_has_method(plugin_script, "_refresh_preview_button_state"), "Scene preview editor plugin manifest contract requires a preview button state refresh entrypoint on plugin.gd"):
		return
	if not T.require_true(self, _script_has_method(plugin_script, "build_preview_request_for_scene_root"), "Scene preview editor plugin manifest contract requires build_preview_request_for_scene_root() on plugin.gd for testable orchestration"):
		return
	if not T.require_true(self, _script_has_method(plugin_script, "trigger_preview_for_scene_root"), "Scene preview editor plugin manifest contract requires trigger_preview_for_scene_root() on plugin.gd for the actual button flow"):
		return

	T.pass_and_quit(self)

func _script_has_method(script: Variant, method_name: String) -> bool:
	if script == null:
		return false
	for method_variant in script.get_script_method_list():
		if not (method_variant is Dictionary):
			continue
		if str((method_variant as Dictionary).get("name", "")) == method_name:
			return true
	return false
