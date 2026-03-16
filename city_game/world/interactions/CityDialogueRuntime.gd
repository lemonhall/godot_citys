extends RefCounted

var _state := _build_idle_state()

func begin_dialogue(contract: Dictionary) -> Dictionary:
	var actor_id := str(contract.get("actor_id", "")).strip_edges()
	var body_text := str(contract.get("opening_line", "")).strip_edges()
	if actor_id == "" or body_text == "":
		return {}
	var speaker_name := str(contract.get("display_name", "")).strip_edges()
	if speaker_name == "":
		speaker_name = actor_id
	_state = {
		"status": "active",
		"owner_actor_id": actor_id,
		"speaker_name": speaker_name,
		"body_text": body_text,
		"dialogue_id": str(contract.get("dialogue_id", "")).strip_edges(),
	}
	return get_state()

func close_dialogue() -> Dictionary:
	_state = _build_idle_state()
	return get_state()

func is_active() -> bool:
	return str(_state.get("status", "")) == "active"

func get_state() -> Dictionary:
	return _state.duplicate(true)

func _build_idle_state() -> Dictionary:
	return {
		"status": "idle",
		"owner_actor_id": "",
		"speaker_name": "",
		"body_text": "",
		"dialogue_id": "",
	}

