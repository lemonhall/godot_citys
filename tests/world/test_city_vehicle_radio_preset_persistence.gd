extends SceneTree

const T := preload("res://tests/_test_util.gd")
const STORE_PATH := "res://city_game/world/radio/CityRadioUserStateStore.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var store_script := load(STORE_PATH)
	if not T.require_true(self, store_script != null, "Vehicle radio preset persistence contract requires CityRadioUserStateStore.gd"):
		return

	var store = store_script.new()
	if not T.require_true(self, store != null and store.has_method("build_presets_path"), "Vehicle radio preset persistence contract requires build_presets_path()"):
		return
	if not T.require_true(self, store.has_method("save_presets"), "Vehicle radio preset persistence contract requires save_presets()"):
		return
	if not T.require_true(self, store.has_method("load_presets"), "Vehicle radio preset persistence contract requires load_presets()"):
		return
	if not T.require_true(self, store.has_method("save_favorites"), "Vehicle radio preset persistence contract requires save_favorites()"):
		return
	if not T.require_true(self, store.has_method("load_favorites"), "Vehicle radio preset persistence contract requires load_favorites()"):
		return
	if not T.require_true(self, store.has_method("save_recents"), "Vehicle radio preset persistence contract requires save_recents()"):
		return
	if not T.require_true(self, store.has_method("load_recents"), "Vehicle radio preset persistence contract requires load_recents()"):
		return
	if not T.require_true(self, store.has_method("save_session_state"), "Vehicle radio preset persistence contract requires save_session_state()"):
		return
	if not T.require_true(self, store.has_method("load_session_state"), "Vehicle radio preset persistence contract requires load_session_state()"):
		return

	var presets_path := str(store.build_presets_path())
	var favorites_path := str(store.build_favorites_path())
	var recents_path := str(store.build_recents_path())
	var session_path := str(store.build_session_state_path())
	if not T.require_true(self, presets_path == "user://radio/presets.json", "Presets path must freeze to user://radio/presets.json"):
		return
	if not T.require_true(self, favorites_path == "user://radio/favorites.json", "Favorites path must freeze to user://radio/favorites.json"):
		return
	if not T.require_true(self, recents_path == "user://radio/recents.json", "Recents path must freeze to user://radio/recents.json"):
		return
	if not T.require_true(self, session_path == "user://radio/session_state.json", "Session state path must freeze to user://radio/session_state.json"):
		return

	var station_snapshot := {
		"station_id": "station:cn:1",
		"station_name": "Xi'an Traffic FM",
		"country": "CN",
		"codec": "aac",
	}
	var presets := [
		{"slot_index": 0, "station_snapshot": station_snapshot.duplicate(true)},
		{"slot_index": 1, "station_snapshot": {}},
	]
	var favorites := [station_snapshot.duplicate(true)]
	var recents := [station_snapshot.duplicate(true)]
	var session_state := {
		"power_state": "on",
		"selected_station_snapshot": station_snapshot.duplicate(true),
		"selected_station_id": "station:cn:1",
	}

	if not T.require_true(self, bool(store.save_presets(presets, 100).get("success", false)), "Preset save must succeed"):
		return
	if not T.require_true(self, bool(store.save_favorites(favorites, 100).get("success", false)), "Favorites save must succeed"):
		return
	if not T.require_true(self, bool(store.save_recents(recents, 100).get("success", false)), "Recents save must succeed"):
		return
	if not T.require_true(self, bool(store.save_session_state(session_state, 100).get("success", false)), "Session state save must succeed"):
		return

	station_snapshot["station_name"] = "Mutated Outside"
	(presets[0].get("station_snapshot", {}) as Dictionary)["station_name"] = "Mutated Preset"
	(favorites[0] as Dictionary)["station_name"] = "Mutated Favorite"
	(recents[0] as Dictionary)["station_name"] = "Mutated Recent"
	(session_state.get("selected_station_snapshot", {}) as Dictionary)["station_name"] = "Mutated Session"

	var loaded_presets: Dictionary = store.load_presets()
	var preset_slots := loaded_presets.get("slots", []) as Array
	if not T.require_true(self, preset_slots.size() == 2, "Preset load must preserve slot count"):
		return
	var first_slot_snapshot: Dictionary = ((preset_slots[0] as Dictionary).get("station_snapshot", {}) as Dictionary)
	if not T.require_true(self, str(first_slot_snapshot.get("station_name", "")) == "Xi'an Traffic FM", "Preset persistence must store a snapshot copy instead of a mutable external reference"):
		return

	var loaded_favorites: Dictionary = store.load_favorites()
	var favorite_entries := loaded_favorites.get("stations", []) as Array
	if not T.require_true(self, favorite_entries.size() == 1, "Favorites load must preserve station count"):
		return
	if not T.require_true(self, str((favorite_entries[0] as Dictionary).get("station_name", "")) == "Xi'an Traffic FM", "Favorites persistence must preserve the original station snapshot"):
		return

	var loaded_recents: Dictionary = store.load_recents()
	var recent_entries := loaded_recents.get("stations", []) as Array
	if not T.require_true(self, recent_entries.size() == 1, "Recents load must preserve station count"):
		return
	if not T.require_true(self, str((recent_entries[0] as Dictionary).get("station_name", "")) == "Xi'an Traffic FM", "Recents persistence must preserve the original station snapshot"):
		return

	var loaded_session: Dictionary = store.load_session_state()
	var session_snapshot: Dictionary = loaded_session.get("selected_station_snapshot", {}) as Dictionary
	if not T.require_true(self, str(session_snapshot.get("station_name", "")) == "Xi'an Traffic FM", "Session state persistence must preserve the original selected station snapshot"):
		return

	if not _require_pretty_json(presets_path):
		return
	if not _require_pretty_json(favorites_path):
		return
	if not _require_pretty_json(recents_path):
		return
	if not _require_pretty_json(session_path):
		return

	T.pass_and_quit(self)

func _require_pretty_json(path: String) -> bool:
	var global_path := ProjectSettings.globalize_path(path)
	var text := FileAccess.get_file_as_string(global_path)
	if not T.require_true(self, text.contains("\n"), "Radio user-state JSON must be multi-line pretty-print: %s" % path):
		return false
	if not T.require_true(self, text.contains("  \"") or text.contains("\t\""), "Radio user-state JSON must contain indented object keys: %s" % path):
		return false
	return true
