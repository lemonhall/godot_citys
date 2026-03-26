extends Node3D

const EXPLOSION_AUDIO_PATH := "res://city_game/combat/helicopter/audio/rockt-explosions.wav"
const EXPLOSION_AUDIO_STREAM := preload("res://city_game/combat/helicopter/audio/rockt-explosions.wav")

@export var explosion_radius_m := 16.0
@export var explosion_effect_duration_sec := 0.72
@export var audio_enabled := true
@export var audio_volume_db := -1.5

var _elapsed_sec := 0.0
var _played := false
var _explosion_ring: MeshInstance3D = null
var _explosion_sphere: MeshInstance3D = null
var _explosion_audio: AudioStreamPlayer3D = null
var _audio_trigger_count := 0

func _ready() -> void:
	_ensure_nodes()

func configure(world_position: Vector3, radius_m: float, duration_sec: float) -> void:
	global_position = world_position
	explosion_radius_m = maxf(radius_m, 0.1)
	explosion_effect_duration_sec = maxf(duration_sec, 0.001)
	_elapsed_sec = 0.0
	_played = false
	_audio_trigger_count = 0
	_ensure_nodes()
	if _explosion_ring != null:
		_explosion_ring.visible = false
		_explosion_ring.scale = Vector3(0.36, 1.0, 0.36)
	if _explosion_sphere != null:
		_explosion_sphere.visible = false
		_explosion_sphere.scale = Vector3.ONE * 0.42
	if _explosion_audio != null:
		_explosion_audio.stop()

func play() -> void:
	if _played:
		return
	_played = true
	_ensure_nodes()
	if _explosion_ring != null:
		_explosion_ring.visible = true
		_explosion_ring.scale = Vector3(0.36, 1.0, 0.36)
	if _explosion_sphere != null:
		_explosion_sphere.visible = true
		_explosion_sphere.scale = Vector3.ONE * 0.42
	if audio_enabled and _explosion_audio != null and _explosion_audio.stream != null:
		_audio_trigger_count += 1
		_explosion_audio.play()

func get_debug_state() -> Dictionary:
	return {
		"played": _played,
		"ring_enabled": _explosion_ring != null and is_instance_valid(_explosion_ring),
		"sphere_enabled": _explosion_sphere != null and is_instance_valid(_explosion_sphere),
		"audio_trigger_count": _audio_trigger_count,
		"audio_stream_path": _explosion_audio.stream.resource_path if _explosion_audio != null and _explosion_audio.stream != null else "",
		"world_position": global_position,
		"radius_m": explosion_radius_m,
	}

func _process(delta: float) -> void:
	if not _played:
		return
	_elapsed_sec += maxf(delta, 0.0)
	var duration_sec := maxf(explosion_effect_duration_sec, 0.001)
	var progress := clampf(_elapsed_sec / duration_sec, 0.0, 1.0)
	if _explosion_ring != null:
		var ring_scale := lerpf(0.36, explosion_radius_m * 0.62, progress)
		_explosion_ring.scale = Vector3(ring_scale, 1.0, ring_scale)
		var ring_material := _explosion_ring.material_override as StandardMaterial3D
		if ring_material != null:
			ring_material.albedo_color.a = lerpf(0.76, 0.0, progress)
			ring_material.emission_energy_multiplier = lerpf(2.0, 0.0, progress)
	if _explosion_sphere != null:
		var sphere_scale := lerpf(0.42, explosion_radius_m * 0.24, progress)
		_explosion_sphere.scale = Vector3.ONE * sphere_scale
		var sphere_material := _explosion_sphere.material_override as StandardMaterial3D
		if sphere_material != null:
			sphere_material.albedo_color.a = lerpf(0.46, 0.0, progress)
			sphere_material.emission_energy_multiplier = lerpf(2.4, 0.0, progress)
	if progress >= 1.0:
		queue_free()

func _ensure_nodes() -> void:
	if _explosion_ring == null or not is_instance_valid(_explosion_ring):
		_explosion_ring = get_node_or_null("ExplosionRing") as MeshInstance3D
	if _explosion_ring == null:
		_explosion_ring = MeshInstance3D.new()
		_explosion_ring.name = "ExplosionRing"
		var ring_mesh := CylinderMesh.new()
		ring_mesh.top_radius = 1.0
		ring_mesh.bottom_radius = 1.0
		ring_mesh.height = 0.14
		ring_mesh.radial_segments = 28
		_explosion_ring.mesh = ring_mesh
		_explosion_ring.position = Vector3(0.0, 0.06, 0.0)
		var ring_material := StandardMaterial3D.new()
		ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_material.albedo_color = Color(1.0, 0.67451, 0.243137, 0.76)
		ring_material.emission_enabled = true
		ring_material.emission = Color(1.0, 0.572549, 0.184314, 1.0)
		ring_material.emission_energy_multiplier = 2.0
		_explosion_ring.material_override = ring_material
		_explosion_ring.visible = false
		add_child(_explosion_ring)
	if _explosion_sphere == null or not is_instance_valid(_explosion_sphere):
		_explosion_sphere = get_node_or_null("ExplosionSphere") as MeshInstance3D
	if _explosion_sphere == null:
		_explosion_sphere = MeshInstance3D.new()
		_explosion_sphere.name = "ExplosionSphere"
		var sphere_mesh := SphereMesh.new()
		sphere_mesh.radius = 1.0
		sphere_mesh.height = 2.0
		_explosion_sphere.mesh = sphere_mesh
		var sphere_material := StandardMaterial3D.new()
		sphere_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sphere_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sphere_material.albedo_color = Color(1.0, 0.458824, 0.203922, 0.46)
		sphere_material.emission_enabled = true
		sphere_material.emission = Color(1.0, 0.713726, 0.301961, 1.0)
		sphere_material.emission_energy_multiplier = 2.4
		_explosion_sphere.material_override = sphere_material
		_explosion_sphere.visible = false
		add_child(_explosion_sphere)
	if _explosion_audio == null or not is_instance_valid(_explosion_audio):
		_explosion_audio = get_node_or_null("ExplosionAudio") as AudioStreamPlayer3D
	if _explosion_audio == null:
		_explosion_audio = AudioStreamPlayer3D.new()
		_explosion_audio.name = "ExplosionAudio"
		_explosion_audio.unit_size = 72.0
		_explosion_audio.max_distance = 200.0
		_explosion_audio.volume_db = audio_volume_db
		add_child(_explosion_audio)
	if _explosion_audio.stream == null:
		_explosion_audio.stream = EXPLOSION_AUDIO_STREAM
