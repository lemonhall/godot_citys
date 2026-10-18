extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var shader := load("res://city_game/world/rendering/CityToonOutlinePostProcess.gdshader")
	if not T.require_true(self, shader != null, "Toon outline post-process shader must exist"):
		return
	var overlay_script := load("res://city_game/world/rendering/CityToonOutlineOverlay.gd")
	if not T.require_true(self, overlay_script != null, "Toon outline overlay script must exist"):
		return

	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if not T.require_true(self, scene is PackedScene, "CityPrototype scene must load"):
		return
	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var outline := world.get_node_or_null("ToonOutlineOverlay") as MeshInstance3D
	if not T.require_true(self, outline != null, "CityPrototype must include the full-screen toon outline overlay"):
		return
	if not T.require_true(self, outline.mesh is QuadMesh, "Toon outline overlay must render through a full-screen QuadMesh"):
		return
	if not T.require_true(self, outline.material_override is ShaderMaterial, "Toon outline overlay must use a ShaderMaterial"):
		return
	if not T.require_true(self, outline.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Toon outline overlay must not cast shadows"):
		return

	var environment_node := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if not T.require_true(self, environment_node != null and environment_node.environment != null, "CityPrototype must keep a configured world environment"):
		return
	var environment := environment_node.environment
	if not T.require_true(self, environment.sky != null, "v62 screenshot state must keep the procedural gradient sky"):
		return
	if not T.require_true(self, environment.background_mode == Environment.BG_SKY, "v62 screenshot state must render the sky instead of a flat clear color"):
		return
	if not T.require_true(self, environment.fog_enabled, "v62 screenshot state must keep distance haze for aerial perspective"):
		return
	if not T.require_true(self, environment.fog_aerial_perspective > 0.0, "v62 fog must tint distant buildings toward the sky"):
		return
	if not T.require_true(self, environment.ssao_enabled, "v62 screenshot state must keep ambient occlusion for street-level depth"):
		return
	if not T.require_true(self, not environment.glow_enabled, "v62 screenshot state must avoid muddy glow post effects"):
		return

	var sun := world.get_node_or_null("Sun") as DirectionalLight3D
	if not T.require_true(self, sun != null and sun.light_energy >= 2.4, "Screenshot state must keep the stronger toy sun"):
		return
	var fill := world.get_node_or_null("ToyFillLight") as DirectionalLight3D
	if not T.require_true(self, fill != null and fill.light_energy >= 0.7, "Screenshot state must keep the blue fill light"):
		return

	world.queue_free()
	T.pass_and_quit(self)
