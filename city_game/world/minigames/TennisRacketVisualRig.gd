extends Node3D

const RACKET_SCENE_PATH := "res://city_game/assets/minigames/tennis/props/TennisRacket.glb"
const DEFAULT_TARGET_LENGTH_M := 1.02
const DEFAULT_SWING_DURATION_SEC := 0.24
const AUDIO_SAMPLE_RATE := 22050

static var _shared_audio_stream_cache: Dictionary = {}

var _config: Dictionary = {}
var _mount_root: Node3D = null
var _visual_root: Node3D = null
var _swing_audio_player: AudioStreamPlayer3D = null
var _swing_elapsed_sec := 0.0
var _swing_duration_sec := DEFAULT_SWING_DURATION_SEC
var _last_swing_style := ""
var _swing_count := 0
var _swing_sound_count := 0
var _resolved_grip_anchor_source_point := Vector3.ZERO
var _resolved_visual_center_source_point := Vector3.ZERO

func _ready() -> void:
	_ensure_mount_root()
	_ensure_visual_root()
	_ensure_swing_audio_player()
	_apply_config()
	_update_pose()

func _process(delta: float) -> void:
	if _swing_elapsed_sec <= 0.0:
		return
	_swing_elapsed_sec = maxf(_swing_elapsed_sec - maxf(delta, 0.0), 0.0)
	_update_pose()

func configure_rig(config: Dictionary) -> void:
	_config = config.duplicate(true)
	if is_node_ready():
		_ensure_mount_root()
		_ensure_visual_root()
		_apply_config()
		_update_pose()

func set_equipped_visible(is_visible: bool) -> void:
	visible = is_visible

func play_swing(style: String = "forehand") -> void:
	_ensure_mount_root()
	_ensure_visual_root()
	visible = true
	_last_swing_style = _normalize_swing_style(style)
	_swing_duration_sec = maxf(float(_config.get("swing_duration_sec", DEFAULT_SWING_DURATION_SEC)), 0.05)
	_swing_elapsed_sec = _swing_duration_sec
	_swing_count += 1
	_play_swing_audio(_last_swing_style)
	_update_pose()

func get_visual_state() -> Dictionary:
	var grip_anchor_world_position: Variant = null
	var head_center_world_position: Variant = null
	if _visual_root != null and is_instance_valid(_visual_root):
		grip_anchor_world_position = _visual_root.to_global(_resolved_grip_anchor_source_point)
		head_center_world_position = _visual_root.to_global(_resolved_visual_center_source_point)
	return {
		"racket_present": _visual_root != null and is_instance_valid(_visual_root),
		"equipped_visible": visible,
		"swing_active": _swing_elapsed_sec > 0.0,
		"swing_progress": _resolve_swing_progress(),
		"swing_count": _swing_count,
		"swing_sound_count": _swing_sound_count,
		"last_swing_style": _last_swing_style,
		"target_length_m": maxf(float(_config.get("target_length_m", DEFAULT_TARGET_LENGTH_M)), 0.2),
		"grip_anchor_source_point": _resolved_grip_anchor_source_point,
		"grip_anchor_world_position": grip_anchor_world_position,
		"head_center_source_point": _resolved_visual_center_source_point,
		"head_center_world_position": head_center_world_position,
		"mount_position": _mount_root.position if _mount_root != null else Vector3.ZERO,
		"mount_rotation_degrees": _mount_root.rotation_degrees if _mount_root != null else Vector3.ZERO,
	}

func _ensure_mount_root() -> void:
	if _mount_root != null and is_instance_valid(_mount_root):
		return
	_mount_root = get_node_or_null("MountRoot") as Node3D
	if _mount_root == null:
		_mount_root = Node3D.new()
		_mount_root.name = "MountRoot"
		add_child(_mount_root)

func _ensure_visual_root() -> void:
	_ensure_mount_root()
	if _visual_root != null and is_instance_valid(_visual_root):
		return
	_visual_root = _mount_root.get_node_or_null("Visual") as Node3D
	if _visual_root == null:
		_visual_root = _instantiate_racket_visual()
		if _visual_root == null:
			_visual_root = _build_fallback_racket_visual()
		_visual_root.name = "Visual"
		_mount_root.add_child(_visual_root)

func _instantiate_racket_visual() -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var parse_error := document.append_from_file(ProjectSettings.globalize_path(RACKET_SCENE_PATH), state)
	if parse_error != OK:
		return null
	var generated_scene := document.generate_scene(state)
	if generated_scene is Node3D:
		return generated_scene as Node3D
	return null

