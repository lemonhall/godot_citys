@tool
extends RefCounted

const HARNESS_SCENE_PATH := "res://city_game/preview/ScenePreviewHarness.tscn"
const WRAPPER_GENERATOR_SCRIPT_PATH := "res://tools/scene_preview/generate_scene_preview_wrapper.gd"
const EDITOR_SUBJECT_CACHE_DIR := "user://scene_preview/editor_subjects"
const EDITOR_WRAPPER_CACHE_DIR := "user://scene_preview/editor_wrappers"

const EligibilityScript := preload("res://addons/scene_preview/ScenePreviewEditorEligibility.gd")

var _eligibility = EligibilityScript.new()

func build_preview_request_from_scene_root(scene_root: Node, options: Dictionary = {}) -> Dictionary:
	var eligibility_state: Dictionary = _eligibility.evaluate_scene_root(scene_root)
	if not bool(eligibility_state.get("eligible", false)):
		return {
			"success": false,
			"error": str(eligibility_state.get("reason", "Scene is not eligible for preview.")),
			"eligibility": eligibility_state.duplicate(true),
		}
	var scene_root_3d := scene_root as Node3D
	var source_scene_path := _resolve_source_scene_path(scene_root_3d, options)
	var session_id := _resolve_session_id(scene_root_3d, options)
	var subject_snapshot_path := "%s/%s.tscn" % [EDITOR_SUBJECT_CACHE_DIR, session_id]
	var wrapper_scene_path := "%s/%s.tscn" % [EDITOR_WRAPPER_CACHE_DIR, session_id]
	var snapshot_result := _save_scene_root_snapshot(scene_root_3d, subject_snapshot_path)
	if not bool(snapshot_result.get("success", false)):
		return snapshot_result
	var wrapper_generator = load(WRAPPER_GENERATOR_SCRIPT_PATH)
	if wrapper_generator == null or not wrapper_generator.has_method("generate_wrapper_scene"):
		return {
			"success": false,
			"error": "Scene preview wrapper generator is unavailable.",
		}
	var wrapper_result: Variant = wrapper_generator.call(
		"generate_wrapper_scene",
		subject_snapshot_path,
		wrapper_scene_path,
		HARNESS_SCENE_PATH
	)
	if not (wrapper_result is Dictionary):
		return {
			"success": false,
			"error": "Scene preview wrapper generator returned an invalid result.",
		}
	var wrapper_state := wrapper_result as Dictionary
	if not bool(wrapper_state.get("success", false)):
		return {
			"success": false,
			"error": str(wrapper_state.get("error", "Failed to generate preview wrapper.")),
		}
	return {
		"success": true,
		"eligibility": eligibility_state.duplicate(true),
		"session_id": session_id,
		"source_scene_path": source_scene_path,
		"subject_snapshot_path": subject_snapshot_path,
		"wrapper_scene_path": wrapper_scene_path,
		"play_scene_path": wrapper_scene_path,
		"harness_scene_path": HARNESS_SCENE_PATH,
		"uses_unsaved_editor_state": true,
	}

func _resolve_source_scene_path(scene_root: Node3D, options: Dictionary) -> String:
	var override_path := str(options.get("source_scene_path", "")).strip_edges()
	if override_path != "":
		return override_path
	var scene_file_path := scene_root.scene_file_path.strip_edges()
	if scene_file_path != "":
		return scene_file_path
	return "res://unsaved/%s.tscn" % _sanitize_name(scene_root.name)

func _resolve_session_id(scene_root: Node3D, options: Dictionary) -> String:
	var override_id := _sanitize_name(str(options.get("session_id", "")))
	if override_id != "":
		return override_id
	var root_name := _sanitize_name(scene_root.name)
	if root_name == "":
		root_name = "scene_preview"
	return "%s_%d" % [root_name, Time.get_unix_time_from_system()]

func _save_scene_root_snapshot(scene_root: Node3D, subject_snapshot_path: String) -> Dictionary:
	var duplicated_root := scene_root.duplicate()
	if duplicated_root == null or not (duplicated_root is Node3D):
		return {
			"success": false,
			"error": "Failed to duplicate the edited scene root for preview.",
		}
	var duplicated_root_3d := duplicated_root as Node3D
	_normalize_owners_recursive(duplicated_root_3d, duplicated_root_3d)
	var packed_scene := PackedScene.new()
	var pack_error := packed_scene.pack(duplicated_root_3d)
	duplicated_root_3d.free()
	if pack_error != OK:
		return {
			"success": false,
			"error": "Failed to pack the temporary preview subject scene.",
		}
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(subject_snapshot_path.get_base_dir()))
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return {
			"success": false,
			"error": "Failed to create the preview subject cache directory.",
		}
	var save_error := ResourceSaver.save(packed_scene, subject_snapshot_path)
	if save_error != OK:
		return {
			"success": false,
			"error": "Failed to save the temporary preview subject scene.",
		}
	return {
		"success": true,
		"subject_snapshot_path": subject_snapshot_path,
	}

func _normalize_owners_recursive(node: Node, owner_root: Node) -> void:
	for child in node.get_children():
		child.owner = owner_root
		_normalize_owners_recursive(child, owner_root)

func _sanitize_name(raw_name: String) -> String:
	var trimmed := raw_name.strip_edges()
	if trimmed == "":
		return ""
	var sanitized := ""
	var previous_was_separator := false
	for index in trimmed.length():
		var codepoint := trimmed.unicode_at(index)
		var is_ascii_letter := (codepoint >= 65 and codepoint <= 90) or (codepoint >= 97 and codepoint <= 122)
		var is_ascii_digit := codepoint >= 48 and codepoint <= 57
		if is_ascii_letter or is_ascii_digit:
			sanitized += char(codepoint)
			previous_was_separator = false
			continue
		if previous_was_separator:
			continue
		sanitized += "_"
		previous_was_separator = true
	while sanitized.begins_with("_"):
		sanitized = sanitized.trim_prefix("_")
	while sanitized.ends_with("_"):
		sanitized = sanitized.trim_suffix("_")
	return sanitized
