extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for player controller contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "CityPrototype must keep Player node"):
		return
	if not T.require_true(self, player.has_method("get_pitch_limits_degrees"), "PlayerController must expose get_pitch_limits_degrees()"):
		return

	var limits: Dictionary = player.get_pitch_limits_degrees()
	if not T.require_true(self, float(limits.get("min", 0.0)) <= -60.0, "Player look-down limit must stay natural"):
		return
	if not T.require_true(self, float(limits.get("max", 0.0)) >= 30.0, "Player must be able to look upward by at least 30 degrees"):
		return

	world.queue_free()
	T.pass_and_quit(self)
