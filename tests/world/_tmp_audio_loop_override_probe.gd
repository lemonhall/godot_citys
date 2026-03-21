extends SceneTree

func _initialize() -> void:
	var scene := load("res://tests/world/_tmp_audio_loop_override_probe.tscn") as PackedScene
	var root := scene.instantiate()
	var rotor_audio := root.get_node("RotorAudio") as AudioStreamPlayer3D
	var stream := rotor_audio.stream as AudioStreamWAV
	print("loop_mode=%s" % str(stream.loop_mode if stream != null else -1))
	root.free()
	quit()
