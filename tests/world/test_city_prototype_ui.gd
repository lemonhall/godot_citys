extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for UI contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, hud != null, "CityPrototype must include Hud"):
		return
	if not T.require_true(self, hud.has_method("is_debug_expanded"), "PrototypeHud must expose is_debug_expanded()"):
		return
	if not T.require_true(self, hud.has_method("toggle_debug_expanded"), "PrototypeHud must expose toggle_debug_expanded()"):
		return
	if not T.require_true(self, not hud.is_debug_expanded(), "Inspection HUD must stay collapsed by default"):
		return

	hud.toggle_debug_expanded()
	if not T.require_true(self, hud.is_debug_expanded(), "Inspection HUD must expand on demand"):
		return

	var debug_overlay := world.get_node_or_null("DebugOverlay") as CanvasLayer
	if not T.require_true(self, debug_overlay != null, "CityPrototype must keep DebugOverlay node for compatibility"):
		return
	if not T.require_true(self, not debug_overlay.visible, "Standalone debug overlay must stay hidden by default once HUD is integrated"):
		return

	world.queue_free()
	T.pass_and_quit(self)
