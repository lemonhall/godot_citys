extends SceneTree

const T := preload("res://tests/_test_util.gd")
const DRONE_SCENE_PATH := "res://city_game/combat/drone/CityDroneGunship.tscn"
const DRONE_RUNTIME_SCRIPT_PATH := "res://city_game/combat/drone/CityPlayerDroneRuntime.gd"
const HELICOPTER_GUNSHIP_SCRIPT_PATH := "res://city_game/combat/helicopter/CityHelicopterGunship.gd"
const DRONE_FLIGHT_CONTROLLER_PATH := "res://city_game/combat/drone/CityPlayerDroneFlightController.gd"
const DRONE_CAMERA_RIG_SCENE_PATH := "res://city_game/combat/drone/CityPlayerDroneCameraRig.tscn"
const DRONE_MODEL_PATH := "res://city_game/assets/environment/source/aircraft/drone_a.glb"
const ROTOR_BLUR_SHADER_PATH := "res://city_game/combat/helicopter/CityHelicopterRotorBlur.gdshader"
const DRONE_FLIGHT_AUDIO_PATH := "res://city_game/combat/drone/audio/drone-in-flight.wav"
const DRONE_FPV_OVERLAY_SHADER_PATH := "res://city_game/combat/drone/shaders/CityDroneFpvInfraredOverlay.gdshader"

