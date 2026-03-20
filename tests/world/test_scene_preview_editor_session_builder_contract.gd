extends SceneTree

const T := preload("res://tests/_test_util.gd")

const ELIGIBILITY_SCRIPT_PATH := "res://addons/scene_preview/ScenePreviewEditorEligibility.gd"
const SESSION_BUILDER_SCRIPT_PATH := "res://addons/scene_preview/ScenePreviewEditorSessionBuilder.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(ELIGIBILITY_SCRIPT_PATH, "Script"), "Scene preview editor session builder contract requires ScenePreviewEditorEligibility.gd"):
		return
	if not T.require_true(self, ResourceLoader.exists(SESSION_BUILDER_SCRIPT_PATH, "Script"), "Scene preview editor session builder contract requires ScenePreviewEditorSessionBuilder.gd"):
		return

	var eligibility_script = load(ELIGIBILITY_SCRIPT_PATH)
	var session_builder_script = load(SESSION_BUILDER_SCRIPT_PATH)
	if not T.require_true(self, eligibility_script != null and session_builder_script != null, "Scene preview editor session builder contract must load both service scripts"):
		return

	var eligibility = eligibility_script.new()
	var session_builder = session_builder_script.new()
	if not T.require_true(self, eligibility != null and session_builder != null, "Scene preview editor session builder contract must instantiate both service classes"):
		return

	var no_scene_state: Dictionary = eligibility.evaluate_scene_root(null)
	if not T.require_true(self, not bool(no_scene_state.get("eligible", true)), "Scene preview editor session builder contract must reject a missing edited scene root"):
		return
	if not T.require_true(self, str(no_scene_state.get("reason", "")).find("scene") >= 0, "Scene preview editor session builder contract must expose a useful reason for missing scene roots"):
		return

	var non_3d_root := Node.new()
	non_3d_root.name = "FlatRoot"
	var non_3d_state: Dictionary = eligibility.evaluate_scene_root(non_3d_root)
	if not T.require_true(self, not bool(non_3d_state.get("eligible", true)), "Scene preview editor session builder contract must reject non-Node3D scene roots"):
		return
	if not T.require_true(self, str(non_3d_state.get("reason", "")).find("Node3D") >= 0, "Scene preview editor session builder contract must explain Node3D eligibility failures"):
		return
	non_3d_root.free()

	var edited_scene_root := _build_edited_scene_root()
	var eligible_state: Dictionary = eligibility.evaluate_scene_root(edited_scene_root)
	if not T.require_true(self, bool(eligible_state.get("eligible", false)), "Scene preview editor session builder contract must accept Node3D edited scene roots"):
		return

	var preview_request: Dictionary = session_builder.build_preview_request_from_scene_root(edited_scene_root, {
		"session_id": "unit_scene_preview_editor_session",
		"source_scene_path": "res://tests/virtual/EditedPreviewSubject.tscn",
	})
	if not T.require_true(self, bool(preview_request.get("success", false)), "Scene preview editor session builder contract must build a preview request for eligible Node3D scenes"):
		return
	if not T.require_true(self, str(preview_request.get("subject_snapshot_path", "")).begins_with("user://scene_preview/editor_subjects/"), "Scene preview editor session builder contract must place subject snapshots under user://scene_preview/editor_subjects/"):
		return
	if not T.require_true(self, str(preview_request.get("wrapper_scene_path", "")).begins_with("user://scene_preview/editor_wrappers/"), "Scene preview editor session builder contract must place wrapper scenes under user://scene_preview/editor_wrappers/"):
		return
	if not T.require_true(self, not str(preview_request.get("subject_snapshot_path", "")).begins_with("res://"), "Scene preview editor session builder contract must not emit subject snapshots into res://"):
		return
	if not T.require_true(self, not str(preview_request.get("wrapper_scene_path", "")).begins_with("res://"), "Scene preview editor session builder contract must not emit wrapper scenes into res://"):
		return
	if not T.require_true(self, bool(preview_request.get("uses_unsaved_editor_state", false)), "Scene preview editor session builder contract must mark the request as using current unsaved editor state"):
		return

	var subject_snapshot_path := str(preview_request.get("subject_snapshot_path", ""))
	var wrapper_scene_path := str(preview_request.get("wrapper_scene_path", ""))
	if not T.require_true(self, FileAccess.file_exists(subject_snapshot_path), "Scene preview editor session builder contract must persist the temporary subject snapshot scene"):
		return
	if not T.require_true(self, FileAccess.file_exists(wrapper_scene_path), "Scene preview editor session builder contract must persist the temporary wrapper scene"):
		return

	var wrapper_scene_text := FileAccess.get_file_as_string(wrapper_scene_path)
	if not T.require_true(self, wrapper_scene_text.find("res://city_game/preview/ScenePreviewHarness.tscn") >= 0, "Scene preview editor session builder contract must reference the formal ScenePreviewHarness in the wrapper output"):
		return
	if not T.require_true(self, wrapper_scene_text.find(subject_snapshot_path) >= 0, "Scene preview editor session builder contract must point the wrapper at the temporary subject snapshot"):
		return

	var subject_snapshot_scene := load(subject_snapshot_path) as PackedScene
	if not T.require_true(self, subject_snapshot_scene != null, "Scene preview editor session builder contract must generate a loadable subject snapshot PackedScene"):
		return
	var subject_snapshot_root := subject_snapshot_scene.instantiate() as Node3D
	if not T.require_true(self, subject_snapshot_root != null, "Scene preview editor session builder contract must instantiate the temporary subject snapshot as Node3D"):
		return
	var probe_mesh := subject_snapshot_root.get_node_or_null("ProbeMesh") as MeshInstance3D
	if not T.require_true(self, probe_mesh != null, "Scene preview editor session builder contract must preserve the ProbeMesh child in the saved snapshot"):
		return
	if not T.require_true(self, is_equal_approx(probe_mesh.position.x, 7.25), "Scene preview editor session builder contract must preserve unsaved child transform edits in the temporary snapshot"):
		return

	subject_snapshot_root.free()
	edited_scene_root.free()
	subject_snapshot_scene = null
	session_builder = null
	session_builder_script = null
	eligibility = null
	eligibility_script = null
	T.pass_and_quit(self)

func _build_edited_scene_root() -> Node3D:
	var root := Node3D.new()
	root.name = "EditedPreviewSubject"
	var mesh := MeshInstance3D.new()
	mesh.name = "ProbeMesh"
	mesh.mesh = BoxMesh.new()
	mesh.position = Vector3(7.25, 1.5, -2.0)
	root.add_child(mesh)
	mesh.owner = root
	return root
