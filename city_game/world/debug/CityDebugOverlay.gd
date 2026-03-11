extends CanvasLayer

var _snapshot: Dictionary = {}

func _ready() -> void:
	_apply_snapshot()

func set_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	_apply_snapshot()

func get_debug_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)

func get_debug_text() -> String:
	return "\n".join([
		"current_chunk_id=%s" % str(_snapshot.get("current_chunk_id", "")),
		"active_chunk_count=%d" % int(_snapshot.get("active_chunk_count", 0)),
		"last_prepare_usec=%d" % int(_snapshot.get("last_prepare_usec", 0)),
		"last_mount_usec=%d" % int(_snapshot.get("last_mount_usec", 0)),
		"last_retire_usec=%d" % int(_snapshot.get("last_retire_usec", 0)),
	])

func _apply_snapshot() -> void:
	var label := get_node_or_null("DebugMargin/DebugPanel/DebugLabel") as Label
	if label != null:
		label.text = get_debug_text()

