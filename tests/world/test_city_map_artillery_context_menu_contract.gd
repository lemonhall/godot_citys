extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for map artillery context-menu contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("set_full_map_open"), "Map artillery context-menu contract requires full-map visibility control"):
		return
	if not T.require_true(self, world.has_method("get_map_screen_state"), "Map artillery context-menu contract requires map render state introspection"):
		return

	world.set_full_map_open(true)
	await process_frame

	var full_map := world.get_node_or_null("Hud/Root/FullMap") as Control
	if not T.require_true(self, full_map != null, "Map artillery context-menu contract requires the mounted FullMap control"):
		return

	var initial_state: Dictionary = world.get_map_screen_state()
	var initial_context_menu: Dictionary = initial_state.get("context_menu", {})
	if not T.require_true(self, not bool(initial_context_menu.get("visible", false)), "Full map artillery context menu must stay hidden before the user right-clicks inside the map canvas"):
		return

	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	right_click.position = full_map.size * 0.5
	full_map._gui_input(right_click)
	await process_frame

	var map_state: Dictionary = world.get_map_screen_state()
	var context_menu: Dictionary = map_state.get("context_menu", {})
	if not T.require_true(self, bool(context_menu.get("visible", false)), "Right-clicking inside the full map canvas must surface the formal artillery context menu"):
		return
	var actions: Array = context_menu.get("actions", [])
	if not T.require_true(self, actions.size() > 0, "Artillery context menu must expose a formal action list instead of relying on a hidden hard-coded click path"):
		return

	var saw_fire_mission_action := false
	for action_variant in actions:
		var action: Dictionary = action_variant
		if str(action.get("action_id", "")) != "artillery_fire_mission":
			continue
		saw_fire_mission_action = true
		if not T.require_true(self, str(action.get("label", "")) == "炮击标记", "The artillery context menu action label must freeze to 炮击标记"):
			return
	if not T.require_true(self, saw_fire_mission_action, "Full map artillery context menu must offer the formal artillery_fire_mission action instead of only retaining destination selection"):
		return

	world.set_full_map_open(false)
	await process_frame

	map_state = world.get_map_screen_state()
	context_menu = map_state.get("context_menu", {})
	if not T.require_true(self, not bool(context_menu.get("visible", false)), "Closing the full map must clear any stale artillery context menu visibility"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)
