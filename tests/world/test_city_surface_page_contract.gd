extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var layout_script := load("res://city_game/world/rendering/CityRoadSurfacePageLayout.gd")
	if not T.require_true(self, layout_script != null, "Surface page layout script must exist for v4 M4"):
		return

	var layout = layout_script.new()
	if not T.require_true(self, layout.has_method("build_chunk_contract"), "Surface page layout must expose build_chunk_contract()"):
		return

	var contract_a: Dictionary = layout.build_chunk_contract(Vector2i(136, 136), 256.0)
	var contract_b: Dictionary = layout.build_chunk_contract(Vector2i(137, 136), 256.0)
	var contract_c: Dictionary = layout.build_chunk_contract(Vector2i(140, 136), 256.0)

	if not T.require_true(self, contract_a.has("page_key"), "Surface page contract must include page_key"):
		return
	if not T.require_true(self, contract_a.has("uv_rect"), "Surface page contract must include uv_rect"):
		return
	if not T.require_true(self, contract_a.get("page_key", Vector2i.ZERO) == contract_b.get("page_key", Vector2i.ZERO), "Adjacent chunks inside same page must share page_key"):
		return
	if not T.require_true(self, contract_a.get("page_key", Vector2i.ZERO) != contract_c.get("page_key", Vector2i.ZERO), "Chunks crossing page boundary must move to next page_key"):
		return

	var uv_a: Rect2 = contract_a.get("uv_rect", Rect2())
	var uv_b: Rect2 = contract_b.get("uv_rect", Rect2())
	if not T.require_true(self, uv_a.size == uv_b.size, "Chunks inside same page must share the same UV tile size"):
		return
	if not T.require_true(self, uv_b.position.x > uv_a.position.x, "Later chunk inside same page must map to later UV tile slot"):
		return

	T.pass_and_quit(self)
