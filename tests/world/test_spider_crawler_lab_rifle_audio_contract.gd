extends SceneTree

const T := preload("res://tests/_test_util.gd")
const RIFLE_FIRE_AUDIO_PATH := "res://city_game/assets/weapons/rifles/audio/M4 Assault rifle Long Burst.wav"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/labs/SpiderCrawlerLab.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing SpiderCrawlerLab.tscn for rifle lab-audio contract")
		return

	var lab := (scene as PackedScene).instantiate()
	root.add_child(lab)
	await process_frame

	var player := lab.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Spider lab rifle audio contract requires Player node"):
		return
	if not T.require_true(self, player.has_method("set_weapon_mode"), "PlayerController must expose set_weapon_mode() for spider lab rifle audio verification"):
		return
	if not T.require_true(self, player.has_method("set_primary_fire_active"), "PlayerController must expose set_primary_fire_active() for spider lab held-fire audio verification"):
		return
	if not T.require_true(self, lab.has_method("get_player_rifle_audio_debug_state"), "SpiderCrawlerLab must expose get_player_rifle_audio_debug_state() so rifle sound can ride the same world combat chain as weapon 8"):
		return

	player.set_weapon_mode("rifle")
	await process_frame

	var initial_audio_state: Dictionary = lab.get_player_rifle_audio_debug_state()
	if not T.require_true(self, bool(initial_audio_state.get("emitter_present", false)), "Spider lab rifle audio contract requires a dedicated world-side rifle emitter"):
		return
	if not T.require_true(self, bool(initial_audio_state.get("stream_bound", false)), "Spider lab rifle emitter must bind the formal M4 long-burst WAV"):
		return
	if not T.require_true(self, str(initial_audio_state.get("stream_path", "")) == RIFLE_FIRE_AUDIO_PATH, "Spider lab rifle emitter must report the formal M4 long-burst WAV path"):
		return
	if not T.require_true(self, not bool(initial_audio_state.get("loop_enabled", true)), "Spider lab rifle emitter must not rely on Godot WAV loop mode because that path goes silent for this M4 asset"):
		return

	player.set_primary_fire_active(true)
	for _frame in range(24):
		await physics_frame
		await process_frame

	var early_held_audio_state: Dictionary = lab.get_player_rifle_audio_debug_state()
	if not T.require_true(self, bool(early_held_audio_state.get("playing", false)), "Holding rifle fire in the spider lab must keep the world-side rifle audio emitter active"):
		return
	if not T.require_true(self, int(early_held_audio_state.get("play_trigger_count", 0)) == 1, "Spider lab held rifle fire must start the world-side rifle burst once at hold start"):
		return

	for _frame in range(190):
		await physics_frame
		await process_frame

	var held_audio_state: Dictionary = lab.get_player_rifle_audio_debug_state()
	if not T.require_true(self, bool(held_audio_state.get("playing", false)), "Holding rifle fire in the spider lab beyond the raw clip length must keep the world-side emitter alive via manual restitching"):
		return
	if not T.require_true(self, int(held_audio_state.get("play_trigger_count", 0)) >= 2, "Spider lab held rifle fire must re-trigger the non-loop rifle clip after it nears the end instead of staying on the broken Godot loop path"):
		return
	if not T.require_true(self, int(held_audio_state.get("restart_trigger_count", 0)) >= 1, "Spider lab held rifle fire must record at least one manual rifle audio restart beyond the raw clip length"):
		return

	player.set_primary_fire_active(false)
	for _frame in range(4):
		await process_frame

	var released_audio_state: Dictionary = lab.get_player_rifle_audio_debug_state()
	if not T.require_true(self, not bool(released_audio_state.get("playing", false)), "Releasing rifle fire in the spider lab must stop the world-side rifle emitter promptly"):
		return
	if not T.require_true(self, int(released_audio_state.get("stop_count", 0)) >= 1, "Spider lab rifle emitter must record a stop event after held fire is released"):
		return

	lab.queue_free()
	T.pass_and_quit(self)
