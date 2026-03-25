extends SceneTree

const T := preload("res://tests/_test_util.gd")

const CITY_SCENE_PATH := "res://city_game/scenes/CityPrototype.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(CITY_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Artillery solution HUD contract requires CityPrototype.tscn so the shared PrototypeHud consumer can be regression tested"):
		return

	var world := scene.instantiate()
	if not T.require_true(self, world != null, "Artillery solution HUD contract must instantiate the main world scene"):
		return

	root.add_child(world)
	await process_frame
	await process_frame

	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, hud != null, "Artillery solution HUD contract requires the shared Hud node in the main world scene"):
		return
	if not T.require_true(self, hud.has_method("set_artillery_solution_state"), "PrototypeHud must expose set_artillery_solution_state() so world-level artillery consumers do not create lab-only HUD forks"):
		return
	if not T.require_true(self, hud.has_method("get_artillery_solution_state"), "PrototypeHud must expose get_artillery_solution_state() so artillery HUD state remains introspectable and testable"):
		return
	if not T.require_true(self, hud.get_node_or_null("Root/ArtillerySolutionHud") != null, "PrototypeHud must mount a formal ArtillerySolutionHud view instead of leaving artillery readout to debug text"):
		return

	var hidden_state := hud.get_artillery_solution_state() as Dictionary
	if not T.require_true(self, not bool(hidden_state.get("visible", false)), "Artillery solution HUD must stay hidden by default when no howitzer operator owns it"):
		return

	hud.set_artillery_solution_state({
		"visible": true,
		"title": "射击诸元",
		"yaw_label_text": "方位",
		"pitch_label_text": "高低",
		"yaw_bearing_deg": 87.26,
		"pitch_deg": 24.5,
		"pitch_min_deg": 0.0,
		"pitch_max_deg": 71.0,
	})
	await process_frame

	var visible_state := hud.get_artillery_solution_state() as Dictionary
	if not T.require_true(self, bool(visible_state.get("visible", false)), "Setting artillery solution HUD visible must actually surface the shared world-level consumer"):
		return
	if not T.require_true(self, absf(float(visible_state.get("yaw_bearing_deg", -999.0)) - 87.26) <= 0.01, "Artillery solution HUD state must preserve the pushed world bearing value instead of silently reinterpreting it as relative yaw"):
		return
	if not T.require_true(self, absf(float(visible_state.get("pitch_deg", -999.0)) - 24.5) <= 0.01, "Artillery solution HUD state must preserve the pushed pitch value instead of replacing it with another UI-only angle"):
		return

	var artillery_solution_view := hud.get_node_or_null("Root/ArtillerySolutionHud")
	if not T.require_true(self, artillery_solution_view != null and bool(artillery_solution_view.visible), "PrototypeHud must drive the formal ArtillerySolutionHud view visible once artillery state becomes active"):
		return
	if not T.require_true(self, artillery_solution_view.has_method("get_state"), "ArtillerySolutionHud view must expose get_state() so focused tests can verify the rendered contract directly"):
		return

	var rendered_state := artillery_solution_view.get_state() as Dictionary
	if not T.require_true(self, absf(float(rendered_state.get("yaw_bearing_deg", -999.0)) - 87.26) <= 0.01, "ArtillerySolutionHud view must mirror the shared HUD state's world bearing payload"):
		return
	if not T.require_true(self, absf(float(rendered_state.get("pitch_deg", -999.0)) - 24.5) <= 0.01, "ArtillerySolutionHud view must mirror the shared HUD state's pitch payload"):
		return
	var yaw_strip := artillery_solution_view.get_node_or_null("Panel/Margin/VBox/YawStrip")
	if not T.require_true(self, yaw_strip != null and yaw_strip.has_method("get_state"), "ArtillerySolutionHud view must expose the YawStrip state so the rendered bearing precision can be regression tested directly"):
		return
	var yaw_strip_state := yaw_strip.get_state() as Dictionary
	if not T.require_true(self, str(yaw_strip_state.get("bearing_text", "")) == "87.3°", "ArtillerySolutionHud yaw strip must render bearing_text to 0.1° precision instead of rounding the artillery bearing back to whole degrees"):
		return
	var panel := artillery_solution_view.get_node_or_null("Panel") as PanelContainer
	if not T.require_true(self, panel != null, "ArtillerySolutionHud view must expose a Panel root so the rounded shell layout can be regression tested"):
		return
	var required_min_height := panel.get_combined_minimum_size().y
	if not T.require_true(self, artillery_solution_view.size.y + 0.5 >= required_min_height, "ArtillerySolutionHud outer height must fully contain its combined minimum content height so the rounded panel does not clip the lower strip (outer_height=%.2f required_min_height=%.2f)" % [artillery_solution_view.size.y, required_min_height]):
		return

	hud.set_artillery_solution_state({"visible": false})
	await process_frame

	var rehidden_state := hud.get_artillery_solution_state() as Dictionary
	if not T.require_true(self, not bool(rehidden_state.get("visible", false)), "Artillery solution HUD must hide again when the owning artillery interaction releases it"):
		return
	if not T.require_true(self, not bool(artillery_solution_view.visible), "ArtillerySolutionHud view must hide again once the shared artillery solution state is cleared"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)
