extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var view_script := load("res://city_game/ui/CityMinimapView.gd")
	if view_script == null:
		T.fail_and_quit(self, "Missing CityMinimapView.gd")
		return

	var view = view_script.new()
	root.add_child(view)
	await process_frame
	if not T.require_true(self, view.has_method("build_player_marker_polygon"), "CityMinimapView must expose build_player_marker_polygon() for deterministic marker orientation"):
		return

	var polygon: PackedVector2Array = view.build_player_marker_polygon(Vector2(100.0, 100.0), 0.0)
	if not T.require_true(self, polygon.size() == 3, "Player marker polygon must contain exactly three points"):
		return

	var tip := polygon[0]
	var base_mid_y := (polygon[1].y + polygon[2].y) * 0.5
	if not T.require_true(self, tip.y < base_mid_y, "Heading 0 marker must point toward north/up on the minimap"):
		return

	view.queue_free()
	T.pass_and_quit(self)
