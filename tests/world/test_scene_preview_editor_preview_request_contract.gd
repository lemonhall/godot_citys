extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SESSION_BUILDER_SCRIPT_PATH := "res://addons/scene_preview/ScenePreviewEditorSessionBuilder.gd"
const MISSILE_SUBJECT_SCENE_PATH := "res://city_game/assets/minigames/missile_command/projectiles/InterceptorMissileVisual.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(SESSION_BUILDER_SCRIPT_PATH, "Script"), "Scene preview editor preview request contract requires ScenePreviewEditorSessionBuilder.gd"):
		return
	if not T.require_true(self, ResourceLoader.exists(MISSILE_SUBJECT_SCENE_PATH, "PackedScene"), "Scene preview editor preview request contract requires the real missile subject scene"):
		return

	var session_builder_script = load(SESSION_BUILDER_SCRIPT_PATH)
	if not T.require_true(self, session_builder_script != null, "Scene preview editor preview request contract must load the session builder script resource"):
		return
	var session_builder = session_builder_script.new()
	if not T.require_true(self, session_builder != null, "Scene preview editor preview request contract must instantiate the session builder service"):
		return

	var missile_subject_scene := load(MISSILE_SUBJECT_SCENE_PATH) as PackedScene
	if not T.require_true(self, missile_subject_scene != null, "Scene preview editor preview request contract must load InterceptorMissileVisual as PackedScene"):
		return
	var edited_scene_root := missile_subject_scene.instantiate() as Node3D
	if not T.require_true(self, edited_scene_root != null, "Scene preview editor preview request contract must instantiate InterceptorMissileVisual for editor-session simulation"):
		return

	var preview_request: Dictionary = session_builder.build_preview_request_from_scene_root(edited_scene_root, {
		"session_id": "unit_scene_preview_editor_missile",
		"source_scene_path": MISSILE_SUBJECT_SCENE_PATH,
	})
	if not T.require_true(self, bool(preview_request.get("success", false)), "Scene preview editor preview request contract must build a preview request for the real missile subject"):
		return
	if not T.require_true(self, str(preview_request.get("harness_scene_path", "")) == "res://city_game/preview/ScenePreviewHarness.tscn", "Scene preview editor preview request contract must reuse the formal v30 ScenePreviewHarness"):
		return
	if not T.require_true(self, str(preview_request.get("play_scene_path", "")) == str(preview_request.get("wrapper_scene_path", "")), "Scene preview editor preview request contract must target the generated wrapper scene as the play scene"):
		return

	var wrapper_scene := load(str(preview_request.get("wrapper_scene_path", ""))) as PackedScene
	if not T.require_true(self, wrapper_scene != null, "Scene preview editor preview request contract must generate a loadable wrapper scene for the real missile subject"):
		return
	var harness := wrapper_scene.instantiate() as Node3D
	if not T.require_true(self, harness != null, "Scene preview editor preview request contract must instantiate the generated wrapper as Node3D"):
		return
	if not T.require_true(self, harness.has_method("get_preview_runtime_state"), "Scene preview editor preview request contract must still root the generated wrapper in the shared preview harness"):
		return

	root.add_child(harness)
	await process_frame
	await process_frame

	var runtime_state := harness.get_preview_runtime_state() as Dictionary
	if not T.require_true(self, bool(runtime_state.get("subject_loaded", false)), "Scene preview editor preview request contract must load the temporary missile snapshot into the shared preview harness"):
		return
	var preview_subject := harness.get_node_or_null("PreviewSubjectRoot/InterceptorMissileVisual") as Node3D
	if not T.require_true(self, preview_subject != null, "Scene preview editor preview request contract must mount the missile subject under PreviewSubjectRoot"):
		return
	if not T.require_true(self, preview_subject.has_method("get_debug_state"), "Scene preview editor preview request contract must keep the missile preview subject debug state callable"):
		return

	var preview_subject_state := await _wait_for_preview_subject_state(preview_subject)
	if not T.require_true(self, bool(preview_subject_state.get("preview_active", false)), "Scene preview editor preview request contract must activate the missile subject preview behavior through the editor preview request path"):
		return
	if not T.require_true(self, bool(preview_subject_state.get("trail_visible", false)), "Scene preview editor preview request contract must preserve the missile tail flame in the editor preview request path"):
		return

	root.remove_child(harness)
	harness.free()
	edited_scene_root.free()
	wrapper_scene = null
	missile_subject_scene = null
	session_builder = null
	session_builder_script = null
	T.pass_and_quit(self)

func _wait_for_preview_subject_state(preview_subject: Node3D) -> Dictionary:
	for _frame in range(90):
		await process_frame
		var debug_state := preview_subject.get_debug_state() as Dictionary
		if bool(debug_state.get("preview_active", false)) and bool(debug_state.get("trail_visible", false)):
			return debug_state
	return preview_subject.get_debug_state() as Dictionary
