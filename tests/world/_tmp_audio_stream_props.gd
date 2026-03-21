extends SceneTree
func _initialize() -> void:
	var stream := load('res://city_game/combat/helicopter/audio/helicopter.wav')
	if stream == null:
		print('stream=null')
		quit(1)
		return
	print('before=', stream.loop_mode)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	print('after=', stream.loop_mode)
	quit()
