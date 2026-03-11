extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var chunk_scene_script := load("res://city_game/world/rendering/CityChunkScene.gd")
	if chunk_scene_script == null:
		T.fail_and_quit(self, "Missing CityChunkScene.gd")
		return

	var chunk_scene = chunk_scene_script.new()
	root.add_child(chunk_scene)
	await process_frame

	chunk_scene.setup({
		"chunk_id": "chunk_13_13",
		"chunk_key": Vector2i(13, 13),
		"chunk_center": Vector3.ZERO,
		"chunk_size_m": 256.0,
	})

	if not T.require_true(self, chunk_scene.has_node("NearGroup"), "Chunk scene must provide NearGroup"):
		return
	if not T.require_true(self, chunk_scene.has_node("MidProxy"), "Chunk scene must provide MidProxy"):
		return
	if not T.require_true(self, chunk_scene.has_node("FarProxy"), "Chunk scene must provide FarProxy"):
		return
	if not T.require_true(self, chunk_scene.has_method("get_lod_signature"), "Chunk scene must expose get_lod_signature()"):
		return
	if not T.require_true(self, chunk_scene.has_method("get_profile_signature"), "Chunk scene must expose get_profile_signature()"):
		return

	var contract: Dictionary = chunk_scene.get_lod_contract()
	if not T.require_true(self, contract.get("modes", []) == ["near", "mid", "far"], "LOD contract must expose near/mid/far modes"):
		return
	if not T.require_true(self, float(contract.get("near_threshold_m", 0.0)) >= 440.0, "Near LOD threshold must be expanded to at least double the previous range"):
		return
	if not T.require_true(self, float(contract.get("mid_threshold_m", 0.0)) >= 900.0, "Mid LOD threshold must be expanded to keep a broader natural transition band"):
		return
	if not T.require_true(self, chunk_scene.get_lod_signature("near") == chunk_scene.get_lod_signature("mid"), "Mid LOD must preserve the same silhouette signature as near LOD"):
		return
	if not T.require_true(self, chunk_scene.get_lod_signature("mid") == chunk_scene.get_lod_signature("far"), "Far LOD must preserve the same silhouette signature as near/mid LOD"):
		return

	chunk_scene.set_lod_mode("mid")
	if not T.require_true(self, chunk_scene.get_current_lod_mode() == "mid", "Chunk scene must switch to mid LOD"):
		return
	if not T.require_true(self, not chunk_scene.get_node("NearGroup").visible and chunk_scene.get_node("MidProxy").visible, "Mid LOD must hide NearGroup and show MidProxy"):
		return

	chunk_scene.set_lod_mode("far")
	if not T.require_true(self, chunk_scene.get_current_lod_mode() == "far", "Chunk scene must switch to far LOD"):
		return
	var near_group = chunk_scene.get_node("NearGroup")
	var far_proxy = chunk_scene.get_node("FarProxy")
	if not T.require_true(self, near_group.get_child_count() > 1, "NearGroup must contain multiple detailed children"):
		return
	if not T.require_true(self, far_proxy.get_child_count() <= 1, "FarProxy must be a simplified proxy, not a duplicated near tree"):
		return

	chunk_scene.queue_free()
	T.pass_and_quit(self)
