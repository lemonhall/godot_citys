extends Node3D

const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")

@onready var generated_city: Node = $GeneratedCity
@onready var hud: CanvasLayer = $Hud
@onready var player: Node3D = $Player
@onready var debug_overlay: CanvasLayer = $DebugOverlay
@onready var chunk_renderer: Node3D = $ChunkRenderer

var _world_config
var _world_data: Dictionary = {}
var _chunk_streamer

func _ready() -> void:
	_world_config = CityWorldConfig.new()
	_world_data = CityWorldGenerator.new().generate_world(_world_config)
	_chunk_streamer = CityChunkStreamer.new(_world_config, _world_data)
	if chunk_renderer != null and chunk_renderer.has_method("setup"):
		chunk_renderer.setup(_world_config, _world_data)

	update_streaming_for_position(player.global_position)
	_refresh_hud_status()

func _process(_delta: float) -> void:
	if player == null:
		return
	update_streaming_for_position(player.global_position)

func _refresh_hud_status() -> void:
	if not generated_city.has_method("get_city_summary"):
		return
	if not hud.has_method("set_status"):
		return

	var snapshot: Dictionary = get_streaming_snapshot()
	var world_summary := str(_world_data.get("summary", "World data unavailable"))
	var lines := PackedStringArray([
		"City sandbox skeleton",
		"WASD / arrows move",
		"Shift sprint  Space jump",
		"Mouse rotates camera  Esc releases cursor",
		generated_city.get_city_summary(),
		world_summary,
		"current_chunk_id=%s | active_chunk_count=%d" % [
			str(snapshot.get("current_chunk_id", "")),
			int(snapshot.get("active_chunk_count", 0))
		],
		"multimesh_instance_total=%d" % int(snapshot.get("multimesh_instance_total", 0))
	])
	hud.set_status("\n".join(lines))

func get_world_config():
	return _world_config

func get_world_data() -> Dictionary:
	return _world_data

func get_chunk_streamer():
	return _chunk_streamer

func get_chunk_renderer():
	return chunk_renderer

func get_streaming_snapshot() -> Dictionary:
	if _chunk_streamer == null:
		return {}
	var snapshot: Dictionary = _chunk_streamer.get_streaming_snapshot()
	if chunk_renderer != null and chunk_renderer.has_method("get_renderer_stats"):
		snapshot.merge(chunk_renderer.get_renderer_stats(), true)
	var current_chunk_id := str(snapshot.get("current_chunk_id", ""))
	if current_chunk_id != "" and chunk_renderer != null and chunk_renderer.has_method("get_chunk_scene_stats"):
		var current_chunk_stats: Dictionary = chunk_renderer.get_chunk_scene_stats(current_chunk_id)
		snapshot["current_chunk_multimesh_instance_count"] = int(current_chunk_stats.get("multimesh_instance_count", 0))
		snapshot["current_chunk_lod_mode"] = str(current_chunk_stats.get("lod_mode", ""))
	return snapshot

func update_streaming_for_position(world_position: Vector3) -> Array:
	if _chunk_streamer == null:
		return []
	var events: Array = _chunk_streamer.update_for_world_position(world_position)
	if chunk_renderer != null and chunk_renderer.has_method("sync_streaming"):
		chunk_renderer.sync_streaming(_chunk_streamer.get_active_chunk_entries(), world_position)
	if debug_overlay != null and debug_overlay.has_method("set_snapshot"):
		debug_overlay.set_snapshot(get_streaming_snapshot())
	_refresh_hud_status()
	return events
