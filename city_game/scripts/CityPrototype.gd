extends Node3D

const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")

@onready var generated_city: Node = $GeneratedCity
@onready var hud: CanvasLayer = $Hud
@onready var player: Node3D = $Player
@onready var debug_overlay: CanvasLayer = $DebugOverlay

var _world_config
var _world_data: Dictionary = {}
var _chunk_streamer

func _ready() -> void:
	_world_config = CityWorldConfig.new()
	_world_data = CityWorldGenerator.new().generate_world(_world_config)
	_chunk_streamer = CityChunkStreamer.new(_world_config, _world_data)

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

	var snapshot := get_streaming_snapshot()
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
		]
	])
	hud.set_status("\n".join(lines))

func get_world_config():
	return _world_config

func get_world_data() -> Dictionary:
	return _world_data

func get_chunk_streamer():
	return _chunk_streamer

func get_streaming_snapshot() -> Dictionary:
	if _chunk_streamer == null:
		return {}
	return _chunk_streamer.get_streaming_snapshot()

func update_streaming_for_position(world_position: Vector3) -> Array:
	if _chunk_streamer == null:
		return []
	var events: Array = _chunk_streamer.update_for_world_position(world_position)
	if debug_overlay != null and debug_overlay.has_method("set_snapshot"):
		debug_overlay.set_snapshot(_chunk_streamer.get_streaming_snapshot())
	_refresh_hud_status()
	return events
