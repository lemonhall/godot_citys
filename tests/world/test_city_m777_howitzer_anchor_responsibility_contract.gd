extends SceneTree

const T := preload("res://tests/_test_util.gd")

const HOWITZER_SCENE_PATH := "res://city_game/combat/artillery/CityM777Howitzer.tscn"
const FX_SHIFT := Vector3(0.23, -0.11, 0.07)
const BALLISTICS_SHIFT := Vector3(-0.19, 0.09, -0.13)
const LANYARD_SHIFT := Vector3(0.05, 0.02, -0.04)
const AUDIO_SHIFT := Vector3(-0.03, 0.06, 0.05)
const POSITION_TOLERANCE_M := 0.01

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(HOWITZER_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "M777 anchor responsibility contract requires the formal howitzer scene"):
		return

	var howitzer := scene.instantiate() as Node3D
	if not T.require_true(self, howitzer != null and howitzer.has_method("get_firing_solution_snapshot"), "M777 anchor responsibility contract must instantiate the formal howitzer runtime"):
		return

	root.add_child(howitzer)
	await process_frame
	await process_frame

	var muzzle_anchor := howitzer.get_node_or_null("Anchors/MuzzleFxAnchor") as Marker3D
	var muzzle_ballistics_anchor := howitzer.get_node_or_null("Anchors/MuzzleBallisticsAnchor") as Marker3D
	var lanyard_anchor := howitzer.get_node_or_null("Anchors/LanyardAnchor") as Marker3D
	var fire_audio_anchor := howitzer.get_node_or_null("Anchors/FireAudioAnchor") as Marker3D
	var muzzle_fx_rig := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/MuzzleFxRig") as Node3D
	var flash_burst := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/MuzzleFxRig/FlashBurst") as Node3D
	var smoke_burst := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/MuzzleFxRig/SmokeBurst") as Node3D
	var muzzle_ballistics_probe := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/MuzzleBallisticsProbe") as Node3D
	var lanyard := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/Lanyard") as Node3D
	var fire_audio := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/FireAudio") as Node3D
	if not T.require_true(self, muzzle_anchor != null and muzzle_ballistics_anchor != null and lanyard_anchor != null and fire_audio_anchor != null and muzzle_fx_rig != null and flash_burst != null and smoke_burst != null and muzzle_ballistics_probe != null and lanyard != null and fire_audio != null, "M777 anchor responsibility contract requires the dedicated authored anchors and rebuilt runtime attachment nodes"):
		return

	var baseline_fx_rig_world_position := muzzle_fx_rig.global_position
	var baseline_flash_world_position := flash_burst.global_position
	var baseline_smoke_world_position := smoke_burst.global_position
	var baseline_ballistics_world_position := muzzle_ballistics_probe.global_position
	var baseline_lanyard_world_position := lanyard.global_position
	var baseline_audio_world_position := fire_audio.global_position
	var baseline_solution := howitzer.get_firing_solution_snapshot() as Dictionary
	var baseline_origin_world_position := baseline_solution.get("origin_world_position", Vector3.ZERO) as Vector3

	muzzle_anchor.position += FX_SHIFT
	howitzer.call("_sync_fire_presentation_from_anchors")
	await process_frame
	var fx_shifted_rig_world_position := muzzle_fx_rig.global_position
	var fx_shifted_flash_world_position := flash_burst.global_position
	var fx_shifted_smoke_world_position := smoke_burst.global_position
	var fx_shifted_ballistics_world_position := muzzle_ballistics_probe.global_position
	var fx_shifted_solution := howitzer.get_firing_solution_snapshot() as Dictionary
	var fx_shifted_origin_world_position := fx_shifted_solution.get("origin_world_position", Vector3.ZERO) as Vector3
	if not T.require_true(self, fx_shifted_rig_world_position.distance_to(baseline_fx_rig_world_position) > 0.05 and fx_shifted_flash_world_position.distance_to(baseline_flash_world_position) > 0.05 and fx_shifted_smoke_world_position.distance_to(baseline_smoke_world_position) > 0.05, "Changing MuzzleFxAnchor must visibly move the rebuilt FX rig and both burst nodes instead of being ignored by runtime"):
		return
	if not T.require_true(self, fx_shifted_ballistics_world_position.distance_to(baseline_ballistics_world_position) <= POSITION_TOLERANCE_M, "Changing MuzzleFxAnchor must not drag the ballistic probe with it; FX and ballistics must be decoupled"):
		return
	if not T.require_true(self, fx_shifted_origin_world_position.distance_to(baseline_origin_world_position) <= POSITION_TOLERANCE_M, "Changing MuzzleFxAnchor must not mutate the formal ballistic origin because the FX anchor is visual-only"):
		return

	muzzle_ballistics_anchor.position += BALLISTICS_SHIFT
	howitzer.call("_sync_fire_presentation_from_anchors")
	await process_frame
	var ballistics_shifted_rig_world_position := muzzle_fx_rig.global_position
	var ballistics_shifted_probe_world_position := muzzle_ballistics_probe.global_position
	var ballistics_shifted_solution := howitzer.get_firing_solution_snapshot() as Dictionary
	var ballistics_shifted_origin_world_position := ballistics_shifted_solution.get("origin_world_position", Vector3.ZERO) as Vector3
	if not T.require_true(self, ballistics_shifted_rig_world_position.distance_to(fx_shifted_rig_world_position) <= POSITION_TOLERANCE_M, "Changing MuzzleBallisticsAnchor must not drag MuzzleFxRig away from the authored FX anchor"):
		return
	if not T.require_true(self, ballistics_shifted_probe_world_position.distance_to(fx_shifted_ballistics_world_position) > 0.05, "Changing MuzzleBallisticsAnchor must move the ballistic probe instead of being ignored"):
		return
	if not T.require_true(self, ballistics_shifted_origin_world_position.distance_to(fx_shifted_origin_world_position) > 0.05, "Changing MuzzleBallisticsAnchor must move the formal ballistic origin instead of leaving solver state frozen to the FX anchor"):
		return

	lanyard_anchor.position += LANYARD_SHIFT
	howitzer.call("_sync_fire_presentation_from_anchors")
	await process_frame
	var lanyard_shifted_lanyard_world_position := lanyard.global_position
	var lanyard_shifted_audio_world_position := fire_audio.global_position
	if not T.require_true(self, lanyard_shifted_lanyard_world_position.distance_to(baseline_lanyard_world_position) > 0.03, "Changing LanyardAnchor must move the rope attachment instead of being ignored"):
		return
	if not T.require_true(self, lanyard_shifted_audio_world_position.distance_to(baseline_audio_world_position) <= POSITION_TOLERANCE_M, "Changing LanyardAnchor must not drag FireAudio with it; rope and audio anchors must be decoupled"):
		return

	fire_audio_anchor.position += AUDIO_SHIFT
	howitzer.call("_sync_fire_presentation_from_anchors")
	await process_frame
	var audio_shifted_lanyard_world_position := lanyard.global_position
	var audio_shifted_audio_world_position := fire_audio.global_position
	if not T.require_true(self, audio_shifted_lanyard_world_position.distance_to(lanyard_shifted_lanyard_world_position) <= POSITION_TOLERANCE_M, "Changing FireAudioAnchor must not move the lanyard attachment point"):
		return
	if not T.require_true(self, audio_shifted_audio_world_position.distance_to(lanyard_shifted_audio_world_position) > 0.03, "Changing FireAudioAnchor must move the shot audio origin instead of still following the lanyard anchor"):
		return

	howitzer.queue_free()
	await process_frame
	T.pass_and_quit(self)