const REQUIRED_NODE_PATHS := [
	"CollisionShape3D",
	"ModelRoot",
	"ModelRoot/DroneModel",
	"Anchors",
	"Anchors/BodyCenter",
	"RotorBlurRoot",
	"RotorBlurRoot/FrontLeftRotorBlur",
	"RotorBlurRoot/FrontRightRotorBlur",
	"RotorBlurRoot/RearLeftRotorBlur",
	"RotorBlurRoot/RearRightRotorBlur",
	"CameraRig",
	"CameraRig/ThirdPersonPose",
	"CameraRig/FpvPivot",
	"CameraRig/FpvPivot/FpvPose",
	"CameraRig/Camera3D",
	"FpvOverlay",
	"FpvOverlay/InfraredRect",
	"RotorAudio",
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
	if not T.require_true(self, ResourceLoader.exists(DRONE_SCENE_PATH, "PackedScene"), "Drone foundation contract requires a dedicated authored CityDroneGunship.tscn scene"):
		return
	if not T.require_true(self, ResourceLoader.exists(DRONE_RUNTIME_SCRIPT_PATH, "Script"), "Drone foundation contract requires CityPlayerDroneRuntime.gd under combat/drone"):
		return
	if not T.require_true(self, ResourceLoader.exists(DRONE_FLIGHT_CONTROLLER_PATH, "Script"), "Drone foundation contract requires CityPlayerDroneFlightController.gd under combat/drone"):
		return
	if not T.require_true(self, ResourceLoader.exists(DRONE_CAMERA_RIG_SCENE_PATH, "PackedScene"), "Drone foundation contract requires a dedicated drone chase-camera rig scene"):
		return
	if not T.require_true(self, ResourceLoader.exists(DRONE_MODEL_PATH, "PackedScene"), "Drone foundation contract requires the formal drone_a.glb source asset"):
		return
	if not T.require_true(self, ResourceLoader.exists(ROTOR_BLUR_SHADER_PATH, "Shader"), "Drone foundation contract requires the shared rotor blur shader resource for all four rotors"):
		return
	if not T.require_true(self, ResourceLoader.exists(DRONE_FLIGHT_AUDIO_PATH, "AudioStreamWAV"), "Drone foundation contract requires the formal looped in-flight audio asset under combat/drone/audio"):
		return
	if not T.require_true(self, ResourceLoader.exists(DRONE_FPV_OVERLAY_SHADER_PATH, "Shader"), "Drone scene contract requires the formal FPV infrared overlay shader resource"):
		return

	var scene_text := FileAccess.get_file_as_string(DRONE_SCENE_PATH)
	if not T.require_true(self, scene_text.find(DRONE_RUNTIME_SCRIPT_PATH) >= 0, "Drone scene must bind CityPlayerDroneRuntime.gd instead of a helicopter combat script"):
		return
	if not T.require_true(self, scene_text.find(HELICOPTER_GUNSHIP_SCRIPT_PATH) < 0, "Drone scene must not keep any direct CityHelicopterGunship.gd reference after v42 runtime split"):
		return
	if not T.require_true(self, scene_text.find(DRONE_CAMERA_RIG_SCENE_PATH) >= 0, "Drone scene must mount the dedicated drone chase-camera rig scene through CityDroneGunship.tscn"):
		return
	if not T.require_true(self, scene_text.find(DRONE_MODEL_PATH) >= 0, "Drone scene must wrap drone_a.glb through the authored .tscn"):
		return
	if not T.require_true(self, scene_text.find(ROTOR_BLUR_SHADER_PATH) >= 0, "Drone scene must bind the shared rotor blur shader through the scene instead of rebuilding it from code"):
		return
	if not T.require_true(self, scene_text.find(DRONE_FLIGHT_AUDIO_PATH) >= 0, "Drone scene must bind the formal looped in-flight audio asset through RotorAudio"):
		return
	if not T.require_true(self, scene_text.find(DRONE_FPV_OVERLAY_SHADER_PATH) >= 0, "Drone scene must bind the formal FPV infrared overlay shader through the authored scene"):
		return

	var scene := load(DRONE_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Drone foundation contract must load CityDroneGunship.tscn as a PackedScene"):
		return

	var drone := scene.instantiate() as CharacterBody3D
	if not T.require_true(self, drone != null, "Drone foundation contract must instantiate the player drone as CharacterBody3D"):
		return

	root.add_child(drone)
	await process_frame

	var runtime_script := drone.get_script() as Script
	if not T.require_true(self, runtime_script != null and str(runtime_script.resource_path) == DRONE_RUNTIME_SCRIPT_PATH, "Drone scene root must point at CityPlayerDroneRuntime.gd under combat/drone"):
		return

	for node_path in REQUIRED_NODE_PATHS:
		if not T.require_true(self, drone.get_node_or_null(node_path) != null, "Drone scene contract must author %s in the runtime hierarchy" % node_path):
			return

	var collision_shape := drone.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not T.require_true(self, collision_shape != null and collision_shape.shape is BoxShape3D, "Drone foundation contract requires a BoxShape3D hit volume on the root collision shape"):
		return
	var hitbox := collision_shape.shape as BoxShape3D
	if not T.require_true(self, hitbox.size.x >= 1.0 and hitbox.size.y >= 0.4 and hitbox.size.z >= 1.0, "Drone hit volume must cover the body with a non-trivial collision envelope"):
		return

	var rotor_audio := drone.get_node_or_null("RotorAudio") as AudioStreamPlayer3D
	if not T.require_true(self, rotor_audio != null and rotor_audio.stream != null, "Drone foundation contract requires RotorAudio to carry the formal in-flight hum stream"):
		return
	if not T.require_true(self, str(rotor_audio.stream.resource_path) == DRONE_FLIGHT_AUDIO_PATH, "Drone RotorAudio must point at the formal combat/drone audio asset instead of an ad-hoc root-level file"):
		return

	var fpv_overlay_rect := drone.get_node_or_null("FpvOverlay/InfraredRect") as ColorRect
	if not T.require_true(self, fpv_overlay_rect != null and fpv_overlay_rect.material is ShaderMaterial, "Drone scene contract requires an authored InfraredRect ColorRect with ShaderMaterial"):
		return
	var fpv_overlay_material := fpv_overlay_rect.material as ShaderMaterial
	if not T.require_true(self, fpv_overlay_material.shader != null and fpv_overlay_material.shader.resource_path == DRONE_FPV_OVERLAY_SHADER_PATH, "Drone InfraredRect must point at the formal combat/drone FPV overlay shader resource"):
		return

	var rotor_positions: Array[Vector3] = []
	for rotor_path in REQUIRED_ROTOR_BLUR_PATHS:
		var rotor_blur := drone.get_node_or_null(rotor_path) as MeshInstance3D
		if not T.require_true(self, rotor_blur != null, "Drone scene contract must author %s as a MeshInstance3D blur disc" % rotor_path):
			return
		if not T.require_true(self, rotor_blur.mesh is QuadMesh, "Drone rotor blur %s must stay a cheap QuadMesh disc" % rotor_path):
			return
		if not T.require_true(self, rotor_blur.material_override is ShaderMaterial, "Drone rotor blur %s must use a ShaderMaterial" % rotor_path):
			return
		var rotor_material := rotor_blur.material_override as ShaderMaterial
		if not T.require_true(self, rotor_material.shader != null and rotor_material.shader.resource_path == ROTOR_BLUR_SHADER_PATH, "Drone rotor blur %s must point at the shared helicopter rotor blur shader resource" % rotor_path):
			return
		rotor_positions.append(rotor_blur.global_position)

	for rotor_index in range(rotor_positions.size()):
		for other_index in range(rotor_index + 1, rotor_positions.size()):
			if not T.require_true(self, rotor_positions[rotor_index].distance_to(rotor_positions[other_index]) >= 0.25, "Drone rotor blur discs must stay separated instead of collapsing toward a fake single-rotor center"):
				return

	for required_method in [
		"get_visual_root",
		"get_crosshair_state",
		"get_debug_state",
		"get_portability_contract",
	]:
		if not T.require_true(self, drone.has_method(required_method), "Drone runtime root must expose %s() for runtime integration and focused tests" % required_method):
			return

	drone.queue_free()
	await process_frame
	T.pass_and_quit(self)
