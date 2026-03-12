extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for pedestrian debug overlay")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Pedestrian debug overlay requires Player node"):
		return

	var overlay := world.get_node_or_null("DebugOverlay")
	if not T.require_true(self, overlay != null, "CityPrototype must keep DebugOverlay for pedestrian debug overlay"):
		return
	if not T.require_true(self, overlay.has_method("get_debug_snapshot"), "CityDebugOverlay must expose get_debug_snapshot() for pedestrian debug overlay"):
		return
	if not T.require_true(self, overlay.has_method("get_debug_text"), "CityDebugOverlay must expose get_debug_text() for pedestrian debug overlay"):
		return
	if not T.require_true(self, overlay.has_method("is_expanded"), "CityDebugOverlay must expose is_expanded() for folded crowd debug state"):
		return
	if not T.require_true(self, overlay.has_method("toggle_expanded"), "CityDebugOverlay must expose toggle_expanded() for crowd debug inspection"):
		return
	if not T.require_true(self, not overlay.is_expanded(), "Pedestrian debug overlay must stay folded by default"):
		return
	if not T.require_true(self, not overlay.visible, "Pedestrian debug overlay must stay hidden while folded"):
		return

	world.update_streaming_for_position(player.global_position)
	var snapshot: Dictionary = overlay.get_debug_snapshot()
	for required_key in [
		"pedestrian_mode",
		"crowd_update_avg_usec",
		"crowd_spawn_avg_usec",
		"crowd_render_commit_avg_usec",
		"ped_tier1_count",
		"ped_page_cache_miss_count",
	]:
		if not T.require_true(self, snapshot.has(required_key), "Pedestrian debug snapshot must expose %s" % required_key):
			return

	overlay.toggle_expanded()
	world.update_streaming_for_position(player.global_position)
	await process_frame

	if not T.require_true(self, overlay.is_expanded(), "Pedestrian debug overlay must expand on demand"):
		return
	if not T.require_true(self, overlay.visible, "Expanded pedestrian debug overlay must become visible"):
		return

	var text := str(overlay.get_debug_text())
	if not T.require_true(self, "pedestrian_mode=lite" in text, "Pedestrian debug overlay must report the lite pedestrian mode"):
		return
	if not T.require_true(self, "crowd_update_avg_usec=" in text, "Pedestrian debug overlay must report crowd update timing"):
		return
	if not T.require_true(self, "crowd_spawn_avg_usec=" in text, "Pedestrian debug overlay must report crowd spawn timing"):
		return
	if not T.require_true(self, "crowd_render_commit_avg_usec=" in text, "Pedestrian debug overlay must report crowd render commit timing"):
		return
	if not T.require_true(self, "ped_tier1_count=" in text, "Pedestrian debug overlay must report pedestrian tier counts"):
		return
	if not T.require_true(self, "ped_page_cache_miss_count=" in text, "Pedestrian debug overlay must report crowd page/cache stats"):
		return

	world.queue_free()
	T.pass_and_quit(self)
