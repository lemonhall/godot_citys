extends SceneTree

const T := preload("res://tests/_test_util.gd")

const GENERATOR_SCRIPT_PATH := "res://tools/scene_preview/generate_scene_preview_wrapper.gd"
const HARNESS_SCENE_PATH := "res://city_game/preview/ScenePreviewHarness.tscn"
const SUBJECT_SCENE_PATH := "res://city_game/assets/minigames/missile_command/projectiles/InterceptorMissileVisual.tscn"
const OUTPUT_WRAPPER_PATH := "user://tests/scene_preview/GeneratedInterceptorPreview.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(GENERATOR_SCRIPT_PATH, "Script"), "Scene preview wrapper generator contract requires generate_scene_preview_wrapper.gd"):
		return
	if not T.require_true(self, ResourceLoader.exists(SUBJECT_SCENE_PATH, "PackedScene"), "Scene preview wrapper generator contract requires a real subject scene input"):
		return

	var generator_script := load(GENERATOR_SCRIPT_PATH)
	if not T.require_true(self, generator_script != null, "Scene preview wrapper generator contract must load the generator script resource"):
		return
	if not T.require_true(self, generator_script.has_method("generate_wrapper_scene"), "Scene preview wrapper generator contract requires generate_wrapper_scene() on the generator script"):
		return

	var generation_result: Variant = generator_script.call("generate_wrapper_scene", SUBJECT_SCENE_PATH, OUTPUT_WRAPPER_PATH)
	if not T.require_true(self, generation_result is Dictionary, "Scene preview wrapper generator contract must return a Dictionary result from generate_wrapper_scene()"):
		return
	var generation_state := generation_result as Dictionary
	if not T.require_true(self, bool(generation_state.get("success", false)), "Scene preview wrapper generator contract must report success for a valid subject scene path"):
		return
	if not T.require_true(self, FileAccess.file_exists(OUTPUT_WRAPPER_PATH), "Scene preview wrapper generator contract must persist the wrapper scene to the requested output path"):
		return

	var wrapper_scene_text := FileAccess.get_file_as_string(OUTPUT_WRAPPER_PATH)
	if not T.require_true(self, wrapper_scene_text.find(HARNESS_SCENE_PATH) >= 0, "Scene preview wrapper generator contract must reference the formal ScenePreviewHarness scene instead of duplicating it"):
		return
	if not T.require_true(self, wrapper_scene_text.find(SUBJECT_SCENE_PATH) >= 0, "Scene preview wrapper generator contract must reference the requested subject scene path in the wrapper output"):
		return
	if not T.require_true(self, wrapper_scene_text.find("node name=\"PreviewLight\" type=") < 0, "Scene preview wrapper generator contract must output a thin wrapper that instances the harness instead of copying harness nodes inline"):
		return

	var wrapper_scene := load(OUTPUT_WRAPPER_PATH) as PackedScene
	if not T.require_true(self, wrapper_scene != null, "Scene preview wrapper generator contract must generate a loadable wrapper PackedScene"):
		return
	var wrapper_root := wrapper_scene.instantiate() as Node3D
	if not T.require_true(self, wrapper_root != null, "Scene preview wrapper generator contract must instantiate the generated wrapper scene as Node3D"):
		return
	if not T.require_true(self, wrapper_root.has_method("get_preview_runtime_state"), "Scene preview wrapper generator contract must generate a wrapper rooted in the formal preview harness"):
		return

	root.add_child(wrapper_root)
	await process_frame
	await process_frame
	var runtime_state := wrapper_root.get_preview_runtime_state() as Dictionary
	if not T.require_true(self, bool(runtime_state.get("subject_loaded", false)), "Scene preview wrapper generator contract must boot a generated wrapper with the subject mounted"):
		return
	if not T.require_true(self, str(runtime_state.get("subject_scene_path", "")) == SUBJECT_SCENE_PATH, "Scene preview wrapper generator contract must preserve the formal subject_scene_path in runtime state"):
		return

	wrapper_root.queue_free()
	await process_frame
	T.pass_and_quit(self)
