extends SceneTree

const T := preload("res://tests/_test_util.gd")

const HOWITZER_SCENE_PATH := "res://city_game/combat/artillery/CityM777Howitzer.tscn"
const FIRE_AUDIO_PATH := "res://city_game/combat/helicopter/audio/rockt-explosions.wav"
const EXPECTED_FIRE_COOLDOWN_SEC := 6.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(HOWITZER_SCENE_PATH, "PackedScene"), "M777 fire contract requires the formal howitzer scene"):
		return
	if not T.require_true(self, FileAccess.file_exists(FIRE_AUDIO_PATH) or ResourceLoader.exists(FIRE_AUDIO_PATH, "AudioStreamWAV"), "M777 fire contract requires the frozen formal weapon fire audio asset"):
		return

	var scene := load(HOWITZER_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "M777 fire contract must load the formal howitzer PackedScene"):
		return

	var howitzer := scene.instantiate() as Node3D
	if not T.require_true(self, howitzer != null, "M777 fire contract must instantiate the formal howitzer runtime"):
		return

	root.add_child(howitzer)
	await process_frame
	await process_frame

	var muzzle_flash := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/MuzzleFlash") as Node3D
	var muzzle_smoke := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/MuzzleSmoke") as Node3D
	var lanyard := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/Lanyard") as MeshInstance3D
	var fire_audio := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/FireAudio") as AudioStreamPlayer3D
	var gun_assembly := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot/m777_gun_assembly") as Node3D
	if not T.require_true(self, muzzle_flash != null and muzzle_smoke != null and lanyard != null and fire_audio != null and gun_assembly != null, "M777 fire contract requires authored formal fire presentation nodes in the howitzer scene"):
		return
	if not T.require_true(self, fire_audio.stream != null and fire_audio.stream.resource_path == FIRE_AUDIO_PATH, "M777 fire contract requires FireAudio to bind the frozen current artillery weapon fire stream"):
		return
	if not T.require_true(self, not fire_audio.autoplay, "M777 FireAudio must stay event-driven and not autoplay on spawn"):
		return

	var fire_state_before := howitzer.get_fire_state() as Dictionary
	if not T.require_true(self, bool(fire_state_before.get("can_fire", false)), "Fresh howitzer runtime must start ready to fire"):
		return
	if not T.require_true(self, absf(float(fire_state_before.get("cooldown_duration_sec", 0.0)) - EXPECTED_FIRE_COOLDOWN_SEC) <= 0.001, "Howitzer fire contract must freeze the default cooldown at 6.0 seconds"):
		return
	var fire_count_before := int(fire_state_before.get("fire_count", 0))
	var node_count_before := _count_descendants(howitzer)
	var gun_position_before := gun_assembly.position

	var fire_result := howitzer.request_fire() as Dictionary
	if not T.require_true(self, bool(fire_result.get("accepted", false)), "Howitzer fire contract must accept request_fire() while cooldown is clear"):
		return

	await _advance_frames(4)

	var fire_state := howitzer.get_fire_state() as Dictionary
	if not T.require_true(self, not bool(fire_state.get("can_fire", true)), "Accepted howitzer fire must enter cooldown immediately"):
		return
	if not T.require_true(self, float(fire_state.get("cooldown_sec", 0.0)) > EXPECTED_FIRE_COOLDOWN_SEC * 0.7, "Accepted howitzer fire must report a substantial remaining cooldown right after the shot"):
		return
	if not T.require_true(self, int(fire_state.get("fire_count", 0)) == fire_count_before + 1, "Accepted howitzer fire must increment fire_count exactly once"):
		return
	if not T.require_true(self, bool(fire_state.get("muzzle_flash_active", false)), "Accepted howitzer fire must activate muzzle flash state"):
		return
	if not T.require_true(self, bool(fire_state.get("smoke_active", false)), "Accepted howitzer fire must activate muzzle smoke state"):
		return
	if not T.require_true(self, bool(fire_state.get("lanyard_tension_active", false)), "Accepted howitzer fire must activate lanyard tension state"):
		return
	if not T.require_true(self, bool(fire_state.get("recoil_active", false)), "Accepted howitzer fire must activate recoil state"):
		return
	if not T.require_true(self, int(fire_state.get("audio_trigger_count", 0)) >= 1, "Accepted howitzer fire must trigger formal weapon fire audio at least once"):
		return
	if not T.require_true(self, muzzle_flash.visible and muzzle_smoke.visible and lanyard.visible, "Accepted howitzer fire must visibly expose the authored fire presentation nodes instead of leaving them dormant"):
		return
	if not T.require_true(self, gun_assembly.position.distance_to(gun_position_before) > 0.0001, "Accepted howitzer fire must visibly offset the gun assembly for recoil instead of only mutating invisible debug state"):
		return
	if not T.require_true(self, _count_descendants(howitzer) == node_count_before, "Howitzer fire presentation must not spawn projectile / grenade / missile nodes; the authored node count should stay unchanged during the shot"):
		return

	var rejected_result := howitzer.request_fire() as Dictionary
	if not T.require_true(self, not bool(rejected_result.get("accepted", false)) and str(rejected_result.get("error", "")) == "cooldown_active", "Repeated howitzer fire requests during cooldown must be rejected with cooldown_active instead of replaying the shot"):
		return

	await _advance_frames(430)

	var recovered_fire_state := howitzer.get_fire_state() as Dictionary
	if not T.require_true(self, bool(recovered_fire_state.get("can_fire", false)), "Howitzer must become fire-ready again after the frozen cooldown window elapses"):
		return
	if not T.require_true(self, float(recovered_fire_state.get("cooldown_sec", 1.0)) <= 0.02, "Howitzer cooldown must decay back to zero after the fire window closes"):
		return
	if not T.require_true(self, not bool(recovered_fire_state.get("muzzle_flash_active", true)) and not bool(recovered_fire_state.get("smoke_active", true)) and not bool(recovered_fire_state.get("lanyard_tension_active", true)) and not bool(recovered_fire_state.get("recoil_active", true)), "Howitzer fire presentation states must clear back to idle once the shot finishes and cooldown closes"):
		return

	howitzer.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _advance_frames(frame_count: int) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame

func _count_descendants(node: Node) -> int:
	var total := 0
	for child in node.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		total += 1
		total += _count_descendants(child_node)
	return total