func _apply_config() -> void:
	if _mount_root == null:
		return
	var mount_position: Variant = _config.get("mount_position", Vector3(0.5, 1.05, -0.12))
	if mount_position is Vector3:
		_mount_root.position = mount_position as Vector3
	var rest_rotation_deg: Variant = _config.get("rest_rotation_deg", Vector3(18.0, 10.0, -38.0))
	if rest_rotation_deg is Vector3:
		_mount_root.rotation_degrees = rest_rotation_deg as Vector3
	if _visual_root != null and is_instance_valid(_visual_root):
		_normalize_visual_scale(maxf(float(_config.get("target_length_m", DEFAULT_TARGET_LENGTH_M)), 0.2))

func _ensure_swing_audio_player() -> void:
	if _swing_audio_player != null and is_instance_valid(_swing_audio_player):
		return
	_swing_audio_player = get_node_or_null("SwingAudio") as AudioStreamPlayer3D
	if _swing_audio_player == null:
		_swing_audio_player = AudioStreamPlayer3D.new()
		_swing_audio_player.name = "SwingAudio"
		_swing_audio_player.unit_size = 5.0
		_swing_audio_player.max_distance = 220.0
		_swing_audio_player.volume_db = -10.0
		add_child(_swing_audio_player)

func _play_swing_audio(style: String) -> void:
	_ensure_swing_audio_player()
	if _swing_audio_player == null or not is_instance_valid(_swing_audio_player):
		return
	_swing_audio_player.stream = _resolve_swing_audio_stream(style)
	_swing_audio_player.play()
	_swing_sound_count += 1

func _update_pose() -> void:
	if _mount_root == null:
		return
	var rest_mount_position := _resolve_config_vector("mount_position", Vector3(0.5, 1.05, -0.12))
	var rest_rotation_deg: Variant = _config.get("rest_rotation_deg", Vector3(18.0, 10.0, -38.0))
	var resolved_rest_rotation := Vector3(18.0, 10.0, -38.0)
	if rest_rotation_deg is Vector3:
		resolved_rest_rotation = rest_rotation_deg as Vector3
	var progress := _resolve_swing_progress()
	var envelope := sin(progress * PI)
	_mount_root.position = rest_mount_position + _resolve_swing_position(_last_swing_style) * envelope
	_mount_root.rotation_degrees = resolved_rest_rotation + _resolve_swing_rotation(_last_swing_style) * envelope

func _resolve_swing_progress() -> float:
	if _swing_duration_sec <= 0.0 or _swing_elapsed_sec <= 0.0:
		return 0.0
	return clampf(1.0 - (_swing_elapsed_sec / _swing_duration_sec), 0.0, 1.0)

func _resolve_swing_rotation(style: String) -> Vector3:
	match _normalize_swing_style(style):
		"serve":
			return _resolve_config_vector("serve_rotation_deg", Vector3(-88.0, 22.0, -148.0))
		"backhand":
			return _resolve_config_vector("backhand_rotation_deg", Vector3(-26.0, -18.0, 102.0))
		_:
			return _resolve_config_vector("forehand_rotation_deg", Vector3(-36.0, 12.0, -112.0))

func _resolve_swing_position(style: String) -> Vector3:
	match _normalize_swing_style(style):
		"serve":
			return _resolve_config_vector("serve_position_offset", Vector3(0.06, 0.32, 0.24))
		"backhand":
			return _resolve_config_vector("backhand_position_offset", Vector3(-0.14, -0.03, 0.16))
		_:
			return _resolve_config_vector("forehand_position_offset", Vector3(0.14, -0.06, 0.18))

func _normalize_swing_style(style: String) -> String:
	var normalized := style.strip_edges().to_lower()
	if normalized == "serve" or normalized == "backhand" or normalized == "forehand":
		return normalized
	return "forehand"

func _resolve_config_vector(key: String, fallback_value: Vector3) -> Vector3:
	var value: Variant = _config.get(key, fallback_value)
	if value is Vector3:
		return value as Vector3
	return fallback_value

func _resolve_swing_audio_stream(style: String) -> AudioStreamWAV:
	var normalized_style := _normalize_swing_style(style)
	if _shared_audio_stream_cache.has(normalized_style):
		return _shared_audio_stream_cache.get(normalized_style) as AudioStreamWAV
	var stream := _build_swing_audio_stream(normalized_style)
	_shared_audio_stream_cache[normalized_style] = stream
	return stream

