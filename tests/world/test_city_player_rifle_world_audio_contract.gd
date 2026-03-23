extends SceneTree

const T := preload("res://tests/_test_util.gd")
const RIFLE_FIRE_AUDIO_PATH := "res://city_game/assets/weapons/rifles/audio/M4 Assault rifle Long Burst.wav"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for rifle world-audio contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Rifle world-audio contract requires Player node"):
		return
	if not T.require_true(self, player.has_method("set_weapon_mode"), "PlayerController must expose set_weapon_mode() for rifle world-audio verification"):
		return
	if not T.require_true(self, player.has_method("set_primary_fire_active"), "PlayerController must expose set_primary_fire_active() for rifle held-fire world-audio verification"):
		return
	if not T.require_true(self, world.has_method("get_player_rifle_audio_debug_state"), "CityPrototype must expose get_player_rifle_audio_debug_state() so rifle sound can be verified through the same world combat chain as weapon 8"):
		return

	player.set_weapon_mode("rifle")
	await process_frame

	var initial_audio_state: Dictionary = world.get_player_rifle_audio_debug_state()
	if not T.require_true(self, bool(initial_audio_state.get("emitter_present", false)), "Main-world rifle audio contract requires a dedicated world-side emitter instead of relying only on Player-local audio playback"):
		return
	if not T.require_true(self, bool(initial_audio_state.get("stream_bound", false)), "Main-world rifle audio emitter must bind the formal M4 long-burst WAV"):
		return
	if not T.require_true(self, str(initial_audio_state.get("stream_path", "")) == RIFLE_FIRE_AUDIO_PATH, "Main-world rifle audio emitter must report the formal M4 long-burst WAV path"):
		return
	if not T.require_true(self, not bool(initial_audio_state.get("loop_enabled", true)), "Main-world rifle emitter must not rely on Godot WAV loop mode because that path goes silent for this M4 asset"):
		return

	player.set_primary_fire_active(true)
	for _frame in range(24):
		await physics_frame
		await process_frame

	var early_held_audio_state: Dictionary = world.get_player_rifle_audio_debug_state()
	if not T.require_true(self, bool(early_held_audio_state.get("playing", false)), "Holding rifle fire in the main world must keep the world-side rifle audio emitter active"):
		return
	if not T.require_true(self, int(early_held_audio_state.get("play_trigger_count", 0)) == 1, "Main-world held rifle fire must start the world-side rifle burst once at hold start"):
		return

	for _frame in range(190):
		await physics_frame
		await process_frame

	var held_audio_state: Dictionary = world.get_player_rifle_audio_debug_state()
	if not T.require_true(self, bool(held_audio_state.get("playing", false)), "Main-world held rifle fire must keep the dedicated rifle emitter alive beyond the raw clip length via manual restitching"):
		return
	if not T.require_true(self, int(held_audio_state.get("play_trigger_count", 0)) >= 2, "Main-world held rifle fire must re-trigger the non-loop rifle clip after it nears the end instead of staying on the broken Godot loop path"):
		return
	if not T.require_true(self, int(held_audio_state.get("restart_trigger_count", 0)) >= 1, "Main-world held rifle fire must record at least one manual rifle audio restart beyond the raw clip length"):
		return

	player.set_primary_fire_active(false)
	for _frame in range(4):
		await process_frame

	var released_audio_state: Dictionary = world.get_player_rifle_audio_debug_state()
	if not T.require_true(self, not bool(released_audio_state.get("playing", false)), "Releasing rifle fire in the main world must stop the world-side rifle emitter promptly"):
		return
	if not T.require_true(self, int(released_audio_state.get("stop_count", 0)) >= 1, "Main-world rifle emitter must record a stop event after held fire is released"):
		return

	world.queue_free()
	T.pass_and_quit(self)
