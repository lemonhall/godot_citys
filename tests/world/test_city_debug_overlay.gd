extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var overlay_script := load("res://city_game/world/debug/CityDebugOverlay.gd")
	if overlay_script == null:
		T.fail_and_quit(self, "Missing CityDebugOverlay.gd")
		return

	var overlay = overlay_script.new()
	if not T.require_true(self, overlay != null, "CityDebugOverlay must instantiate"):
		return
	if not T.require_true(self, overlay.has_method("is_expanded"), "CityDebugOverlay must expose is_expanded() for folded inspection UI"):
		return
	if not T.require_true(self, overlay.has_method("toggle_expanded"), "CityDebugOverlay must expose toggle_expanded()"):
		return
	if not T.require_true(self, not overlay.is_expanded(), "Debug overlay must stay folded by default"):
		return

	var snapshot := {
		"current_chunk_id": "chunk_13_13",
		"active_chunk_count": 25,
		"last_prepare_usec": 17,
		"last_mount_usec": 19,
	}
	overlay.set_snapshot(snapshot)

	if not T.require_true(self, overlay.get_debug_snapshot()["current_chunk_id"] == "chunk_13_13", "Debug snapshot must keep current_chunk_id"):
		return
	var text: String = str(overlay.get_debug_text())
	if not T.require_true(self, "current_chunk_id=chunk_13_13" in text, "Debug text must include current_chunk_id"):
		return
	if not T.require_true(self, "active_chunk_count=25" in text, "Debug text must include active_chunk_count"):
		return
	if not T.require_true(self, "last_prepare_usec=17" in text, "Debug text must include last_prepare_usec"):
		return

	overlay.toggle_expanded()
	if not T.require_true(self, overlay.is_expanded(), "Debug overlay must expand on demand"):
		return

	overlay.free()
	T.pass_and_quit(self)
