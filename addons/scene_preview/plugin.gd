@tool
extends EditorPlugin

const EligibilityScript := preload("res://addons/scene_preview/ScenePreviewEditorEligibility.gd")
const SessionBuilderScript := preload("res://addons/scene_preview/ScenePreviewEditorSessionBuilder.gd")

var _preview_button: Button = null
var _eligibility = EligibilityScript.new()
var _session_builder = SessionBuilderScript.new()

func _enter_tree() -> void:
	_ensure_preview_button()
	_refresh_preview_button_state()
	if not scene_changed.is_connected(_on_scene_changed):
		scene_changed.connect(_on_scene_changed)

func _exit_tree() -> void:
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	if _preview_button != null:
		if _preview_button.pressed.is_connected(_on_preview_button_pressed):
			_preview_button.pressed.disconnect(_on_preview_button_pressed)
		if _preview_button.get_parent() != null:
			remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _preview_button)
		_preview_button.queue_free()
		_preview_button = null

func build_preview_request_for_scene_root(scene_root: Node, options: Dictionary = {}) -> Dictionary:
	return _session_builder.build_preview_request_from_scene_root(scene_root, options)

func trigger_preview_for_scene_root(scene_root: Node, options: Dictionary = {}) -> Dictionary:
	var preview_request := build_preview_request_for_scene_root(scene_root, options)
	if not bool(preview_request.get("success", false)):
		return preview_request
	var play_scene_path := str(preview_request.get("play_scene_path", "")).strip_edges()
	if play_scene_path == "":
		return {
			"success": false,
			"error": "Missing play_scene_path in preview request.",
		}
	get_editor_interface().play_custom_scene(play_scene_path)
	var triggered_request := preview_request.duplicate(true)
	triggered_request["triggered"] = true
	return triggered_request

func _refresh_preview_button_state() -> void:
	if _preview_button == null:
		return
	var scene_root := get_editor_interface().get_edited_scene_root()
	var eligibility_state: Dictionary = _eligibility.evaluate_scene_root(scene_root)
	var eligible := bool(eligibility_state.get("eligible", false))
	_preview_button.disabled = not eligible
	_preview_button.tooltip_text = "Preview current edited 3D scene." if eligible else str(eligibility_state.get("reason", "Scene preview is unavailable."))

func _ensure_preview_button() -> void:
	if _preview_button != null:
		return
	_preview_button = Button.new()
	_preview_button.name = "ScenePreviewButton"
	_preview_button.text = "Preview"
	_preview_button.focus_mode = Control.FOCUS_NONE
	_preview_button.tooltip_text = "Preview current edited 3D scene."
	_preview_button.flat = false
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _preview_button)
	if not _preview_button.pressed.is_connected(_on_preview_button_pressed):
		_preview_button.pressed.connect(_on_preview_button_pressed)

func _on_scene_changed(_scene_root: Node) -> void:
	_refresh_preview_button_state()

func _on_preview_button_pressed() -> void:
	var scene_root := get_editor_interface().get_edited_scene_root()
	var preview_request := trigger_preview_for_scene_root(scene_root)
	if not bool(preview_request.get("success", false)):
		push_warning(str(preview_request.get("error", "Scene preview failed.")))
	_refresh_preview_button_state()
