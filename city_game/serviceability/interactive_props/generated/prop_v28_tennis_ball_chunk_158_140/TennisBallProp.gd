extends RigidBody3D

const GROUP_NAME := "city_interactable_prop"
const DEFAULT_DISPLAY_NAME := "网球"
const DEFAULT_INTERACTION_KIND := "swing"
const DEFAULT_PROMPT_TEXT := "按 E 击球"
const DEFAULT_TARGET_DIAMETER_M := 0.135
const DEFAULT_INTERACTION_RADIUS_M := 2.1
const DEFAULT_MASS_KG := 0.058
const DEFAULT_SWING_IMPULSE := 1.9
const DEFAULT_SWING_LIFT_IMPULSE := 1.05
const TRAIL_VISIBILITY_SPEED_MPS := 9.5
const IMPACT_AUDIO_MIN_SPEED_MPS := 4.0
const IMPACT_AUDIO_COOLDOWN_SEC := 0.09
const AUDIO_SAMPLE_RATE := 22050

@onready var _collision_shape := $CollisionShape3D as CollisionShape3D
@onready var _visual_root := $VisualRoot as Node3D

var _entry: Dictionary = {}
var _contract: Dictionary = {}
var _target_diameter_m := DEFAULT_TARGET_DIAMETER_M
var _interaction_radius_m := DEFAULT_INTERACTION_RADIUS_M
var _swing_impulse := DEFAULT_SWING_IMPULSE
var _swing_lift_impulse := DEFAULT_SWING_LIFT_IMPULSE
var _glow_shell: MeshInstance3D = null
var _trail_visual: MeshInstance3D = null
var _impact_audio_player: AudioStreamPlayer3D = null
var _impact_audio_cooldown_sec := 0.0
var _impact_audio_play_count := 0
var _last_impact_kind := ""
var _trail_visible := false
var _last_feedback_speed_mps := 0.0
var _impact_audio_stream_cache: Dictionary = {}

func _ready() -> void:
	_apply_entry_settings()
	_ensure_feedback_visuals()
	_connect_feedback_signals()
	_normalize_visual_scale()
	_update_feedback_visuals(0.0)
	sleeping = true
	if not is_in_group(GROUP_NAME):
		add_to_group(GROUP_NAME)

func _process(delta: float) -> void:
	_update_feedback_visuals(delta)

func _physics_process(_delta: float) -> void:
	_maybe_play_impact_audio_from_contacts()

func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	_impact_audio_stream_cache.clear()
	if _impact_audio_player != null and is_instance_valid(_impact_audio_player):
		_impact_audio_player.stop()
		_impact_audio_player.stream = null

func configure_interactive_prop(entry: Dictionary) -> void:
	_entry = entry.duplicate(true)
	if is_node_ready():
		_apply_entry_settings()
		_ensure_feedback_visuals()
		_normalize_visual_scale()

func get_interaction_contract() -> Dictionary:
	return _contract.duplicate(true)

func get_ball_feedback_state() -> Dictionary:
	return {
		"glow_shell_present": _glow_shell != null and is_instance_valid(_glow_shell),
		"trail_present": _trail_visual != null and is_instance_valid(_trail_visual),
		"trail_visible": _trail_visible and _trail_visual != null and is_instance_valid(_trail_visual) and _trail_visual.visible,
		"impact_audio_player_present": _impact_audio_player != null and is_instance_valid(_impact_audio_player),
		"impact_audio_play_count": _impact_audio_play_count,
		"last_impact_kind": _last_impact_kind,
	}

func apply_player_interaction(player_node: Node3D, interaction_contract: Dictionary = {}) -> Dictionary:
	if player_node == null or not is_instance_valid(player_node):
		return _build_interaction_result(false, "missing_player", interaction_contract)
	var direction := -player_node.global_transform.basis.z
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = global_position - player_node.global_position
		direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	var run_up_boost := 0.0
	var player_velocity_variant: Variant = player_node.get("velocity")
	if player_velocity_variant is Vector3:
		var player_velocity: Vector3 = player_velocity_variant
		run_up_boost = clampf(Vector2(player_velocity.x, player_velocity.z).length() * 0.06, 0.0, 0.42)
	sleeping = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	apply_central_impulse(direction * (_swing_impulse + run_up_boost) + Vector3.UP * (_swing_lift_impulse + run_up_boost * 0.24))
	return _build_interaction_result(true, "", interaction_contract)

