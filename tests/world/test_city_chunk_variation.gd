extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var chunk_scene_script := load("res://city_game/world/rendering/CityChunkScene.gd")
	if chunk_scene_script == null:
		T.fail_and_quit(self, "Missing CityChunkScene.gd")
		return

	var config := CityWorldConfig.new()
	var scene_a = chunk_scene_script.new()
	var scene_a_clone = chunk_scene_script.new()
	var scene_b = chunk_scene_script.new()
	root.add_child(scene_a)
	root.add_child(scene_a_clone)
	root.add_child(scene_b)
	await process_frame

	scene_a.setup(_make_chunk_payload(config, Vector2i(13, 13)))
	scene_a_clone.setup(_make_chunk_payload(config, Vector2i(13, 13)))
	scene_b.setup(_make_chunk_payload(config, Vector2i(14, 13)))

	if not T.require_true(self, scene_a.has_method("get_profile_signature"), "Chunk scene must expose get_profile_signature()"):
		return
	if not T.require_true(self, scene_a.has_method("get_visual_variant_id"), "Chunk scene must expose get_visual_variant_id()"):
		return

	var signature_a := str(scene_a.get_profile_signature())
	var signature_a_clone := str(scene_a_clone.get_profile_signature())
	var signature_b := str(scene_b.get_profile_signature())
	if not T.require_true(self, signature_a == signature_a_clone, "Same chunk must reproduce the same profile signature"):
		return
	if not T.require_true(self, signature_a != signature_b, "Adjacent chunks must not reuse the exact same building profile"):
		return
	if not T.require_true(self, str(scene_a.get_visual_variant_id()) != "", "Chunk variation must expose a stable visual variant id"):
		return
	if not T.require_true(self, scene_a.has_method("get_building_archetype_ids"), "Chunk scene must expose get_building_archetype_ids() for diversity review"):
		return
	var archetypes_a: Array = scene_a.get_building_archetype_ids()
	var archetypes_b: Array = scene_b.get_building_archetype_ids()
	var combined_archetypes: Dictionary = {}
	for archetype_id in archetypes_a:
		combined_archetypes[str(archetype_id)] = true
	for archetype_id in archetypes_b:
		combined_archetypes[str(archetype_id)] = true
	if not T.require_true(self, combined_archetypes.size() >= 6, "Adjacent chunks must expose a broader set of building archetypes to reduce repetition"):
		return

	scene_a.queue_free()
	scene_a_clone.queue_free()
	scene_b.queue_free()
	T.pass_and_quit(self)

func _make_chunk_payload(config, chunk_key: Vector2i) -> Dictionary:
	return {
		"chunk_id": config.format_chunk_id(chunk_key),
		"chunk_key": chunk_key,
		"chunk_center": Vector3.ZERO,
		"chunk_size_m": float(config.chunk_size_m),
		"chunk_seed": config.derive_seed("render_chunk", chunk_key),
	}
