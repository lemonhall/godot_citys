extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for HUD snapshot refresh contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("_should_build_hud_snapshot_refresh"), "CityPrototype must expose _should_build_hud_snapshot_refresh() for HUD refresh gating"):
		return

	if not T.require_true(
		self,
		not bool(world.call("_should_build_hud_snapshot_refresh", false, true, false, false)),
		"Rendered collapsed HUD without debug overlays must skip heavy HUD snapshot assembly"
	):
		return

	if not T.require_true(
		self,
		bool(world.call("_should_build_hud_snapshot_refresh", false, true, true, false)),
		"Rendered expanded HUD must still request a HUD snapshot"
	):
		return

	if not T.require_true(
		self,
		bool(world.call("_should_build_hud_snapshot_refresh", false, false, false, true)),
		"Debug overlay expansion must still request a HUD snapshot even when the collapsed HUD is throttled"
	):
		return

	world.queue_free()
	T.pass_and_quit(self)