func _apply_entry_settings() -> void:
	var display_name := str(_entry.get("display_name", DEFAULT_DISPLAY_NAME)).strip_edges()
	if display_name == "":
		display_name = DEFAULT_DISPLAY_NAME
	_target_diameter_m = clampf(float(_entry.get("target_diameter_m", DEFAULT_TARGET_DIAMETER_M)), 0.08, 0.36)
	_interaction_radius_m = maxf(float(_entry.get("interaction_radius_m", DEFAULT_INTERACTION_RADIUS_M)), 0.8)
	_swing_impulse = maxf(float(_entry.get("kick_impulse", DEFAULT_SWING_IMPULSE)), 0.1)
	_swing_lift_impulse = maxf(float(_entry.get("kick_lift_impulse", DEFAULT_SWING_LIFT_IMPULSE)), 0.0)
	mass = clampf(float(_entry.get("physics_mass_kg", DEFAULT_MASS_KG)), 0.03, 0.2)
	var sphere_shape := _collision_shape.shape as SphereShape3D
	if sphere_shape == null:
		sphere_shape = SphereShape3D.new()
		_collision_shape.shape = sphere_shape
	sphere_shape.radius = _target_diameter_m * 0.5
	_contract = {
		"prop_id": str(_entry.get("prop_id", "")),
		"display_name": display_name,
		"feature_kind": str(_entry.get("feature_kind", "scene_interactive_prop")),
		"interaction_kind": str(_entry.get("interaction_kind", DEFAULT_INTERACTION_KIND)),
		"interaction_radius_m": _interaction_radius_m,
		"prompt_text": str(_entry.get("prompt_text", DEFAULT_PROMPT_TEXT)),
	}

func _normalize_visual_scale() -> void:
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
	var scale_factor := _target_diameter_m / max_extent
	_visual_root.scale = Vector3.ONE * scale_factor
	_visual_root.position = -center * scale_factor

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
		if bool(visual.get_meta("feedback_visual", false)):
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

func _build_interaction_result(success: bool, error: String, interaction_contract: Dictionary) -> Dictionary:
	var prop_id := str(_contract.get("prop_id", ""))
	if prop_id == "":
		prop_id = str(interaction_contract.get("prop_id", ""))
	return {
		"success": success,
		"error": error,
		"prop_id": prop_id,
		"interaction_kind": str(_contract.get("interaction_kind", DEFAULT_INTERACTION_KIND)),
	}

func _ensure_feedback_visuals() -> void:
	if _visual_root == null:
		return
	_glow_shell = _visual_root.get_node_or_null("GlowShell") as MeshInstance3D
	if _glow_shell == null:
		_glow_shell = MeshInstance3D.new()
		_glow_shell.name = "GlowShell"
		var glow_mesh := SphereMesh.new()
		glow_mesh.radius = 0.079
		glow_mesh.height = 0.158
		_glow_shell.mesh = glow_mesh
		_glow_shell.material_override = _build_glow_shell_material()
		_glow_shell.set_meta("feedback_visual", true)
		_visual_root.add_child(_glow_shell)
	_glow_shell.visible = true
	_trail_visual = _visual_root.get_node_or_null("TrailVisual") as MeshInstance3D
	if _trail_visual == null:
		_trail_visual = MeshInstance3D.new()
		_trail_visual.name = "TrailVisual"
		var trail_mesh := BoxMesh.new()
		trail_mesh.size = Vector3(0.085, 0.085, 0.64)
		_trail_visual.mesh = trail_mesh
		_trail_visual.material_override = _build_trail_material()
		_trail_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_trail_visual.visible = false
		_trail_visual.set_meta("feedback_visual", true)
		_visual_root.add_child(_trail_visual)
	_ensure_impact_audio_player()

func _ensure_impact_audio_player() -> void:
	if _impact_audio_player != null and is_instance_valid(_impact_audio_player):
		return
	_impact_audio_player = get_node_or_null("ImpactAudio") as AudioStreamPlayer3D
	if _impact_audio_player == null:
		_impact_audio_player = AudioStreamPlayer3D.new()
		_impact_audio_player.name = "ImpactAudio"
		_impact_audio_player.unit_size = 4.0
		_impact_audio_player.max_distance = 180.0
		_impact_audio_player.volume_db = -10.0
		add_child(_impact_audio_player)

