extends RefCounted

const EVENT_PREPARE := "prepare"
const EVENT_MOUNT := "mount"
const EVENT_RETIRE := "retire"

static func make_event(sequence: int, event_type: String, chunk_id: String, chunk_key: Vector2i) -> Dictionary:
	return {
		"sequence": sequence,
		"event_type": event_type,
		"chunk_id": chunk_id,
		"chunk_key": chunk_key,
	}

