extends SceneTree

const DEFAULT_HARNESS_SCENE_PATH := "res://city_game/preview/ScenePreviewHarness.tscn"

func _init() -> void:
	call_deferred("_run_cli")

static func generate_wrapper_scene(subject_scene_path: String, output_wrapper_path: String = "", harness_scene_path: String = DEFAULT_HARNESS_SCENE_PATH) -> Dictionary:
	var resolved_subject_scene_path := subject_scene_path.strip_edges()
	if resolved_subject_scene_path == "":
		return {
			"success": false,
			"error": "subject scene path is required",
		}
	if not ResourceLoader.exists(resolved_subject_scene_path, "PackedScene"):
		return {
			"success": false,
			"error": "subject scene does not exist: %s" % resolved_subject_scene_path,
		}
	var resolved_harness_scene_path := harness_scene_path.strip_edges()
	if resolved_harness_scene_path == "":
		resolved_harness_scene_path = DEFAULT_HARNESS_SCENE_PATH
	if not ResourceLoader.exists(resolved_harness_scene_path, "PackedScene"):
		return {
			"success": false,
			"error": "harness scene does not exist: %s" % resolved_harness_scene_path,
		}
	var resolved_output_wrapper_path := output_wrapper_path.strip_edges()
	if resolved_output_wrapper_path == "":
		resolved_output_wrapper_path = resolve_default_output_path(resolved_subject_scene_path)
	if not resolved_output_wrapper_path.ends_with(".tscn"):
		return {
			"success": false,
			"error": "output wrapper path must end with .tscn",
		}
	var scene_name := _resolve_wrapper_scene_name(resolved_subject_scene_path, resolved_output_wrapper_path)
	var wrapper_scene_text := _build_wrapper_scene_text(scene_name, resolved_harness_scene_path, resolved_subject_scene_path)
	var make_dir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(resolved_output_wrapper_path.get_base_dir()))
	if make_dir_error != OK and make_dir_error != ERR_ALREADY_EXISTS:
		return {
			"success": false,
			"error": "failed to create output directory for %s" % resolved_output_wrapper_path,
		}
	var file := FileAccess.open(ProjectSettings.globalize_path(resolved_output_wrapper_path), FileAccess.WRITE)
	if file == null:
		return {
			"success": false,
			"error": "failed to open output wrapper file: %s" % resolved_output_wrapper_path,
		}
	file.store_string(wrapper_scene_text)
	file.close()
	return {
		"success": true,
		"output_wrapper_path": resolved_output_wrapper_path,
		"scene_name": scene_name,
		"harness_scene_path": resolved_harness_scene_path,
		"subject_scene_path": resolved_subject_scene_path,
	}

static func resolve_default_output_path(subject_scene_path: String) -> String:
	var base_directory := subject_scene_path.get_base_dir()
	var base_name := subject_scene_path.get_file().get_basename()
	return "%s/%sPreview.tscn" % [base_directory, base_name]

static func _build_wrapper_scene_text(scene_name: String, harness_scene_path: String, subject_scene_path: String) -> String:
	return "\n".join([
		"[gd_scene load_steps=3 format=3]",
		"",
		"[ext_resource type=\"PackedScene\" path=\"%s\" id=\"1_harness\"]" % harness_scene_path,
		"[ext_resource type=\"PackedScene\" path=\"%s\" id=\"2_subject\"]" % subject_scene_path,
		"",
		"[node name=\"%s\" instance=ExtResource(\"1_harness\")]" % scene_name,
		"subject_scene = ExtResource(\"2_subject\")",
		"subject_scene_path = \"%s\"" % subject_scene_path,
		"",
	])

static func _resolve_wrapper_scene_name(subject_scene_path: String, output_wrapper_path: String) -> String:
	var output_name := _sanitize_node_name(output_wrapper_path.get_file().get_basename())
	if output_name != "":
		return output_name
	return _sanitize_node_name("%sPreview" % subject_scene_path.get_file().get_basename())

static func _sanitize_node_name(raw_name: String) -> String:
	var trimmed := raw_name.strip_edges()
	if trimmed == "":
		return ""
	var sanitized := ""
	for index in trimmed.length():
		var codepoint := trimmed.unicode_at(index)
		var is_ascii_letter := (codepoint >= 65 and codepoint <= 90) or (codepoint >= 97 and codepoint <= 122)
		var is_ascii_digit := codepoint >= 48 and codepoint <= 57
		if is_ascii_letter or is_ascii_digit or codepoint == 95:
			sanitized += char(codepoint)
			continue
		sanitized += "_"
	return sanitized.strip_edges()

func _run_cli() -> void:
	var parse_result := _parse_cli_arguments(OS.get_cmdline_user_args())
	if not bool(parse_result.get("success", false)):
		print(parse_result.get("message", ""))
		_print_usage()
		quit(1)
		return
	var generation_result := generate_wrapper_scene(
		str(parse_result.get("source_scene_path", "")),
		str(parse_result.get("output_wrapper_path", "")),
		str(parse_result.get("harness_scene_path", DEFAULT_HARNESS_SCENE_PATH))
	)
	if bool(generation_result.get("success", false)):
		print("Generated scene preview wrapper: %s" % str(generation_result.get("output_wrapper_path", "")))
		quit(0)
		return
	push_error(str(generation_result.get("error", "unknown error")))
	print("FAIL: %s" % str(generation_result.get("error", "unknown error")))
	quit(1)

func _parse_cli_arguments(arguments: PackedStringArray) -> Dictionary:
	var source_scene_path := ""
	var output_wrapper_path := ""
	var harness_scene_path := DEFAULT_HARNESS_SCENE_PATH
	var index := 0
	while index < arguments.size():
		var argument := str(arguments[index])
		match argument:
			"--source", "--subject":
				if index + 1 >= arguments.size():
					return {
						"success": false,
						"message": "missing value for %s" % argument,
					}
				source_scene_path = str(arguments[index + 1])
				index += 2
				continue
			"--output":
				if index + 1 >= arguments.size():
					return {
						"success": false,
						"message": "missing value for --output",
					}
				output_wrapper_path = str(arguments[index + 1])
				index += 2
				continue
			"--harness":
				if index + 1 >= arguments.size():
					return {
						"success": false,
						"message": "missing value for --harness",
					}
				harness_scene_path = str(arguments[index + 1])
				index += 2
				continue
			"--help", "-h":
				return {
					"success": false,
					"message": "scene preview wrapper generator help requested",
				}
			_:
				return {
					"success": false,
					"message": "unknown argument: %s" % argument,
				}
	return {
		"success": source_scene_path.strip_edges() != "",
		"message": "missing required --source <scene_path>" if source_scene_path.strip_edges() == "" else "",
		"source_scene_path": source_scene_path,
		"output_wrapper_path": output_wrapper_path,
		"harness_scene_path": harness_scene_path,
	}

func _print_usage() -> void:
	print("Usage: godot --headless --path <project> --script res://tools/scene_preview/generate_scene_preview_wrapper.gd -- --source <subject_scene_path> [--output <wrapper_scene_path>] [--harness <harness_scene_path>]")
