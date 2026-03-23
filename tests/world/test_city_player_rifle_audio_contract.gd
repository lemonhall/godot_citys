extends SceneTree

const T := preload("res://tests/_test_util.gd")
const RIFLE_FIRE_AUDIO_PATH := "res://city_game/assets/weapons/rifles/audio/M4 Assault rifle Long Burst.wav"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, FileAccess.file_exists(RIFLE_FIRE_AUDIO_PATH) or ResourceLoader.exists(RIFLE_FIRE_AUDIO_PATH, "AudioStreamWAV"), "Rifle audio contract requires the dedicated M4 long-burst WAV under the formal rifle audio asset directory"):
		return

	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for rifle audio contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Rifle audio contract requires Player node"):
		return
	if not T.require_true(self, player.has_method("set_weapon_mode"), "PlayerController must expose set_weapon_mode() for rifle audio verification"):
		return
	if not T.require_true(self, player.has_method("set_primary_fire_active"), "PlayerController must expose set_primary_fire_active() for held-fire rifle audio verification"):
		return
	if not T.require_true(self, player.has_method("get_rifle_audio_state"), "PlayerController must expose get_rifle_audio_state() for rifle audio verification"):
		return

	player.set_weapon_mode("rifle")
	await process_frame

	var initial_audio_state: Dictionary = player.get_rifle_audio_state()
	var rifle_audio_node := player.get_node_or_null("RifleFireAudio")
	if not T.require_true(self, rifle_audio_node is AudioStreamPlayer, "Player rifle audio debug state must still surface the formal local AudioStreamPlayer node"):
		return
	if not T.require_true(self, not (rifle_audio_node is AudioStreamPlayer3D), "Player rifle audio debug node must stay as AudioStreamPlayer instead of AudioStreamPlayer3D"):
		return
	if not T.require_true(self, (rifle_audio_node as AudioStreamPlayer).bus == &"Master", "Player rifle audio debug node must stay on Master so state inspection still targets the formal rifle asset"):
		return
	if not T.require_true(self, bool(initial_audio_state.get("stream_bound", false)), "Rifle audio state must keep the formal M4 burst stream bound even before firing"):
		return
	if not T.require_true(self, str(initial_audio_state.get("stream_path", "")) == RIFLE_FIRE_AUDIO_PATH, "Rifle audio state must report the formal M4 burst WAV as the active stream"):
		return
	if not T.require_true(self, not bool(initial_audio_state.get("loop_enabled", true)), "Player-local rifle audio debug node must not use Godot's WAV loop mode because that path goes silent for this M4 asset"):
		return
	if not T.require_true(self, int(initial_audio_state.get("play_trigger_count", 0)) == 0, "Fresh rifle audio state must boot with zero play triggers"):
		return

	player.set_primary_fire_active(true)
	for _frame in range(24):
		await physics_frame
		await process_frame

	var early_held_audio_state: Dictionary = player.get_rifle_audio_state()
	if not T.require_true(self, not bool(early_held_audio_state.get("playing", false)), "PlayerController local rifle audio must stay dormant because audible rifle fire now belongs to the world combat emitter chain"):
		return
	if not T.require_true(self, int(early_held_audio_state.get("play_trigger_count", 0)) == 0, "Holding rifle primary fire must not start a duplicate local burst audio path on PlayerController"):
		return
	if not T.require_true(self, int(early_held_audio_state.get("stop_count", 0)) == 0, "Dormant PlayerController rifle audio must not record synthetic stop events while the world emitter owns playback"):
		return

	for _frame in range(190):
		await physics_frame
		await process_frame

	var held_audio_state: Dictionary = player.get_rifle_audio_state()
	if not T.require_true(self, not bool(held_audio_state.get("playing", false)), "Long-held rifle fire must still avoid reviving the dormant PlayerController-local audio path"):
		return
	if not T.require_true(self, int(held_audio_state.get("play_trigger_count", 0)) == 0, "A long held burst must not retrigger dormant local rifle audio on PlayerController"):
		return
	if not T.require_true(self, int(held_audio_state.get("stop_count", 0)) == 0, "Dormant PlayerController-local rifle audio must keep zero stop events across a long hold"):
		return

	player.set_primary_fire_active(false)
	for _frame in range(4):
		await process_frame

	var released_audio_state: Dictionary = player.get_rifle_audio_state()
	if not T.require_true(self, not bool(released_audio_state.get("playing", false)), "Releasing rifle primary fire must keep the dormant PlayerController-local audio path inactive"):
		return
	if not T.require_true(self, int(released_audio_state.get("stop_count", 0)) == 0, "Dormant PlayerController-local rifle audio must not record stop events after release because it never owned playback"):
		return

	world.queue_free()
	T.pass_and_quit(self)
