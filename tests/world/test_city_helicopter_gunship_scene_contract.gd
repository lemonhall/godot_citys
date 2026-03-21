extends SceneTree

const T := preload("res://tests/_test_util.gd")
const GUNSHIP_SCENE_PATH := "res://city_game/combat/helicopter/CityHelicopterGunship.tscn"
const GUNSHIP_SCRIPT_PATH := "res://city_game/combat/helicopter/CityHelicopterGunship.gd"
const GUNSHIP_MODEL_PATH := "res://city_game/assets/environment/source/aircraft/helicopter_a.glb"
const ROTOR_BLUR_SHADER_PATH := "res://city_game/combat/helicopter/CityHelicopterRotorBlur.gdshader"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(GUNSHIP_SCENE_PATH, "PackedScene"), "Helicopter gunship contract requires a dedicated authored .tscn scene instead of script-only visuals"):
		return
	if not T.require_true(self, ResourceLoader.exists(GUNSHIP_SCRIPT_PATH, "Script"), "Helicopter gunship contract requires a dedicated runtime script alongside the scene wrapper"):
		return
	if not T.require_true(self, ResourceLoader.exists(GUNSHIP_MODEL_PATH, "PackedScene"), "Helicopter gunship contract requires the formal helicopter_a.glb source asset"):
		return
	if not T.require_true(self, ResourceLoader.exists(ROTOR_BLUR_SHADER_PATH, "Shader"), "Helicopter gunship contract requires a dedicated rotor blur shader for the cheap spinning-rotor illusion"):
		return

	var scene_text := FileAccess.get_file_as_string(GUNSHIP_SCENE_PATH)
	if not T.require_true(self, scene_text.find(GUNSHIP_MODEL_PATH) >= 0, "Helicopter gunship scene must wrap helicopter_a.glb through the .tscn instead of creating visuals in code"):
		return
	if not T.require_true(self, scene_text.find("[node name=\"DebugHitboxPreview\"") >= 0, "Helicopter gunship scene must author a dedicated DebugHitboxPreview box for editor-side hit volume inspection"):
		return
	if not T.require_true(self, scene_text.find("editor_only = true") >= 0, "Helicopter gunship debug hitbox preview must be editor_only so it never leaks into runtime gameplay"):
		return
	if not T.require_true(self, scene_text.find("albedo_color = Color(1, 0, 0") >= 0 or scene_text.find("albedo_color = Color(1.0, 0.0, 0.0") >= 0, "Helicopter gunship debug hitbox preview must use a red material for quick visual inspection in the editor"):
		return
	if not T.require_true(self, scene_text.find("[node name=\"RotorBlurDebugPreview\"") >= 0, "Helicopter gunship scene must author a dedicated RotorBlurDebugPreview mesh so rotor blur placement can be tuned visually in the editor"):
		return
	if not T.require_true(self, scene_text.find("RotorBlurDebugPreview") >= 0 and scene_text.find("editor_only = true", scene_text.find("RotorBlurDebugPreview")) >= 0, "Helicopter gunship RotorBlurDebugPreview must stay editor_only so the authored guide mesh never leaks into runtime gameplay"):
		return
	if not T.require_true(self, scene_text.find(ROTOR_BLUR_SHADER_PATH) >= 0, "Helicopter gunship scene must author the rotor blur shader through the scene instead of building it from code"):
		return

	var scene := load(GUNSHIP_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Helicopter gunship scene contract must load CityHelicopterGunship.tscn as PackedScene"):
		return

	var gunship := scene.instantiate() as CharacterBody3D
	if not T.require_true(self, gunship != null, "Helicopter gunship scene contract must instantiate as CharacterBody3D so future hit detection and air movement share one root"):
		return

	root.add_child(gunship)
	await process_frame

	for required_node_path in [
		"CollisionShape3D",
		"ModelRoot",
		"ModelRoot/HelicopterModel",
		"Anchors",
		"Anchors/BodyCenter",
		"Anchors/GunMuzzle",
		"Anchors/MissileMuzzleLeft",
		"Anchors/MissileMuzzleRight",
		"Anchors/DamageSmokeAnchor",
		"Anchors/RotorHub",
		"RotorBlurRoot",
		"RotorBlurRoot/MainRotorBlur",
	]:
		if not T.require_true(self, gunship.get_node_or_null(required_node_path) != null, "Helicopter gunship scene must author %s in the scene hierarchy" % required_node_path):
			return

	var collision_shape := gunship.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not T.require_true(self, collision_shape != null and collision_shape.shape is BoxShape3D, "Helicopter gunship scene contract requires a BoxShape3D hit volume on the root collision shape"):
		return
	if not T.require_true(self, gunship.get_node_or_null("DebugHitboxPreview") == null, "Helicopter gunship debug hitbox preview must stay absent at runtime because it is editor-only inspection geometry"):
		return
	if not T.require_true(self, gunship.get_node_or_null("RotorBlurRoot/RotorBlurDebugPreview") == null, "Helicopter gunship rotor blur debug preview must stay absent at runtime because it is editor-only inspection geometry"):
		return
	var hitbox := collision_shape.shape as BoxShape3D
	if not T.require_true(self, hitbox.size.z >= 30.0, "Helicopter gunship hit volume must sync to the larger whole-body rectangular envelope tuned in the editor preview"):
		return
	if not T.require_true(self, hitbox.size.x >= 10.0, "Helicopter gunship hit volume must be wide enough to box in the full body and both side pylons"):
		return
	if not T.require_true(self, hitbox.size.y >= 4.0, "Helicopter gunship hit volume must be tall enough to box in the whole helicopter body rather than only a thin midline slice"):
		return
	if not T.require_true(self, collision_shape.position.z <= -2.0, "Helicopter gunship hit volume center must also sync to the tuned preview offset instead of keeping the old runtime position"):
		return

	for required_method in [
		"get_visual_root",
		"get_health_state",
		"get_debug_state",
		"apply_projectile_hit",
		"get_gun_muzzle_world_position",
		"get_missile_muzzle_world_positions",
	]:
		if not T.require_true(self, gunship.has_method(required_method), "Helicopter gunship root must expose %s() for runtime and focused tests" % required_method):
			return

	var visual_root := gunship.get_visual_root() as Node3D
	if not T.require_true(self, visual_root != null and visual_root.name == "ModelRoot", "Helicopter gunship contract must expose the authored ModelRoot as the visual root"):
		return

	var main_rotor_blur := gunship.get_node_or_null("RotorBlurRoot/MainRotorBlur") as MeshInstance3D
	if not T.require_true(self, main_rotor_blur != null, "Helicopter gunship scene must mount a dedicated MainRotorBlur mesh instance for the cheap spinning illusion"):
		return
	if not T.require_true(self, main_rotor_blur.material_override is ShaderMaterial, "Helicopter gunship MainRotorBlur must use a ShaderMaterial instead of static opaque geometry"):
		return
	if not T.require_true(self, main_rotor_blur.mesh is QuadMesh, "Helicopter gunship MainRotorBlur must stay a cheap QuadMesh disc instead of heavier geometry"):
		return
	var rotor_blur_mesh := main_rotor_blur.mesh as QuadMesh
	if not T.require_true(self, rotor_blur_mesh.size.x >= 11.0 and rotor_blur_mesh.size.y >= 11.0, "Helicopter gunship MainRotorBlur must be large enough to visibly cover the rotor sweep in gameplay, not just a tiny disc at the hub"):
		return
	if not T.require_true(self, main_rotor_blur.position.y >= 2.05, "Helicopter gunship MainRotorBlur must sit slightly above the static rotor plane to avoid disappearing into the source mesh"):
		return
	var rotor_shader_material := main_rotor_blur.material_override as ShaderMaterial
	if not T.require_true(self, rotor_shader_material.shader != null and rotor_shader_material.shader.resource_path == ROTOR_BLUR_SHADER_PATH, "Helicopter gunship MainRotorBlur must point at the dedicated rotor blur shader resource"):
		return
	var blur_color: Color = rotor_shader_material.get_shader_parameter("blur_color")
	if not T.require_true(self, blur_color.a >= 0.4, "Helicopter gunship MainRotorBlur must use a stronger visible alpha because the subtle dark disc disappears against the sky and body silhouette"):
		return

	var missile_muzzles: Array = gunship.get_missile_muzzle_world_positions()
	if not T.require_true(self, missile_muzzles.size() == 2, "Helicopter gunship contract must expose left/right missile muzzle anchors through the runtime API"):
		return
	if not T.require_true(self, missile_muzzles[0] is Vector3 and missile_muzzles[1] is Vector3, "Helicopter gunship missile muzzle API must return Vector3 world positions"):
		return
	if not T.require_true(self, (missile_muzzles[0] as Vector3).distance_to(missile_muzzles[1] as Vector3) > 0.5, "Helicopter gunship left/right missile muzzles must not collapse to the same point"):
		return

	var gun_muzzle: Variant = gunship.get_gun_muzzle_world_position()
	if not T.require_true(self, gun_muzzle is Vector3, "Helicopter gunship gun muzzle API must expose a Vector3 world position"):
		return

	var health_state: Dictionary = gunship.get_health_state()
	if not T.require_true(self, float(health_state.get("max", 0.0)) >= 160.0, "Helicopter gunship scene contract must freeze a health pool large enough to survive ten player missiles"):
		return
	if not T.require_true(self, bool(health_state.get("alive", false)), "Fresh helicopter gunship instances must begin alive"):
		return

	var debug_state: Dictionary = gunship.get_debug_state()
	if not T.require_true(self, str(debug_state.get("model_scene_path", "")) == GUNSHIP_MODEL_PATH, "Debug state must preserve the wrapped helicopter model path"):
		return

	gunship.queue_free()
	await process_frame
	T.pass_and_quit(self)
