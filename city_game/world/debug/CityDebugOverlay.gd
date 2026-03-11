extends CanvasLayer

var _snapshot: Dictionary = {}
var _expanded := false

func _ready() -> void:
	_apply_snapshot()

func set_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	_apply_snapshot()

func get_debug_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)

func set_expanded(expanded: bool) -> void:
	_expanded = expanded

func toggle_expanded() -> void:
	_expanded = not _expanded

func is_expanded() -> bool:
	return _expanded

func get_debug_text() -> String:
	var lines := [
		"control_mode=%s" % str(_snapshot.get("control_mode", "player")),
		"current_chunk_id=%s" % str(_snapshot.get("current_chunk_id", "")),
		"active_chunk_count=%d" % int(_snapshot.get("active_chunk_count", 0)),
		"last_prepare_usec=%d" % int(_snapshot.get("last_prepare_usec", 0)),
		"last_mount_usec=%d" % int(_snapshot.get("last_mount_usec", 0)),
		"last_retire_usec=%d" % int(_snapshot.get("last_retire_usec", 0)),
	]
	if _snapshot.has("multimesh_instance_total"):
		lines.append("multimesh_instance_total=%d" % int(_snapshot.get("multimesh_instance_total", 0)))
	if _snapshot.has("lod_mode_counts"):
		lines.append("lod_mode_counts=%s" % str(_snapshot.get("lod_mode_counts", {})))
	if _snapshot.has("current_chunk_multimesh_instance_count"):
		lines.append("current_chunk_multimesh_instance_count=%d" % int(_snapshot.get("current_chunk_multimesh_instance_count", 0)))
	if _snapshot.has("current_chunk_lod_mode"):
		lines.append("current_chunk_lod_mode=%s" % str(_snapshot.get("current_chunk_lod_mode", "")))
	if _snapshot.has("current_chunk_visual_variant_id"):
		lines.append("current_chunk_visual_variant_id=%s" % str(_snapshot.get("current_chunk_visual_variant_id", "")))
	if _snapshot.has("tracked_position"):
		lines.append("tracked_position=%s" % str(_snapshot.get("tracked_position", {})))
	return "\n".join(lines)

func _apply_snapshot() -> void:
	var label := get_node_or_null("DebugMargin/DebugPanel/DebugLabel") as Label
	if label != null:
		label.text = get_debug_text()
