extends SceneTree

const T := preload("res://tests/_test_util.gd")

const TERRAIN_PAGE_LAYOUT_PATH := "res://city_game/world/rendering/CityTerrainPageLayout.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var layout_script := load(TERRAIN_PAGE_LAYOUT_PATH)
	if not T.require_true(self, layout_script != null, "Terrain page layout script must exist for v5 M2"):
		return

	var layout = layout_script.new()
	if not T.require_true(self, layout.has_method("build_chunk_contract"), "Terrain page layout must expose build_chunk_contract()"):
		return

	var contract_a: Dictionary = layout.build_chunk_contract(Vector2i(136, 136), 256.0)
	var contract_b: Dictionary = layout.build_chunk_contract(Vector2i(137, 136), 256.0)
	var contract_c: Dictionary = layout.build_chunk_contract(Vector2i(140, 136), 256.0)

	if not T.require_true(self, contract_a.has("page_key"), "Terrain page contract must include page_key"):
		return
	if not T.require_true(self, contract_a.has("chunk_slot"), "Terrain page contract must include chunk_slot"):
		return
	if not T.require_true(self, contract_a.has("uv_rect"), "Terrain page contract must include uv_rect for page sub-tiles"):
		return
	if not T.require_true(self, contract_a.get("page_key", Vector2i.ZERO) == contract_b.get("page_key", Vector2i.ZERO), "Adjacent chunks inside same terrain page must share page_key"):
		return
	if not T.require_true(self, contract_a.get("page_key", Vector2i.ZERO) != contract_c.get("page_key", Vector2i.ZERO), "Chunks crossing terrain page boundary must move to next page_key"):
		return

	T.pass_and_quit(self)
