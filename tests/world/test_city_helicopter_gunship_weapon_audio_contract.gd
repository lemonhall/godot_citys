extends SceneTree

const T := preload("res://tests/_test_util.gd")
const GUNSHIP_SCENE_PATH := "res://city_game/combat/helicopter/CityHelicopterGunship.tscn"
const MISSILE_FIRE_AUDIO_PATH := "res://city_game/combat/helicopter/audio/rockt-explosions.wav"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(GUNSHIP_SCENE_PATH, "PackedScene"), "Helicopter gunship weapon audio contract requires the formal gunship scene"):
		return
	if not T.require_true(self, FileAccess.file_exists(MISSILE_FIRE_AUDIO_PATH) or ResourceLoader.exists(MISSILE_FIRE_AUDIO_PATH, "AudioStreamWAV"), "Helicopter gunship weapon audio contract requires the dedicated rockt-explosions.wav asset"):
		return

	var scene := load(GUNSHIP_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Helicopter gunship weapon audio contract must load the gunship scene as PackedScene"):
		return

	var target := Node3D.new()
	target.name = "DummyTarget"
	root.add_child(target)
	target.global_position = Vector3.ZERO

	var gunship := scene.instantiate() as CharacterBody3D
	if not T.require_true(self, gunship != null, "Helicopter gunship weapon audio contract must instantiate the formal gunship runtime"):
		return
	root.add_child(gunship)
	gunship.global_position = Vector3(0.0, 28.0, -10.0)
	await process_frame

	var missile_fire_audio := gunship.get_node_or_null("MissileFireAudio") as AudioStreamPlayer3D
	if not T.require_true(self, missile_fire_audio != null, "Helicopter gunship scene must author a dedicated MissileFireAudio node so missile launches carry a weapon SFX"):
		return
	if not T.require_true(self, missile_fire_audio.stream != null, "Helicopter gunship MissileFireAudio node must bind the dedicated launch SFX stream"):
		return
	if not T.require_true(self, missile_fire_audio.stream.resource_path == MISSILE_FIRE_AUDIO_PATH, "Helicopter gunship MissileFireAudio must point at rockt-explosions.wav instead of reusing rotor audio"):
		return
	if not T.require_true(self, not missile_fire_audio.autoplay, "Helicopter gunship MissileFireAudio must stay event-driven and not autoplay on spawn"):
		return

	gunship.configure_combat(target, gunship.global_position)
	for _frame in range(120):
		await physics_frame
		await process_frame
		var debug_state: Dictionary = gunship.get_debug_state()
		var weapon_audio_state: Dictionary = debug_state.get("weapon_fire_audio", {})
		if int(weapon_audio_state.get("trigger_count", 0)) > 0:
			if not T.require_true(self, bool(weapon_audio_state.get("stream_bound", false)), "Helicopter gunship weapon audio debug state must confirm the launch SFX stream stays bound when missiles fire"):
				return
			if not T.require_true(self, str(weapon_audio_state.get("stream_path", "")) == MISSILE_FIRE_AUDIO_PATH, "Helicopter gunship weapon audio debug state must report rockt-explosions.wav as the active launch SFX stream"):
				return
			gunship.queue_free()
			target.queue_free()
			await process_frame
			T.pass_and_quit(self)
			return

	T.fail_and_quit(self, "Helicopter gunship weapon audio contract requires missile launches to trigger the dedicated launch SFX at least once during live combat")
