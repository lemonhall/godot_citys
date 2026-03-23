extends SceneTree

const T := preload("res://tests/_test_util.gd")
const DRONE_SCENE_PATH := "res://city_game/combat/drone/CityDroneGunship.tscn"
const SHARED_GUNSHIP_SCRIPT_PATH := "res://city_game/combat/helicopter/CityHelicopterGunship.gd"
const DRONE_MODEL_PATH := "res://city_game/assets/environment/source/aircraft/drone_a.glb"
const ROTOR_BLUR_SHADER_PATH := "res://city_game/combat/helicopter/CityHelicopterRotorBlur.gdshader"

const REQUIRED_NODE_PATHS := [
	"CollisionShape3D",
	"ModelRoot",
	"ModelRoot/DroneModel",
	"Anchors",
	"Anchors/BodyCenter",
	"Anchors/GunMuzzle",
	"Anchors/MissileMuzzleLeft",
	"Anchors/MissileMuzzleRight",
	"Anchors/DamageSmokeAnchor",
	"RotorBlurRoot",
	"RotorBlurRoot/FrontLeftRotorBlur",
	"RotorBlurRoot/FrontRightRotorBlur",
	"RotorBlurRoot/RearLeftRotorBlur",
	"RotorBlurRoot/RearRightRotorBlur",
	"DeathFxRoot",
	"DeathFxRoot/ExplosionRing",
	"DeathFxRoot/ExplosionSphere",
	"RotorAudio",
	"MissileFireAudio",
]

const REQUIRED_ROTOR_BLUR_PATHS := [
	"RotorBlurRoot/FrontLeftRotorBlur",
	"RotorBlurRoot/FrontRightRotorBlur",
	"RotorBlurRoot/RearLeftRotorBlur",
	"RotorBlurRoot/RearRightRotorBlur",
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(DRONE_SCENE_PATH, "PackedScene"), "Drone gunship contract requires a dedicated authored .tscn scene"):
		return
	if not T.require_true(self, ResourceLoader.exists(SHARED_GUNSHIP_SCRIPT_PATH, "Script"), "Drone gunship contract requires the shared helicopter gunship runtime script to stay available for reuse"):
		return
	if not T.require_true(self, ResourceLoader.exists(DRONE_MODEL_PATH, "PackedScene"), "Drone gunship contract requires the formal drone_a.glb source asset"):
		return
	if not T.require_true(self, ResourceLoader.exists(ROTOR_BLUR_SHADER_PATH, "Shader"), "Drone gunship contract requires the shared helicopter rotor blur shader for all four rotors"):
		return

	var scene_text := FileAccess.get_file_as_string(DRONE_SCENE_PATH)
	if not T.require_true(self, scene_text.find(SHARED_GUNSHIP_SCRIPT_PATH) >= 0, "Drone gunship scene must reuse CityHelicopterGunship.gd instead of forking runtime logic"):
		return
	if not T.require_true(self, scene_text.find(DRONE_MODEL_PATH) >= 0, "Drone gunship scene must wrap drone_a.glb through the authored .tscn"):
		return
	if not T.require_true(self, scene_text.find(ROTOR_BLUR_SHADER_PATH) >= 0, "Drone gunship scene must bind the shared rotor blur shader through the scene"):
		return

	var scene := load(DRONE_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Drone gunship scene contract must load CityDroneGunship.tscn as PackedScene"):
		return

	var drone := scene.instantiate() as CharacterBody3D
	if not T.require_true(self, drone != null, "Drone gunship scene must instantiate as CharacterBody3D so it can reuse the helicopter combat runtime directly"):
		return

	root.add_child(drone)
	await process_frame

	if not T.require_true(self, drone.get_script() != null and drone.get_script().resource_path == SHARED_GUNSHIP_SCRIPT_PATH, "Drone gunship root must directly reuse CityHelicopterGunship.gd"):
		return

	for node_path in REQUIRED_NODE_PATHS:
		if not T.require_true(self, drone.get_node_or_null(node_path) != null, "Drone gunship scene must author %s in the scene hierarchy" % node_path):
			return

	var collision_shape := drone.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not T.require_true(self, collision_shape != null and collision_shape.shape is BoxShape3D, "Drone gunship scene contract requires a BoxShape3D hit volume on the root collision shape"):
		return
	var hitbox := collision_shape.shape as BoxShape3D
	if not T.require_true(self, hitbox.size.x >= 1.0 and hitbox.size.y >= 0.4 and hitbox.size.z >= 1.0, "Drone gunship hit volume must cover the drone body with a non-trivial envelope"):
		return

	var rotor_positions: Array[Vector3] = []
	for rotor_path in REQUIRED_ROTOR_BLUR_PATHS:
		var rotor_blur := drone.get_node_or_null(rotor_path) as MeshInstance3D
		if not T.require_true(self, rotor_blur != null, "Drone gunship scene must author %s as a MeshInstance3D" % rotor_path):
			return
		if not T.require_true(self, rotor_blur.mesh is QuadMesh, "Drone gunship rotor blur %s must stay a cheap QuadMesh disc" % rotor_path):
			return
		if not T.require_true(self, rotor_blur.material_override is ShaderMaterial, "Drone gunship rotor blur %s must use a ShaderMaterial" % rotor_path):
			return
		var rotor_mesh := rotor_blur.mesh as QuadMesh
		if not T.require_true(self, rotor_mesh.size.x >= 0.45 and rotor_mesh.size.y >= 0.45, "Drone gunship rotor blur %s must stay visibly wide enough to read in motion" % rotor_path):
			return
		var rotor_material := rotor_blur.material_override as ShaderMaterial
		if not T.require_true(self, rotor_material.shader != null and rotor_material.shader.resource_path == ROTOR_BLUR_SHADER_PATH, "Drone gunship rotor blur %s must point at the shared helicopter rotor blur shader resource" % rotor_path):
			return
		var blur_color: Color = rotor_material.get_shader_parameter("blur_color")
		if not T.require_true(self, blur_color.a >= 0.3, "Drone gunship rotor blur %s must keep enough alpha to read as spinning rotors in gameplay" % rotor_path):
			return
		rotor_positions.append(rotor_blur.global_position)

	for rotor_index in range(rotor_positions.size()):
		for other_index in range(rotor_index + 1, rotor_positions.size()):
			if not T.require_true(self, rotor_positions[rotor_index].distance_to(rotor_positions[other_index]) >= 0.25, "Drone gunship rotor blur discs must stay separated instead of collapsing into a single center rotor"):
				return

	if not T.require_true(self, drone.has_method("get_visual_root"), "Drone gunship root must expose the shared helicopter visual root API"):
		return
	if not T.require_true(self, drone.has_method("get_missile_muzzle_world_positions"), "Drone gunship root must expose the shared helicopter missile muzzle API"):
		return
	if not T.require_true(self, drone.has_method("apply_projectile_hit"), "Drone gunship root must expose the shared helicopter hit handling API"):
		return

	drone.queue_free()
	await process_frame
	T.pass_and_quit(self)