func _build_swing_audio_stream(style: String) -> AudioStreamWAV:
	var duration_sec := 0.18 if style == "serve" else 0.14
	var start_hz := 460.0
	var end_hz := 210.0
	match style:
		"serve":
			start_hz = 520.0
			end_hz = 160.0
		"backhand":
			start_hz = 400.0
			end_hz = 240.0
	var sample_count := maxi(int(round(duration_sec * AUDIO_SAMPLE_RATE)), 1)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for sample_index in range(sample_count):
		var progress := float(sample_index) / float(maxi(sample_count - 1, 1))
		var time_sec := float(sample_index) / float(AUDIO_SAMPLE_RATE)
		var frequency_hz := lerpf(start_hz, end_hz, progress)
		var envelope := sin(progress * PI)
		var wobble := sin(TAU * (frequency_hz * 0.47) * time_sec) * 0.14
		var sample := sin(TAU * frequency_hz * time_sec + wobble) * envelope * 0.58
		sample += sin(TAU * (frequency_hz * 2.35) * time_sec) * envelope * 0.16
		var pcm_value := int(round(clampf(sample, -1.0, 1.0) * 32767.0))
		if pcm_value < 0:
			pcm_value += 65536
		data[sample_index * 2] = pcm_value & 0xFF
		data[sample_index * 2 + 1] = (pcm_value >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = AUDIO_SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream

func _normalize_visual_scale(target_length_m: float) -> void:
	if _visual_root == null:
		return
	var local_bounds := _collect_visual_bounds()
	if local_bounds.is_empty():
		return
	var size: Vector3 = local_bounds.get("size", Vector3.ZERO)
	var center: Vector3 = local_bounds.get("center", Vector3.ZERO)
	var max_extent := maxf(size.x, maxf(size.y, size.z))
	if max_extent <= 0.0001:
		return
	var scale_factor := target_length_m / max_extent
	_resolved_visual_center_source_point = center
	_resolved_grip_anchor_source_point = _resolve_grip_anchor_source_point(center)
	_visual_root.scale = Vector3.ONE * scale_factor
	_visual_root.position = -_resolved_grip_anchor_source_point * scale_factor

func _resolve_grip_anchor_source_point(fallback_center: Vector3) -> Vector3:
	var grip_anchor_source_point: Variant = _config.get("grip_anchor_source_point", fallback_center)
	if grip_anchor_source_point is Vector3:
		return grip_anchor_source_point as Vector3
	return fallback_center

func _collect_visual_bounds() -> Dictionary:
	if _visual_root == null:
		return {}
	var min_corner := Vector3(INF, INF, INF)
	var max_corner := Vector3(-INF, -INF, -INF)
	var visual_count := 0
	var root_inverse := _visual_root.global_transform.affine_inverse()
	for child in _visual_root.find_children("*", "VisualInstance3D", true, false):
		var visual := child as VisualInstance3D
		if visual == null or not visual.visible:
			continue
		var local_transform := root_inverse * visual.global_transform
		var aabb := visual.get_aabb()
		for corner in _aabb_corners(aabb):
			var local_corner := local_transform * corner
			min_corner.x = minf(min_corner.x, local_corner.x)
			min_corner.y = minf(min_corner.y, local_corner.y)
			min_corner.z = minf(min_corner.z, local_corner.z)
			max_corner.x = maxf(max_corner.x, local_corner.x)
			max_corner.y = maxf(max_corner.y, local_corner.y)
			max_corner.z = maxf(max_corner.z, local_corner.z)
		visual_count += 1
	if visual_count <= 0:
		return {}
	return {
		"size": max_corner - min_corner,
		"center": (min_corner + max_corner) * 0.5,
	}

func _aabb_corners(aabb: AABB) -> Array[Vector3]:
	var base := aabb.position
	var size := aabb.size
	return [
		base,
		base + Vector3(size.x, 0.0, 0.0),
		base + Vector3(0.0, size.y, 0.0),
		base + Vector3(0.0, 0.0, size.z),
		base + Vector3(size.x, size.y, 0.0),
		base + Vector3(size.x, 0.0, size.z),
		base + Vector3(0.0, size.y, size.z),
		base + size,
	]

func _build_fallback_racket_visual() -> Node3D:
	var root := Node3D.new()
	var ring := MeshInstance3D.new()
	ring.name = "Head"
	var ring_mesh := BoxMesh.new()
	ring_mesh.size = Vector3(0.38, 0.52, 0.04)
	ring.mesh = ring_mesh
	ring.position = Vector3(0.0, 0.28, 0.0)
	ring.material_override = _build_material(Color(0.909804, 0.941176, 0.976471, 1.0), 0.08)
	root.add_child(ring)
	var strings := MeshInstance3D.new()
	strings.name = "Strings"
	var strings_mesh := BoxMesh.new()
	strings_mesh.size = Vector3(0.26, 0.38, 0.01)
	strings.mesh = strings_mesh
	strings.position = Vector3(0.0, 0.28, 0.0)
	strings.material_override = _build_material(Color(0.901961, 0.941176, 0.803922, 1.0), 0.0)
	root.add_child(strings)
	var handle := MeshInstance3D.new()
	handle.name = "Handle"
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.06, 0.4, 0.05)
	handle.mesh = handle_mesh
	handle.position = Vector3(0.0, -0.2, 0.0)
	handle.material_override = _build_material(Color(0.164706, 0.141176, 0.12549, 1.0), 0.02)
	root.add_child(handle)
	return root

func _build_material(albedo: Color, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = 0.72
	material.metallic = metallic
	return material
