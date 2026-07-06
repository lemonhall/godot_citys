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
	if not T.require_true(self, environment.background_color.is_equal_approx(Color(0.42, 0.76, 1.0, 1.0)), "Screenshot state must keep the bright blue toy sky"):
		return
	if not T.require_true(self, not environment.fog_enabled, "Screenshot state must disable gray fog"):
		return
	if not T.require_true(self, not environment.ssao_enabled and not environment.glow_enabled, "Screenshot state must avoid muddy SSAO/glow post effects"):
		return

	var sun := world.get_node_or_null("Sun") as DirectionalLight3D
	if not T.require_true(self, sun != null and sun.light_energy >= 2.4, "Screenshot state must keep the stronger toy sun"):
		return
	var fill := world.get_node_or_null("ToyFillLight") as DirectionalLight3D
	if not T.require_true(self, fill != null and fill.light_energy >= 0.7, "Screenshot state must keep the blue fill light"):
		return

	world.queue_free()
	T.pass_and_quit(self)
