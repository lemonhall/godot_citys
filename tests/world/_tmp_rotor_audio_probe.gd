extends SceneTree

const GUNSHIP_SCENE_PATH := "res://city_game/combat/helicopter/CityHelicopterGunship.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(GUNSHIP_SCENE_PATH) as PackedScene
	if scene == null:
		push_error("probe: failed to load gunship scene")
		quit(1)
		return
	var gunship := scene.instantiate() as CharacterBody3D
	root.add_child(gunship)
	await process_frame
	var rotor_audio := gunship.get_node_or_null("RotorAudio") as AudioStreamPlayer3D
	if rotor_audio == null:
		push_error("probe: missing RotorAudio")
		quit(1)
		return
	var stream := rotor_audio.stream as AudioStreamWAV
	print("probe:member_rotor_audio_null=%s" % str(gunship.get("_rotor_audio") == null))
	print("probe:before loop_mode=%s playing=%s" % [
		str(stream.loop_mode if stream != null else -1),
		str(rotor_audio.playing),
	])
	gunship.call("_configure_rotor_audio")
	stream = rotor_audio.stream as AudioStreamWAV
	print("probe:after loop_mode=%s playing=%s" % [
		str(stream.loop_mode if stream != null else -1),
		str(rotor_audio.playing),
	])
	gunship.queue_free()
	await process_frame
	quit()