func _connect_feedback_signals() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _update_feedback_visuals(delta: float) -> void:
	_impact_audio_cooldown_sec = maxf(_impact_audio_cooldown_sec - maxf(delta, 0.0), 0.0)
	var speed_mps := linear_velocity.length()
	_last_feedback_speed_mps = speed_mps
	if _glow_shell != null and is_instance_valid(_glow_shell):
		var pulse := 1.04 + minf(speed_mps / 34.0, 0.18)
		_glow_shell.scale = Vector3.ONE * pulse
	if _trail_visual == null or not is_instance_valid(_trail_visual):
		_trail_visible = false
		return
	var should_show_trail := not sleeping and speed_mps >= TRAIL_VISIBILITY_SPEED_MPS
	_trail_visible = should_show_trail
	_trail_visual.visible = should_show_trail
	if not should_show_trail:
		return
	var direction := linear_velocity.normalized()
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	var trail_length := clampf(0.58 + (speed_mps - TRAIL_VISIBILITY_SPEED_MPS) * 0.055, 0.58, 1.9)
	var trail_width := clampf(_target_diameter_m * 0.28, 0.085, 0.16)
	var trail_mesh := _trail_visual.mesh as BoxMesh
	if trail_mesh != null:
		trail_mesh.size = Vector3(trail_width, trail_width, trail_length)
	_trail_visual.position = -direction * trail_length * 0.44
	var up_axis := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.94 else Vector3.FORWARD
	_trail_visual.look_at(_trail_visual.global_position + direction, up_axis)

func _on_body_entered(body: Node) -> void:
	if body == null or _impact_audio_cooldown_sec > 0.0:
		return
	var impact_speed_mps := maxf(linear_velocity.length(), _last_feedback_speed_mps)
	if impact_speed_mps < IMPACT_AUDIO_MIN_SPEED_MPS:
		return
	var impact_kind := _resolve_impact_kind(body)
	_play_impact_audio(impact_kind, impact_speed_mps)

func _resolve_impact_kind(body: Node) -> String:
	var body_name := body.name.to_lower()
	return "net" if body_name.contains("net") else "bounce"

func _maybe_play_impact_audio_from_contacts() -> void:
	if _impact_audio_cooldown_sec > 0.0 or get_contact_count() <= 0:
		return
	var impact_speed_mps := maxf(linear_velocity.length(), _last_feedback_speed_mps)
	if impact_speed_mps < IMPACT_AUDIO_MIN_SPEED_MPS:
		return
	var impact_kind := "bounce"
	for body_variant in get_colliding_bodies():
		if body_variant is Node and _resolve_impact_kind(body_variant as Node) == "net":
			impact_kind = "net"
			break
	_play_impact_audio(impact_kind, impact_speed_mps)

func _play_impact_audio(impact_kind: String, impact_speed_mps: float) -> void:
	_ensure_impact_audio_player()
	_last_impact_kind = impact_kind
	_impact_audio_play_count += 1
	_impact_audio_cooldown_sec = IMPACT_AUDIO_COOLDOWN_SEC
	if _impact_audio_player == null or not is_instance_valid(_impact_audio_player):
		return
	_impact_audio_player.pitch_scale = 0.92 if impact_kind == "net" else clampf(0.92 + impact_speed_mps * 0.015, 0.92, 1.24)
	_impact_audio_player.stream = _resolve_impact_audio_stream(impact_kind)
	_impact_audio_player.play()

func _resolve_impact_audio_stream(impact_kind: String) -> AudioStreamWAV:
	var normalized_kind := impact_kind.strip_edges().to_lower()
	if normalized_kind != "net":
		normalized_kind = "bounce"
	if _impact_audio_stream_cache.has(normalized_kind):
		return _impact_audio_stream_cache.get(normalized_kind) as AudioStreamWAV
	var stream := _build_impact_audio_stream(normalized_kind)
	_impact_audio_stream_cache[normalized_kind] = stream
	return stream

func _build_impact_audio_stream(impact_kind: String) -> AudioStreamWAV:
	var duration_sec := 0.085 if impact_kind == "bounce" else 0.11
	var start_hz := 280.0 if impact_kind == "bounce" else 156.0
	var end_hz := 180.0 if impact_kind == "bounce" else 108.0
	var harmonic_gain := 0.18 if impact_kind == "bounce" else 0.1
	var sample_count := maxi(int(round(duration_sec * AUDIO_SAMPLE_RATE)), 1)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for sample_index in range(sample_count):
		var progress := float(sample_index) / float(maxi(sample_count - 1, 1))
		var time_sec := float(sample_index) / float(AUDIO_SAMPLE_RATE)
		var frequency_hz := lerpf(start_hz, end_hz, progress)
		var envelope := pow(maxf(1.0 - progress, 0.0), 1.8)
		var sample := sin(TAU * frequency_hz * time_sec) * envelope * 0.62
		sample += sin(TAU * (frequency_hz * 2.1) * time_sec) * envelope * harmonic_gain
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

func _build_glow_shell_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.929412, 1.0, 0.576471, 0.24)
	material.emission_enabled = true
	material.emission = Color(0.866667, 0.968627, 0.337255, 1.0)
	material.emission_energy_multiplier = 0.72
	return material

func _build_trail_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.929412, 1.0, 0.576471, 0.18)
	material.emission_enabled = true
	material.emission = Color(0.882353, 0.984314, 0.435294, 1.0)
	material.emission_energy_multiplier = 0.58
	return material
