extends Node3D

const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityChunkKey := preload("res://city_game/world/streaming/CityChunkKey.gd")
const CityChunkNavRuntime := preload("res://city_game/world/navigation/CityChunkNavRuntime.gd")
const CityFastTravelResolver := preload("res://city_game/world/navigation/CityFastTravelResolver.gd")
const CityAutodriveController := preload("res://city_game/world/navigation/CityAutodriveController.gd")
const CityDestinationWorldMarker := preload("res://city_game/world/navigation/CityDestinationWorldMarker.gd")
const CityTaskTriggerRuntime := preload("res://city_game/world/tasks/runtime/CityTaskTriggerRuntime.gd")
const CityTaskWorldMarkerRuntime := preload("res://city_game/world/tasks/runtime/CityTaskWorldMarkerRuntime.gd")
const CityPlaceIndexBuilder := preload("res://city_game/world/generation/CityPlaceIndexBuilder.gd")
const CityResolvedTarget := preload("res://city_game/world/model/CityResolvedTarget.gd")
const CityChunkProfileBuilder := preload("res://city_game/world/rendering/CityChunkProfileBuilder.gd")
const CityChunkGroundSampler := preload("res://city_game/world/rendering/CityChunkGroundSampler.gd")
const CityMinimapProjector := preload("res://city_game/world/map/CityMinimapProjector.gd")
const CityMapScreenScene := preload("res://city_game/ui/CityMapScreen.tscn")
const CityMapPinRegistry := preload("res://city_game/world/map/CityMapPinRegistry.gd")
const CityVehicleRadioControllerScript := preload("res://city_game/world/radio/CityVehicleRadioController.gd")
const CityRadioCatalogStoreScript := preload("res://city_game/world/radio/CityRadioCatalogStore.gd")
const CityRadioCatalogRepositoryScript := preload("res://city_game/world/radio/CityRadioCatalogRepository.gd")
const CityRadioBrowserApiScript := preload("res://city_game/world/radio/CityRadioBrowserApi.gd")
const CityRadioNativeBackendScript := preload("res://city_game/world/radio/backend/CityRadioNativeBackend.gd")
const CityRadioMockBackendScript := preload("res://city_game/world/radio/backend/CityRadioMockBackend.gd")
const CityRadioQuickBankScript := preload("res://city_game/world/radio/CityRadioQuickBank.gd")
const CityRadioUserStateStoreScript := preload("res://city_game/world/radio/CityRadioUserStateStore.gd")
const CityTaskBriefViewModel := preload("res://city_game/world/tasks/presentation/CityTaskBriefViewModel.gd")
const CityTaskPinProjection := preload("res://city_game/world/tasks/presentation/CityTaskPinProjection.gd")
const CityVehicleVisualCatalog := preload("res://city_game/world/vehicles/rendering/CityVehicleVisualCatalog.gd")
const CityProjectile := preload("res://city_game/combat/CityProjectile.gd")
const CityGrenade := preload("res://city_game/combat/CityGrenade.gd")
const CityMissileScene := preload("res://city_game/combat/CityMissile.tscn")
const CityLaserDesignatorBeam := preload("res://city_game/combat/CityLaserDesignatorBeam.gd")
const CityTraumaEnemy := preload("res://city_game/combat/CityTraumaEnemy.gd")
const CityHelicopterGunshipWorldEncounterScene := preload("res://city_game/combat/helicopter/CityHelicopterGunshipWorldEncounter.tscn")
const CityWorldInspectionResolver := preload("res://city_game/world/inspection/CityWorldInspectionResolver.gd")
const CityBuildingSceneExporter := preload("res://city_game/world/serviceability/CityBuildingSceneExporter.gd")
const CityBuildingOverrideRegistry := preload("res://city_game/world/serviceability/CityBuildingOverrideRegistry.gd")
const CityServiceBuildingMapPinRuntime := preload("res://city_game/world/serviceability/CityServiceBuildingMapPinRuntime.gd")
const CitySceneLandmarkRegistry := preload("res://city_game/world/features/CitySceneLandmarkRegistry.gd")
const CitySceneLandmarkRuntime := preload("res://city_game/world/features/CitySceneLandmarkRuntime.gd")
const CitySceneInteractivePropRegistry := preload("res://city_game/world/features/CitySceneInteractivePropRegistry.gd")
const CitySceneInteractivePropRuntime := preload("res://city_game/world/features/CitySceneInteractivePropRuntime.gd")
const CitySceneMinigameVenueRegistry := preload("res://city_game/world/features/CitySceneMinigameVenueRegistry.gd")
const CitySceneMinigameVenueRuntime := preload("res://city_game/world/features/CitySceneMinigameVenueRuntime.gd")
const CityTerrainRegionFeatureRegistry := preload("res://city_game/world/features/CityTerrainRegionFeatureRegistry.gd")
const CityTerrainRegionFeatureRuntime := preload("res://city_game/world/features/CityTerrainRegionFeatureRuntime.gd")
const CityLakeFishSchoolRuntime := preload("res://city_game/world/features/lake/CityLakeFishSchoolRuntime.gd")
const CitySoccerVenueRuntime := preload("res://city_game/world/minigames/CitySoccerVenueRuntime.gd")
const CityTennisVenueRuntime := preload("res://city_game/world/minigames/CityTennisVenueRuntime.gd")
const CityMissileCommandVenueRuntime := preload("res://city_game/world/minigames/CityMissileCommandVenueRuntime.gd")
const CityFishingVenueRuntime := preload("res://city_game/world/minigames/CityFishingVenueRuntime.gd")
const CityMusicRoadRuntimeScript := preload("res://city_game/world/features/music_road/CityMusicRoadRuntime.gd")
const CityNpcInteractionRuntime := preload("res://city_game/world/interactions/CityNpcInteractionRuntime.gd")
const CityInteractivePropRuntime := preload("res://city_game/world/interactions/CityInteractivePropRuntime.gd")
const CityDialogueRuntime := preload("res://city_game/world/interactions/CityDialogueRuntime.gd")

const CONTROL_MODE_PLAYER := "player"
const CONTROL_MODE_INSPECTION := "inspection"
const MINIMAP_POSITION_REFRESH_M := 256.0
const HUD_REFRESH_INTERVAL_USEC := 50000
const HUD_REFRESH_INTERVAL_FAST_USEC := 120000
const MINIMAP_HUD_REFRESH_INTERVAL_USEC := 120000
const MINIMAP_HUD_REFRESH_INTERVAL_FAST_USEC := 320000
const INSPECTION_HUD_REFRESH_INTERVAL_USEC := 160000
const INSPECTION_MINIMAP_HUD_REFRESH_INTERVAL_USEC := 480000
const HEADLESS_HUD_REFRESH_INTERVAL_USEC := 200000
const HEADLESS_HUD_REFRESH_INTERVAL_FAST_USEC := 400000
const HEADLESS_MINIMAP_HUD_REFRESH_INTERVAL_USEC := 400000
const HEADLESS_MINIMAP_HUD_REFRESH_INTERVAL_FAST_USEC := 800000
const ACTOR_PAGE_PREWARM_RING_RADIUS_CHUNKS := 5
const CHUNK_PAGE_PREWARM_RING_RADIUS_CHUNKS := 7
const ABANDONED_HIJACK_VEHICLE_LIFETIME_SEC := 15.0
const MINIMAP_WORLD_RADIUS_M := 1600.0
const MANUAL_ROUTE_REFRESH_INTERVAL_SEC := 3.5
const AUTODRIVE_ROUTE_REFRESH_INTERVAL_SEC := 3.5
const ACTIVE_ROUTE_REFRESH_MIN_MOVEMENT_M := 48.0
const ACTIVE_ROUTE_REFRESH_MIN_ORIGIN_DELTA_M := 36.0
const FAST_TRAVEL_SHORTCUT_AIR_DROP_HEIGHT_M := 10.0
const DESTINATION_WORLD_MARKER_RADIUS_M := 8.0
const DESTINATION_WORLD_MARKER_CLEAR_DISTANCE_M := 10.5
const DESTINATION_WORLD_MARKER_SURFACE_OFFSET_M := 0.12
const ROUTE_STYLE_DESTINATION := "destination"
const ROUTE_STYLE_TASK_AVAILABLE := "task_available"
const ROUTE_STYLE_TASK_ACTIVE := "task_active"
const VEHICLE_RADIO_MIN_REAL_COUNTRY_COUNT := 50
const VEHICLE_RADIO_DEFAULT_PROXY_MODE := "local_proxy"
const VEHICLE_RADIO_DIRECT_PROXY_MODE := "direct"
const VEHICLE_RADIO_SYSTEM_PROXY_MODE := "system_proxy"
const VEHICLE_RADIO_LOCAL_PROXY_MODE := "local_proxy"
const VEHICLE_RADIO_PINNED_COUNTRY_ORDER := [
	"CN",
	"US",
	"GB",
	"FR",
	"RU",
	"JP",
	"BR",
	"ES",
	"CU",
	"AR",
]
const VEHICLE_RADIO_INPUT_ACTIONS := [
	"vehicle_radio_quick_open",
	"vehicle_radio_next",
	"vehicle_radio_prev",
	"vehicle_radio_power_toggle",
	"vehicle_radio_browser_open",
	"vehicle_radio_confirm",
	"vehicle_radio_cancel",
]
const BUILDING_EXPORT_WINDOW_SEC := 10.0
const BUILDING_EXPORT_TOAST_DURATION_SEC := 6.0
const BUILDING_EXPORT_SCENE_ROOT_PREFERRED := "res://city_game/serviceability/buildings/generated"
const BUILDING_EXPORT_SCENE_ROOT_FALLBACK := "user://serviceability/buildings/generated"
const SCENE_LANDMARK_REGISTRY_PATH := "res://city_game/serviceability/landmarks/generated/landmark_override_registry.json"
const SCENE_INTERACTIVE_PROP_REGISTRY_PATH := "res://city_game/serviceability/interactive_props/generated/interactive_prop_registry.json"
const SCENE_MINIGAME_VENUE_REGISTRY_PATH := "res://city_game/serviceability/minigame_venues/generated/minigame_venue_registry.json"
const TERRAIN_REGION_REGISTRY_PATH := "res://city_game/serviceability/terrain_regions/generated/terrain_region_registry.json"
const SERVICE_BUILDING_MAP_PIN_STARTUP_DELAY_FRAMES := 120
const SERVICE_BUILDING_MAP_PIN_BATCH_SIZE := 1
const SERVICE_BUILDING_MAP_PIN_BATCH_BUDGET_USEC := 1200
const HELICOPTER_GUNSHIP_TASK_ID := "task_helicopter_gunship_v37"
const HELICOPTER_GUNSHIP_COMPLETION_EVENT_ID := "encounter:helicopter_gunship_v37"
const HELICOPTER_GUNSHIP_REPEATABLE_RESET_DELAY_SEC := 0.35

@onready var generated_city: Node = $GeneratedCity
@onready var hud: CanvasLayer = $Hud
@onready var player: Node3D = $Player
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var debug_overlay: CanvasLayer = $DebugOverlay
@onready var chunk_renderer: Node3D = $ChunkRenderer

var _world_config
var _world_data: Dictionary = {}
var _chunk_streamer
var _navigation_runtime
var _fast_travel_resolver
var _autodrive_controller
var _control_mode := CONTROL_MODE_PLAYER
var _minimap_projector
var _minimap_route_world_positions: Array[Vector3] = []
var _active_destination_target: Dictionary = {}
var _active_route_result: Dictionary = {}
var _active_route_refresh_elapsed_sec := 0.0
var _active_route_refresh_anchor := Vector3.ZERO
var _last_map_selection_contract: Dictionary = {}
var _map_screen: Control = null
var _map_pin_registry = null
var _full_map_open := false
var _controls_help_open := false
var _world_simulation_paused := false
var _task_catalog = null
var _task_slot_index = null
var _task_runtime = null
var _task_brief_view_model = null
var _task_pin_projection = null
var _task_trigger_runtime = null
var _task_world_marker_runtime: Node3D = null
var _helicopter_gunship_encounter_runtime: Node3D = null
var _helicopter_gunship_pending_reset_task_id := ""
var _helicopter_gunship_pending_reset_delay_sec := 0.0
var _npc_interaction_runtime: Node = null
var _interactive_prop_runtime: Node = null
var _dialogue_runtime = null
var _paused_world_process_entries: Array[Dictionary] = []
var _vehicle_radio_quick_bank = null
var _vehicle_radio_controller = null
var _vehicle_radio_catalog_store = null
var _vehicle_radio_catalog_repository = null
var _vehicle_radio_backend = null
var _vehicle_radio_user_state_store = null
var _vehicle_radio_selection_sources := {
	"presets": [],
	"favorites": [],
	"recents": [],
}
var _vehicle_radio_browser_open := false
var _vehicle_radio_browser_selected_tab_id := "browse"
var _vehicle_radio_browser_selected_country_code := ""
var _vehicle_radio_browser_filter_text := ""
var _vehicle_radio_browser_cached_countries: Array = []
var _vehicle_radio_browser_cached_country_code := ""
var _vehicle_radio_browser_cached_station_rows: Array = []
var _vehicle_radio_catalog_sync_thread: Thread = null
var _vehicle_radio_catalog_sync_job: Dictionary = {}
var _vehicle_radio_catalog_sync_pending_result: Dictionary = {}
var _vehicle_radio_catalog_sync_queued_job: Dictionary = {}
var _vehicle_radio_browser_countries_loading := false
var _vehicle_radio_browser_countries_error := ""
var _vehicle_radio_browser_stations_loading := false
var _vehicle_radio_browser_station_loading_country_code := ""
var _vehicle_radio_browser_stations_error := ""
var _vehicle_radio_debug_state := {
	"browser_country_load_count": 0,
	"browser_station_page_load_count": 0,
}
var _vehicle_radio_quick_slots: Array = []
var _vehicle_radio_quick_overlay_open := false
var _vehicle_radio_quick_selected_index := -1
var _vehicle_radio_power_on := false
var _vehicle_radio_browser_request_count := 0
var _vehicle_radio_catalog_proxy_mode := VEHICLE_RADIO_DIRECT_PROXY_MODE
var _minimap_snapshot_cache: Dictionary = {}
var _minimap_cache_key := ""
var _minimap_cache_hits := 0
var _minimap_cache_misses := 0
var _minimap_rebuild_count := 0
var _world_generation_usec := 0
var _world_generation_profile: Dictionary = {}
var _update_streaming_sample_count := 0
var _update_streaming_total_usec := 0
var _update_streaming_max_usec := 0
var _update_streaming_last_usec := 0
var _update_streaming_chunk_streamer_sample_count := 0
var _update_streaming_chunk_streamer_total_usec := 0
var _update_streaming_chunk_streamer_max_usec := 0
var _update_streaming_chunk_streamer_last_usec := 0
var _update_streaming_renderer_sync_sample_count := 0
var _update_streaming_renderer_sync_total_usec := 0
var _update_streaming_renderer_sync_max_usec := 0
var _update_streaming_renderer_sync_last_usec := 0
var _performance_diagnostics_enabled := false
var _hud_refresh_sample_count := 0
var _hud_refresh_total_usec := 0
var _hud_refresh_max_usec := 0
var _hud_refresh_last_usec := 0
var _frame_step_sample_count := 0
var _frame_step_total_usec := 0
var _frame_step_max_usec := 0
var _frame_step_last_usec := 0
var _minimap_request_count := 0
var _minimap_build_total_usec := 0
var _minimap_build_max_usec := 0
var _minimap_build_last_usec := 0
var _combat_root: Node3D = null
var _projectile_root: Node3D = null
var _grenade_root: Node3D = null
var _missile_root: Node3D = null
var _laser_beam_root: Node3D = null
var _enemy_projectile_root: Node3D = null
var _enemy_root: Node3D = null
var _pedestrians_visible := true
var _fps_overlay_visible := false
var _last_fps_sample := 0.0
var _last_hud_refresh_tick_usec := -HUD_REFRESH_INTERVAL_USEC
var _last_minimap_hud_refresh_tick_usec := -MINIMAP_HUD_REFRESH_INTERVAL_USEC
var _vehicle_visual_catalog: CityVehicleVisualCatalog = null
var _abandoned_vehicle_visual_root: Node3D = null
var _abandoned_vehicle_visuals: Array = []
var _pending_player_vehicle_impact_result: Dictionary = {}
var _destination_world_marker: Node3D = null
var _destination_world_marker_dismissed_route_id := ""
var _destination_world_marker_cached_route_id := ""
var _destination_world_marker_cached_anchor := Vector3.INF
var _destination_world_marker_cached_world_position := Vector3.ZERO
var _destination_world_marker_surface_resolve_count := 0
var _inspection_resolver = null
var _last_laser_designator_result: Dictionary = {}
var _last_laser_designator_clipboard_text := ""
var _last_missile_explosion_result: Dictionary = {}
var _building_scene_exporter = null
var _building_override_registry = null
var _building_export_thread: Thread = null
var _building_export_request: Dictionary = {}
var _building_export_pending_result: Dictionary = {}
var _building_export_started_process_frame := -1
var _service_building_map_pin_runtime = null
var _scene_landmark_registry = null
var _scene_landmark_runtime = null
var _scene_interactive_prop_registry = null
var _scene_interactive_prop_runtime = null
var _scene_minigame_venue_registry = null
var _scene_minigame_venue_runtime = null
var _terrain_region_feature_registry = null
var _terrain_region_feature_runtime = null
var _lake_fish_school_runtime = null
var _soccer_venue_runtime = null
var _tennis_venue_runtime = null
var _missile_command_venue_runtime = null
var _fishing_venue_runtime = null
var _last_fishing_feedback_token := 0
var _music_road_runtime = null
var _music_road_runtime_time_sec := 0.0
var _lake_player_water_state := {
	"in_water": false,
	"underwater": false,
	"region_id": "",
	"water_level_y_m": 0.0,
	"depth_m": 0.0,
	"floor_y_m": 0.0,
	"world_position": Vector3.ZERO,
}
var _building_export_state: Dictionary = {
	"running": false,
	"status": "idle",
	"building_id": "",
	"display_name": "",
	"scene_root": "",
	"scene_path": "",
	"manifest_path": "",
	"error": "",
	"export_root_kind": "",
}
var _exportable_building_inspection_result: Dictionary = {}
var _exportable_building_inspection_expire_usec := 0
var _building_serviceability_preferred_scene_root := BUILDING_EXPORT_SCENE_ROOT_PREFERRED
var _building_serviceability_fallback_scene_root := BUILDING_EXPORT_SCENE_ROOT_FALLBACK
var _building_serviceability_registry_override_path := ""

func _ready() -> void:
	_configure_environment()
	_ensure_combat_roots()
	_world_config = CityWorldConfig.new()
	var world_generator := CityWorldGenerator.new()
	var generation_started_usec := Time.get_ticks_usec()
	_world_data = world_generator.generate_world(_world_config)
	_world_generation_usec = Time.get_ticks_usec() - generation_started_usec
	_world_generation_profile = _world_data.get("generation_profile", {})
	_task_catalog = _world_data.get("task_catalog")
	_task_slot_index = _world_data.get("task_slot_index")
	_task_runtime = _world_data.get("task_runtime")
	_task_brief_view_model = CityTaskBriefViewModel.new()
	_task_pin_projection = CityTaskPinProjection.new()
	_chunk_streamer = CityChunkStreamer.new(_world_config, _world_data)
	_navigation_runtime = CityChunkNavRuntime.new(_world_config, _world_data)
	_fast_travel_resolver = CityFastTravelResolver.new(_world_config, _world_data)
	_autodrive_controller = CityAutodriveController.new()
	_minimap_projector = CityMinimapProjector.new(_world_config, _world_data)
	_vehicle_radio_quick_bank = CityRadioQuickBankScript.new()
	_vehicle_radio_controller = CityVehicleRadioControllerScript.new()
	_vehicle_radio_catalog_store = CityRadioCatalogStoreScript.new()
	_vehicle_radio_catalog_repository = CityRadioCatalogRepositoryScript.new(_vehicle_radio_catalog_store)
	_vehicle_radio_backend = _create_vehicle_radio_backend()
	_vehicle_radio_user_state_store = CityRadioUserStateStoreScript.new()
	if _vehicle_radio_controller != null and _vehicle_radio_controller.has_method("configure"):
		_vehicle_radio_controller.configure(_vehicle_radio_backend)
	if _vehicle_radio_backend != null and _vehicle_radio_backend.has_method("attach_audio_host"):
		_vehicle_radio_backend.attach_audio_host(self)
	_reload_vehicle_radio_selection_sources_from_store()
	_restore_vehicle_radio_session_state_from_store()
	_vehicle_visual_catalog = CityVehicleVisualCatalog.new()
	_inspection_resolver = CityWorldInspectionResolver.new()
	_building_scene_exporter = CityBuildingSceneExporter.new()
	_building_override_registry = CityBuildingOverrideRegistry.new()
	_service_building_map_pin_runtime = CityServiceBuildingMapPinRuntime.new()
	_scene_landmark_registry = CitySceneLandmarkRegistry.new()
	_scene_landmark_runtime = CitySceneLandmarkRuntime.new()
	_scene_interactive_prop_registry = CitySceneInteractivePropRegistry.new()
	_scene_interactive_prop_runtime = CitySceneInteractivePropRuntime.new()
	_scene_minigame_venue_registry = CitySceneMinigameVenueRegistry.new()
	_scene_minigame_venue_runtime = CitySceneMinigameVenueRuntime.new()
	_terrain_region_feature_registry = CityTerrainRegionFeatureRegistry.new()
	_terrain_region_feature_runtime = CityTerrainRegionFeatureRuntime.new()
	_lake_fish_school_runtime = CityLakeFishSchoolRuntime.new()
	_soccer_venue_runtime = CitySoccerVenueRuntime.new()
	_tennis_venue_runtime = CityTennisVenueRuntime.new()
	_missile_command_venue_runtime = CityMissileCommandVenueRuntime.new()
	_fishing_venue_runtime = CityFishingVenueRuntime.new()
	_music_road_runtime = CityMusicRoadRuntimeScript.new()
	_music_road_runtime_time_sec = 0.0
	if _inspection_resolver != null and _inspection_resolver.has_method("setup"):
		_inspection_resolver.setup(_world_config, _world_data)
	_setup_map_ui()
	_connect_vehicle_radio_browser_ui()
	_connect_vehicle_radio_quick_overlay_ui()
	_ensure_interaction_runtimes()
	_ensure_destination_world_marker()
	_ensure_task_system_runtimes()
	_ensure_helicopter_gunship_encounter_runtime()
	if chunk_renderer != null and chunk_renderer.has_method("setup"):
		chunk_renderer.setup(_world_config, _world_data)
		_reload_building_override_registry()
		_reload_scene_landmark_registry()
		_reload_scene_interactive_prop_registry()
		_reload_scene_minigame_venue_registry()
		_reload_terrain_region_feature_registry()
		if chunk_renderer.has_method("set_pedestrians_visible"):
			chunk_renderer.set_pedestrians_visible(_pedestrians_visible)
	_disable_legacy_generated_city_runtime_geometry()
	if debug_overlay != null:
		debug_overlay.visible = false
	_align_player_to_streamed_ground()
	if player != null and player.has_method("suspend_ground_stabilization"):
		player.suspend_ground_stabilization(24)
	_connect_player_combat()
	if player != null:
		player.add_to_group("city_player")

	set_control_mode(CONTROL_MODE_PLAYER)
	update_streaming_for_position(_get_active_anchor_position())
	_update_minigame_venue_runtimes(0.0)
	_prewarm_actor_pages_around_spawn()
	if hud != null and hud.has_method("set_fps_overlay_visible"):
		hud.set_fps_overlay_visible(_fps_overlay_visible)
	_sync_navigation_consumers(true)
	_sync_vehicle_radio_browser()
	_sync_vehicle_radio_quick_overlay()
	_sync_controls_help_overlay()
	_update_task_system(0.0)
	_update_music_road_runtime(0.0)
	_refresh_hud_status()
	_update_npc_interaction_system()

func _disable_legacy_generated_city_runtime_geometry() -> void:
	if generated_city == null:
		return
	var generated_city_node := generated_city as Node3D
	if generated_city_node != null:
		generated_city_node.visible = false
	generated_city.process_mode = Node.PROCESS_MODE_DISABLED
	_disable_legacy_generated_city_collisions_recursive(generated_city)

func _disable_legacy_generated_city_collisions_recursive(root: Node) -> void:
	if root == null:
		return
	var collision_object := root as CollisionObject3D
	if collision_object != null:
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
	if root is CollisionShape3D:
		(root as CollisionShape3D).disabled = true
	for child in root.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		_disable_legacy_generated_city_collisions_recursive(child_node)

func _create_vehicle_radio_backend() -> RefCounted:
	var native_backend: RefCounted = CityRadioNativeBackendScript.new()
	if native_backend != null and native_backend.has_method("is_available") and bool(native_backend.is_available()):
		return native_backend
	return CityRadioMockBackendScript.new()

func _exit_tree() -> void:
	if _vehicle_radio_catalog_sync_thread != null and _vehicle_radio_catalog_sync_thread.is_started():
		_vehicle_radio_catalog_sync_thread.wait_to_finish()
	_vehicle_radio_catalog_sync_thread = null
	_vehicle_radio_catalog_sync_job.clear()
	_vehicle_radio_catalog_sync_pending_result.clear()
	_vehicle_radio_catalog_sync_queued_job.clear()
	if _building_export_thread != null and _building_export_thread.is_started():
		var thread_result: Variant = _building_export_thread.wait_to_finish()
		if thread_result is Dictionary:
			_finalize_building_export_result(thread_result, false, false)
		else:
			_finalize_building_export_result({
				"success": false,
				"status": "failed",
				"building_id": str(_building_export_request.get("building_id", "")),
				"display_name": str(_building_export_request.get("display_name", "")),
				"error": "invalid_thread_result",
			}, false, false)
	elif not _building_export_pending_result.is_empty():
		_finalize_building_export_result(_building_export_pending_result, false, false)
	_building_export_thread = null
	_building_export_pending_result.clear()

func _process(delta: float) -> void:
	_collect_completed_vehicle_radio_catalog_sync_job()
	_collect_completed_building_export_job()
	_expire_exportable_building_inspection_window()
	_update_service_building_map_pins()
	_sync_vehicle_radio_runtime_driving_context()
	_update_vehicle_radio_audio_backend()
	if _world_simulation_paused:
		_update_npc_interaction_system()
		return
	_step_autodrive(delta)
	_step_active_route_refresh(delta)
	_update_destination_world_marker(delta)
	_update_abandoned_vehicle_visuals(delta)
	if player == null:
		return
	_update_lake_player_water_state()
	_update_minigame_venue_runtimes(delta)
	var frame_started_usec := Time.get_ticks_usec()
	update_streaming_for_position(player.global_position, delta)
	_update_task_system(delta)
	_update_music_road_runtime(delta)
	_update_npc_interaction_system()
	var impact_result := _resolve_player_vehicle_pedestrian_impact_impl()
	if not impact_result.is_empty():
		_pending_player_vehicle_impact_result = impact_result.duplicate(true)
	var frame_duration_usec := Time.get_ticks_usec() - frame_started_usec
	_record_frame_step_sample(frame_duration_usec)
	if delta > 0.0:
		_last_fps_sample = 1.0 / delta
	elif frame_duration_usec > 0:
		_last_fps_sample = 1000000.0 / float(frame_duration_usec)
	if DisplayServer.get_name() != "headless" and hud != null and hud.has_method("set_fps_overlay_sample"):
		hud.set_fps_overlay_sample(_last_fps_sample)

func _unhandled_input(event: InputEvent) -> void:
	if _handle_vehicle_radio_bound_input(event):
		get_viewport().set_input_as_handled()
		return
	if _handle_missile_command_input(event):
		get_viewport().set_input_as_handled()
		return
	if _is_missile_command_mode_active():
		if not (event is InputEventMouseMotion):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F1:
			toggle_controls_help()
			get_viewport().set_input_as_handled()
			return
		if _controls_help_open:
			return
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_M:
			toggle_full_map()
			get_viewport().set_input_as_handled()
			return
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_T:
			if _handle_fast_travel_shortcut():
				get_viewport().set_input_as_handled()
				return
		if _full_map_open:
			return
		if key_event.pressed and not key_event.echo and (key_event.keycode == KEY_KP_ADD or key_event.physical_keycode == KEY_KP_ADD):
			var export_request := request_export_from_last_building_inspection()
			if not bool(export_request.get("accepted", false)):
				var rejection_message := _describe_building_export_request_error(str(export_request.get("error", "")))
				if rejection_message != "":
					_show_building_export_toast(rejection_message, 3.0)
			get_viewport().set_input_as_handled()
			return
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_E:
			var interaction_result: Dictionary = handle_primary_interaction()
			if bool(interaction_result.get("success", false)):
				get_viewport().set_input_as_handled()
				return
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F:
			handle_vehicle_interaction()
			return
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_G:
			if _handle_autodrive_shortcut():
				return
		if key_event.pressed and not key_event.echo and handle_debug_keypress(key_event.keycode, key_event.physical_keycode):
			return
	elif _full_map_open:
		return
	if DisplayServer.get_name() == "headless":
		return

func _handle_missile_command_input(event: InputEvent) -> bool:
	if _missile_command_venue_runtime == null:
		return false
	if not _is_missile_command_mode_active():
		return false
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
			var fire_result := request_missile_command_primary_fire()
			return bool(fire_result.get("success", false))
		if button.button_index == MOUSE_BUTTON_RIGHT:
			var zoom_result := set_missile_command_zoom_active(button.pressed)
			return bool(zoom_result.get("success", false))
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var look_result := rotate_missile_command_view(motion.relative)
		return bool(look_result.get("success", false))
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return false
		if key_event.keycode == KEY_Q:
			var cycle_result := cycle_missile_command_silo()
			return bool(cycle_result.get("success", false))
		if key_event.keycode == KEY_ESCAPE:
			var exit_result := exit_missile_command_mode()
			return bool(exit_result.get("success", false))
	return false

func _is_missile_command_mode_active() -> bool:
	if _missile_command_venue_runtime == null or not _missile_command_venue_runtime.has_method("get_state"):
		return false
	return bool((_missile_command_venue_runtime.get_state() as Dictionary).get("battery_mode_active", false))

func _handle_autodrive_shortcut() -> bool:
	if player == null or not player.has_method("is_driving_vehicle") or not bool(player.is_driving_vehicle()):
		return false
	if is_autodrive_active():
		stop_autodrive("interrupted")
		_refresh_hud_status({}, true)
		return true
	var start_result: Dictionary = start_autodrive_to_active_destination()
	if bool(start_result.get("success", false)):
		_refresh_hud_status({}, true)
		return true
	return false

func open_vehicle_radio_quick_overlay() -> Dictionary:
	if player == null or not player.has_method("is_driving_vehicle") or not bool(player.is_driving_vehicle()):
		_sync_vehicle_radio_quick_overlay()
		return {
			"success": false,
			"error": "not_driving",
		}
	if _full_map_open:
		return {
			"success": false,
			"error": "full_map_open",
		}
	if _vehicle_radio_browser_open:
		close_vehicle_radio_browser()
	if _vehicle_radio_quick_slots.is_empty():
		_rebuild_vehicle_radio_quick_slots()
	if _vehicle_radio_quick_slots.is_empty():
		return {
			"success": false,
			"error": "empty_slots",
		}
	_vehicle_radio_quick_overlay_open = true
	_sync_vehicle_radio_quick_selected_index_to_runtime_state()
	_apply_world_simulation_pause(true)
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_sync_vehicle_radio_quick_overlay()
	return {
		"success": true,
		"slot_count": _vehicle_radio_quick_slots.size(),
	}

func close_vehicle_radio_quick_overlay() -> Dictionary:
	if not _vehicle_radio_quick_overlay_open:
		_sync_vehicle_radio_quick_overlay()
		return {
			"success": false,
			"error": "not_open",
		}
	_vehicle_radio_quick_overlay_open = false
	_vehicle_radio_quick_selected_index = -1
	if not _full_map_open:
		_apply_world_simulation_pause(false)
		if DisplayServer.get_name() != "headless" and not _vehicle_radio_browser_open and not _controls_help_open:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_sync_vehicle_radio_quick_overlay()
	return {
		"success": true,
	}

func get_vehicle_radio_quick_overlay_state() -> Dictionary:
	return _build_vehicle_radio_quick_overlay_state()

func get_vehicle_radio_runtime_state() -> Dictionary:
	_sync_vehicle_radio_runtime_driving_context()
	if _vehicle_radio_controller != null and _vehicle_radio_controller.has_method("get_runtime_state"):
		return _vehicle_radio_controller.get_runtime_state()
	return {}

func get_vehicle_radio_debug_state() -> Dictionary:
	return _vehicle_radio_debug_state.duplicate(true)

func open_vehicle_radio_browser() -> Dictionary:
	if _full_map_open:
		return {
			"success": false,
			"error": "full_map_open",
		}
	if _vehicle_radio_quick_overlay_open:
		close_vehicle_radio_quick_overlay()
	_vehicle_radio_browser_open = true
	if not _is_vehicle_radio_browser_tab_id_valid(_vehicle_radio_browser_selected_tab_id):
		_vehicle_radio_browser_selected_tab_id = "browse"
	if _vehicle_radio_browser_cached_countries.is_empty():
		_ensure_vehicle_radio_browser_countries_ready()
	_apply_world_simulation_pause(true)
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_sync_vehicle_radio_browser()
	return {
		"success": true,
		"tab_count": int((_build_vehicle_radio_browser_state().get("tabs", []) as Array).size()),
	}

func close_vehicle_radio_browser() -> Dictionary:
	if not _vehicle_radio_browser_open:
		_sync_vehicle_radio_browser()
		return {
			"success": false,
			"error": "not_open",
		}
	_vehicle_radio_browser_open = false
	if not _full_map_open and not _vehicle_radio_quick_overlay_open:
		_apply_world_simulation_pause(false)
		if DisplayServer.get_name() != "headless" and not _controls_help_open:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_sync_vehicle_radio_browser()
	return {
		"success": true,
	}

func get_vehicle_radio_browser_state() -> Dictionary:
	return _build_vehicle_radio_browser_state()

func set_vehicle_radio_browser_tab(tab_id: String) -> Dictionary:
	if not _is_vehicle_radio_browser_tab_id_valid(tab_id):
		return {
			"success": false,
			"error": "invalid_tab",
		}
	_vehicle_radio_browser_selected_tab_id = tab_id
	_persist_vehicle_radio_session_state()
	_sync_vehicle_radio_browser()
	return {
		"success": true,
	}

func select_vehicle_radio_browser_country(country_code: String) -> Dictionary:
	if not _vehicle_radio_browser_open:
		return {
			"success": false,
			"error": "browser_closed",
		}
	var normalized_country_code := country_code.strip_edges().to_upper()
	if normalized_country_code == "":
		return {
			"success": false,
			"error": "invalid_country",
		}
	_vehicle_radio_browser_selected_tab_id = "browse"
	_vehicle_radio_browser_selected_country_code = normalized_country_code
	_vehicle_radio_browser_filter_text = ""
	_ensure_vehicle_radio_browser_station_rows_loaded(normalized_country_code)
	_persist_vehicle_radio_session_state()
	_sync_vehicle_radio_browser()
	return {
		"success": true,
		"selected_country_code": normalized_country_code,
	}

func set_vehicle_radio_browser_filter_text(filter_text: String) -> void:
	_vehicle_radio_browser_filter_text = filter_text.strip_edges()
	_persist_vehicle_radio_session_state()
	_sync_vehicle_radio_browser()

func show_vehicle_radio_browser_country_root() -> void:
	_vehicle_radio_browser_selected_tab_id = "browse"
	_vehicle_radio_browser_selected_country_code = ""
	_vehicle_radio_browser_filter_text = ""
	_ensure_vehicle_radio_browser_countries_ready()
	_persist_vehicle_radio_session_state()
	_sync_vehicle_radio_browser()

func refresh_vehicle_radio_browser_catalog() -> Dictionary:
	if _vehicle_radio_browser_selected_country_code == "":
		_vehicle_radio_browser_cached_countries = []
		_ensure_vehicle_radio_browser_countries_ready(true)
		_sync_vehicle_radio_browser()
		return {
			"success": true,
			"refreshed_kind": "countries",
		}
	_vehicle_radio_browser_cached_station_rows = []
	_ensure_vehicle_radio_browser_station_rows_loaded(_vehicle_radio_browser_selected_country_code, true)
	_sync_vehicle_radio_browser()
	return {
		"success": true,
		"refreshed_kind": "stations",
		"country_code": _vehicle_radio_browser_selected_country_code,
	}

func set_vehicle_radio_browser_proxy_mode(proxy_mode: String) -> Dictionary:
	var normalized_proxy_mode := _normalize_vehicle_radio_browser_proxy_mode(proxy_mode)
	if normalized_proxy_mode == "":
		return {
			"success": false,
			"error": "invalid_proxy_mode",
		}
	_vehicle_radio_catalog_proxy_mode = normalized_proxy_mode
	_apply_vehicle_radio_catalog_proxy_settings()
	_persist_vehicle_radio_session_state()
	_sync_vehicle_radio_browser()
	return {
		"success": true,
		"proxy_mode": _vehicle_radio_catalog_proxy_mode,
	}

func toggle_vehicle_radio_browser_favorite(station_id: String) -> Dictionary:
	var station_snapshot := _find_vehicle_radio_station_snapshot_by_id(station_id)
	if station_snapshot.is_empty():
		return {
			"success": false,
			"error": "station_not_found",
		}
	var favorites: Array = (_vehicle_radio_selection_sources.get("favorites", []) as Array).duplicate(true)
	var existing_index := _find_station_snapshot_index(favorites, station_id)
	if existing_index >= 0:
		favorites.remove_at(existing_index)
	else:
		favorites.append(station_snapshot)
	var save_result := _save_vehicle_radio_favorites(favorites)
	if not bool(save_result.get("success", false)):
		return save_result
	_reload_vehicle_radio_selection_sources_from_store()
	_sync_vehicle_radio_browser()
	_sync_vehicle_radio_quick_overlay()
	return {
		"success": true,
		"favorite_count": favorites.size(),
	}

func assign_vehicle_radio_browser_preset(slot_index: int, station_id: String) -> Dictionary:
	if slot_index < 0 or slot_index >= CityRadioQuickBank.MAX_SLOT_COUNT:
		return {
			"success": false,
			"error": "invalid_slot",
		}
	var station_snapshot := _find_vehicle_radio_station_snapshot_by_id(station_id)
	if station_snapshot.is_empty():
		return {
			"success": false,
			"error": "station_not_found",
		}
	var presets := _normalize_vehicle_radio_preset_entries(_vehicle_radio_selection_sources.get("presets", []) as Array)
	presets[slot_index] = {
		"slot_index": slot_index,
		"station_snapshot": station_snapshot,
	}
	var save_result := _save_vehicle_radio_presets(presets)
	if not bool(save_result.get("success", false)):
		return save_result
	_reload_vehicle_radio_selection_sources_from_store()
	_rebuild_vehicle_radio_quick_slots()
	_sync_vehicle_radio_browser()
	_sync_vehicle_radio_quick_overlay()
	return {
		"success": true,
		"slot_index": slot_index,
	}

func select_vehicle_radio_browser_station(station_id: String) -> Dictionary:
	var station_snapshot := _find_vehicle_radio_station_snapshot_by_id(station_id)
	if station_snapshot.is_empty():
		return {
			"success": false,
			"error": "station_not_found",
		}
	var resolved_stream := _build_vehicle_radio_resolved_stream(station_snapshot)
	if resolved_stream.is_empty():
		return {
			"success": false,
			"error": "stream_unavailable",
		}
	return _activate_vehicle_radio_station_playback(station_snapshot, resolved_stream, true)

func play_vehicle_radio_browser_selected_station() -> Dictionary:
	var runtime_state: Dictionary = get_vehicle_radio_runtime_state()
	var station_snapshot := _sanitize_vehicle_radio_station_snapshot((runtime_state.get("selected_station_snapshot", {}) as Dictionary).duplicate(true))
	if station_snapshot.is_empty():
		return {
			"success": false,
			"error": "station_not_selected",
		}
	var resolved_stream := _build_vehicle_radio_resolved_stream(station_snapshot)
	if resolved_stream.is_empty():
		return {
			"success": false,
			"error": "stream_unavailable",
		}
	return _activate_vehicle_radio_station_playback(station_snapshot, resolved_stream, true)

func stop_vehicle_radio_browser_playback() -> Dictionary:
	if _vehicle_radio_controller == null:
		return {
			"success": false,
			"error": "controller_unavailable",
		}
	_vehicle_radio_power_on = false
	if _vehicle_radio_controller.has_method("set_browser_preview_enabled"):
		_vehicle_radio_controller.set_browser_preview_enabled(false)
	if _vehicle_radio_controller.has_method("set_power_state"):
		_vehicle_radio_controller.set_power_state(false)
	if _vehicle_radio_controller.has_method("stop"):
		_vehicle_radio_controller.stop("browser_stop")
	_persist_vehicle_radio_session_state()
	_sync_vehicle_radio_browser()
	_sync_vehicle_radio_quick_overlay()
	return {
		"success": true,
		"power_state": "off",
	}

func set_vehicle_radio_browser_volume_linear(volume_linear: float) -> Dictionary:
	if _vehicle_radio_controller == null or not _vehicle_radio_controller.has_method("set_volume_linear"):
		return {
			"success": false,
			"error": "controller_unavailable",
		}
	var clamped_volume := clampf(volume_linear, 0.0, 1.0)
	_vehicle_radio_controller.set_volume_linear(clamped_volume)
	_persist_vehicle_radio_session_state()
	_sync_vehicle_radio_browser()
	return {
		"success": true,
		"volume_linear": clamped_volume,
	}

func set_vehicle_radio_selection_sources(presets: Array, favorites: Array, recents: Array) -> void:
	_vehicle_radio_selection_sources = {
		"presets": presets.duplicate(true),
		"favorites": favorites.duplicate(true),
		"recents": recents.duplicate(true),
	}
	_rebuild_vehicle_radio_quick_slots()
	_sync_vehicle_radio_browser()
	_sync_vehicle_radio_quick_overlay()

func _handle_fast_travel_shortcut() -> bool:
	if _active_destination_target.is_empty():
		return false
	var result: Dictionary = fast_travel_to_active_destination(FAST_TRAVEL_SHORTCUT_AIR_DROP_HEIGHT_M, false)
	if not bool(result.get("success", false)):
		return false
	if _full_map_open:
		set_full_map_open(false)
	_refresh_hud_status({}, true)
	return true

func handle_debug_keypress(keycode: int, physical_keycode: int = 0) -> bool:
	if keycode == KEY_C:
		set_control_mode(CONTROL_MODE_INSPECTION if _control_mode == CONTROL_MODE_PLAYER else CONTROL_MODE_PLAYER)
		return true
	if keycode == KEY_KP_MULTIPLY or physical_keycode == KEY_KP_MULTIPLY:
		toggle_pedestrians_visible()
		return true
	if keycode == KEY_KP_SUBTRACT or physical_keycode == KEY_KP_SUBTRACT:
		toggle_fps_overlay()
		return true
	if keycode == KEY_KP_DIVIDE or physical_keycode == KEY_KP_DIVIDE:
		spawn_trauma_enemy()
		return true
	return false

func _handle_vehicle_radio_action(action_name: String) -> bool:
	match action_name:
		"vehicle_radio_quick_open":
			if _vehicle_radio_quick_overlay_open:
				return bool(close_vehicle_radio_quick_overlay().get("success", false))
			if _vehicle_radio_browser_open:
				close_vehicle_radio_browser()
			return bool(open_vehicle_radio_quick_overlay().get("success", false))
		"vehicle_radio_cancel":
			if _vehicle_radio_browser_open:
				return bool(close_vehicle_radio_browser().get("success", false))
			return bool(close_vehicle_radio_quick_overlay().get("success", false))
		"vehicle_radio_browser_open":
			_vehicle_radio_browser_request_count += 1
			if _vehicle_radio_browser_open:
				return bool(close_vehicle_radio_browser().get("success", false))
			if _vehicle_radio_quick_overlay_open:
				close_vehicle_radio_quick_overlay()
			return bool(open_vehicle_radio_browser().get("success", false))
	if not _vehicle_radio_quick_overlay_open:
		return false
	match action_name:
		"vehicle_radio_next":
			_step_vehicle_radio_quick_selection(1)
			return true
		"vehicle_radio_prev":
			_step_vehicle_radio_quick_selection(-1)
			return true
		"vehicle_radio_power_toggle":
			_vehicle_radio_power_on = not _vehicle_radio_power_on
			if _vehicle_radio_controller != null and _vehicle_radio_controller.has_method("set_power_state"):
				_vehicle_radio_controller.set_power_state(_vehicle_radio_power_on)
			_persist_vehicle_radio_session_state()
			_sync_vehicle_radio_browser()
			_sync_vehicle_radio_quick_overlay()
			return true
		"vehicle_radio_confirm":
			_commit_vehicle_radio_quick_selection()
			_sync_vehicle_radio_browser()
			_sync_vehicle_radio_quick_overlay()
			return true
	return false

func _handle_vehicle_radio_bound_input(event: InputEvent) -> bool:
	for action_name_variant in VEHICLE_RADIO_INPUT_ACTIONS:
		var action_name := str(action_name_variant)
		if event.is_action_pressed(action_name, false, true):
			return _handle_vehicle_radio_action(action_name)
	return false

func _refresh_hud_status(snapshot_override: Dictionary = {}, force: bool = false) -> void:
	if not force and not _should_refresh_hud():
		return
	var refresh_started_usec := Time.get_ticks_usec()
	if not generated_city.has_method("get_city_summary"):
		return
	if hud == null:
		return
	_sync_vehicle_radio_quick_overlay()
	var is_headless := DisplayServer.get_name() == "headless"
	if is_headless:
		if _should_refresh_hud_minimap(true):
			build_minimap_snapshot()
			_last_minimap_hud_refresh_tick_usec = Time.get_ticks_usec()
		if hud.has_method("set_crosshair_state"):
			hud.set_crosshair_state(_build_crosshair_state())
		_last_hud_refresh_tick_usec = Time.get_ticks_usec()
		_record_hud_refresh_sample(Time.get_ticks_usec() - refresh_started_usec)
		return
	var hud_debug_expanded := hud.has_method("is_debug_expanded") and bool(hud.is_debug_expanded())
	var snapshot: Dictionary = {}
	if hud_debug_expanded:
		snapshot = snapshot_override.duplicate(false) if not snapshot_override.is_empty() else _build_hud_snapshot(false)
	if hud_debug_expanded and hud.has_method("set_status"):
		var world_summary := str(_world_data.get("summary", "World data unavailable"))
		var active_speed_text := ""
		if player != null and player.has_method("get_walk_speed_mps") and player.has_method("get_sprint_speed_mps"):
			active_speed_text = "move_speed=%.1f / %.1f m/s" % [float(player.get_walk_speed_mps()), float(player.get_sprint_speed_mps())]
		var lines := PackedStringArray([
			"City sandbox skeleton",
			"WASD / arrows move",
			"Shift sprint  Space jump",
			"Mouse rotates player camera  Esc releases cursor",
			"Press C to toggle normal / inspection speed",
			"0 laser  1 rifle  2 grenade  8 missile  Left click fires / throws / inspects  Right click ADS / hold grenade",
			"Numpad / spawns trauma squad enemy",
			"Numpad * toggles pedestrians  Numpad - toggles FPS overlay",
			"control_mode=%s" % _control_mode,
			"pedestrian_visible=%s fps_overlay_visible=%s" % [str(are_pedestrians_visible()), str(_fps_overlay_visible)],
			"tracked_position=%s" % str(_vector3_to_dict(player.global_position if player != null else Vector3.ZERO)),
			generated_city.get_city_summary(),
			world_summary,
			"current_chunk_id=%s | active_chunk_count=%d" % [
				str(snapshot.get("current_chunk_id", "")),
				int(snapshot.get("active_chunk_count", 0))
			],
			"current_chunk_lod=%s" % str(snapshot.get("current_chunk_lod_mode", "")),
			"visual_variant=%s" % str(snapshot.get("current_chunk_visual_variant_id", "")),
			"combat=player_projectiles:%d grenades:%d missiles:%d enemy_projectiles:%d enemies:%d" % [
				get_active_projectile_count(),
				get_active_grenade_count(),
				get_active_missile_count(),
				get_active_enemy_projectile_count(),
				get_active_enemy_count()
			],
			_weapon_status_text(),
			active_speed_text,
		])
		hud.set_status("\n".join(lines))
	if hud_debug_expanded and hud.has_method("set_debug_text") and debug_overlay != null and debug_overlay.has_method("get_debug_text"):
		hud.set_debug_text(debug_overlay.get_debug_text())
	if hud.has_method("set_minimap_snapshot") and _should_refresh_hud_minimap(false):
		hud.set_minimap_snapshot(build_minimap_snapshot())
		_last_minimap_hud_refresh_tick_usec = Time.get_ticks_usec()
	if hud.has_method("set_crosshair_state"):
		hud.set_crosshair_state(_build_crosshair_state())
	if hud.has_method("set_fps_overlay_visible"):
		hud.set_fps_overlay_visible(_fps_overlay_visible)
	_last_hud_refresh_tick_usec = Time.get_ticks_usec()
	_record_hud_refresh_sample(Time.get_ticks_usec() - refresh_started_usec)

func get_world_config():
	return _world_config

func get_world_data() -> Dictionary:
	return _world_data

func get_chunk_streamer():
	return _chunk_streamer

func get_chunk_renderer():
	return chunk_renderer

func get_pedestrian_runtime_snapshot() -> Dictionary:
	if chunk_renderer == null or not chunk_renderer.has_method("get_pedestrian_runtime_snapshot"):
		return {}
	return chunk_renderer.get_pedestrian_runtime_snapshot()

func get_vehicle_runtime_snapshot() -> Dictionary:
	if chunk_renderer == null or not chunk_renderer.has_method("get_vehicle_runtime_snapshot"):
		return {}
	return chunk_renderer.get_vehicle_runtime_snapshot()

func get_navigation_runtime():
	return _navigation_runtime

func get_task_catalog():
	return _task_catalog

func get_task_slot_index():
	return _task_slot_index

func get_task_runtime():
	return _task_runtime

func get_task_runtime_snapshot() -> Dictionary:
	if _task_runtime == null or not _task_runtime.has_method("get_state_snapshot"):
		return {}
	return _task_runtime.get_state_snapshot()

func get_npc_interaction_state() -> Dictionary:
	if _npc_interaction_runtime == null or not _npc_interaction_runtime.has_method("get_state"):
		return {}
	return _npc_interaction_runtime.get_state()

func get_interactive_prop_interaction_state() -> Dictionary:
	if _interactive_prop_runtime == null or not _interactive_prop_runtime.has_method("get_state"):
		return {}
	var state: Dictionary = (_interactive_prop_runtime.get_state() as Dictionary).duplicate(true)
	return _augment_tennis_interaction_prompt_state(state)

func get_primary_interaction_state() -> Dictionary:
	return _resolve_primary_interaction_prompt_state()

func get_dialogue_runtime_state() -> Dictionary:
	if _dialogue_runtime == null or not _dialogue_runtime.has_method("get_state"):
		return {
			"status": "idle",
		}
	return _dialogue_runtime.get_state()

func get_tracked_task_id() -> String:
	if _task_runtime == null or not _task_runtime.has_method("get_tracked_task_id"):
		return ""
	return str(_task_runtime.get_tracked_task_id())

func get_tracked_task_snapshot() -> Dictionary:
	if _task_runtime == null or not _task_runtime.has_method("get_tracked_task_snapshot"):
		return {}
	return _task_runtime.get_tracked_task_snapshot()

func get_task_world_marker_state() -> Dictionary:
	if _task_world_marker_runtime == null or not _task_world_marker_runtime.has_method("get_state"):
		return {}
	return _task_world_marker_runtime.get_state()

func get_helicopter_gunship_encounter_state() -> Dictionary:
	if _helicopter_gunship_encounter_runtime == null or not _helicopter_gunship_encounter_runtime.has_method("get_state"):
		return {}
	return _helicopter_gunship_encounter_runtime.get_state()

func get_active_helicopter_gunship() -> Node3D:
	if _helicopter_gunship_encounter_runtime == null or not _helicopter_gunship_encounter_runtime.has_method("get_active_gunship"):
		return null
	return _helicopter_gunship_encounter_runtime.get_active_gunship()

func is_player_driving_vehicle() -> bool:
	return player != null and player.has_method("is_driving_vehicle") and bool(player.is_driving_vehicle())

func get_player_vehicle_state() -> Dictionary:
	if player == null or not player.has_method("get_driving_vehicle_state"):
		return {}
	return player.get_driving_vehicle_state()

func fire_player_projectile() -> Node3D:
	if player == null or not player.has_method("get_projectile_spawn_transform") or not player.has_method("get_projectile_direction"):
		return null
	var spawn_transform: Transform3D = player.get_projectile_spawn_transform()
	return _spawn_projectile(spawn_transform.origin, player.get_projectile_direction())

func fire_player_projectile_toward(target_world_position: Vector3) -> Node3D:
	if player == null or not player.has_method("get_projectile_spawn_transform"):
		return null
	var spawn_transform: Transform3D = player.get_projectile_spawn_transform()
	var direction := (target_world_position - spawn_transform.origin).normalized()
	if direction.length_squared() <= 0.0001:
		direction = player.get_projectile_direction() if player.has_method("get_projectile_direction") else -spawn_transform.basis.z
	return _spawn_projectile(spawn_transform.origin, direction)

func get_active_projectile_count() -> int:
	return 0 if _projectile_root == null else _projectile_root.get_child_count()

func get_active_grenade_count() -> int:
	return 0 if _grenade_root == null else _grenade_root.get_child_count()

func get_active_missile_count() -> int:
	return 0 if _missile_root == null else _missile_root.get_child_count()

func get_active_laser_beam_count() -> int:
	return 0 if _laser_beam_root == null else _laser_beam_root.get_child_count()

func get_last_laser_designator_result() -> Dictionary:
	return _last_laser_designator_result.duplicate(true)

func get_last_laser_designator_clipboard_text() -> String:
	return _last_laser_designator_clipboard_text

func get_last_missile_explosion_result() -> Dictionary:
	return _last_missile_explosion_result.duplicate(true)

func get_building_generation_contract(building_id: String) -> Dictionary:
	if chunk_renderer == null or not chunk_renderer.has_method("get_building_generation_contract"):
		return {}
	return chunk_renderer.get_building_generation_contract(building_id)

func configure_building_serviceability_paths(preferred_scene_root: String, fallback_scene_root: String = "", registry_path: String = "") -> void:
	var resolved_preferred := _normalize_serviceability_resource_path(preferred_scene_root)
	var resolved_fallback := _normalize_serviceability_resource_path(fallback_scene_root)
	_building_serviceability_preferred_scene_root = resolved_preferred if resolved_preferred != "" else BUILDING_EXPORT_SCENE_ROOT_PREFERRED
	_building_serviceability_fallback_scene_root = resolved_fallback if resolved_fallback != "" else BUILDING_EXPORT_SCENE_ROOT_FALLBACK
	_building_serviceability_registry_override_path = _normalize_serviceability_resource_path(registry_path)
	if is_inside_tree():
		_reload_building_override_registry()

func request_export_from_last_building_inspection() -> Dictionary:
	_collect_completed_building_export_job()
	_expire_exportable_building_inspection_window()
	if bool(_building_export_state.get("running", false)):
		return {
			"accepted": false,
			"error": "export_running",
			"building_id": str(_building_export_state.get("building_id", "")),
		}
	if _exportable_building_inspection_result.is_empty():
		return {
			"accepted": false,
			"error": "missing_exportable_building",
		}
	var export_request := _build_building_export_request(_exportable_building_inspection_result)
	var building_id := str(export_request.get("building_id", ""))
	var building_contract: Dictionary = export_request.get("building_contract", {})
	if building_id == "" or building_contract.is_empty():
		_clear_exportable_building_inspection_window()
		return {
			"accepted": false,
			"error": "missing_building_contract",
		}
	var existing_override_entry: Dictionary = get_building_override_entry(building_id)
	if not existing_override_entry.is_empty():
		_clear_exportable_building_inspection_window()
		return {
			"accepted": false,
			"error": "override_exists",
			"building_id": building_id,
		}
	_building_export_request = export_request.duplicate(true)
	_building_export_state = {
		"running": true,
		"status": "running",
		"building_id": building_id,
		"display_name": str(export_request.get("display_name", "")),
		"scene_root": "",
		"scene_path": "",
		"manifest_path": "",
		"error": "",
		"export_root_kind": "",
	}
	_show_building_export_toast(_build_building_export_started_message(_building_export_state), 2.5)
	_building_export_pending_result.clear()
	_building_export_started_process_frame = Engine.get_process_frames()
	_clear_exportable_building_inspection_window()
	var thread := Thread.new()
	var start_error := thread.start(Callable(self, "_run_building_export_thread").bind(export_request))
	if start_error != OK:
		_building_export_thread = null
		_finalize_building_export_result(_run_building_export_thread(export_request))
		return {
			"accepted": true,
			"started_async": false,
			"building_id": building_id,
		}
	_building_export_thread = thread
	return {
		"accepted": true,
		"started_async": true,
		"building_id": building_id,
	}

func get_building_export_state() -> Dictionary:
	return _building_export_state.duplicate(true)

func get_building_override_entry(building_id: String) -> Dictionary:
	if building_id == "":
		return {}
	if _building_override_registry != null and _building_override_registry.has_method("get_entry"):
		var registry_entry: Dictionary = _building_override_registry.get_entry(building_id)
		if not registry_entry.is_empty():
			return registry_entry
	if chunk_renderer != null and chunk_renderer.has_method("get_building_override_entry"):
		return chunk_renderer.get_building_override_entry(building_id)
	return {}

func find_building_override_node(building_id: String) -> Node:
	if building_id == "" or chunk_renderer == null or not chunk_renderer.has_method("find_building_override_node"):
		return null
	return chunk_renderer.find_building_override_node(building_id)

func get_active_enemy_projectile_count() -> int:
	return 0 if _enemy_projectile_root == null else _enemy_projectile_root.get_child_count()

func throw_player_grenade() -> Node3D:
	if player == null or not player.has_method("get_grenade_spawn_transform") or not player.has_method("get_grenade_launch_velocity"):
		return null
	var spawn_transform: Transform3D = player.get_grenade_spawn_transform()
	return _spawn_grenade(spawn_transform.origin, player.get_grenade_launch_velocity())

func fire_player_missile_launcher() -> Node3D:
	if player == null or not player.has_method("get_projectile_spawn_transform") or not player.has_method("get_projectile_direction"):
		return null
	var spawn_transform: Transform3D = player.get_projectile_spawn_transform()
	return _spawn_missile(spawn_transform.origin, player.get_projectile_direction())

func fire_player_laser_designator() -> Dictionary:
	if player == null or not player.has_method("get_aim_trace_segment"):
		return {}
	var trace_segment: Dictionary = player.get_aim_trace_segment()
	return inspect_laser_designator_segment(
		trace_segment.get("origin", Vector3.ZERO),
		trace_segment.get("target", Vector3.ZERO)
	)

func inspect_laser_designator_segment(origin: Vector3, target: Vector3) -> Dictionary:
	_ensure_combat_roots()
	var hit: Dictionary = _perform_laser_designator_trace(origin, target)
	if hit.is_empty():
		_clear_exportable_building_inspection_window()
		return {}
	var hit_position: Vector3 = hit.get("position", target)
	if _laser_beam_root != null:
		var beam := CityLaserDesignatorBeam.new()
		beam.configure(origin, hit_position)
		_laser_beam_root.add_child(beam)
	var inspection_result: Dictionary = {}
	if _inspection_resolver != null and _inspection_resolver.has_method("resolve_hit"):
		inspection_result = _inspection_resolver.resolve_hit(hit, chunk_renderer)
	_last_laser_designator_result = inspection_result.duplicate(true)
	var message_text := str(inspection_result.get("message_text", ""))
	var clipboard_text := str(inspection_result.get("clipboard_text", message_text))
	if hud != null and hud.has_method("set_focus_message"):
		if message_text != "":
			hud.set_focus_message(message_text, 10.0)
	if clipboard_text != "":
		_commit_laser_designator_clipboard_text(clipboard_text)
	_update_exportable_building_inspection_result(inspection_result)
	return inspection_result

func spawn_trauma_enemy() -> CharacterBody3D:
	var spawn_position := _resolve_enemy_spawn_world_position(_get_active_anchor_position())
	return spawn_trauma_enemy_at_world_position(spawn_position)

func spawn_trauma_enemy_at_world_position(world_position: Vector3) -> CharacterBody3D:
	_ensure_combat_roots()
	if _enemy_root == null:
		return null
	var enemy := CityTraumaEnemy.new()
	if enemy.has_method("configure"):
		enemy.configure(player)
	_connect_enemy_combat(enemy)
	var standing_height := enemy.get_standing_height() if enemy.has_method("get_standing_height") else 1.0
	var grounded_position := _resolve_nearby_enemy_spawn_world_position(world_position, standing_height)
	_enemy_root.add_child(enemy)
	enemy.global_position = grounded_position
	return enemy

func get_active_enemy_count() -> int:
	if _enemy_root == null:
		return 0
	var active_count := 0
	for child in _enemy_root.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if child.has_method("is_combat_active"):
			if child.is_combat_active():
				active_count += 1
			continue
		active_count += 1
	return active_count

func get_control_mode() -> String:
	return _control_mode

func set_control_mode(mode: String) -> void:
	if mode != CONTROL_MODE_PLAYER and mode != CONTROL_MODE_INSPECTION:
		return
	_control_mode = mode
	if player != null and player.has_method("set_control_enabled"):
		player.set_control_enabled(true)
	if player != null and player.has_method("set_speed_profile"):
		player.set_speed_profile(mode)
	_set_camera_current(player.get_node_or_null("CameraRig/Camera3D"), true)
	_refresh_hud_status({}, true)

func set_pedestrians_visible(should_be_visible: bool) -> void:
	_pedestrians_visible = should_be_visible
	if chunk_renderer != null and chunk_renderer.has_method("set_pedestrians_visible"):
		chunk_renderer.set_pedestrians_visible(should_be_visible)
	_refresh_hud_status({}, true)

func toggle_pedestrians_visible() -> void:
	set_pedestrians_visible(not _pedestrians_visible)

func are_pedestrians_visible() -> bool:
	if chunk_renderer != null and chunk_renderer.has_method("are_pedestrians_visible"):
		return bool(chunk_renderer.are_pedestrians_visible())
	return _pedestrians_visible

func set_fps_overlay_visible(should_be_visible: bool) -> void:
	_fps_overlay_visible = should_be_visible
	if hud != null and hud.has_method("set_fps_overlay_visible"):
		hud.set_fps_overlay_visible(should_be_visible)
	if hud != null and hud.has_method("set_fps_overlay_sample"):
		hud.set_fps_overlay_sample(_last_fps_sample)
	_refresh_hud_status({}, true)

func toggle_fps_overlay() -> void:
	set_fps_overlay_visible(not _fps_overlay_visible)

func is_fps_overlay_visible() -> bool:
	return _fps_overlay_visible

func set_performance_diagnostics_enabled(enabled: bool) -> void:
	_performance_diagnostics_enabled = enabled
	if chunk_renderer != null and chunk_renderer.has_method("set_detailed_streaming_diagnostics_enabled"):
		chunk_renderer.set_detailed_streaming_diagnostics_enabled(enabled)

func get_streaming_snapshot() -> Dictionary:
	if _chunk_streamer == null:
		return {}
	var snapshot: Dictionary = _chunk_streamer.get_streaming_snapshot()
	if chunk_renderer != null and chunk_renderer.has_method("get_renderer_stats"):
		snapshot.merge(chunk_renderer.get_renderer_stats(), true)
	snapshot["control_mode"] = _control_mode
	snapshot["tracked_position"] = _vector3_to_dict(player.global_position if player != null else Vector3.ZERO)
	snapshot["pedestrian_visible"] = are_pedestrians_visible()
	snapshot["fps_overlay_visible"] = _fps_overlay_visible
	snapshot["pedestrian_mode"] = str(snapshot.get("pedestrian_mode", (snapshot.get("pedestrian_budget_contract", {}) as Dictionary).get("preset", "lite")))
	snapshot["vehicle_mode"] = str(snapshot.get("vehicle_mode", "lite"))
	snapshot["ped_tier0_count"] = int(snapshot.get("pedestrian_tier0_total", snapshot.get("ped_tier0_count", 0)))
	snapshot["ped_tier1_count"] = int(snapshot.get("pedestrian_tier1_total", snapshot.get("ped_tier1_count", 0)))
	snapshot["ped_tier2_count"] = int(snapshot.get("pedestrian_tier2_total", snapshot.get("ped_tier2_count", 0)))
	snapshot["ped_tier3_count"] = int(snapshot.get("pedestrian_tier3_total", snapshot.get("ped_tier3_count", 0)))
	snapshot["ped_page_cache_hit_count"] = int(snapshot.get("pedestrian_page_cache_hit_count", 0))
	snapshot["ped_page_cache_miss_count"] = int(snapshot.get("pedestrian_page_cache_miss_count", 0))
	snapshot["ped_duplicate_page_load_count"] = int(snapshot.get("pedestrian_duplicate_page_load_count", 0))
	snapshot["veh_tier0_count"] = int(snapshot.get("vehicle_tier0_total", snapshot.get("veh_tier0_count", 0)))
	snapshot["veh_tier1_count"] = int(snapshot.get("vehicle_tier1_total", snapshot.get("veh_tier1_count", 0)))
	snapshot["veh_tier2_count"] = int(snapshot.get("vehicle_tier2_total", snapshot.get("veh_tier2_count", 0)))
	snapshot["veh_tier3_count"] = int(snapshot.get("vehicle_tier3_total", snapshot.get("veh_tier3_count", 0)))
	snapshot["veh_page_cache_hit_count"] = int(snapshot.get("vehicle_page_cache_hit_count", 0))
	snapshot["veh_page_cache_miss_count"] = int(snapshot.get("vehicle_page_cache_miss_count", 0))
	snapshot["veh_duplicate_page_load_count"] = int(snapshot.get("vehicle_duplicate_page_load_count", 0))
	var current_chunk_id := str(snapshot.get("current_chunk_id", ""))
	if current_chunk_id != "" and chunk_renderer != null and chunk_renderer.has_method("get_chunk_scene_stats"):
		var current_chunk_stats: Dictionary = chunk_renderer.get_chunk_scene_stats(current_chunk_id)
		snapshot["current_chunk_multimesh_instance_count"] = int(current_chunk_stats.get("multimesh_instance_count", 0))
		snapshot["current_chunk_lod_mode"] = str(current_chunk_stats.get("lod_mode", ""))
		snapshot["current_chunk_visual_variant_id"] = str(current_chunk_stats.get("visual_variant_id", ""))
	return snapshot

func _build_hud_snapshot(collapsed: bool = false) -> Dictionary:
	if not collapsed:
		return get_streaming_snapshot()
	var snapshot: Dictionary = _chunk_streamer.get_streaming_snapshot() if _chunk_streamer != null else {}
	snapshot["control_mode"] = _control_mode
	snapshot["tracked_position"] = _vector3_to_dict(player.global_position if player != null else Vector3.ZERO)
	snapshot["pedestrian_visible"] = are_pedestrians_visible()
	snapshot["fps_overlay_visible"] = _fps_overlay_visible
	if chunk_renderer != null:
		if chunk_renderer.has_method("get_streaming_budget_stats"):
			snapshot.merge(chunk_renderer.get_streaming_budget_stats(), true)
		if chunk_renderer.has_method("get_streaming_profile_stats"):
			var streaming_profile: Dictionary = chunk_renderer.get_streaming_profile_stats()
			snapshot["crowd_update_avg_usec"] = int(streaming_profile.get("crowd_update_avg_usec", 0))
			snapshot["crowd_spawn_avg_usec"] = int(streaming_profile.get("crowd_spawn_avg_usec", 0))
			snapshot["crowd_render_commit_avg_usec"] = int(streaming_profile.get("crowd_render_commit_avg_usec", 0))
			snapshot["crowd_active_state_count"] = int(streaming_profile.get("crowd_active_state_count", 0))
			snapshot["crowd_step_usec"] = int(streaming_profile.get("crowd_step_usec", 0))
			snapshot["crowd_reaction_usec"] = int(streaming_profile.get("crowd_reaction_usec", 0))
			snapshot["crowd_rank_usec"] = int(streaming_profile.get("crowd_rank_usec", 0))
			snapshot["crowd_snapshot_rebuild_usec"] = int(streaming_profile.get("crowd_snapshot_rebuild_usec", 0))
			snapshot["crowd_farfield_count"] = int(streaming_profile.get("crowd_farfield_count", 0))
			snapshot["crowd_midfield_count"] = int(streaming_profile.get("crowd_midfield_count", 0))
			snapshot["crowd_nearfield_count"] = int(streaming_profile.get("crowd_nearfield_count", 0))
			snapshot["crowd_farfield_step_usec"] = int(streaming_profile.get("crowd_farfield_step_usec", 0))
			snapshot["crowd_midfield_step_usec"] = int(streaming_profile.get("crowd_midfield_step_usec", 0))
			snapshot["crowd_nearfield_step_usec"] = int(streaming_profile.get("crowd_nearfield_step_usec", 0))
			snapshot["crowd_assignment_rebuild_usec"] = int(streaming_profile.get("crowd_assignment_rebuild_usec", 0))
			snapshot["crowd_assignment_candidate_count"] = int(streaming_profile.get("crowd_assignment_candidate_count", 0))
			snapshot["crowd_threat_broadcast_usec"] = int(streaming_profile.get("crowd_threat_broadcast_usec", 0))
			snapshot["crowd_threat_candidate_count"] = int(streaming_profile.get("crowd_threat_candidate_count", 0))
			snapshot["crowd_chunk_commit_usec"] = int(streaming_profile.get("crowd_chunk_commit_usec", 0))
			snapshot["crowd_tier1_transform_writes"] = int(streaming_profile.get("crowd_tier1_transform_writes", 0))
			snapshot["traffic_update_avg_usec"] = int(streaming_profile.get("traffic_update_avg_usec", 0))
			snapshot["traffic_spawn_avg_usec"] = int(streaming_profile.get("traffic_spawn_avg_usec", 0))
			snapshot["traffic_render_commit_avg_usec"] = int(streaming_profile.get("traffic_render_commit_avg_usec", 0))
			snapshot["traffic_active_state_count"] = int(streaming_profile.get("traffic_active_state_count", 0))
			snapshot["traffic_step_usec"] = int(streaming_profile.get("traffic_step_usec", 0))
			snapshot["traffic_rank_usec"] = int(streaming_profile.get("traffic_rank_usec", 0))
			snapshot["traffic_snapshot_rebuild_usec"] = int(streaming_profile.get("traffic_snapshot_rebuild_usec", 0))
			snapshot["traffic_tier1_count"] = int(streaming_profile.get("traffic_tier1_count", 0))
			snapshot["traffic_tier2_count"] = int(streaming_profile.get("traffic_tier2_count", 0))
			snapshot["traffic_tier3_count"] = int(streaming_profile.get("traffic_tier3_count", 0))
			snapshot["traffic_chunk_commit_usec"] = int(streaming_profile.get("traffic_chunk_commit_usec", 0))
			snapshot["traffic_tier1_transform_writes"] = int(streaming_profile.get("traffic_tier1_transform_writes", 0))
		if chunk_renderer.has_method("get_pedestrian_runtime_summary"):
			snapshot.merge(chunk_renderer.get_pedestrian_runtime_summary(), true)
		if chunk_renderer.has_method("get_vehicle_runtime_summary"):
			snapshot.merge(chunk_renderer.get_vehicle_runtime_summary(), true)
	return snapshot

func _prewarm_actor_pages_around_spawn() -> void:
	if _chunk_streamer == null or chunk_renderer == null or not chunk_renderer.has_method("prewarm_actor_pages"):
		return
	var active_entries: Array = _chunk_streamer.get_active_chunk_entries()
	if active_entries.is_empty():
		return
	var min_key := Vector2i(2147483647, 2147483647)
	var max_key := Vector2i(-2147483648, -2147483648)
	for entry_variant in active_entries:
		var entry: Dictionary = entry_variant
		var chunk_key: Vector2i = entry.get("chunk_key", Vector2i.ZERO)
		min_key.x = mini(min_key.x, chunk_key.x)
		min_key.y = mini(min_key.y, chunk_key.y)
		max_key.x = maxi(max_key.x, chunk_key.x)
		max_key.y = maxi(max_key.y, chunk_key.y)
	var prewarm_entries: Array[Dictionary] = []
	for chunk_x in range(min_key.x - ACTOR_PAGE_PREWARM_RING_RADIUS_CHUNKS, max_key.x + ACTOR_PAGE_PREWARM_RING_RADIUS_CHUNKS + 1):
		for chunk_y in range(min_key.y - ACTOR_PAGE_PREWARM_RING_RADIUS_CHUNKS, max_key.y + ACTOR_PAGE_PREWARM_RING_RADIUS_CHUNKS + 1):
			var chunk_key := Vector2i(chunk_x, chunk_y)
			prewarm_entries.append({
				"chunk_key": chunk_key,
				"chunk_id": _world_config.format_chunk_id(chunk_key),
			})
	chunk_renderer.prewarm_actor_pages(prewarm_entries)
	if chunk_renderer.has_method("prewarm_chunk_pages"):
		var page_prewarm_entries: Array[Dictionary] = []
		for chunk_x in range(min_key.x - CHUNK_PAGE_PREWARM_RING_RADIUS_CHUNKS, max_key.x + CHUNK_PAGE_PREWARM_RING_RADIUS_CHUNKS + 1):
			for chunk_y in range(min_key.y - CHUNK_PAGE_PREWARM_RING_RADIUS_CHUNKS, max_key.y + CHUNK_PAGE_PREWARM_RING_RADIUS_CHUNKS + 1):
				var page_chunk_key := Vector2i(chunk_x, chunk_y)
				page_prewarm_entries.append({
					"chunk_key": page_chunk_key,
					"chunk_id": _world_config.format_chunk_id(page_chunk_key),
				})
		chunk_renderer.prewarm_chunk_pages(page_prewarm_entries, false, true)

func _ensure_combat_roots() -> void:
	if _combat_root == null:
		_combat_root = get_node_or_null("CombatRoot") as Node3D
		if _combat_root == null:
			_combat_root = Node3D.new()
			_combat_root.name = "CombatRoot"
			add_child(_combat_root)
	if _projectile_root == null:
		_projectile_root = _combat_root.get_node_or_null("Projectiles") as Node3D
		if _projectile_root == null:
			_projectile_root = Node3D.new()
			_projectile_root.name = "Projectiles"
			_combat_root.add_child(_projectile_root)
	if _grenade_root == null:
		_grenade_root = _combat_root.get_node_or_null("Grenades") as Node3D
		if _grenade_root == null:
			_grenade_root = Node3D.new()
			_grenade_root.name = "Grenades"
			_combat_root.add_child(_grenade_root)
	if _missile_root == null:
		_missile_root = _combat_root.get_node_or_null("Missiles") as Node3D
		if _missile_root == null:
			_missile_root = Node3D.new()
			_missile_root.name = "Missiles"
			_combat_root.add_child(_missile_root)
	if _laser_beam_root == null:
		_laser_beam_root = _combat_root.get_node_or_null("LaserBeams") as Node3D
		if _laser_beam_root == null:
			_laser_beam_root = Node3D.new()
			_laser_beam_root.name = "LaserBeams"
			_combat_root.add_child(_laser_beam_root)
	if _enemy_projectile_root == null:
		_enemy_projectile_root = _combat_root.get_node_or_null("EnemyProjectiles") as Node3D
		if _enemy_projectile_root == null:
			_enemy_projectile_root = Node3D.new()
			_enemy_projectile_root.name = "EnemyProjectiles"
			_combat_root.add_child(_enemy_projectile_root)
	if _enemy_root == null:
		_enemy_root = _combat_root.get_node_or_null("Enemies") as Node3D
		if _enemy_root == null:
			_enemy_root = Node3D.new()
			_enemy_root.name = "Enemies"
			_combat_root.add_child(_enemy_root)

func _connect_player_combat() -> void:
	if player == null:
		return
	if player.has_signal("primary_fire_requested"):
		var primary_fire_callable := Callable(self, "_on_player_primary_fire_requested")
		if not player.primary_fire_requested.is_connected(primary_fire_callable):
			player.primary_fire_requested.connect(primary_fire_callable)
	if player.has_signal("grenade_throw_requested"):
		var grenade_throw_callable := Callable(self, "_on_player_grenade_throw_requested")
		if not player.grenade_throw_requested.is_connected(grenade_throw_callable):
			player.grenade_throw_requested.connect(grenade_throw_callable)
	if player.has_signal("laser_designator_requested"):
		var laser_callable := Callable(self, "_on_player_laser_designator_requested")
		if not player.laser_designator_requested.is_connected(laser_callable):
			player.laser_designator_requested.connect(laser_callable)
	if player.has_signal("missile_launcher_requested"):
		var missile_callable := Callable(self, "_on_player_missile_launcher_requested")
		if not player.missile_launcher_requested.is_connected(missile_callable):
			player.missile_launcher_requested.connect(missile_callable)
	if player.has_signal("weapon_mode_changed"):
		var weapon_mode_callable := Callable(self, "_on_player_weapon_mode_changed")
		if not player.weapon_mode_changed.is_connected(weapon_mode_callable):
			player.weapon_mode_changed.connect(weapon_mode_callable)
	if player.has_signal("aim_down_sights_changed"):
		var ads_callable := Callable(self, "_on_player_aim_down_sights_changed")
		if not player.aim_down_sights_changed.is_connected(ads_callable):
			player.aim_down_sights_changed.connect(ads_callable)
	if player.has_signal("fishing_preview_toggled"):
		var fishing_preview_callable := Callable(self, "_on_player_fishing_preview_toggled")
		if not player.fishing_preview_toggled.is_connected(fishing_preview_callable):
			player.fishing_preview_toggled.connect(fishing_preview_callable)
	if player.has_signal("fishing_cast_action_requested"):
		var fishing_cast_callable := Callable(self, "_on_player_fishing_cast_action_requested")
		if not player.fishing_cast_action_requested.is_connected(fishing_cast_callable):
			player.fishing_cast_action_requested.connect(fishing_cast_callable)

func _on_player_primary_fire_requested() -> void:
	fire_player_projectile()

func _on_player_grenade_throw_requested() -> void:
	throw_player_grenade()

func _on_player_laser_designator_requested() -> void:
	fire_player_laser_designator()

func _on_player_missile_launcher_requested() -> void:
	fire_player_missile_launcher()

func _on_player_weapon_mode_changed(_weapon_mode: String) -> void:
	_refresh_hud_status({}, true)

func _on_player_aim_down_sights_changed(_is_active: bool) -> void:
	_refresh_hud_status({}, true)

func _on_player_fishing_preview_toggled(active: bool) -> void:
	set_fishing_cast_preview_active(active)

func _on_player_fishing_cast_action_requested() -> void:
	request_fishing_cast_action()

func _spawn_projectile(origin: Vector3, direction: Vector3) -> Node3D:
	_ensure_combat_roots()
	if _projectile_root == null:
		return
	var projectile := CityProjectile.new()
	projectile.configure(
		origin,
		direction,
		player,
		1.0,
		"city_projectile",
		"city_enemy",
		Color(0.65098, 0.85098, 1.0, 1.0),
		Color(0.360784, 0.713725, 1.0, 1.0),
		chunk_renderer if chunk_renderer != null and chunk_renderer.has_method("resolve_projectile_hit") else null,
		chunk_renderer if chunk_renderer != null and chunk_renderer.has_method("resolve_vehicle_projectile_hit") else null
	)
	_projectile_root.add_child(projectile)
	if chunk_renderer != null and chunk_renderer.has_method("notify_projectile_event"):
		chunk_renderer.notify_projectile_event(origin, direction, projectile.max_distance_m if projectile != null else 36.0)
	return projectile

func _spawn_grenade(origin: Vector3, launch_velocity: Vector3) -> Node3D:
	_ensure_combat_roots()
	if _grenade_root == null:
		return null
	var grenade := CityGrenade.new()
	grenade.configure(origin, launch_velocity, player, player)
	if grenade.has_signal("exploded"):
		grenade.exploded.connect(_on_player_grenade_exploded)
	_grenade_root.add_child(grenade)
	return grenade

func _spawn_missile(origin: Vector3, direction: Vector3) -> Node3D:
	_ensure_combat_roots()
	if _missile_root == null:
		return null
	var missile_scene := CityMissileScene
	if missile_scene == null:
		return null
	var missile := missile_scene.instantiate() as Node3D
	if missile == null:
		return null
	_missile_root.add_child(missile)
	if missile.has_method("configure"):
		missile.configure(origin, direction, player, player)
	if missile.has_signal("exploded"):
		missile.exploded.connect(_on_player_missile_exploded)
	return missile

func _on_player_grenade_exploded(world_position: Vector3, radius_m: float) -> void:
	if chunk_renderer != null and chunk_renderer.has_method("resolve_explosion_impact"):
		chunk_renderer.resolve_explosion_impact(world_position, maxf(radius_m * 0.35, 4.0), radius_m)
	if chunk_renderer != null and chunk_renderer.has_method("resolve_vehicle_explosion"):
		chunk_renderer.resolve_vehicle_explosion(world_position, radius_m)

func _on_player_missile_exploded(result: Dictionary) -> void:
	_last_missile_explosion_result = result.duplicate(true)
	var world_position := result.get("world_position", Vector3.ZERO) as Vector3
	var radius_m := float(result.get("radius_m", 18.0))
	if chunk_renderer != null and chunk_renderer.has_method("resolve_explosion_impact"):
		chunk_renderer.resolve_explosion_impact(world_position, maxf(radius_m * 0.42, 5.0), radius_m)
	if chunk_renderer != null and chunk_renderer.has_method("resolve_vehicle_explosion"):
		chunk_renderer.resolve_vehicle_explosion(world_position, radius_m)

func resolve_pedestrian_explosion(world_position: Vector3, lethal_radius_m: float, threat_radius_m: float = -1.0) -> Dictionary:
	if chunk_renderer == null or not chunk_renderer.has_method("resolve_explosion_impact"):
		return {}
	return chunk_renderer.resolve_explosion_impact(world_position, lethal_radius_m, threat_radius_m)

func resolve_vehicle_projectile_hit(start_position: Vector3, end_position: Vector3, damage: float = 1.0, velocity: Vector3 = Vector3.ZERO) -> Dictionary:
	if chunk_renderer == null or not chunk_renderer.has_method("resolve_vehicle_projectile_hit"):
		return {}
	return chunk_renderer.resolve_vehicle_projectile_hit(start_position, end_position, damage, velocity)

func resolve_vehicle_explosion(world_position: Vector3, radius_m: float) -> Dictionary:
	if chunk_renderer == null or not chunk_renderer.has_method("resolve_vehicle_explosion"):
		return {}
	return chunk_renderer.resolve_vehicle_explosion(world_position, radius_m)

func resolve_player_vehicle_pedestrian_impact() -> Dictionary:
	if not _pending_player_vehicle_impact_result.is_empty():
		var cached_result := _pending_player_vehicle_impact_result.duplicate(true)
		_pending_player_vehicle_impact_result.clear()
		return cached_result
	return _resolve_player_vehicle_pedestrian_impact_impl()

func find_hijackable_vehicle_candidate(max_distance_m: float = 6.5) -> Dictionary:
	if chunk_renderer == null or not chunk_renderer.has_method("find_hijackable_vehicle_candidate"):
		return {}
	return chunk_renderer.find_hijackable_vehicle_candidate(_get_active_anchor_position(), max_distance_m)

func handle_vehicle_interaction(max_distance_m: float = 6.5, abandoned_vehicle_lifetime_sec: float = ABANDONED_HIJACK_VEHICLE_LIFETIME_SEC) -> Dictionary:
	if player != null and player.has_method("is_driving_vehicle") and bool(player.is_driving_vehicle()):
		return try_exit_player_vehicle(abandoned_vehicle_lifetime_sec)
	var abandoned_candidate := _find_abandoned_vehicle_candidate(_get_active_anchor_position(), max_distance_m)
	if not abandoned_candidate.is_empty():
		return try_reenter_abandoned_vehicle(str(abandoned_candidate.get("vehicle_id", "")))
	return try_hijack_nearby_vehicle(max_distance_m)

func try_hijack_nearby_vehicle(max_distance_m: float = 6.5) -> Dictionary:
	if player == null or chunk_renderer == null:
		return {
			"success": false,
		}
	if player.has_method("is_driving_vehicle") and bool(player.is_driving_vehicle()):
		return {
			"success": false,
		}
	if not chunk_renderer.has_method("find_hijackable_vehicle_candidate") or not chunk_renderer.has_method("claim_vehicle_for_player"):
		return {
			"success": false,
		}
	var candidate: Dictionary = chunk_renderer.find_hijackable_vehicle_candidate(_get_active_anchor_position(), max_distance_m)
	if candidate.is_empty():
		return {
			"success": false,
		}
	var hijack_result: Dictionary = chunk_renderer.claim_vehicle_for_player(str(candidate.get("vehicle_id", "")))
	if hijack_result.is_empty():
		return {
			"success": false,
		}
	stop_autodrive("interrupted")
	if player.has_method("enter_vehicle_drive_mode"):
		player.enter_vehicle_drive_mode(hijack_result)
	update_streaming_for_position(_get_active_anchor_position(), 0.0)
	_refresh_hud_status({}, true)
	hijack_result["success"] = true
	return hijack_result

func try_exit_player_vehicle(abandoned_vehicle_lifetime_sec: float = ABANDONED_HIJACK_VEHICLE_LIFETIME_SEC) -> Dictionary:
	if player == null or not player.has_method("is_driving_vehicle") or not bool(player.is_driving_vehicle()):
		return {
			"success": false,
		}
	stop_autodrive("interrupted")
	if not player.has_method("exit_vehicle_drive_mode"):
		return {
			"success": false,
		}
	var exit_result: Dictionary = player.exit_vehicle_drive_mode()
	if exit_result.is_empty():
		return {
			"success": false,
		}
	var abandoned_spawned := _spawn_abandoned_vehicle_visual(exit_result, abandoned_vehicle_lifetime_sec)
	update_streaming_for_position(_get_active_anchor_position(), 0.0)
	_refresh_hud_status({}, true)
	exit_result["success"] = true
	exit_result["abandoned_vehicle_spawned"] = abandoned_spawned
	return exit_result

func try_reenter_abandoned_vehicle(vehicle_id: String) -> Dictionary:
	if player == null or vehicle_id.is_empty():
		return {
			"success": false,
		}
	if not player.has_method("enter_vehicle_drive_mode"):
		return {
			"success": false,
		}
	_prune_abandoned_vehicle_visuals()
	for entry_index in range(_abandoned_vehicle_visuals.size()):
		var entry: Dictionary = _abandoned_vehicle_visuals[entry_index]
		if str(entry.get("vehicle_id", "")) != vehicle_id:
			continue
		var vehicle_state: Dictionary = (entry.get("vehicle_state", {}) as Dictionary).duplicate(true)
		_free_abandoned_vehicle_visual(entry)
		_abandoned_vehicle_visuals.remove_at(entry_index)
		stop_autodrive("interrupted")
		player.enter_vehicle_drive_mode(vehicle_state)
		update_streaming_for_position(_get_active_anchor_position(), 0.0)
		_refresh_hud_status({}, true)
		vehicle_state["success"] = true
		vehicle_state["reentered"] = true
		return vehicle_state
	return {
		"success": false,
	}

func get_abandoned_vehicle_visual_count() -> int:
	_prune_abandoned_vehicle_visuals()
	return _abandoned_vehicle_visuals.size()

func _spawn_abandoned_vehicle_visual(vehicle_state: Dictionary, lifetime_sec: float) -> bool:
	_ensure_abandoned_vehicle_visual_root()
	if _abandoned_vehicle_visual_root == null:
		return false
	var model_root := _instantiate_vehicle_visual_model(vehicle_state)
	if model_root == null:
		return false
	var vehicle_root := Node3D.new()
	vehicle_root.name = "AbandonedHijackedVehicle"
	var world_position: Vector3 = vehicle_state.get("world_position", Vector3.ZERO)
	var heading: Vector3 = vehicle_state.get("heading", Vector3.FORWARD)
	heading.y = 0.0
	if heading.length_squared() <= 0.0001:
		heading = Vector3.FORWARD
	vehicle_root.position = world_position
	vehicle_root.rotation.y = _yaw_from_vehicle_heading(heading.normalized()) + PI
	vehicle_root.add_child(model_root)
	_abandoned_vehicle_visual_root.add_child(vehicle_root)
	_remove_abandoned_vehicle_visual(str(vehicle_state.get("vehicle_id", "")))
	_prune_abandoned_vehicle_visuals()
	_abandoned_vehicle_visuals.append({
		"vehicle_id": str(vehicle_state.get("vehicle_id", "")),
		"vehicle_state": vehicle_state.duplicate(true),
		"visual_root": vehicle_root,
		"remaining_sec": maxf(lifetime_sec, 0.1),
	})
	return true

func _ensure_abandoned_vehicle_visual_root() -> void:
	if _abandoned_vehicle_visual_root != null and is_instance_valid(_abandoned_vehicle_visual_root):
		return
	var root := Node3D.new()
	root.name = "AbandonedHijackedVehicles"
	add_child(root)
	_abandoned_vehicle_visual_root = root

func _instantiate_vehicle_visual_model(vehicle_state: Dictionary) -> Node3D:
	if _vehicle_visual_catalog == null:
		_vehicle_visual_catalog = CityVehicleVisualCatalog.new()
	var model_id := str(vehicle_state.get("model_id", ""))
	var entry := _vehicle_visual_catalog.get_entry(model_id)
	if entry.is_empty():
		entry = _vehicle_visual_catalog.select_entry_for_state(vehicle_state)
	if entry.is_empty():
		return null
	var model_root := _vehicle_visual_catalog.instantiate_scene_for_entry(entry)
	if model_root == null:
		return null
	var runtime_scale := _vehicle_visual_catalog.resolve_runtime_scale(entry)
	model_root.scale = Vector3.ONE * runtime_scale
	model_root.position = Vector3(0.0, _vehicle_visual_catalog.resolve_ground_offset_m(entry) * runtime_scale, 0.0)
	return model_root

func _yaw_from_vehicle_heading(heading: Vector3) -> float:
	return atan2(-heading.x, -heading.z)

func _prune_abandoned_vehicle_visuals() -> void:
	var survivors: Array = []
	for entry_variant in _abandoned_vehicle_visuals:
		var entry: Dictionary = entry_variant
		var visual_root = entry.get("visual_root", null)
		if visual_root != null and is_instance_valid(visual_root):
			survivors.append(entry)
	_abandoned_vehicle_visuals = survivors

func _resolve_player_vehicle_pedestrian_impact_impl() -> Dictionary:
	if player == null or not player.has_method("is_driving_vehicle") or not bool(player.is_driving_vehicle()):
		return {}
	if chunk_renderer == null or not chunk_renderer.has_method("resolve_player_vehicle_pedestrian_impact"):
		return {}
	var vehicle_state := get_player_vehicle_state()
	if vehicle_state.is_empty():
		return {}
	var impact_result: Dictionary = chunk_renderer.resolve_player_vehicle_pedestrian_impact(vehicle_state)
	if impact_result.is_empty():
		return {}
	var speed_after_mps := float(vehicle_state.get("speed_mps", 0.0))
	if player.has_method("apply_vehicle_impact_slowdown"):
		speed_after_mps = float(player.apply_vehicle_impact_slowdown())
	if player.has_method("trigger_camera_shake"):
		player.trigger_camera_shake(
			float(player.get("vehicle_impact_camera_shake_duration_sec")),
			float(player.get("vehicle_impact_camera_shake_amplitude_m"))
		)
	impact_result["vehicle_speed_after_mps"] = speed_after_mps
	return impact_result

func _update_abandoned_vehicle_visuals(delta: float) -> void:
	if _abandoned_vehicle_visuals.is_empty():
		return
	var survivors: Array = []
	for entry_variant in _abandoned_vehicle_visuals:
		var entry: Dictionary = entry_variant
		var visual_root = entry.get("visual_root", null)
		if visual_root == null or not is_instance_valid(visual_root):
			continue
		var remaining_sec := maxf(float(entry.get("remaining_sec", 0.0)) - maxf(delta, 0.0), 0.0)
		if remaining_sec <= 0.0:
			_free_abandoned_vehicle_visual(entry)
			continue
		entry["remaining_sec"] = remaining_sec
		survivors.append(entry)
	_abandoned_vehicle_visuals = survivors

func _remove_abandoned_vehicle_visual(vehicle_id: String) -> void:
	if vehicle_id.is_empty():
		return
	var survivors: Array = []
	for entry_variant in _abandoned_vehicle_visuals:
		var entry: Dictionary = entry_variant
		if str(entry.get("vehicle_id", "")) == vehicle_id:
			_free_abandoned_vehicle_visual(entry)
			continue
		var visual_root = entry.get("visual_root", null)
		if visual_root != null and is_instance_valid(visual_root):
			survivors.append(entry)
	_abandoned_vehicle_visuals = survivors

func _find_abandoned_vehicle_candidate(player_position: Vector3, max_distance_m: float = 6.5) -> Dictionary:
	_prune_abandoned_vehicle_visuals()
	var best_candidate := {}
	var best_distance_m := max_distance_m
	for entry_variant in _abandoned_vehicle_visuals:
		var entry: Dictionary = entry_variant
		var vehicle_state: Dictionary = entry.get("vehicle_state", {})
		if vehicle_state.is_empty():
			continue
		var distance_m := player_position.distance_to(vehicle_state.get("world_position", Vector3.ZERO))
		if distance_m > best_distance_m:
			continue
		best_distance_m = distance_m
		best_candidate = vehicle_state.duplicate(true)
		best_candidate["distance_m"] = distance_m
		best_candidate["remaining_sec"] = float(entry.get("remaining_sec", 0.0))
	if best_candidate.is_empty():
		return {}
	return best_candidate

func _free_abandoned_vehicle_visual(entry: Dictionary) -> void:
	var visual_root = entry.get("visual_root", null)
	if visual_root != null and is_instance_valid(visual_root):
		visual_root.queue_free()

func _connect_enemy_combat(enemy: Node) -> void:
	if enemy == null or not enemy.has_signal("projectile_fire_requested"):
		return
	var callable := Callable(self, "_on_enemy_projectile_fire_requested")
	if not enemy.projectile_fire_requested.is_connected(callable):
		enemy.projectile_fire_requested.connect(callable)

func _on_enemy_projectile_fire_requested(origin: Vector3, direction: Vector3) -> void:
	_spawn_enemy_projectile(origin, direction)

func _spawn_enemy_projectile(origin: Vector3, direction: Vector3) -> Node3D:
	_ensure_combat_roots()
	if _enemy_projectile_root == null:
		return null
	var projectile := CityProjectile.new()
	projectile.speed_mps = 120.0
	projectile.max_distance_m = 240.0
	projectile.max_lifetime_sec = 2.4
	projectile.configure(
		origin,
		direction,
		null,
		1.0,
		"city_enemy_projectile",
		"city_player",
		Color(1.0, 0.403922, 0.360784, 1.0),
		Color(1.0, 0.25098, 0.188235, 1.0)
	)
	_enemy_projectile_root.add_child(projectile)
	return projectile

func update_streaming_for_position(world_position: Vector3, delta: float = 0.0) -> Array:
	var started_usec := Time.get_ticks_usec()
	if _chunk_streamer == null:
		return []
	var chunk_streamer_started_usec := Time.get_ticks_usec()
	var events: Array = _chunk_streamer.update_for_world_position(world_position)
	_record_update_streaming_chunk_streamer_sample(Time.get_ticks_usec() - chunk_streamer_started_usec)
	if chunk_renderer != null and chunk_renderer.has_method("sync_streaming"):
		var renderer_sync_started_usec := Time.get_ticks_usec()
		chunk_renderer.sync_streaming(
			_chunk_streamer.get_active_chunk_entries(),
			world_position,
			delta,
			_build_pedestrian_player_context()
		)
		_record_update_streaming_renderer_sync_sample(Time.get_ticks_usec() - renderer_sync_started_usec)
	var is_headless := DisplayServer.get_name() == "headless"
	var hud_debug_expanded := hud != null and hud.has_method("is_debug_expanded") and bool(hud.is_debug_expanded())
	var debug_expanded := debug_overlay != null and debug_overlay.has_method("is_expanded") and bool(debug_overlay.is_expanded())
	var should_refresh_hud := _should_refresh_hud()
	var allow_headless_hud_refresh := should_refresh_hud and (
		not is_headless
		or not _has_streaming_backpressure()
	)
	var needs_snapshot := _should_build_hud_snapshot_refresh(
		is_headless,
		allow_headless_hud_refresh,
		hud_debug_expanded,
		debug_expanded
	)
	var hud_snapshot := {}
	if needs_snapshot:
		hud_snapshot = _build_hud_snapshot(not hud_debug_expanded and not debug_expanded)
	if debug_overlay != null:
		if needs_snapshot and debug_overlay.has_method("set_snapshot"):
			debug_overlay.set_snapshot(hud_snapshot)
		debug_overlay.visible = debug_expanded
	if allow_headless_hud_refresh:
		_refresh_hud_status(hud_snapshot, true)
	_record_update_streaming_sample(Time.get_ticks_usec() - started_usec)
	return events

func plan_macro_route(start_position: Vector3, goal_position: Vector3) -> Array:
	if _navigation_runtime == null:
		return []
	return _navigation_runtime.plan_route(start_position, goal_position)

func plan_route_result(origin_target_or_world_position: Variant, destination_target_or_world_position: Variant, reroute_generation: int = 0, route_style_id: String = ROUTE_STYLE_DESTINATION) -> Dictionary:
	if _navigation_runtime == null:
		return {}
	var origin_target: Dictionary = _resolve_route_target(origin_target_or_world_position)
	var destination_target: Dictionary = _resolve_route_target(destination_target_or_world_position)
	if origin_target.is_empty() or destination_target.is_empty():
		return {}
	var route_result: Dictionary = _navigation_runtime.plan_route_result(origin_target, destination_target, reroute_generation)
	if route_result.is_empty():
		return {}
	_apply_active_route_result(route_result, destination_target, false, route_style_id)
	return route_result

func get_active_route_result() -> Dictionary:
	return _active_route_result.duplicate(true)

func get_destination_world_marker_state() -> Dictionary:
	_update_destination_world_marker(0.0)
	if _destination_world_marker != null and _destination_world_marker.has_method("get_state"):
		return _destination_world_marker.get_state()
	return {
		"visible": false,
		"world_position": Vector3.ZERO,
		"radius_m": DESTINATION_WORLD_MARKER_RADIUS_M,
	}

func get_destination_world_marker_debug_state() -> Dictionary:
	return {
		"cached_route_id": _destination_world_marker_cached_route_id,
		"cached_anchor": _destination_world_marker_cached_anchor,
		"cached_world_position": _destination_world_marker_cached_world_position,
		"surface_resolve_count": _destination_world_marker_surface_resolve_count,
	}

func get_route_cache_stats() -> Dictionary:
	if _navigation_runtime == null or not _navigation_runtime.has_method("get_route_cache_stats"):
		return {}
	return _navigation_runtime.get_route_cache_stats()

func toggle_full_map() -> void:
	set_full_map_open(not _full_map_open)

func set_full_map_open(is_open: bool) -> void:
	if _full_map_open == is_open:
		return
	if is_open and _controls_help_open:
		_controls_help_open = false
		_sync_controls_help_overlay()
	_full_map_open = is_open
	if is_open and is_dialogue_active() and _dialogue_runtime != null and _dialogue_runtime.has_method("close_dialogue"):
		_dialogue_runtime.close_dialogue()
	_apply_world_simulation_pause(is_open)
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if is_open else Input.MOUSE_MODE_CAPTURED)
	_sync_navigation_consumers(true)
	_update_npc_interaction_system()

func is_full_map_open() -> bool:
	return _full_map_open

func toggle_controls_help() -> void:
	set_controls_help_open(not _controls_help_open)

func set_controls_help_open(is_open: bool) -> void:
	if _controls_help_open == is_open:
		return
	if is_open:
		if _full_map_open:
			set_full_map_open(false)
		if _vehicle_radio_browser_open:
			close_vehicle_radio_browser()
		if _vehicle_radio_quick_overlay_open:
			close_vehicle_radio_quick_overlay()
		if is_dialogue_active() and _dialogue_runtime != null and _dialogue_runtime.has_method("close_dialogue"):
			_dialogue_runtime.close_dialogue()
	_controls_help_open = is_open
	_apply_world_simulation_pause(is_open)
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if is_open else Input.MOUSE_MODE_CAPTURED)
	_sync_controls_help_overlay()
	_sync_navigation_consumers(true)
	_update_npc_interaction_system()

func is_controls_help_open() -> bool:
	return _controls_help_open

func is_world_simulation_paused() -> bool:
	return _world_simulation_paused

func get_controls_help_state() -> Dictionary:
	return _build_controls_help_state().duplicate(true)

func select_map_destination_from_world_point(world_position: Vector3) -> Dictionary:
	var clamped_world_position := _clamp_world_position_to_bounds(world_position)
	var resolved_target: Dictionary = _resolve_route_target(clamped_world_position)
	if resolved_target.is_empty():
		return {}
	resolved_target["selection_mode"] = "map_world_point"
	resolved_target["raw_world_anchor"] = clamped_world_position
	var route_request_target := resolved_target.duplicate(true)
	var selection_contract := {
		"selection_mode": "map_world_point",
		"raw_world_anchor": clamped_world_position,
		"resolved_target": resolved_target.duplicate(true),
		"route_request_target": route_request_target.duplicate(true),
		"route_style_id": ROUTE_STYLE_DESTINATION,
	}
	var route_result: Dictionary = plan_route_result(_get_route_refresh_anchor_position(), route_request_target, 0, ROUTE_STYLE_DESTINATION)
	if route_result.is_empty():
		return {}
	_last_map_selection_contract = selection_contract.duplicate(true)
	if _map_pin_registry != null and _map_pin_registry.has_method("upsert_destination_pin"):
		_map_pin_registry.upsert_destination_pin(resolved_target)
	_sync_navigation_consumers(true)
	return selection_contract.duplicate(true)

func get_last_map_selection_contract() -> Dictionary:
	return _last_map_selection_contract.duplicate(true)

func get_map_screen_state() -> Dictionary:
	if _map_screen == null or not _map_screen.has_method("get_render_state"):
		return {}
	return _map_screen.get_render_state()

func get_pin_registry_state() -> Dictionary:
	if _map_pin_registry == null or not _map_pin_registry.has_method("get_state"):
		return {}
	return _map_pin_registry.get_state()

func get_service_building_map_pin_state() -> Dictionary:
	if _service_building_map_pin_runtime == null or not _service_building_map_pin_runtime.has_method("get_state"):
		return {}
	return _service_building_map_pin_runtime.get_state()

func get_scene_landmark_runtime_state() -> Dictionary:
	if _scene_landmark_runtime == null or not _scene_landmark_runtime.has_method("get_state"):
		return {}
	return _scene_landmark_runtime.get_state()

func get_scene_interactive_prop_runtime_state() -> Dictionary:
	if _scene_interactive_prop_runtime == null or not _scene_interactive_prop_runtime.has_method("get_state"):
		return {}
	return _scene_interactive_prop_runtime.get_state()

func get_scene_minigame_venue_runtime_state() -> Dictionary:
	if _scene_minigame_venue_runtime == null or not _scene_minigame_venue_runtime.has_method("get_state"):
		return {}
	return _scene_minigame_venue_runtime.get_state()

func get_lake_player_water_state() -> Dictionary:
	return _lake_player_water_state.duplicate(true)

func _build_default_soccer_match_hud_state() -> Dictionary:
	return {
		"visible": false,
		"match_state": "idle",
		"home_score": 0,
		"away_score": 0,
		"home_team_color_id": "red",
		"away_team_color_id": "blue",
		"clock_text": "05:00",
		"winner_side": "",
	}

func _build_default_tennis_match_hud_state() -> Dictionary:
	return {
		"visible": false,
		"match_state": "idle",
		"home_games": 0,
		"away_games": 0,
		"home_point_label": "0",
		"away_point_label": "0",
		"server_side": "home",
		"winner_side": "",
		"point_end_reason": "",
		"landing_marker_visible": false,
		"landing_marker_world_position": Vector3.ZERO,
		"auto_footwork_assist_state": "idle",
		"strike_window_state": "idle",
		"strike_quality_feedback": "",
		"expected_service_box_id": "",
		"state_text": "",
		"coach_text": "",
		"coach_tone": "neutral",
		"feedback_event_token": 0,
		"feedback_event_kind": "",
		"feedback_event_text": "",
		"feedback_event_tone": "neutral",
	}

func _build_default_missile_command_hud_state() -> Dictionary:
	return {
		"visible": false,
		"wave_index": 0,
		"wave_total": 3,
		"wave_state": "idle",
		"selected_silo_id": "",
		"cities_alive_count": 0,
		"enemy_remaining_count": 0,
		"zoom_active": false,
		"feedback_event_token": 0,
		"feedback_event_text": "",
		"feedback_event_tone": "neutral",
	}

func _build_default_fishing_hud_state() -> Dictionary:
	return {
		"visible": false,
		"fishing_mode_active": false,
		"pole_equipped": false,
		"cast_state": "idle",
		"target_school_id": "",
		"last_catch_result": {},
		"display_name": "Lakeside Fishing",
		"state_text": "按 E 拿起鱼竿",
		"result_text": "",
		"feedback_event_token": 0,
		"feedback_event_text": "",
		"feedback_event_tone": "neutral",
	}

func get_soccer_venue_runtime_state() -> Dictionary:
	if _soccer_venue_runtime == null or not _soccer_venue_runtime.has_method("get_state"):
		return {}
	return _soccer_venue_runtime.get_state()

func get_soccer_match_hud_state() -> Dictionary:
	if _soccer_venue_runtime == null or not _soccer_venue_runtime.has_method("get_match_hud_state"):
		return _build_default_soccer_match_hud_state()
	return _soccer_venue_runtime.get_match_hud_state()

func get_tennis_venue_runtime_state() -> Dictionary:
	if _tennis_venue_runtime == null or not _tennis_venue_runtime.has_method("get_state"):
		return {}
	return _tennis_venue_runtime.get_state()

func get_tennis_match_hud_state() -> Dictionary:
	if _tennis_venue_runtime == null or not _tennis_venue_runtime.has_method("get_match_hud_state"):
		return _build_default_tennis_match_hud_state()
	return _tennis_venue_runtime.get_match_hud_state()

func get_missile_command_runtime_state() -> Dictionary:
	if _missile_command_venue_runtime == null or not _missile_command_venue_runtime.has_method("get_state"):
		return {}
	return _missile_command_venue_runtime.get_state()

func get_missile_command_hud_state() -> Dictionary:
	if _missile_command_venue_runtime == null or not _missile_command_venue_runtime.has_method("get_match_hud_state"):
		return _build_default_missile_command_hud_state()
	return _missile_command_venue_runtime.get_match_hud_state()

func get_fishing_venue_runtime_state() -> Dictionary:
	if _fishing_venue_runtime == null or not _fishing_venue_runtime.has_method("get_state"):
		return {}
	return _fishing_venue_runtime.get_state()

func get_fishing_hud_state() -> Dictionary:
	if _fishing_venue_runtime == null or not _fishing_venue_runtime.has_method("get_match_hud_state"):
		return _build_default_fishing_hud_state()
	return _fishing_venue_runtime.get_match_hud_state()

func get_fishing_primary_interaction_state() -> Dictionary:
	if _fishing_venue_runtime == null or not _fishing_venue_runtime.has_method("get_primary_interaction_state"):
		return {
			"visible": false,
			"owner_kind": "fishing_venue",
			"prompt_text": "",
			"distance_m": 0.0,
		}
	return _fishing_venue_runtime.get_primary_interaction_state(player)

func set_fishing_cast_preview_active(active: bool) -> Dictionary:
	if player != null and player.has_method("set_fishing_cast_preview_active"):
		player.set_fishing_cast_preview_active(active)
	if _fishing_venue_runtime == null or not _fishing_venue_runtime.has_method("set_cast_preview_active"):
		return {"success": false, "error": "missing_fishing_runtime"}
	var result: Dictionary = _fishing_venue_runtime.set_cast_preview_active(chunk_renderer, player, active, _get_player_fishing_preview_state())
	if not bool(result.get("success", false)) and player != null and player.has_method("set_fishing_cast_preview_active"):
		player.set_fishing_cast_preview_active(false)
	_sync_player_fishing_state()
	_apply_fishing_feedback_from_state(get_fishing_venue_runtime_state())
	return result

func request_fishing_cast_action() -> Dictionary:
	if _fishing_venue_runtime == null or not _fishing_venue_runtime.has_method("request_cast_action"):
		return {"success": false, "error": "missing_fishing_runtime"}
	var result: Dictionary = _fishing_venue_runtime.request_cast_action(chunk_renderer, player, _get_player_fishing_preview_state())
	if bool(result.get("success", false)) and str(result.get("action", "")) == "cast_started":
		if player != null and player.has_method("play_fishing_cast_swing"):
			player.play_fishing_cast_swing()
		if player != null and player.has_method("set_fishing_cast_preview_active"):
			player.set_fishing_cast_preview_active(false)
	_sync_player_fishing_state()
	_apply_fishing_feedback_from_state(get_fishing_venue_runtime_state())
	return result

func debug_set_fishing_bite_delay_override(seconds: float) -> void:
	if _fishing_venue_runtime != null and _fishing_venue_runtime.has_method("debug_set_bite_delay_override"):
		_fishing_venue_runtime.debug_set_bite_delay_override(seconds)

func is_ambient_simulation_frozen() -> bool:
	if chunk_renderer != null and chunk_renderer.has_method("is_ambient_simulation_frozen"):
		return bool(chunk_renderer.is_ambient_simulation_frozen())
	if _soccer_venue_runtime != null and _soccer_venue_runtime.has_method("is_ambient_simulation_frozen"):
		if bool(_soccer_venue_runtime.is_ambient_simulation_frozen()):
			return true
	if _tennis_venue_runtime != null and _tennis_venue_runtime.has_method("is_ambient_simulation_frozen"):
		if bool(_tennis_venue_runtime.is_ambient_simulation_frozen()):
			return true
	if _missile_command_venue_runtime != null and _missile_command_venue_runtime.has_method("is_ambient_simulation_frozen"):
		if bool(_missile_command_venue_runtime.is_ambient_simulation_frozen()):
			return true
	if _fishing_venue_runtime != null and _fishing_venue_runtime.has_method("is_ambient_simulation_frozen"):
		return bool(_fishing_venue_runtime.is_ambient_simulation_frozen())
	return false

func request_missile_command_primary_fire() -> Dictionary:
	if _missile_command_venue_runtime == null or not _missile_command_venue_runtime.has_method("request_primary_fire"):
		return {"success": false, "error": "runtime_unavailable"}
	return _missile_command_venue_runtime.request_primary_fire()

func request_missile_command_fire_at_world_position(world_position: Vector3) -> Dictionary:
	if _missile_command_venue_runtime == null or not _missile_command_venue_runtime.has_method("request_fire_at_world_position"):
		return {"success": false, "error": "runtime_unavailable"}
	return _missile_command_venue_runtime.request_fire_at_world_position(world_position)

func cycle_missile_command_silo() -> Dictionary:
	if _missile_command_venue_runtime == null or not _missile_command_venue_runtime.has_method("cycle_silo"):
		return {"success": false, "error": "runtime_unavailable"}
	return _missile_command_venue_runtime.cycle_silo()

func set_missile_command_zoom_active(active: bool) -> Dictionary:
	if _missile_command_venue_runtime == null or not _missile_command_venue_runtime.has_method("set_zoom_active"):
		return {"success": false, "error": "runtime_unavailable"}
	return _missile_command_venue_runtime.set_zoom_active(active)

func rotate_missile_command_view(relative: Vector2) -> Dictionary:
	if _missile_command_venue_runtime == null or not _missile_command_venue_runtime.has_method("apply_look_input"):
		return {"success": false, "error": "runtime_unavailable"}
	return _missile_command_venue_runtime.apply_look_input(relative)

func exit_missile_command_mode() -> Dictionary:
	if _missile_command_venue_runtime == null or not _missile_command_venue_runtime.has_method("exit_battery_mode"):
		return {"success": false, "error": "runtime_unavailable"}
	return _missile_command_venue_runtime.exit_battery_mode()

func debug_set_missile_command_wave_seed(seed_value: int) -> Dictionary:
	if _missile_command_venue_runtime == null or not _missile_command_venue_runtime.has_method("debug_set_wave_seed"):
		return {"success": false, "error": "runtime_unavailable"}
	return _missile_command_venue_runtime.debug_set_wave_seed(seed_value)

func debug_set_soccer_ball_state(world_position: Vector3, linear_velocity: Vector3 = Vector3.ZERO, angular_velocity: Vector3 = Vector3.ZERO) -> Dictionary:
	if _soccer_venue_runtime == null or not _soccer_venue_runtime.has_method("debug_set_ball_state"):
		return {
			"success": false,
			"error": "runtime_unavailable",
		}
	return _soccer_venue_runtime.debug_set_ball_state(chunk_renderer, world_position, linear_velocity, angular_velocity)

func debug_force_soccer_ball_reset() -> Dictionary:
	if _soccer_venue_runtime == null or not _soccer_venue_runtime.has_method("debug_force_reset_ball"):
		return {
			"success": false,
			"error": "runtime_unavailable",
		}
	return _soccer_venue_runtime.debug_force_reset_ball(chunk_renderer)

func debug_set_soccer_match_seed(match_seed_value: int) -> Dictionary:
	if _soccer_venue_runtime == null or not _soccer_venue_runtime.has_method("debug_set_match_seed"):
		return {
			"success": false,
			"error": "runtime_unavailable",
		}
	return _soccer_venue_runtime.debug_set_match_seed(match_seed_value)

func debug_set_soccer_match_clock_remaining_sec(seconds: float) -> Dictionary:
	if _soccer_venue_runtime == null or not _soccer_venue_runtime.has_method("debug_set_match_clock_remaining_sec"):
		return {
			"success": false,
			"error": "runtime_unavailable",
		}
	return _soccer_venue_runtime.debug_set_match_clock_remaining_sec(seconds)

func debug_advance_soccer_match_time(delta_sec: float) -> Dictionary:
	if _soccer_venue_runtime == null or not _soccer_venue_runtime.has_method("debug_advance_match_time"):
		return {
			"success": false,
			"error": "runtime_unavailable",
		}
	return _soccer_venue_runtime.debug_advance_match_time(delta_sec)

func debug_set_tennis_ball_state(world_position: Vector3, linear_velocity: Vector3 = Vector3.ZERO, angular_velocity: Vector3 = Vector3.ZERO) -> Dictionary:
	if _tennis_venue_runtime == null or not _tennis_venue_runtime.has_method("debug_set_ball_state"):
		return {
			"success": false,
			"error": "runtime_unavailable",
		}
	return _tennis_venue_runtime.debug_set_ball_state(chunk_renderer, world_position, linear_velocity, angular_velocity)

func debug_force_tennis_ball_reset() -> Dictionary:
	if _tennis_venue_runtime == null or not _tennis_venue_runtime.has_method("debug_force_reset_ball"):
		return {
			"success": false,
			"error": "runtime_unavailable",
		}
	return _tennis_venue_runtime.debug_force_reset_ball(chunk_renderer)

func debug_award_tennis_point(winner_side: String, reason: String = "debug_point") -> Dictionary:
	if _tennis_venue_runtime == null or not _tennis_venue_runtime.has_method("debug_award_point"):
		return {
			"success": false,
			"error": "runtime_unavailable",
		}
	return _tennis_venue_runtime.debug_award_point(winner_side, reason)

func debug_set_tennis_ai_pressure_error_kind(error_kind: String) -> Dictionary:
	if _tennis_venue_runtime == null or not _tennis_venue_runtime.has_method("debug_set_ai_pressure_error_kind"):
		return {
			"success": false,
			"error": "runtime_unavailable",
		}
	return _tennis_venue_runtime.debug_set_ai_pressure_error_kind(error_kind)

func get_music_road_runtime_state() -> Dictionary:
	if _music_road_runtime == null or not _music_road_runtime.has_method("get_state"):
		return {}
	return _music_road_runtime.get_state()

func debug_step_music_road_runtime(delta_sec: float, vehicle_state_override: Dictionary = {}) -> Dictionary:
	return _advance_music_road_runtime(delta_sec, vehicle_state_override)

func register_task_pin(pin_id: String, world_position: Vector3, title: String, subtitle: String = "", pin_type: String = "task") -> Dictionary:
	if _map_pin_registry == null or not _map_pin_registry.has_method("register_task_pin"):
		return {}
	var pin: Dictionary = _map_pin_registry.register_task_pin(pin_id, world_position, title, subtitle, pin_type)
	_sync_navigation_consumers(true)
	return pin

func select_task_for_tracking(task_id: String, selection_mode: String = "task_panel") -> Dictionary:
	if _task_runtime == null or not _task_runtime.has_method("set_tracked_task"):
		return {}
	var snapshot: Dictionary = _task_runtime.set_tracked_task(task_id)
	if snapshot.is_empty():
		return {}
	var route_target: Dictionary = snapshot.get("route_target", {})
	if not route_target.is_empty():
		var route_style_id := _resolve_task_route_style_id(snapshot)
		var selection_contract := {
			"selection_mode": selection_mode,
			"task_id": task_id,
			"resolved_target": route_target.duplicate(true),
			"route_request_target": route_target.duplicate(true),
			"route_style_id": route_style_id,
		}
		var route_result: Dictionary = plan_route_result(_get_route_refresh_anchor_position(), route_target, 0, route_style_id)
		if route_result.is_empty():
			return {}
		_last_map_selection_contract = selection_contract.duplicate(true)
		if _map_pin_registry != null and _map_pin_registry.has_method("upsert_destination_pin"):
			_map_pin_registry.upsert_destination_pin(route_target)
	_sync_navigation_consumers(true)
	return snapshot

func resolve_fast_travel_target(target_or_world_position: Variant) -> Dictionary:
	if _fast_travel_resolver == null:
		return {}
	var resolved_target: Dictionary = _resolve_route_target(target_or_world_position)
	if resolved_target.is_empty():
		return {}
	var route_result := _active_route_result
	if route_result.is_empty() or str(route_result.get("destination_target_id", "")) != str(_resolve_target_identity(resolved_target)):
		route_result = plan_route_result(_get_route_refresh_anchor_position(), resolved_target, 0)
	return _fast_travel_resolver.resolve_target(resolved_target, route_result, _estimate_player_standing_height())

func fast_travel_to_target(target_or_world_position: Variant, air_drop_height_m: float = 0.0, snap_to_surface: bool = true) -> Dictionary:
	var resolved_target: Dictionary = _resolve_route_target(target_or_world_position)
	var fast_travel_target: Dictionary = resolve_fast_travel_target(resolved_target)
	if player == null or resolved_target.is_empty() or fast_travel_target.is_empty():
		return {
			"success": false,
		}
	stop_autodrive("interrupted")
	var safe_drop_anchor: Vector3 = fast_travel_target.get("safe_drop_anchor", player.global_position)
	var teleport_world_position := safe_drop_anchor + Vector3.UP * maxf(air_drop_height_m, 0.0)
	if player.has_method("teleport_to_world_position"):
		player.teleport_to_world_position(teleport_world_position)
	else:
		player.global_position = teleport_world_position
	_orient_player_to_heading(fast_travel_target.get("arrival_heading", Vector3.FORWARD))
	if player.has_method("suspend_ground_stabilization"):
		player.suspend_ground_stabilization(12)
	if snap_to_surface:
		_snap_player_to_active_surface()
	update_streaming_for_position(_get_active_anchor_position(), 0.0)
	_refresh_hud_status({}, true)
	var result := fast_travel_target.duplicate(true)
	result["teleport_world_position"] = teleport_world_position
	result["air_drop_height_m"] = maxf(air_drop_height_m, 0.0)
	result["success"] = true
	return result

func fast_travel_to_active_destination(air_drop_height_m: float = 0.0, snap_to_surface: bool = true) -> Dictionary:
	if _active_destination_target.is_empty():
		return {
			"success": false,
		}
	return fast_travel_to_target(_active_destination_target, air_drop_height_m, snap_to_surface)

func start_autodrive_to_active_destination() -> Dictionary:
	if _autodrive_controller == null or _active_route_result.is_empty() or _active_destination_target.is_empty():
		return {
			"success": false,
		}
	if player == null or not player.has_method("is_driving_vehicle") or not bool(player.is_driving_vehicle()):
		return {
			"success": false,
		}
	var route_to_arm := _active_route_result
	if _navigation_runtime != null:
		var rerouted: Dictionary = _navigation_runtime.reroute_from_world_position(_get_route_refresh_anchor_position(), _active_destination_target, int(_active_route_result.get("reroute_generation", 0)))
		if not rerouted.is_empty():
			_apply_active_route_result(rerouted)
			route_to_arm = rerouted
	var state: Dictionary = _autodrive_controller.arm(route_to_arm, _active_destination_target)
	if str(state.get("state", "")) == "failed":
		return {
			"success": false,
			"state": state.get("state", ""),
			"failure_reason": state.get("failure_reason", ""),
		}
	_step_autodrive(0.0)
	state = get_autodrive_state()
	state["success"] = true
	return state

func stop_autodrive(reason: String = "interrupted") -> Dictionary:
	if player != null and player.has_method("clear_vehicle_autodrive_input"):
		player.clear_vehicle_autodrive_input()
	if _autodrive_controller == null:
		return {
			"state": "inactive",
		}
	return _autodrive_controller.stop(reason)

func get_autodrive_state() -> Dictionary:
	if _autodrive_controller == null:
		return {
			"state": "inactive",
		}
	return _autodrive_controller.get_state()

func is_autodrive_active() -> bool:
	return _autodrive_controller != null and _autodrive_controller.has_method("is_active") and bool(_autodrive_controller.is_active())

func build_runtime_report(subject_position = null) -> Dictionary:
	var snapshot: Dictionary = get_streaming_snapshot()
	var resolved_position := _get_active_anchor_position()
	if subject_position is Vector3:
		resolved_position = subject_position
	var transition_count := 0
	if _chunk_streamer != null:
		transition_count = _chunk_streamer.get_transition_log().size()
	return {
		"control_mode": _control_mode,
		"current_chunk_id": str(snapshot.get("current_chunk_id", "")),
		"active_chunk_count": int(snapshot.get("active_chunk_count", 0)),
		"last_prepare_usec": int(snapshot.get("last_prepare_usec", 0)),
		"last_mount_usec": int(snapshot.get("last_mount_usec", 0)),
		"last_retire_usec": int(snapshot.get("last_retire_usec", 0)),
		"transition_count": transition_count,
		"final_position": _vector3_to_dict(resolved_position),
		"lod_mode_counts": snapshot.get("lod_mode_counts", {}),
		"multimesh_instance_total": int(snapshot.get("multimesh_instance_total", 0)),
	}

func build_minimap_snapshot() -> Dictionary:
	if _minimap_projector == null:
		return {}
	_minimap_request_count += 1
	var center_world_position := _get_minimap_center_world_position(_get_active_anchor_position())
	var player_marker_state := _build_navigation_player_marker_state()
	var player_world_position: Vector3 = player_marker_state.get("world_position", Vector3.ZERO)
	var player_heading := float(player_marker_state.get("heading_rad", 0.0))
	var crowd_debug_enabled := _is_minimap_crowd_debug_enabled()
	var cache_key := _build_minimap_cache_key(center_world_position, MINIMAP_WORLD_RADIUS_M)
	if cache_key == _minimap_cache_key and not _minimap_snapshot_cache.is_empty():
		_minimap_cache_hits += 1
		var cached_snapshot := _minimap_snapshot_cache.duplicate(false)
		cached_snapshot["player_marker"] = _minimap_projector.build_player_marker(center_world_position, player_world_position, player_heading, MINIMAP_WORLD_RADIUS_M)
		cached_snapshot["route_overlay"] = _build_current_minimap_route_overlay(center_world_position, MINIMAP_WORLD_RADIUS_M)
		cached_snapshot["pin_overlay"] = _build_current_minimap_pin_overlay(center_world_position, MINIMAP_WORLD_RADIUS_M)
		cached_snapshot["crowd_debug_layer"] = _minimap_projector.build_pedestrian_debug_layer(center_world_position, MINIMAP_WORLD_RADIUS_M, crowd_debug_enabled)
		return cached_snapshot

	_minimap_cache_misses += 1
	_minimap_rebuild_count += 1
	var minimap_started_usec := Time.get_ticks_usec()
	var snapshot: Dictionary = _minimap_projector.build_road_snapshot(center_world_position, MINIMAP_WORLD_RADIUS_M)
	_minimap_cache_key = cache_key
	_minimap_snapshot_cache = snapshot.duplicate(false)
	_record_minimap_build_sample(Time.get_ticks_usec() - minimap_started_usec)
	snapshot["player_marker"] = _minimap_projector.build_player_marker(center_world_position, player_world_position, player_heading, MINIMAP_WORLD_RADIUS_M)
	snapshot["route_overlay"] = _build_current_minimap_route_overlay(center_world_position, MINIMAP_WORLD_RADIUS_M)
	snapshot["pin_overlay"] = _build_current_minimap_pin_overlay(center_world_position, MINIMAP_WORLD_RADIUS_M)
	snapshot["crowd_debug_layer"] = _minimap_projector.build_pedestrian_debug_layer(center_world_position, MINIMAP_WORLD_RADIUS_M, crowd_debug_enabled)
	return snapshot

func _resolve_minimap_heading_rad() -> float:
	if player == null:
		return 0.0
	var heading := Vector3.ZERO
	var vehicle_state := get_player_vehicle_state()
	if bool(vehicle_state.get("driving", false)):
		heading = vehicle_state.get("heading", Vector3.ZERO)
	else:
		heading = -player.global_transform.basis.z
	heading.y = 0.0
	if heading.length_squared() <= 0.0001:
		heading = Vector3.FORWARD
	heading = heading.normalized()
	return atan2(heading.x, -heading.z)

func _build_navigation_player_marker_state() -> Dictionary:
	if player == null:
		return {}
	return {
		"world_position": player.global_position,
		"heading_rad": _resolve_minimap_heading_rad(),
	}

func build_minimap_route_overlay(start_position: Vector3, goal_position: Vector3) -> Dictionary:
	if _minimap_projector == null:
		return {}
	var route_result := plan_route_result(start_position, goal_position, 0, ROUTE_STYLE_DESTINATION)
	if route_result.is_empty():
		return {}
	var overlay := _build_current_minimap_route_overlay(_get_minimap_center_world_position(_get_active_anchor_position()), MINIMAP_WORLD_RADIUS_M)
	if hud != null and hud.has_method("set_minimap_snapshot"):
		hud.set_minimap_snapshot(build_minimap_snapshot())
	return overlay.duplicate(true)

func get_minimap_cache_stats() -> Dictionary:
	return {
		"cache_key": _minimap_cache_key,
		"hit_count": _minimap_cache_hits,
		"miss_count": _minimap_cache_misses,
		"rebuild_count": _minimap_rebuild_count,
	}

func _build_crosshair_state() -> Dictionary:
	var viewport_size := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	)
	if get_viewport() != null:
		var visible_rect := get_viewport().get_visible_rect()
		if visible_rect.size.x > 0.0 and visible_rect.size.y > 0.0:
			viewport_size = visible_rect.size
	if _missile_command_venue_runtime != null and _missile_command_venue_runtime.has_method("get_crosshair_state"):
		var missile_crosshair_state := (_missile_command_venue_runtime.get_crosshair_state() as Dictionary).duplicate(true)
		if bool(missile_crosshair_state.get("visible", false)):
			return missile_crosshair_state
	if player == null or not player.has_method("get_aim_target_world_position"):
		return {
			"visible": false,
			"screen_position": viewport_size * 0.5,
			"viewport_size": viewport_size,
			"world_target": Vector3.ZERO,
			"aim_down_sights_active": false,
		}
	var camera := player.get_node_or_null("CameraRig/Camera3D") as Camera3D
	var world_target: Vector3 = player.get_aim_target_world_position()
	var screen_position := viewport_size * 0.5
	if camera != null:
		screen_position = camera.unproject_position(world_target)
	var weapon_mode: String = player.get_weapon_mode() if player.has_method("get_weapon_mode") else "rifle"
	var driving_vehicle := player.has_method("is_driving_vehicle") and bool(player.is_driving_vehicle())
	return {
		"visible": weapon_mode != "grenade" and not driving_vehicle,
		"screen_position": screen_position,
		"viewport_size": viewport_size,
		"world_target": world_target,
		"aim_down_sights_active": player.is_aim_down_sights_active() if player.has_method("is_aim_down_sights_active") else false,
	}

func _weapon_status_text() -> String:
	if player == null or not player.has_method("get_weapon_state"):
		return ""
	if player.has_method("is_driving_vehicle") and bool(player.is_driving_vehicle()):
		var driving_state: Dictionary = get_player_vehicle_state()
		return "vehicle=driving model=%s speed=%.1f exit_prompt=F:exit" % [
			str(driving_state.get("model_id", "")),
			float(driving_state.get("speed_mps", 0.0))
		]
	var weapon_state: Dictionary = player.get_weapon_state()
	var mode := str(weapon_state.get("mode", "rifle"))
	var grenade_ready := bool(weapon_state.get("grenade_ready", false))
	var hijack_candidate: Dictionary = find_hijackable_vehicle_candidate()
	var abandoned_candidate := _find_abandoned_vehicle_candidate(_get_active_anchor_position())
	var prompt_text := ""
	if not abandoned_candidate.is_empty():
		prompt_text = " resume_prompt=F:%s" % str(abandoned_candidate.get("model_id", "vehicle"))
	elif not hijack_candidate.is_empty():
		prompt_text = " hijack_prompt=F:%s" % str(hijack_candidate.get("model_id", "vehicle"))
	return "weapon=%s grenade_ready=%s%s" % [mode, str(grenade_ready), prompt_text]

func reset_performance_profile() -> void:
	_update_streaming_sample_count = 0
	_update_streaming_total_usec = 0
	_update_streaming_max_usec = 0
	_update_streaming_last_usec = 0
	_update_streaming_chunk_streamer_sample_count = 0
	_update_streaming_chunk_streamer_total_usec = 0
	_update_streaming_chunk_streamer_max_usec = 0
	_update_streaming_chunk_streamer_last_usec = 0
	_update_streaming_renderer_sync_sample_count = 0
	_update_streaming_renderer_sync_total_usec = 0
	_update_streaming_renderer_sync_max_usec = 0
	_update_streaming_renderer_sync_last_usec = 0
	_hud_refresh_sample_count = 0
	_hud_refresh_total_usec = 0
	_hud_refresh_max_usec = 0
	_hud_refresh_last_usec = 0
	_last_hud_refresh_tick_usec = -HUD_REFRESH_INTERVAL_USEC
	_last_minimap_hud_refresh_tick_usec = -MINIMAP_HUD_REFRESH_INTERVAL_USEC
	_frame_step_sample_count = 0
	_frame_step_total_usec = 0
	_frame_step_max_usec = 0
	_frame_step_last_usec = 0
	_minimap_request_count = 0
	_minimap_build_total_usec = 0
	_minimap_build_max_usec = 0
	_minimap_build_last_usec = 0
	_minimap_cache_hits = 0
	_minimap_cache_misses = 0
	_minimap_rebuild_count = 0
	if chunk_renderer != null and chunk_renderer.has_method("reset_streaming_profile_stats"):
		chunk_renderer.reset_streaming_profile_stats()

func get_performance_profile() -> Dictionary:
	var streaming_profile: Dictionary = {}
	var renderer_stats: Dictionary = {}
	if chunk_renderer != null and chunk_renderer.has_method("get_streaming_profile_stats"):
		streaming_profile = chunk_renderer.get_streaming_profile_stats()
	if chunk_renderer != null and chunk_renderer.has_method("get_renderer_stats"):
		renderer_stats = chunk_renderer.get_renderer_stats()
	return {
		"world_generation_usec": _world_generation_usec,
		"world_generation_profile": _world_generation_profile.duplicate(true),
		"update_streaming_sample_count": _update_streaming_sample_count,
		"update_streaming_avg_usec": _average_usec(_update_streaming_total_usec, _update_streaming_sample_count),
		"update_streaming_max_usec": _update_streaming_max_usec,
		"update_streaming_last_usec": _update_streaming_last_usec,
		"update_streaming_chunk_streamer_sample_count": _update_streaming_chunk_streamer_sample_count,
		"update_streaming_chunk_streamer_avg_usec": _average_usec(_update_streaming_chunk_streamer_total_usec, _update_streaming_chunk_streamer_sample_count),
		"update_streaming_chunk_streamer_max_usec": _update_streaming_chunk_streamer_max_usec,
		"update_streaming_chunk_streamer_last_usec": _update_streaming_chunk_streamer_last_usec,
		"update_streaming_renderer_sync_sample_count": _update_streaming_renderer_sync_sample_count,
		"update_streaming_renderer_sync_avg_usec": _average_usec(_update_streaming_renderer_sync_total_usec, _update_streaming_renderer_sync_sample_count),
		"update_streaming_renderer_sync_max_usec": _update_streaming_renderer_sync_max_usec,
		"update_streaming_renderer_sync_last_usec": _update_streaming_renderer_sync_last_usec,
		"update_streaming_renderer_sync_queue_sample_count": int(streaming_profile.get("renderer_sync_queue_sample_count", 0)),
		"update_streaming_renderer_sync_queue_avg_usec": int(streaming_profile.get("renderer_sync_queue_avg_usec", 0)),
		"update_streaming_renderer_sync_queue_max_usec": int(streaming_profile.get("renderer_sync_queue_max_usec", 0)),
		"update_streaming_renderer_sync_queue_last_usec": int(streaming_profile.get("renderer_sync_queue_last_usec", 0)),
		"update_streaming_renderer_sync_queue_retire_sample_count": int(streaming_profile.get("renderer_sync_queue_retire_sample_count", 0)),
		"update_streaming_renderer_sync_queue_retire_avg_usec": int(streaming_profile.get("renderer_sync_queue_retire_avg_usec", 0)),
		"update_streaming_renderer_sync_queue_retire_max_usec": int(streaming_profile.get("renderer_sync_queue_retire_max_usec", 0)),
		"update_streaming_renderer_sync_queue_retire_last_usec": int(streaming_profile.get("renderer_sync_queue_retire_last_usec", 0)),
		"update_streaming_renderer_sync_queue_terrain_collect_sample_count": int(streaming_profile.get("renderer_sync_queue_terrain_collect_sample_count", 0)),
		"update_streaming_renderer_sync_queue_terrain_collect_avg_usec": int(streaming_profile.get("renderer_sync_queue_terrain_collect_avg_usec", 0)),
		"update_streaming_renderer_sync_queue_terrain_collect_max_usec": int(streaming_profile.get("renderer_sync_queue_terrain_collect_max_usec", 0)),
		"update_streaming_renderer_sync_queue_terrain_collect_last_usec": int(streaming_profile.get("renderer_sync_queue_terrain_collect_last_usec", 0)),
		"update_streaming_renderer_sync_queue_terrain_dispatch_sample_count": int(streaming_profile.get("renderer_sync_queue_terrain_dispatch_sample_count", 0)),
		"update_streaming_renderer_sync_queue_terrain_dispatch_avg_usec": int(streaming_profile.get("renderer_sync_queue_terrain_dispatch_avg_usec", 0)),
		"update_streaming_renderer_sync_queue_terrain_dispatch_max_usec": int(streaming_profile.get("renderer_sync_queue_terrain_dispatch_max_usec", 0)),
		"update_streaming_renderer_sync_queue_terrain_dispatch_last_usec": int(streaming_profile.get("renderer_sync_queue_terrain_dispatch_last_usec", 0)),
		"update_streaming_renderer_sync_queue_surface_collect_sample_count": int(streaming_profile.get("renderer_sync_queue_surface_collect_sample_count", 0)),
		"update_streaming_renderer_sync_queue_surface_collect_avg_usec": int(streaming_profile.get("renderer_sync_queue_surface_collect_avg_usec", 0)),
		"update_streaming_renderer_sync_queue_surface_collect_max_usec": int(streaming_profile.get("renderer_sync_queue_surface_collect_max_usec", 0)),
		"update_streaming_renderer_sync_queue_surface_collect_last_usec": int(streaming_profile.get("renderer_sync_queue_surface_collect_last_usec", 0)),
		"update_streaming_renderer_sync_queue_surface_dispatch_sample_count": int(streaming_profile.get("renderer_sync_queue_surface_dispatch_sample_count", 0)),
		"update_streaming_renderer_sync_queue_surface_dispatch_avg_usec": int(streaming_profile.get("renderer_sync_queue_surface_dispatch_avg_usec", 0)),
		"update_streaming_renderer_sync_queue_surface_dispatch_max_usec": int(streaming_profile.get("renderer_sync_queue_surface_dispatch_max_usec", 0)),
		"update_streaming_renderer_sync_queue_surface_dispatch_last_usec": int(streaming_profile.get("renderer_sync_queue_surface_dispatch_last_usec", 0)),
		"update_streaming_renderer_sync_queue_mount_sample_count": int(streaming_profile.get("renderer_sync_queue_mount_sample_count", 0)),
		"update_streaming_renderer_sync_queue_mount_avg_usec": int(streaming_profile.get("renderer_sync_queue_mount_avg_usec", 0)),
		"update_streaming_renderer_sync_queue_mount_max_usec": int(streaming_profile.get("renderer_sync_queue_mount_max_usec", 0)),
		"update_streaming_renderer_sync_queue_mount_last_usec": int(streaming_profile.get("renderer_sync_queue_mount_last_usec", 0)),
		"update_streaming_renderer_sync_queue_prepare_sample_count": int(streaming_profile.get("renderer_sync_queue_prepare_sample_count", 0)),
		"update_streaming_renderer_sync_queue_prepare_avg_usec": int(streaming_profile.get("renderer_sync_queue_prepare_avg_usec", 0)),
		"update_streaming_renderer_sync_queue_prepare_max_usec": int(streaming_profile.get("renderer_sync_queue_prepare_max_usec", 0)),
		"update_streaming_renderer_sync_queue_prepare_last_usec": int(streaming_profile.get("renderer_sync_queue_prepare_last_usec", 0)),
		"update_streaming_renderer_sync_lod_sample_count": int(streaming_profile.get("renderer_sync_lod_sample_count", 0)),
		"update_streaming_renderer_sync_lod_avg_usec": int(streaming_profile.get("renderer_sync_lod_avg_usec", 0)),
		"update_streaming_renderer_sync_lod_max_usec": int(streaming_profile.get("renderer_sync_lod_max_usec", 0)),
		"update_streaming_renderer_sync_lod_last_usec": int(streaming_profile.get("renderer_sync_lod_last_usec", 0)),
		"update_streaming_renderer_sync_far_proxy_sample_count": int(streaming_profile.get("renderer_sync_far_proxy_sample_count", 0)),
		"update_streaming_renderer_sync_far_proxy_avg_usec": int(streaming_profile.get("renderer_sync_far_proxy_avg_usec", 0)),
		"update_streaming_renderer_sync_far_proxy_max_usec": int(streaming_profile.get("renderer_sync_far_proxy_max_usec", 0)),
		"update_streaming_renderer_sync_far_proxy_last_usec": int(streaming_profile.get("renderer_sync_far_proxy_last_usec", 0)),
		"update_streaming_renderer_sync_crowd_sample_count": int(streaming_profile.get("renderer_sync_crowd_sample_count", 0)),
		"update_streaming_renderer_sync_crowd_avg_usec": int(streaming_profile.get("renderer_sync_crowd_avg_usec", 0)),
		"update_streaming_renderer_sync_crowd_max_usec": int(streaming_profile.get("renderer_sync_crowd_max_usec", 0)),
		"update_streaming_renderer_sync_crowd_last_usec": int(streaming_profile.get("renderer_sync_crowd_last_usec", 0)),
		"update_streaming_renderer_sync_traffic_sample_count": int(streaming_profile.get("renderer_sync_traffic_sample_count", 0)),
		"update_streaming_renderer_sync_traffic_avg_usec": int(streaming_profile.get("renderer_sync_traffic_avg_usec", 0)),
		"update_streaming_renderer_sync_traffic_max_usec": int(streaming_profile.get("renderer_sync_traffic_max_usec", 0)),
		"update_streaming_renderer_sync_traffic_last_usec": int(streaming_profile.get("renderer_sync_traffic_last_usec", 0)),
		"hud_refresh_sample_count": _hud_refresh_sample_count,
		"hud_refresh_avg_usec": _average_usec(_hud_refresh_total_usec, _hud_refresh_sample_count),
		"hud_refresh_max_usec": _hud_refresh_max_usec,
		"hud_refresh_last_usec": _hud_refresh_last_usec,
		"frame_step_sample_count": _frame_step_sample_count,
		"frame_step_avg_usec": _average_usec(_frame_step_total_usec, _frame_step_sample_count),
		"frame_step_max_usec": _frame_step_max_usec,
		"frame_step_last_usec": _frame_step_last_usec,
		"minimap_request_count": _minimap_request_count,
		"minimap_build_avg_usec": _average_usec(_minimap_build_total_usec, _minimap_rebuild_count),
		"minimap_build_max_usec": _minimap_build_max_usec,
		"minimap_build_last_usec": _minimap_build_last_usec,
		"minimap_cache_hits": _minimap_cache_hits,
		"minimap_cache_misses": _minimap_cache_misses,
		"minimap_rebuild_count": _minimap_rebuild_count,
		"pedestrian_mode": str(renderer_stats.get("pedestrian_mode", "lite")),
		"vehicle_mode": str(renderer_stats.get("vehicle_mode", "lite")),
		"crowd_update_max_usec": int(streaming_profile.get("crowd_update_max_usec", 0)),
		"crowd_update_avg_usec": int(streaming_profile.get("crowd_update_avg_usec", 0)),
		"crowd_update_sample_count": int(streaming_profile.get("crowd_update_sample_count", 0)),
		"crowd_update_last_usec": int(streaming_profile.get("crowd_update_last_usec", 0)),
		"crowd_spawn_max_usec": int(streaming_profile.get("crowd_spawn_max_usec", 0)),
		"crowd_spawn_avg_usec": int(streaming_profile.get("crowd_spawn_avg_usec", 0)),
		"crowd_spawn_sample_count": int(streaming_profile.get("crowd_spawn_sample_count", 0)),
		"crowd_spawn_last_usec": int(streaming_profile.get("crowd_spawn_last_usec", 0)),
		"crowd_render_commit_max_usec": int(streaming_profile.get("crowd_render_commit_max_usec", 0)),
		"crowd_render_commit_avg_usec": int(streaming_profile.get("crowd_render_commit_avg_usec", 0)),
		"crowd_render_commit_sample_count": int(streaming_profile.get("crowd_render_commit_sample_count", 0)),
		"crowd_render_commit_last_usec": int(streaming_profile.get("crowd_render_commit_last_usec", 0)),
		"crowd_active_state_count": int(streaming_profile.get("crowd_active_state_count", 0)),
		"crowd_step_usec": int(streaming_profile.get("crowd_step_usec", 0)),
		"crowd_reaction_usec": int(streaming_profile.get("crowd_reaction_usec", 0)),
		"crowd_rank_usec": int(streaming_profile.get("crowd_rank_usec", 0)),
		"crowd_snapshot_rebuild_usec": int(streaming_profile.get("crowd_snapshot_rebuild_usec", 0)),
		"crowd_farfield_count": int(streaming_profile.get("crowd_farfield_count", 0)),
		"crowd_midfield_count": int(streaming_profile.get("crowd_midfield_count", 0)),
		"crowd_nearfield_count": int(streaming_profile.get("crowd_nearfield_count", 0)),
		"crowd_farfield_step_usec": int(streaming_profile.get("crowd_farfield_step_usec", 0)),
		"crowd_midfield_step_usec": int(streaming_profile.get("crowd_midfield_step_usec", 0)),
		"crowd_nearfield_step_usec": int(streaming_profile.get("crowd_nearfield_step_usec", 0)),
		"crowd_assignment_rebuild_usec": int(streaming_profile.get("crowd_assignment_rebuild_usec", 0)),
		"crowd_assignment_candidate_count": int(streaming_profile.get("crowd_assignment_candidate_count", 0)),
		"crowd_threat_broadcast_usec": int(streaming_profile.get("crowd_threat_broadcast_usec", 0)),
		"crowd_threat_candidate_count": int(streaming_profile.get("crowd_threat_candidate_count", 0)),
		"crowd_assignment_decision": str(streaming_profile.get("crowd_assignment_decision", "")),
		"crowd_assignment_rebuild_reason": str(streaming_profile.get("crowd_assignment_rebuild_reason", "")),
		"crowd_assignment_player_velocity_mps": float(streaming_profile.get("crowd_assignment_player_velocity_mps", 0.0)),
		"crowd_assignment_raw_player_velocity_mps": float(streaming_profile.get("crowd_assignment_raw_player_velocity_mps", 0.0)),
		"crowd_assignment_player_speed_delta_mps": float(streaming_profile.get("crowd_assignment_player_speed_delta_mps", 0.0)),
		"crowd_assignment_player_speed_cap_mps": float(streaming_profile.get("crowd_assignment_player_speed_cap_mps", 0.0)),
		"crowd_chunk_commit_usec": int(streaming_profile.get("crowd_chunk_commit_usec", 0)),
		"crowd_tier1_transform_writes": int(streaming_profile.get("crowd_tier1_transform_writes", 0)),
		"ped_tier0_count": int(renderer_stats.get("pedestrian_tier0_total", 0)),
		"ped_tier1_count": int(renderer_stats.get("pedestrian_tier1_total", 0)),
		"ped_tier2_count": int(renderer_stats.get("pedestrian_tier2_total", 0)),
		"ped_tier3_count": int(renderer_stats.get("pedestrian_tier3_total", 0)),
		"ped_page_cache_hit_count": int(renderer_stats.get("pedestrian_page_cache_hit_count", 0)),
		"ped_page_cache_miss_count": int(renderer_stats.get("pedestrian_page_cache_miss_count", 0)),
		"ped_duplicate_page_load_count": int(renderer_stats.get("pedestrian_duplicate_page_load_count", 0)),
		"traffic_update_max_usec": int(streaming_profile.get("traffic_update_max_usec", 0)),
		"traffic_update_avg_usec": int(streaming_profile.get("traffic_update_avg_usec", 0)),
		"traffic_update_sample_count": int(streaming_profile.get("traffic_update_sample_count", 0)),
		"traffic_update_last_usec": int(streaming_profile.get("traffic_update_last_usec", 0)),
		"traffic_spawn_max_usec": int(streaming_profile.get("traffic_spawn_max_usec", 0)),
		"traffic_spawn_avg_usec": int(streaming_profile.get("traffic_spawn_avg_usec", 0)),
		"traffic_spawn_sample_count": int(streaming_profile.get("traffic_spawn_sample_count", 0)),
		"traffic_spawn_last_usec": int(streaming_profile.get("traffic_spawn_last_usec", 0)),
		"traffic_render_commit_max_usec": int(streaming_profile.get("traffic_render_commit_max_usec", 0)),
		"traffic_render_commit_avg_usec": int(streaming_profile.get("traffic_render_commit_avg_usec", 0)),
		"traffic_render_commit_sample_count": int(streaming_profile.get("traffic_render_commit_sample_count", 0)),
		"traffic_render_commit_last_usec": int(streaming_profile.get("traffic_render_commit_last_usec", 0)),
		"traffic_active_state_count": int(streaming_profile.get("traffic_active_state_count", 0)),
		"traffic_step_usec": int(streaming_profile.get("traffic_step_usec", 0)),
		"traffic_rank_usec": int(streaming_profile.get("traffic_rank_usec", 0)),
		"traffic_snapshot_rebuild_usec": int(streaming_profile.get("traffic_snapshot_rebuild_usec", 0)),
		"traffic_tier1_count": int(streaming_profile.get("traffic_tier1_count", 0)),
		"traffic_tier2_count": int(streaming_profile.get("traffic_tier2_count", 0)),
		"traffic_tier3_count": int(streaming_profile.get("traffic_tier3_count", 0)),
		"traffic_chunk_commit_usec": int(streaming_profile.get("traffic_chunk_commit_usec", 0)),
		"traffic_tier1_transform_writes": int(streaming_profile.get("traffic_tier1_transform_writes", 0)),
		"veh_tier0_count": int(renderer_stats.get("vehicle_tier0_total", 0)),
		"veh_tier1_count": int(renderer_stats.get("vehicle_tier1_total", 0)),
		"veh_tier2_count": int(renderer_stats.get("vehicle_tier2_total", 0)),
		"veh_tier3_count": int(renderer_stats.get("vehicle_tier3_total", 0)),
		"veh_page_cache_hit_count": int(renderer_stats.get("vehicle_page_cache_hit_count", 0)),
		"veh_page_cache_miss_count": int(renderer_stats.get("vehicle_page_cache_miss_count", 0)),
		"veh_duplicate_page_load_count": int(renderer_stats.get("vehicle_duplicate_page_load_count", 0)),
		"streaming_prepare_profile_max_usec": int(streaming_profile.get("prepare_profile_max_usec", 0)),
		"streaming_prepare_profile_avg_usec": int(streaming_profile.get("prepare_profile_avg_usec", 0)),
		"streaming_prepare_profile_sample_count": int(streaming_profile.get("prepare_profile_sample_count", 0)),
		"streaming_mount_setup_max_usec": int(streaming_profile.get("mount_setup_max_usec", 0)),
		"streaming_mount_setup_avg_usec": int(streaming_profile.get("mount_setup_avg_usec", 0)),
		"streaming_mount_setup_sample_count": int(streaming_profile.get("mount_setup_sample_count", 0)),
		"streaming_terrain_async_dispatch_max_usec": int(streaming_profile.get("terrain_async_dispatch_max_usec", 0)),
		"streaming_terrain_async_dispatch_avg_usec": int(streaming_profile.get("terrain_async_dispatch_avg_usec", 0)),
		"streaming_terrain_async_dispatch_sample_count": int(streaming_profile.get("terrain_async_dispatch_sample_count", 0)),
		"streaming_terrain_async_complete_max_usec": int(streaming_profile.get("terrain_async_complete_max_usec", 0)),
		"streaming_terrain_async_complete_avg_usec": int(streaming_profile.get("terrain_async_complete_avg_usec", 0)),
		"streaming_terrain_async_complete_sample_count": int(streaming_profile.get("terrain_async_complete_sample_count", 0)),
		"streaming_terrain_commit_max_usec": int(streaming_profile.get("terrain_commit_max_usec", 0)),
		"streaming_terrain_commit_avg_usec": int(streaming_profile.get("terrain_commit_avg_usec", 0)),
		"streaming_terrain_commit_sample_count": int(streaming_profile.get("terrain_commit_sample_count", 0)),
	}

func _align_player_to_streamed_ground() -> void:
	if player == null or _world_config == null:
		return
	var initial_anchor := player.global_position
	var chunk_payload := _build_chunk_payload_for_world_position(initial_anchor)
	var profile := CityChunkProfileBuilder.build_profile(chunk_payload)
	var chunk_center: Vector3 = chunk_payload.get("chunk_center", Vector3.ZERO)
	var local_point := _resolve_spawn_local_point(chunk_payload, profile)
	var standing_height := _estimate_player_standing_height()
	var target_position := Vector3(
		chunk_center.x + local_point.x,
		CityChunkGroundSampler.sample_height(local_point, chunk_payload, profile) + standing_height + 0.7,
		chunk_center.z + local_point.y
	)
	if player.has_method("teleport_to_world_position"):
		player.teleport_to_world_position(target_position)
	else:
		player.global_position = target_position

func _resolve_enemy_spawn_world_position(anchor_world_position: Vector3) -> Vector3:
	var forward := -player.global_transform.basis.z if player != null else Vector3.FORWARD
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var right := player.global_transform.basis.x if player != null else Vector3.RIGHT
	right.y = 0.0
	if right.length_squared() <= 0.0001:
		right = Vector3.RIGHT
	right = right.normalized()
	var best_position := _resolve_surface_world_position(anchor_world_position + forward * 40.0, 1.3)
	var best_score := -INF
	var directions: Array[Vector3] = [
		forward,
		(forward + right).normalized(),
		(forward - right).normalized(),
		right,
		-right,
		-forward,
	]
	for radius in [32.0, 38.0, 44.0, 50.0]:
		for direction in directions:
			if direction.length_squared() <= 0.0001:
				continue
			var candidate := _resolve_surface_world_position(anchor_world_position + direction * radius, 1.3)
			var score := _score_combat_spawn_world_position(candidate)
			if _has_clear_line_of_sight(anchor_world_position + Vector3.UP * 1.4, candidate + Vector3.UP * 1.1):
				score += 32.0
			if score > best_score:
				best_score = score
				best_position = candidate
	return best_position

func _score_combat_spawn_world_position(world_position: Vector3) -> float:
	var chunk_payload := _build_chunk_payload_for_world_position(world_position)
	var profile := CityChunkProfileBuilder.build_profile(chunk_payload)
	var chunk_center: Vector3 = chunk_payload.get("chunk_center", Vector3.ZERO)
	var local_point := Vector2(world_position.x - chunk_center.x, world_position.z - chunk_center.z)
	var road_clearance := _distance_to_profile_roads(local_point, profile)
	var building_clearance := _distance_to_profile_buildings(local_point, profile)
	var score := minf(road_clearance, 24.0) + minf(building_clearance, 24.0)
	var distance_to_anchor := world_position.distance_to(_get_active_anchor_position())
	score -= absf(distance_to_anchor - 40.0) * 0.35
	return score

func _resolve_surface_world_position(world_position: Vector3, standing_height: float) -> Vector3:
	var chunk_payload := _build_chunk_payload_for_world_position(world_position)
	var profile := CityChunkProfileBuilder.build_profile(chunk_payload)
	var chunk_center: Vector3 = chunk_payload.get("chunk_center", Vector3.ZERO)
	var local_point := Vector2(world_position.x - chunk_center.x, world_position.z - chunk_center.z)
	return Vector3(
		world_position.x,
		CityChunkGroundSampler.sample_height(local_point, chunk_payload, profile) + standing_height,
		world_position.z
	)

func _resolve_nearby_enemy_spawn_world_position(world_position: Vector3, standing_height: float) -> Vector3:
	var best_position := _resolve_surface_world_position(world_position, standing_height)
	var best_score := _score_combat_spawn_world_position(best_position)
	var offsets: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(6.0, 0.0),
		Vector2(-6.0, 0.0),
		Vector2(0.0, 6.0),
		Vector2(0.0, -6.0),
		Vector2(4.5, 4.5),
		Vector2(-4.5, 4.5),
		Vector2(4.5, -4.5),
		Vector2(-4.5, -4.5),
	]
	for offset in offsets:
		var candidate_world := Vector3(world_position.x + offset.x, world_position.y, world_position.z + offset.y)
		var candidate := _resolve_surface_world_position(candidate_world, standing_height)
		var score := _score_combat_spawn_world_position(candidate) - candidate.distance_to(world_position) * 0.2
		if _has_clear_line_of_sight(candidate + Vector3.UP * 1.1, _get_active_anchor_position() + Vector3.UP * 1.4):
			score += 16.0
		if score > best_score:
			best_score = score
			best_position = candidate
	return best_position

func _has_clear_line_of_sight(from_world_position: Vector3, to_world_position: Vector3) -> bool:
	if get_world_3d() == null or get_world_3d().direct_space_state == null:
		return true
	var query := PhysicsRayQueryParameters3D.create(from_world_position, to_world_position)
	query.collide_with_areas = false
	query.exclude = [player.get_rid()] if player != null else []
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()

func _snap_player_to_active_surface() -> bool:
	if player == null or get_world_3d() == null:
		return false
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return false
	var from := player.global_position + Vector3.UP * 12.0
	var to := player.global_position + Vector3.DOWN * 24.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var standing_height := _estimate_player_standing_height()
	var hit_position: Vector3 = hit.get("position", player.global_position)
	var target_position := Vector3(player.global_position.x, hit_position.y + standing_height, player.global_position.z)
	if player.has_method("teleport_to_world_position"):
		player.teleport_to_world_position(target_position)
	else:
		player.global_position = target_position
	return true

func _get_active_anchor_position() -> Vector3:
	return player.global_position if player != null else Vector3.ZERO

func _build_chunk_payload_for_world_position(world_position: Vector3) -> Dictionary:
	var chunk_key := CityChunkKey.world_to_chunk_key(_world_config, world_position)
	var bounds: Rect2 = _world_config.get_world_bounds()
	var chunk_center := Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * float(_world_config.chunk_size_m),
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * float(_world_config.chunk_size_m)
	)
	return {
		"chunk_id": _world_config.format_chunk_id(chunk_key),
		"chunk_key": chunk_key,
		"chunk_center": chunk_center,
		"chunk_size_m": float(_world_config.chunk_size_m),
		"chunk_seed": _world_config.derive_seed("render_chunk", chunk_key),
		"world_seed": int(_world_config.base_seed),
		"road_graph": _world_data.get("road_graph"),
	}

func _resolve_spawn_local_point(chunk_payload: Dictionary, profile: Dictionary) -> Vector2:
	var chunk_size := float(chunk_payload.get("chunk_size_m", 256.0))
	var half_extent := chunk_size * 0.5 - 24.0
	var best_point := Vector2.ZERO
	var best_score := -INF
	for local_x in range(-96, 97, 24):
		for local_z in range(-96, 97, 24):
			var candidate := Vector2(
				clampf(float(local_x), -half_extent, half_extent),
				clampf(float(local_z), -half_extent, half_extent)
			)
			var road_clearance := _distance_to_profile_roads(candidate, profile)
			var building_clearance := _distance_to_profile_buildings(candidate, profile)
			var center_penalty := candidate.length() * 0.08
			var score := minf(road_clearance, 48.0) + minf(building_clearance, 48.0) - center_penalty
			if score > best_score:
				best_score = score
				best_point = candidate
	return best_point

func _distance_to_profile_roads(local_point: Vector2, profile: Dictionary) -> float:
	var min_distance := INF
	for road_segment in profile.get("road_segments", []):
		var segment_dict: Dictionary = road_segment
		var width := float(segment_dict.get("width", 0.0))
		var points: Array = segment_dict.get("points", [])
		for point_index in range(points.size() - 1):
			var a: Vector3 = points[point_index]
			var b: Vector3 = points[point_index + 1]
			var distance := Geometry2D.get_closest_point_to_segment(local_point, Vector2(a.x, a.z), Vector2(b.x, b.z)).distance_to(local_point) - width * 0.5
			min_distance = minf(min_distance, distance)
	return 9999.0 if min_distance == INF else min_distance

func _distance_to_profile_buildings(local_point: Vector2, profile: Dictionary) -> float:
	var min_distance := INF
	for building in profile.get("buildings", []):
		var building_dict: Dictionary = building
		var center: Vector3 = building_dict.get("center", Vector3.ZERO)
		var radius := float(building_dict.get("visual_footprint_radius_m", building_dict.get("footprint_radius_m", 0.0)))
		min_distance = minf(min_distance, local_point.distance_to(Vector2(center.x, center.z)) - radius)
	return 9999.0 if min_distance == INF else min_distance

func _estimate_player_standing_height() -> float:
	if player == null:
		return 1.0
	var collision_shape := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		return 1.0
	if collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		return capsule.radius + capsule.height * 0.5
	if collision_shape.shape is BoxShape3D:
		var box := collision_shape.shape as BoxShape3D
		return box.size.y * 0.5
	return 1.0

func _set_camera_current(camera_node: Node, current: bool) -> void:
	var camera := camera_node as Camera3D
	if camera != null:
		camera.current = current

func _vector3_to_dict(value: Vector3) -> Dictionary:
	return {
		"x": snappedf(value.x, 0.01),
		"y": snappedf(value.y, 0.01),
		"z": snappedf(value.z, 0.01),
	}

func _build_pedestrian_player_context() -> Dictionary:
	var speed_profile := _control_mode
	if player != null and player.has_method("get_speed_profile"):
		speed_profile = str(player.get_speed_profile())
	var max_context_speed_mps := 0.0
	if player != null:
		if player.has_method("get_sprint_speed_mps"):
			max_context_speed_mps = float(player.get_sprint_speed_mps())
		elif player.has_method("get_walk_speed_mps"):
			max_context_speed_mps = float(player.get_walk_speed_mps())
	return {
		"control_mode": _control_mode,
		"speed_profile": speed_profile,
		"max_context_speed_mps": max_context_speed_mps,
	}

func _build_minimap_cache_key(center_world_position: Vector3, world_radius_m: float) -> String:
	var center_step := maxf(MINIMAP_POSITION_REFRESH_M, 1.0)
	return "|".join([
		"center:%d:%d" % [int(floor(center_world_position.x / center_step)), int(floor(center_world_position.z / center_step))],
		"radius:%d" % int(round(world_radius_m)),
	])

func _get_minimap_center_world_position(anchor_world_position: Vector3) -> Vector3:
	var center_step := maxf(MINIMAP_POSITION_REFRESH_M, 1.0)
	return Vector3(
		float(int(floor(anchor_world_position.x / center_step))) * center_step,
		anchor_world_position.y,
		float(int(floor(anchor_world_position.z / center_step))) * center_step
	)

func _build_current_minimap_route_overlay(center_world_position: Vector3, world_radius_m: float) -> Dictionary:
	if _minimap_projector == null or _minimap_route_world_positions.is_empty():
		return {}
	return _minimap_projector.build_route_overlay_from_world_positions(
		center_world_position,
		_minimap_route_world_positions,
		world_radius_m,
		str(_active_route_result.get("route_style_id", ROUTE_STYLE_DESTINATION))
	)

func _build_current_minimap_pin_overlay(center_world_position: Vector3, world_radius_m: float) -> Dictionary:
	if _minimap_projector == null:
		return {}
	return _minimap_projector.build_pin_overlay(center_world_position, _get_map_pins("minimap"), world_radius_m)

func _setup_map_ui() -> void:
	_map_pin_registry = CityMapPinRegistry.new()
	if hud == null or CityMapScreenScene == null:
		return
	var root_control := hud.get_node_or_null("Root") as Control
	if root_control == null:
		return
	var map_screen := CityMapScreenScene.instantiate() as Control
	if map_screen == null:
		return
	map_screen.name = "FullMap"
	root_control.add_child(map_screen)
	_map_screen = map_screen
	if _map_screen.has_method("setup") and _world_config != null and _world_config.has_method("get_world_bounds"):
		_map_screen.setup(_world_config.get_world_bounds())
	if _map_screen.has_method("set_road_graph"):
		_map_screen.set_road_graph(_world_data.get("road_graph"))
	if _map_screen.has_signal("map_world_point_selected") and not _map_screen.is_connected("map_world_point_selected", Callable(self, "_on_map_world_point_selected")):
		_map_screen.connect("map_world_point_selected", Callable(self, "_on_map_world_point_selected"))
	if _map_screen.has_signal("task_selected") and not _map_screen.is_connected("task_selected", Callable(self, "_on_task_selected")):
		_map_screen.connect("task_selected", Callable(self, "_on_task_selected"))

func _connect_vehicle_radio_browser_ui() -> void:
	if hud == null:
		return
	var browser := hud.get_node_or_null("Root/VehicleRadioBrowser")
	if browser == null:
		return
	if browser.has_signal("close_requested") and not browser.is_connected("close_requested", Callable(self, "close_vehicle_radio_browser")):
		browser.connect("close_requested", Callable(self, "close_vehicle_radio_browser"))
	if browser.has_signal("tab_selected") and not browser.is_connected("tab_selected", Callable(self, "set_vehicle_radio_browser_tab")):
		browser.connect("tab_selected", Callable(self, "set_vehicle_radio_browser_tab"))
	if browser.has_signal("browse_country_selected") and not browser.is_connected("browse_country_selected", Callable(self, "select_vehicle_radio_browser_country")):
		browser.connect("browse_country_selected", Callable(self, "select_vehicle_radio_browser_country"))
	if browser.has_signal("browse_root_requested") and not browser.is_connected("browse_root_requested", Callable(self, "show_vehicle_radio_browser_country_root")):
		browser.connect("browse_root_requested", Callable(self, "show_vehicle_radio_browser_country_root"))
	if browser.has_signal("catalog_refresh_requested") and not browser.is_connected("catalog_refresh_requested", Callable(self, "refresh_vehicle_radio_browser_catalog")):
		browser.connect("catalog_refresh_requested", Callable(self, "refresh_vehicle_radio_browser_catalog"))
	if browser.has_signal("filter_text_changed") and not browser.is_connected("filter_text_changed", Callable(self, "set_vehicle_radio_browser_filter_text")):
		browser.connect("filter_text_changed", Callable(self, "set_vehicle_radio_browser_filter_text"))
	if browser.has_signal("proxy_mode_selected") and not browser.is_connected("proxy_mode_selected", Callable(self, "set_vehicle_radio_browser_proxy_mode")):
		browser.connect("proxy_mode_selected", Callable(self, "set_vehicle_radio_browser_proxy_mode"))
	if browser.has_signal("station_selected") and not browser.is_connected("station_selected", Callable(self, "select_vehicle_radio_browser_station")):
		browser.connect("station_selected", Callable(self, "select_vehicle_radio_browser_station"))
	if browser.has_signal("current_station_favorite_toggled") and not browser.is_connected("current_station_favorite_toggled", Callable(self, "toggle_vehicle_radio_browser_favorite")):
		browser.connect("current_station_favorite_toggled", Callable(self, "toggle_vehicle_radio_browser_favorite"))
	if browser.has_signal("preset_assign_requested") and not browser.is_connected("preset_assign_requested", Callable(self, "assign_vehicle_radio_browser_preset")):
		browser.connect("preset_assign_requested", Callable(self, "assign_vehicle_radio_browser_preset"))
	if browser.has_signal("play_requested") and not browser.is_connected("play_requested", Callable(self, "play_vehicle_radio_browser_selected_station")):
		browser.connect("play_requested", Callable(self, "play_vehicle_radio_browser_selected_station"))
	if browser.has_signal("stop_requested") and not browser.is_connected("stop_requested", Callable(self, "stop_vehicle_radio_browser_playback")):
		browser.connect("stop_requested", Callable(self, "stop_vehicle_radio_browser_playback"))
	if browser.has_signal("volume_linear_changed") and not browser.is_connected("volume_linear_changed", Callable(self, "set_vehicle_radio_browser_volume_linear")):
		browser.connect("volume_linear_changed", Callable(self, "set_vehicle_radio_browser_volume_linear"))

func _connect_vehicle_radio_quick_overlay_ui() -> void:
	if hud == null:
		return
	var overlay := hud.get_node_or_null("Root/VehicleRadioQuickOverlay")
	if overlay == null:
		return
	if overlay.has_signal("prev_requested") and not overlay.is_connected("prev_requested", Callable(self, "_on_vehicle_radio_quick_overlay_prev_requested")):
		overlay.connect("prev_requested", Callable(self, "_on_vehicle_radio_quick_overlay_prev_requested"))
	if overlay.has_signal("next_requested") and not overlay.is_connected("next_requested", Callable(self, "_on_vehicle_radio_quick_overlay_next_requested")):
		overlay.connect("next_requested", Callable(self, "_on_vehicle_radio_quick_overlay_next_requested"))
	if overlay.has_signal("confirm_requested") and not overlay.is_connected("confirm_requested", Callable(self, "_on_vehicle_radio_quick_overlay_confirm_requested")):
		overlay.connect("confirm_requested", Callable(self, "_on_vehicle_radio_quick_overlay_confirm_requested"))
	if overlay.has_signal("power_toggle_requested") and not overlay.is_connected("power_toggle_requested", Callable(self, "_on_vehicle_radio_quick_overlay_power_toggle_requested")):
		overlay.connect("power_toggle_requested", Callable(self, "_on_vehicle_radio_quick_overlay_power_toggle_requested"))
	if overlay.has_signal("browser_requested") and not overlay.is_connected("browser_requested", Callable(self, "_on_vehicle_radio_quick_overlay_browser_requested")):
		overlay.connect("browser_requested", Callable(self, "_on_vehicle_radio_quick_overlay_browser_requested"))
	if overlay.has_signal("close_requested") and not overlay.is_connected("close_requested", Callable(self, "close_vehicle_radio_quick_overlay")):
		overlay.connect("close_requested", Callable(self, "close_vehicle_radio_quick_overlay"))
	if overlay.has_signal("slot_pressed") and not overlay.is_connected("slot_pressed", Callable(self, "_on_vehicle_radio_quick_overlay_slot_pressed")):
		overlay.connect("slot_pressed", Callable(self, "_on_vehicle_radio_quick_overlay_slot_pressed"))

func _on_vehicle_radio_quick_overlay_prev_requested() -> void:
	_step_vehicle_radio_quick_selection(-1)

func _on_vehicle_radio_quick_overlay_next_requested() -> void:
	_step_vehicle_radio_quick_selection(1)

func _on_vehicle_radio_quick_overlay_confirm_requested() -> void:
	_commit_vehicle_radio_quick_selection()
	_sync_vehicle_radio_browser()
	_sync_vehicle_radio_quick_overlay()

func _on_vehicle_radio_quick_overlay_power_toggle_requested() -> void:
	_handle_vehicle_radio_action("vehicle_radio_power_toggle")

func _on_vehicle_radio_quick_overlay_browser_requested() -> void:
	_handle_vehicle_radio_action("vehicle_radio_browser_open")

func _on_vehicle_radio_quick_overlay_slot_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _vehicle_radio_quick_slots.size():
		return
	_vehicle_radio_quick_selected_index = slot_index
	_commit_vehicle_radio_quick_selection()
	_sync_vehicle_radio_browser()
	_sync_vehicle_radio_quick_overlay()

func _sync_navigation_consumers(force_minimap_refresh: bool = false) -> void:
	_sync_task_presentation_state()
	_refresh_task_world_markers()
	if _map_screen != null:
		if _map_screen.has_method("set_map_open"):
			_map_screen.set_map_open(_full_map_open)
		if _map_screen.has_method("set_world_paused"):
			_map_screen.set_world_paused(_world_simulation_paused)
		if _map_screen.has_method("set_player_marker"):
			_map_screen.set_player_marker(_build_navigation_player_marker_state())
		if _map_screen.has_method("set_pins"):
			_map_screen.set_pins(_get_map_pins("full_map"))
		if _map_screen.has_method("set_route_result"):
			_map_screen.set_route_result(_active_route_result)
		if _map_screen.has_method("set_last_selection_contract"):
			_map_screen.set_last_selection_contract(_last_map_selection_contract)
		if _map_screen.has_method("set_task_panel_state"):
			_map_screen.set_task_panel_state(_build_task_panel_state())
	if force_minimap_refresh and hud != null and hud.has_method("set_minimap_snapshot"):
		hud.set_minimap_snapshot(build_minimap_snapshot())
		_last_minimap_hud_refresh_tick_usec = Time.get_ticks_usec()

func _refresh_task_world_markers() -> void:
	if _task_world_marker_runtime == null or not is_instance_valid(_task_world_marker_runtime):
		return
	if _world_config == null or not _task_world_marker_runtime.has_method("refresh"):
		return
	_task_world_marker_runtime.refresh(_get_route_refresh_anchor_position(), float(_world_config.chunk_size_m) * 1.6)

func _sync_controls_help_overlay() -> void:
	if hud != null and hud.has_method("set_controls_help_state"):
		hud.set_controls_help_state(_build_controls_help_state())

func _build_controls_help_state() -> Dictionary:
	return {
		"visible": _controls_help_open,
		"title": "键位说明",
		"subtitle": "全屏说明层；打开时世界暂停。电台浏览器可随时打开，quick overlay 仍只在驾驶时可用。",
		"close_hint": "F1 关闭",
		"sections": _build_controls_help_sections(),
	}

func _build_controls_help_sections() -> Array:
	return [
		{
			"title": "基础移动与视角",
			"entries": [
				{"binding": "W / A / S / D 或 方向键", "description": "步行移动；驾车时对应油门/转向"},
				{"binding": "Shift", "description": "步行冲刺"},
				{"binding": "Space", "description": "跳跃；驾车时刹车"},
				{"binding": "鼠标移动", "description": "控制视角；驾车时鼠标左右辅助转向"},
				{"binding": "Esc", "description": "释放 / 重新捕获鼠标"},
			],
		},
		{
			"title": "世界交互与导航",
			"entries": [
				{"binding": "E", "description": "与 NPC 互动；对话中再次按下可关闭"},
				{"binding": "F", "description": "进入 / 退出 / 劫持车辆"},
				{"binding": "M", "description": "打开全屏地图"},
				{"binding": "T", "description": "传送到当前目的地"},
				{"binding": "G", "description": "驾车时开启 / 停止自动驾驶"},
				{"binding": "C", "description": "切换普通 / inspection 速度档"},
			],
		},
		{
			"title": "战斗与装备",
			"entries": [
				{"binding": "左键", "description": "开火 / 投掷 / 发射激光指示"},
				{"binding": "右键", "description": "瞄准；手雷模式下为预备投掷"},
				{"binding": "0 / 1 / 2", "description": "切换激光指示 / 步枪 / 手雷"},
				{"binding": "Ctrl", "description": "地面重击"},
			],
		},
		{
			"title": "车辆电台与浏览器",
			"entries": [
				{"binding": _format_input_action_binding("vehicle_radio_quick_open"), "description": "驾驶时打开 quick overlay"},
				{"binding": _format_input_action_binding("vehicle_radio_prev"), "description": "quick overlay 上一台"},
				{"binding": _format_input_action_binding("vehicle_radio_next"), "description": "quick overlay 下一台"},
				{"binding": _format_input_action_binding("vehicle_radio_confirm"), "description": "确认当前 quick slot"},
				{"binding": _format_input_action_binding("vehicle_radio_power_toggle"), "description": "电台开 / 关"},
				{"binding": _format_input_action_binding("vehicle_radio_browser_open"), "description": "随时打开 / 关闭电台浏览器"},
				{"binding": _format_input_action_binding("vehicle_radio_cancel"), "description": "关闭 quick overlay / browser"},
			],
		},
		{
			"title": "调试与显示",
			"entries": [
				{"binding": "F1", "description": "打开这份键位说明"},
				{"binding": "小键盘 +", "description": "建筑导出调试快捷键"},
				{"binding": "小键盘 *", "description": "切换行人显示"},
				{"binding": "小键盘 -", "description": "切换 FPS 叠层"},
				{"binding": "小键盘 /", "description": "生成 trauma enemy"},
			],
		},
	]

func _format_input_action_binding(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return "未绑定"
	var labels := PackedStringArray()
	for event_variant in InputMap.action_get_events(action_name):
		var key_event := event_variant as InputEventKey
		if key_event == null:
			continue
		var keycode := key_event.keycode if key_event.keycode != 0 else key_event.physical_keycode
		var label := OS.get_keycode_string(keycode)
		if label == "" or labels.has(label):
			continue
		labels.append(label)
	if labels.is_empty():
		return "未绑定"
	return " / ".join(labels)

func _get_map_pins(scope: String = "all") -> Array[Dictionary]:
	if _map_pin_registry == null or not _map_pin_registry.has_method("get_pins"):
		return []
	return _map_pin_registry.get_pins(scope)

func _update_service_building_map_pins() -> void:
	if _service_building_map_pin_runtime == null or not _service_building_map_pin_runtime.has_method("advance"):
		return
	if not _full_map_open and Engine.get_process_frames() < SERVICE_BUILDING_MAP_PIN_STARTUP_DELAY_FRAMES:
		return
	if _has_streaming_backpressure():
		return
	var batch_result: Dictionary = _service_building_map_pin_runtime.advance(
		SERVICE_BUILDING_MAP_PIN_BATCH_SIZE,
		SERVICE_BUILDING_MAP_PIN_BATCH_BUDGET_USEC
	)
	if not bool(batch_result.get("did_change", false)):
		return
	if bool(batch_result.get("did_pin_delta", false)):
		_apply_service_building_pin_delta(batch_result)
	if _full_map_open and bool(batch_result.get("did_pin_delta", false)) and _map_screen != null and _map_screen.has_method("set_pins"):
		_map_screen.set_pins(_get_map_pins("full_map"))

func _sync_service_building_pin_registry() -> void:
	if _map_pin_registry == null or not _map_pin_registry.has_method("replace_service_building_pins"):
		return
	var pins: Array = []
	if _service_building_map_pin_runtime != null and _service_building_map_pin_runtime.has_method("get_pins"):
		pins = _service_building_map_pin_runtime.get_pins()
	_map_pin_registry.replace_service_building_pins(pins)

func _apply_service_building_pin_delta(batch_result: Dictionary) -> void:
	if _map_pin_registry == null:
		return
	for pin_id_variant in batch_result.get("pin_remove_ids", []):
		var pin_id := str(pin_id_variant).strip_edges()
		if pin_id == "" or not _map_pin_registry.has_method("remove_pin"):
			continue
		_map_pin_registry.remove_pin(pin_id)
	for pin_variant in batch_result.get("pin_upserts", []):
		if not (pin_variant is Dictionary) or not _map_pin_registry.has_method("register_pin"):
			continue
		_map_pin_registry.register_pin(pin_variant as Dictionary)

func _build_task_panel_state() -> Dictionary:
	if _task_brief_view_model == null or _task_runtime == null or not _task_brief_view_model.has_method("build"):
		return {}
	return _task_brief_view_model.build(_task_runtime)

func _sync_task_presentation_state() -> void:
	if _map_pin_registry != null and _map_pin_registry.has_method("replace_task_pins"):
		var projected_pins: Array = []
		var tracked_task_id := get_tracked_task_id()
		if _task_pin_projection != null and _task_runtime != null and (_full_map_open or tracked_task_id != ""):
			projected_pins = _task_pin_projection.build_pins(_task_runtime, false)
		_map_pin_registry.replace_task_pins(projected_pins)

func _on_task_selected(task_id: String) -> void:
	select_task_for_tracking(task_id)

func _ensure_task_system_runtimes() -> void:
	if _task_trigger_runtime == null:
		_task_trigger_runtime = CityTaskTriggerRuntime.new()
		if _task_trigger_runtime.has_method("setup"):
			_task_trigger_runtime.setup(_task_runtime)
	if _task_world_marker_runtime != null and is_instance_valid(_task_world_marker_runtime):
		return
	_task_world_marker_runtime = get_node_or_null("TaskWorldMarkerRuntime") as Node3D
	if _task_world_marker_runtime == null:
		_task_world_marker_runtime = CityTaskWorldMarkerRuntime.new()
		_task_world_marker_runtime.name = "TaskWorldMarkerRuntime"
		add_child(_task_world_marker_runtime)
	if _task_world_marker_runtime.has_method("setup"):
		_task_world_marker_runtime.setup(_task_runtime, Callable(self, "_resolve_task_marker_world_position"))

func _ensure_helicopter_gunship_encounter_runtime() -> void:
	if _helicopter_gunship_encounter_runtime != null and is_instance_valid(_helicopter_gunship_encounter_runtime):
		return
	_helicopter_gunship_encounter_runtime = get_node_or_null("HelicopterGunshipEncounterRuntime") as Node3D
	if _helicopter_gunship_encounter_runtime == null and CityHelicopterGunshipWorldEncounterScene != null:
		_helicopter_gunship_encounter_runtime = CityHelicopterGunshipWorldEncounterScene.instantiate() as Node3D
		if _helicopter_gunship_encounter_runtime != null:
			_helicopter_gunship_encounter_runtime.name = "HelicopterGunshipEncounterRuntime"
			add_child(_helicopter_gunship_encounter_runtime)
	if _helicopter_gunship_encounter_runtime == null or not _helicopter_gunship_encounter_runtime.has_signal("encounter_completed"):
		return
	var completion_callable := Callable(self, "_on_helicopter_gunship_encounter_completed")
	if not _helicopter_gunship_encounter_runtime.encounter_completed.is_connected(completion_callable):
		_helicopter_gunship_encounter_runtime.encounter_completed.connect(completion_callable)

func _ensure_interaction_runtimes() -> void:
	if _dialogue_runtime == null:
		_dialogue_runtime = CityDialogueRuntime.new()
	if _npc_interaction_runtime == null or not is_instance_valid(_npc_interaction_runtime):
		_npc_interaction_runtime = get_node_or_null("NpcInteractionRuntime")
		if _npc_interaction_runtime == null:
			_npc_interaction_runtime = CityNpcInteractionRuntime.new()
			_npc_interaction_runtime.name = "NpcInteractionRuntime"
			add_child(_npc_interaction_runtime)
	if _npc_interaction_runtime.has_method("setup"):
		_npc_interaction_runtime.setup(player, _dialogue_runtime)
	if _interactive_prop_runtime == null or not is_instance_valid(_interactive_prop_runtime):
		_interactive_prop_runtime = get_node_or_null("InteractivePropRuntime")
		if _interactive_prop_runtime == null:
			_interactive_prop_runtime = CityInteractivePropRuntime.new()
			_interactive_prop_runtime.name = "InteractivePropRuntime"
			add_child(_interactive_prop_runtime)
	if _interactive_prop_runtime.has_method("setup"):
		_interactive_prop_runtime.setup(player)

func _update_npc_interaction_system() -> void:
	_ensure_interaction_runtimes()
	var prompt_blocked := _is_primary_interaction_prompt_blocked()
	if _npc_interaction_runtime != null and _npc_interaction_runtime.has_method("refresh"):
		_npc_interaction_runtime.refresh(prompt_blocked)
	if _interactive_prop_runtime != null and _interactive_prop_runtime.has_method("refresh"):
		_interactive_prop_runtime.refresh(prompt_blocked)
	_sync_npc_interaction_ui()

func _sync_npc_interaction_ui() -> void:
	if hud == null:
		return
	if hud.has_method("set_interaction_prompt_state"):
		hud.set_interaction_prompt_state(_resolve_primary_interaction_prompt_state())
	if hud.has_method("set_dialogue_panel_state"):
		hud.set_dialogue_panel_state(_build_dialogue_panel_state())

func _is_primary_interaction_prompt_blocked() -> bool:
	var prompt_blocked := _full_map_open or _world_simulation_paused or is_dialogue_active()
	if player != null and player.has_method("is_driving_vehicle") and bool(player.is_driving_vehicle()):
		prompt_blocked = true
	return prompt_blocked

func _resolve_primary_interaction_prompt_state() -> Dictionary:
	var npc_state: Dictionary = get_npc_interaction_state()
	if bool(npc_state.get("visible", false)):
		npc_state["owner_kind"] = "npc"
	var prop_state: Dictionary = get_interactive_prop_interaction_state()
	if bool(prop_state.get("visible", false)):
		prop_state["owner_kind"] = "interactive_prop"
	var fishing_state: Dictionary = get_fishing_primary_interaction_state()
	if bool(fishing_state.get("visible", false)):
		fishing_state["owner_kind"] = "fishing_venue"
	var candidates: Array = []
	for state_variant in [npc_state, prop_state, fishing_state]:
		var state: Dictionary = state_variant
		if bool(state.get("visible", false)):
			candidates.append(state)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance_m", INF)) < float(b.get("distance_m", INF))
	)
	return candidates[0]

func _augment_tennis_interaction_prompt_state(prompt_state: Dictionary) -> Dictionary:
	if _tennis_venue_runtime == null or not _tennis_venue_runtime.has_method("get_state"):
		return prompt_state
	var runtime_state: Dictionary = _tennis_venue_runtime.get_state()
	var active_tennis_prop_id := str(runtime_state.get("primary_ball_prop_id", ""))
	if active_tennis_prop_id == "":
		return prompt_state
	if prompt_state.is_empty():
		prompt_state = {
			"visible": false,
			"owner_kind": "interactive_prop",
			"prop_id": active_tennis_prop_id,
			"display_name": "Tennis Ball",
			"interaction_kind": "tennis_ball",
			"prompt_text": "",
			"distance_m": 0.0,
		}
	elif str(prompt_state.get("prop_id", "")) != "" and str(prompt_state.get("prop_id", "")) != active_tennis_prop_id:
		return prompt_state
	else:
		prompt_state["owner_kind"] = "interactive_prop"
		prompt_state["prop_id"] = active_tennis_prop_id
	var match_state := str(runtime_state.get("match_state", "idle"))
	match match_state:
		"pre_serve":
			prompt_state["visible"] = str(runtime_state.get("server_side", "home")) == "home"
			prompt_state["prompt_text"] = "按 E 发球"
		"rally":
			if str(runtime_state.get("target_side", "")) == "home":
				var strike_window_state := str(runtime_state.get("strike_window_state", "idle"))
				var has_receive_chain := bool(runtime_state.get("landing_marker_visible", false)) or str(runtime_state.get("auto_footwork_assist_state", "idle")) != "idle"
				prompt_state["visible"] = strike_window_state == "ready" or has_receive_chain
				prompt_state["prompt_text"] = "按 E 回球" if strike_window_state == "ready" else "跟住绿圈，等待时机"
			else:
				prompt_state["visible"] = false
		_:
			prompt_state["visible"] = false
	return prompt_state

func _build_dialogue_panel_state() -> Dictionary:
	var dialogue_state := get_dialogue_runtime_state()
	return {
		"visible": str(dialogue_state.get("status", "")) == "active",
		"speaker_name": str(dialogue_state.get("speaker_name", "")),
		"body_text": str(dialogue_state.get("body_text", "")),
		"dialogue_id": str(dialogue_state.get("dialogue_id", "")),
		"owner_actor_id": str(dialogue_state.get("owner_actor_id", "")),
		"close_hint_text": "按 E 关闭",
	}

func _update_task_system(delta: float) -> void:
	if player == null or _task_runtime == null:
		return
	_ensure_task_system_runtimes()
	_ensure_helicopter_gunship_encounter_runtime()
	if _task_trigger_runtime != null and _task_trigger_runtime.has_method("update"):
		var trigger_result: Dictionary = _task_trigger_runtime.update(_get_active_anchor_position(), get_player_vehicle_state(), float(_world_config.chunk_size_m) * 1.5)
		_handle_task_trigger_result(trigger_result)
	_update_helicopter_gunship_task_runtime(delta)
	if _task_world_marker_runtime != null and _task_world_marker_runtime.has_method("refresh"):
		_task_world_marker_runtime.refresh(_get_route_refresh_anchor_position(), float(_world_config.chunk_size_m) * 1.6)
		if _task_world_marker_runtime.has_method("tick"):
			_task_world_marker_runtime.tick(delta)

func _handle_task_trigger_result(trigger_result: Dictionary) -> void:
	if trigger_result.is_empty():
		return
	var started_task: Dictionary = trigger_result.get("started_task", {})
	if not started_task.is_empty():
		select_task_for_tracking(str(started_task.get("task_id", "")), "task_trigger")
		return
	var completed_task: Dictionary = trigger_result.get("completed_task", {})
	if not completed_task.is_empty():
		_clear_active_navigation_state(false)
		_sync_navigation_consumers(true)

func _resolve_task_marker_world_position(anchor: Vector3) -> Vector3:
	var surface_position := _resolve_surface_world_position(anchor, DESTINATION_WORLD_MARKER_SURFACE_OFFSET_M)
	surface_position.y += 0.03
	return surface_position

func _update_helicopter_gunship_task_runtime(delta: float) -> void:
	if _task_runtime == null or _task_slot_index == null:
		return
	_ensure_helicopter_gunship_encounter_runtime()
	if _helicopter_gunship_encounter_runtime == null:
		return
	_sync_helicopter_gunship_encounter_anchor()
	var task_snapshot: Dictionary = _task_runtime.get_task_snapshot(HELICOPTER_GUNSHIP_TASK_ID)
	if task_snapshot.is_empty():
		return
	var status := str(task_snapshot.get("status", "available"))
	var encounter_state := get_helicopter_gunship_encounter_state()
	var phase := str(encounter_state.get("phase", "idle"))
	if status == "active":
		if phase == "idle" and _helicopter_gunship_encounter_runtime.has_method("start_encounter"):
			_helicopter_gunship_encounter_runtime.start_encounter()
	elif status != "completed" and phase != "idle" and _helicopter_gunship_encounter_runtime.has_method("reset_encounter"):
		_helicopter_gunship_encounter_runtime.reset_encounter()
	if _helicopter_gunship_pending_reset_task_id == "":
		return
	_helicopter_gunship_pending_reset_delay_sec = maxf(_helicopter_gunship_pending_reset_delay_sec - maxf(delta, 0.0), 0.0)
	if _helicopter_gunship_pending_reset_delay_sec > 0.0:
		return
	if phase != "idle":
		return
	if not _task_runtime.has_method("reset_repeatable_task"):
		return
	var reset_snapshot: Dictionary = _task_runtime.reset_repeatable_task(_helicopter_gunship_pending_reset_task_id)
	if reset_snapshot.is_empty():
		return
	var reset_task_id := str(reset_snapshot.get("task_id", ""))
	var tracked_task_id := get_tracked_task_id()
	_helicopter_gunship_pending_reset_task_id = ""
	_helicopter_gunship_pending_reset_delay_sec = 0.0
	if reset_task_id != "" and tracked_task_id == reset_task_id:
		var selection_mode := str(_last_map_selection_contract.get("selection_mode", "task_panel"))
		select_task_for_tracking(reset_task_id, selection_mode)
	else:
		_sync_navigation_consumers(true)

func _sync_helicopter_gunship_encounter_anchor() -> void:
	if _helicopter_gunship_encounter_runtime == null or _task_runtime == null or _task_slot_index == null:
		return
	var task_snapshot: Dictionary = _task_runtime.get_task_snapshot(HELICOPTER_GUNSHIP_TASK_ID)
	if task_snapshot.is_empty():
		return
	var start_slot: Dictionary = _task_slot_index.get_slot_by_id(str(task_snapshot.get("start_slot", "")))
	if start_slot.is_empty():
		return
	_helicopter_gunship_encounter_runtime.global_position = start_slot.get("world_anchor", Vector3.ZERO)

func _on_helicopter_gunship_encounter_completed(_result: Dictionary) -> void:
	if _task_runtime == null or not _task_runtime.has_method("complete_active_task_by_event"):
		return
	var completed: Dictionary = _task_runtime.complete_active_task_by_event(HELICOPTER_GUNSHIP_COMPLETION_EVENT_ID)
	if completed.is_empty():
		return
	_helicopter_gunship_pending_reset_task_id = str(completed.get("task_id", ""))
	_helicopter_gunship_pending_reset_delay_sec = HELICOPTER_GUNSHIP_REPEATABLE_RESET_DELAY_SEC
	_clear_active_navigation_state(false)

func _handle_npc_interaction_shortcut() -> bool:
	var interaction_result: Dictionary = _handle_npc_primary_interaction()
	return bool(interaction_result.get("success", false))

func handle_primary_interaction() -> Dictionary:
	if _full_map_open:
		return {
			"success": false,
			"error": "full_map_open",
		}
	if is_dialogue_active():
		if _dialogue_runtime != null and _dialogue_runtime.has_method("close_dialogue"):
			_dialogue_runtime.close_dialogue()
			_update_npc_interaction_system()
			return {
				"success": true,
				"owner_kind": "dialogue",
				"interaction_kind": "close_dialogue",
			}
		return {
			"success": false,
			"error": "dialogue_runtime_unavailable",
		}
	if player != null and player.has_method("is_driving_vehicle") and bool(player.is_driving_vehicle()):
		return {
			"success": false,
			"error": "player_driving_vehicle",
		}
	var fishing_interaction_result: Dictionary = _handle_fishing_primary_interaction()
	if bool(fishing_interaction_result.get("handled", false)):
		return fishing_interaction_result
	var primary_state := _resolve_primary_interaction_prompt_state()
	var owner_kind := str(primary_state.get("owner_kind", ""))
	if owner_kind == "interactive_prop":
		return _handle_interactive_prop_primary_interaction()
	if owner_kind == "npc":
		return _handle_npc_primary_interaction()
	return {
		"success": false,
		"error": "missing_primary_candidate",
	}

func _handle_fishing_primary_interaction() -> Dictionary:
	if _fishing_venue_runtime == null or not _fishing_venue_runtime.has_method("handle_primary_interaction"):
		return {
			"success": false,
			"error": "missing_fishing_runtime",
		}
	var interaction_result: Dictionary = _fishing_venue_runtime.handle_primary_interaction(chunk_renderer, player)
	if bool(interaction_result.get("handled", false)):
		_sync_player_fishing_state()
		_apply_fishing_feedback_from_state(get_fishing_venue_runtime_state())
		_update_npc_interaction_system()
	return interaction_result

func _get_player_fishing_preview_state() -> Dictionary:
	if player != null and player.has_method("get_fishing_preview_state"):
		return player.get_fishing_preview_state()
	return {}

func _resolve_active_fishing_venue_node() -> Node3D:
	if chunk_renderer == null or not chunk_renderer.has_method("find_scene_minigame_venue_node"):
		return null
	var runtime_state := get_fishing_venue_runtime_state()
	var venue_id := str(runtime_state.get("active_venue_id", "")).strip_edges()
	if venue_id == "":
		return null
	return chunk_renderer.find_scene_minigame_venue_node(venue_id) as Node3D

func _sync_player_fishing_state(runtime_state: Dictionary = {}) -> void:
	if player == null or not is_instance_valid(player):
		return
	if runtime_state.is_empty():
		runtime_state = get_fishing_venue_runtime_state()
	var active_venue := _resolve_active_fishing_venue_node()
	var bite_zone_world_position := Vector3.ZERO
	if active_venue != null and active_venue.has_method("get_bite_zone"):
		var bite_zone: Dictionary = active_venue.get_bite_zone()
		bite_zone_world_position = bite_zone.get("world_position", Vector3.ZERO)
	if player.has_method("set_fishing_mode_enabled"):
		player.set_fishing_mode_enabled(bool(runtime_state.get("fishing_mode_active", false)), bite_zone_world_position.y)
	if player.has_method("set_fishing_pole_equipped_visible"):
		player.set_fishing_pole_equipped_visible(bool(runtime_state.get("pole_equipped", false)))
	if player.has_method("set_fishing_line_visual_state"):
		player.set_fishing_line_visual_state(
			bool(runtime_state.get("fishing_line_visible", false)),
			runtime_state.get("bobber_world_position", Vector3.ZERO)
		)

func _apply_fishing_feedback_from_state(runtime_state: Dictionary) -> void:
	if hud == null:
		return
	var feedback_token := int(runtime_state.get("feedback_event_token", 0))
	if feedback_token <= 0 or feedback_token == _last_fishing_feedback_token:
		return
	_last_fishing_feedback_token = feedback_token
	var feedback_text := str(runtime_state.get("feedback_event_text", "")).strip_edges()
	if feedback_text == "":
		return
	if hud.has_method("set_focus_message"):
		hud.set_focus_message(feedback_text, 1.8)

func _handle_npc_primary_interaction() -> Dictionary:
	if _npc_interaction_runtime == null or not _npc_interaction_runtime.has_method("get_active_contract"):
		return {
			"success": false,
			"error": "missing_npc_runtime",
		}
	var interaction_contract: Dictionary = _npc_interaction_runtime.get_active_contract()
	if interaction_contract.is_empty():
		return {
			"success": false,
			"error": "missing_npc_contract",
		}
	if _dialogue_runtime == null or not _dialogue_runtime.has_method("begin_dialogue"):
		return {
			"success": false,
			"error": "missing_dialogue_runtime",
			"actor_id": str(interaction_contract.get("actor_id", "")),
		}
	var dialogue_state: Dictionary = _dialogue_runtime.begin_dialogue(interaction_contract)
	if dialogue_state.is_empty():
		return {
			"success": false,
			"error": "dialogue_begin_failed",
			"actor_id": str(interaction_contract.get("actor_id", "")),
		}
	_update_npc_interaction_system()
	return {
		"success": true,
		"owner_kind": "npc",
		"interaction_kind": str(interaction_contract.get("interaction_kind", "")),
		"actor_id": str(interaction_contract.get("actor_id", "")),
	}

func _handle_interactive_prop_primary_interaction() -> Dictionary:
	if _interactive_prop_runtime == null or not _interactive_prop_runtime.has_method("trigger_active_interaction"):
		return {
			"success": false,
			"error": "missing_interactive_prop_runtime",
		}
	var active_contract: Dictionary = _interactive_prop_runtime.get_active_contract() if _interactive_prop_runtime.has_method("get_active_contract") else {}
	var active_prop_id := str(active_contract.get("prop_id", ""))
	if active_prop_id == "":
		var prompt_state: Dictionary = get_interactive_prop_interaction_state()
		if bool(prompt_state.get("visible", false)):
			active_contract = prompt_state.duplicate(true)
			active_prop_id = str(active_contract.get("prop_id", ""))
	if active_prop_id != "" and _tennis_venue_runtime != null and _tennis_venue_runtime.has_method("handle_primary_interaction"):
		var tennis_interaction_result: Dictionary = _tennis_venue_runtime.handle_primary_interaction(chunk_renderer, player, active_prop_id, active_contract.duplicate(true))
		if bool(tennis_interaction_result.get("handled", false)):
			if not tennis_interaction_result.has("owner_kind"):
				tennis_interaction_result["owner_kind"] = "interactive_prop"
			_update_npc_interaction_system()
			return tennis_interaction_result
	var interaction_result: Dictionary = _interactive_prop_runtime.trigger_active_interaction(player)
	if not interaction_result.has("owner_kind"):
		interaction_result["owner_kind"] = "interactive_prop"
	if bool(interaction_result.get("success", false)):
		var prop_id := str(interaction_result.get("prop_id", ""))
		if _soccer_venue_runtime != null and _soccer_venue_runtime.has_method("notify_manual_ball_interaction"):
			_soccer_venue_runtime.notify_manual_ball_interaction(prop_id, player)
	_update_npc_interaction_system()
	return interaction_result

func is_dialogue_active() -> bool:
	return _dialogue_runtime != null and _dialogue_runtime.has_method("is_active") and bool(_dialogue_runtime.is_active())

func _apply_world_simulation_pause(should_pause: bool) -> void:
	if _world_simulation_paused == should_pause:
		return
	_world_simulation_paused = should_pause
	if should_pause:
		_paused_world_process_entries.clear()
		for node in _collect_world_pause_nodes():
			if node == null or not is_instance_valid(node):
				continue
			_paused_world_process_entries.append({
				"node": node,
				"process_mode": node.process_mode,
			})
			node.process_mode = Node.PROCESS_MODE_DISABLED
		return
	for entry_variant in _paused_world_process_entries:
		var entry: Dictionary = entry_variant
		var node := entry.get("node") as Node
		if node == null or not is_instance_valid(node):
			continue
		var saved_process_mode := int(entry.get("process_mode", Node.PROCESS_MODE_INHERIT)) as Node.ProcessMode
		node.process_mode = saved_process_mode
	_paused_world_process_entries.clear()

func _rebuild_vehicle_radio_quick_slots() -> void:
	if _vehicle_radio_quick_bank == null or not _vehicle_radio_quick_bank.has_method("build_slots"):
		_vehicle_radio_quick_slots = []
		_vehicle_radio_quick_selected_index = -1
		return
	_vehicle_radio_quick_slots = _vehicle_radio_quick_bank.build_slots(
		_vehicle_radio_selection_sources.get("presets", []),
		_vehicle_radio_selection_sources.get("favorites", []),
		_vehicle_radio_selection_sources.get("recents", [])
	)
	_sync_vehicle_radio_quick_selected_index_to_runtime_state()

func _step_vehicle_radio_quick_selection(step: int) -> void:
	if _vehicle_radio_quick_slots.is_empty():
		_vehicle_radio_quick_selected_index = -1
	elif _count_selectable_vehicle_radio_quick_slots() <= 0:
		_vehicle_radio_quick_selected_index = -1
	elif _vehicle_radio_quick_selected_index < 0:
		_vehicle_radio_quick_selected_index = _find_first_selectable_vehicle_radio_quick_slot_index()
	else:
		_vehicle_radio_quick_selected_index = _find_next_selectable_vehicle_radio_quick_slot_index(_vehicle_radio_quick_selected_index + step, step)
	_sync_vehicle_radio_quick_overlay()

func _build_vehicle_radio_quick_overlay_state() -> Dictionary:
	var runtime_state: Dictionary = get_vehicle_radio_runtime_state()
	var current_station_snapshot := (runtime_state.get("selected_station_snapshot", {}) as Dictionary).duplicate(true)
	var selected_slot_snapshot: Dictionary = {}
	if _vehicle_radio_quick_selected_index >= 0 and _vehicle_radio_quick_selected_index < _vehicle_radio_quick_slots.size():
		selected_slot_snapshot = (_vehicle_radio_quick_slots[_vehicle_radio_quick_selected_index] as Dictionary).duplicate(true)
	return {
		"visible": _vehicle_radio_quick_overlay_open,
		"slots": _vehicle_radio_quick_slots.duplicate(true),
		"selected_slot_index": _vehicle_radio_quick_selected_index,
		"power_action_available": true,
		"browser_action_available": true,
		"power_state": "on" if _vehicle_radio_power_on else "off",
		"browser_request_count": _vehicle_radio_browser_request_count,
		"playback_state": str(runtime_state.get("playback_state", "stopped")),
		"current_station_name": str(current_station_snapshot.get("station_name", "")),
		"current_station_id": str(current_station_snapshot.get("station_id", "")),
		"selected_station_name": str(selected_slot_snapshot.get("station_name", "")),
		"selected_station_id": str(selected_slot_snapshot.get("station_id", "")),
	}

func _sync_vehicle_radio_quick_overlay() -> void:
	if hud != null and hud.has_method("set_vehicle_radio_quick_overlay_state"):
		hud.set_vehicle_radio_quick_overlay_state(_build_vehicle_radio_quick_overlay_state())

func _build_vehicle_radio_browser_state() -> Dictionary:
	return {
		"visible": _vehicle_radio_browser_open,
		"selected_tab_id": _vehicle_radio_browser_selected_tab_id,
		"tabs": [
			{"tab_id": "presets", "label": "Presets"},
			{"tab_id": "favorites", "label": "Favorites"},
			{"tab_id": "recents", "label": "Recents"},
			{"tab_id": "browse", "label": "Browse"},
			{"tab_id": "proxy", "label": "Proxy"},
		],
		"current_playing": get_vehicle_radio_runtime_state(),
		"presets": _load_vehicle_radio_browser_presets(),
		"favorites": _load_vehicle_radio_browser_favorites(),
		"recents": _load_vehicle_radio_browser_recents(),
		"browse": _build_vehicle_radio_browser_browse_state(),
		"network": _build_vehicle_radio_browser_network_state(),
	}

func _sync_vehicle_radio_browser() -> void:
	if hud != null and hud.has_method("set_vehicle_radio_browser_state"):
		hud.set_vehicle_radio_browser_state(_build_vehicle_radio_browser_state())

func _sync_vehicle_radio_runtime_driving_context() -> void:
	if _vehicle_radio_controller == null or not _vehicle_radio_controller.has_method("set_driving_context"):
		return
	if player != null and player.has_method("is_driving_vehicle") and bool(player.is_driving_vehicle()) and player.has_method("get_driving_vehicle_state"):
		_vehicle_radio_controller.set_driving_context(true, player.get_driving_vehicle_state())
		return
	_vehicle_radio_controller.set_driving_context(false, {})
	if _vehicle_radio_quick_overlay_open:
		close_vehicle_radio_quick_overlay()

func _update_vehicle_radio_audio_backend() -> void:
	if _vehicle_radio_backend == null or not _vehicle_radio_backend.has_method("update_audio_output"):
		return
	_vehicle_radio_backend.update_audio_output()

func _commit_vehicle_radio_quick_selection() -> void:
	if _vehicle_radio_controller == null or not _vehicle_radio_controller.has_method("select_station"):
		return
	if _vehicle_radio_quick_selected_index < 0 or _vehicle_radio_quick_selected_index >= _vehicle_radio_quick_slots.size():
		return
	var slot: Dictionary = (_vehicle_radio_quick_slots[_vehicle_radio_quick_selected_index] as Dictionary).duplicate(true)
	if slot.is_empty() or str(slot.get("station_id", "")).strip_edges() == "":
		return
	_vehicle_radio_power_on = true
	_sync_vehicle_radio_runtime_driving_context()
	if _vehicle_radio_controller.has_method("set_power_state"):
		_vehicle_radio_controller.set_power_state(true)
	var resolved_stream := _build_vehicle_radio_resolved_stream(slot)
	if resolved_stream.is_empty():
		return
	_vehicle_radio_controller.select_station(slot, resolved_stream)
	if _vehicle_radio_controller.has_method("set_browser_preview_enabled"):
		_vehicle_radio_controller.set_browser_preview_enabled(false)
	_record_vehicle_radio_recent_station(slot)
	_persist_vehicle_radio_session_state()
	close_vehicle_radio_quick_overlay()

func _sync_vehicle_radio_quick_selected_index_to_runtime_state() -> void:
	if _vehicle_radio_quick_slots.is_empty():
		_vehicle_radio_quick_selected_index = -1
		return
	var current_station_id := str(get_vehicle_radio_runtime_state().get("selected_station_id", "")).strip_edges()
	var current_slot_index := _find_vehicle_radio_quick_slot_index_by_station_id(current_station_id)
	if current_slot_index >= 0:
		_vehicle_radio_quick_selected_index = current_slot_index
		return
	if _is_vehicle_radio_quick_slot_selectable(_vehicle_radio_quick_selected_index):
		return
	_vehicle_radio_quick_selected_index = _find_first_selectable_vehicle_radio_quick_slot_index()

func _count_selectable_vehicle_radio_quick_slots() -> int:
	var selectable_count := 0
	for slot_index in range(_vehicle_radio_quick_slots.size()):
		if _is_vehicle_radio_quick_slot_selectable(slot_index):
			selectable_count += 1
	return selectable_count

func _find_first_selectable_vehicle_radio_quick_slot_index() -> int:
	for slot_index in range(_vehicle_radio_quick_slots.size()):
		if _is_vehicle_radio_quick_slot_selectable(slot_index):
			return slot_index
	return -1

func _find_next_selectable_vehicle_radio_quick_slot_index(start_index: int, step: int) -> int:
	if _vehicle_radio_quick_slots.is_empty():
		return -1
	var resolved_step := 1 if step >= 0 else -1
	var slot_count := _vehicle_radio_quick_slots.size()
	for offset in range(slot_count):
		var candidate_index := posmod(start_index + resolved_step * offset, slot_count)
		if _is_vehicle_radio_quick_slot_selectable(candidate_index):
			return candidate_index
	return -1

func _find_vehicle_radio_quick_slot_index_by_station_id(station_id: String) -> int:
	var normalized_station_id := station_id.strip_edges()
	if normalized_station_id == "":
		return -1
	for slot_index in range(_vehicle_radio_quick_slots.size()):
		var slot := _vehicle_radio_quick_slots[slot_index] as Dictionary
		if str(slot.get("station_id", "")).strip_edges() == normalized_station_id:
			return slot_index
	return -1

func _is_vehicle_radio_quick_slot_selectable(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= _vehicle_radio_quick_slots.size():
		return false
	var slot := _vehicle_radio_quick_slots[slot_index] as Dictionary
	return str(slot.get("station_id", "")).strip_edges() != ""

func _activate_vehicle_radio_station_playback(station_snapshot: Dictionary, resolved_stream: Dictionary, enable_browser_preview: bool) -> Dictionary:
	if _vehicle_radio_controller == null:
		return {
			"success": false,
			"error": "controller_unavailable",
		}
	_vehicle_radio_power_on = true
	_sync_vehicle_radio_runtime_driving_context()
	if _vehicle_radio_controller.has_method("set_power_state"):
		_vehicle_radio_controller.set_power_state(true)
	if _vehicle_radio_controller.has_method("select_station"):
		_vehicle_radio_controller.select_station(station_snapshot, resolved_stream)
	if _vehicle_radio_controller.has_method("set_browser_preview_enabled"):
		_vehicle_radio_controller.set_browser_preview_enabled(enable_browser_preview)
	_record_vehicle_radio_recent_station(station_snapshot)
	_persist_vehicle_radio_session_state()
	_sync_vehicle_radio_browser()
	_sync_vehicle_radio_quick_overlay()
	return {
		"success": true,
		"selected_station_id": str(station_snapshot.get("station_id", "")),
	}

func _build_vehicle_radio_resolved_stream(station_snapshot: Dictionary) -> Dictionary:
	var final_url := str(station_snapshot.get("stream_url", station_snapshot.get("final_url", ""))).strip_edges()
	if final_url == "":
		return {}
	return {
		"classification": "direct",
		"final_url": final_url,
		"candidates": [final_url],
		"resolution_trace": [{
			"step": "quick_overlay_confirm",
		}],
		"resolved_at_unix_sec": int(Time.get_unix_time_from_system()),
	}

func _load_vehicle_radio_browser_countries() -> Array:
	if not _vehicle_radio_browser_cached_countries.is_empty():
		return _vehicle_radio_browser_cached_countries.duplicate(true)
	_vehicle_radio_browser_cached_countries = _load_vehicle_radio_browser_countries_from_store(true)
	return _vehicle_radio_browser_cached_countries.duplicate(true)

func _ensure_vehicle_radio_browser_countries_ready(force: bool = false) -> void:
	if _vehicle_radio_catalog_repository == null or not _vehicle_radio_catalog_repository.has_method("ensure_countries_ready"):
		return
	_vehicle_radio_browser_stations_loading = false
	_vehicle_radio_browser_station_loading_country_code = ""
	_vehicle_radio_browser_stations_error = ""
	var load_result: Dictionary = _vehicle_radio_catalog_store.load_countries_index() if _vehicle_radio_catalog_store != null and _vehicle_radio_catalog_store.has_method("load_countries_index") else {
		"hit": false,
		"stale": true,
		"countries": [],
	}
	var cached_countries := (load_result.get("countries", []) as Array).duplicate(true)
	var fixture_countries := _looks_like_vehicle_radio_fixture_country_directory(cached_countries)
	if fixture_countries:
		_purge_vehicle_radio_fixture_countries_cache()
	var has_fresh_cached_countries := bool(load_result.get("hit", false)) and not bool(load_result.get("stale", true)) and not cached_countries.is_empty() and not fixture_countries
	var resolved_force := force or fixture_countries
	_vehicle_radio_browser_cached_countries = _resolve_vehicle_radio_browser_country_directory(cached_countries)
	if has_fresh_cached_countries and not resolved_force:
		_vehicle_radio_browser_countries_loading = false
		_vehicle_radio_browser_countries_error = ""
		return
	if _should_background_vehicle_radio_catalog_sync():
		_vehicle_radio_browser_countries_loading = true
		_vehicle_radio_browser_countries_error = ""
		_queue_vehicle_radio_catalog_sync_job("countries", "", resolved_force)
		return
	_apply_vehicle_radio_catalog_sync_result({
		"kind": "countries",
		"country_code": "",
		"result": _vehicle_radio_catalog_repository.ensure_countries_ready(resolved_force),
	})

func _load_vehicle_radio_browser_presets() -> Array:
	return (_vehicle_radio_selection_sources.get("presets", []) as Array).duplicate(true)

func _load_vehicle_radio_browser_favorites() -> Array:
	return (_vehicle_radio_selection_sources.get("favorites", []) as Array).duplicate(true)

func _load_vehicle_radio_browser_recents() -> Array:
	return (_vehicle_radio_selection_sources.get("recents", []) as Array).duplicate(true)

func _build_vehicle_radio_browser_browse_state() -> Dictionary:
	if _vehicle_radio_browser_selected_country_code == "":
		return {
			"root_kind": "countries",
			"countries": _load_vehicle_radio_browser_countries(),
			"stations": [],
			"selected_country_code": "",
			"filter_text": _vehicle_radio_browser_filter_text,
			"loading": _vehicle_radio_browser_countries_loading,
			"load_error": _vehicle_radio_browser_countries_error,
		}
	_ensure_vehicle_radio_browser_station_rows_loaded(_vehicle_radio_browser_selected_country_code)
	return {
		"root_kind": "stations",
		"countries": [],
		"stations": _filter_vehicle_radio_browser_station_rows(_vehicle_radio_browser_cached_station_rows),
		"selected_country_code": _vehicle_radio_browser_selected_country_code,
		"filter_text": _vehicle_radio_browser_filter_text,
		"loading": _vehicle_radio_browser_stations_loading and _vehicle_radio_browser_station_loading_country_code == _vehicle_radio_browser_selected_country_code,
		"load_error": _vehicle_radio_browser_stations_error if _vehicle_radio_browser_station_loading_country_code == _vehicle_radio_browser_selected_country_code else "",
	}

func _build_vehicle_radio_browser_network_state() -> Dictionary:
	var proxy_settings := CityRadioBrowserApi.resolve_proxy_settings({
		"proxy_mode": _vehicle_radio_catalog_proxy_mode,
	})
	return {
		"proxy_mode": str(proxy_settings.get("proxy_mode", VEHICLE_RADIO_DIRECT_PROXY_MODE)),
		"proxy_mode_label": str(proxy_settings.get("effective_label", "直连")),
		"proxy_enabled": bool(proxy_settings.get("enabled", false)),
		"proxy_host": str(proxy_settings.get("host", "")),
		"proxy_port": int(proxy_settings.get("port", 0)),
		"proxy_error": str(proxy_settings.get("effective_error", "")),
		"env_http_proxy": str(proxy_settings.get("env_http_proxy", "")),
		"env_https_proxy": str(proxy_settings.get("env_https_proxy", "")),
		"env_all_proxy": str(proxy_settings.get("env_all_proxy", "")),
		"countries_loading": _vehicle_radio_browser_countries_loading,
		"countries_error": _vehicle_radio_browser_countries_error,
		"stations_loading": _vehicle_radio_browser_stations_loading,
		"stations_error": _vehicle_radio_browser_stations_error,
		"selected_country_code": _vehicle_radio_browser_selected_country_code,
	}

func _ensure_vehicle_radio_browser_station_rows_loaded(country_code: String, force: bool = false) -> void:
	var normalized_country_code := country_code.strip_edges().to_upper()
	if normalized_country_code == "":
		_vehicle_radio_browser_cached_country_code = ""
		_vehicle_radio_browser_cached_station_rows = []
		_vehicle_radio_browser_stations_loading = false
		_vehicle_radio_browser_station_loading_country_code = ""
		_vehicle_radio_browser_stations_error = ""
		return
	if not force and _vehicle_radio_browser_cached_country_code == normalized_country_code and not _vehicle_radio_browser_cached_station_rows.is_empty():
		return
	var load_result: Dictionary = _vehicle_radio_catalog_store.load_country_station_page(normalized_country_code) if _vehicle_radio_catalog_store != null and _vehicle_radio_catalog_store.has_method("load_country_station_page") else {
		"hit": false,
		"stale": true,
		"stations": [],
	}
	var cached_stations := (load_result.get("stations", []) as Array).duplicate(true)
	var fixture_station_page := _looks_like_vehicle_radio_fixture_station_page(cached_stations)
	if fixture_station_page:
		_purge_vehicle_radio_fixture_station_page_cache(normalized_country_code)
	var has_fresh_cached_stations := bool(load_result.get("hit", false)) and not bool(load_result.get("stale", true)) and not fixture_station_page
	var resolved_force := force or fixture_station_page
	_vehicle_radio_browser_cached_country_code = normalized_country_code
	_vehicle_radio_browser_cached_station_rows = [] if fixture_station_page else (_load_vehicle_radio_browser_station_rows_from_store(normalized_country_code, bool(load_result.get("hit", false))) if bool(load_result.get("hit", false)) else _build_vehicle_radio_browser_station_rows(cached_stations))
	if has_fresh_cached_stations:
		_vehicle_radio_browser_stations_loading = false
		_vehicle_radio_browser_station_loading_country_code = normalized_country_code
		_vehicle_radio_browser_stations_error = ""
		return
	if _should_background_vehicle_radio_catalog_sync():
		_vehicle_radio_browser_stations_loading = true
		_vehicle_radio_browser_station_loading_country_code = normalized_country_code
		_vehicle_radio_browser_stations_error = ""
		_queue_vehicle_radio_catalog_sync_job("stations", normalized_country_code, resolved_force)
		return
	_apply_vehicle_radio_catalog_sync_result({
		"kind": "stations",
		"country_code": normalized_country_code,
		"result": _vehicle_radio_catalog_repository.ensure_country_station_page_ready(normalized_country_code, resolved_force),
	})

func _load_vehicle_radio_browser_countries_from_store(count_as_browser_load: bool) -> Array:
	if _vehicle_radio_catalog_store == null or not _vehicle_radio_catalog_store.has_method("load_countries_index"):
		return []
	var load_result: Dictionary = _vehicle_radio_catalog_store.load_countries_index()
	if count_as_browser_load:
		_vehicle_radio_debug_state["browser_country_load_count"] = int(_vehicle_radio_debug_state.get("browser_country_load_count", 0)) + 1
	var countries := (load_result.get("countries", []) as Array).duplicate(true)
	return _resolve_vehicle_radio_browser_country_directory(countries)

func _load_vehicle_radio_browser_station_rows_from_store(country_code: String, count_as_browser_load: bool) -> Array:
	if _vehicle_radio_catalog_store == null or not _vehicle_radio_catalog_store.has_method("load_country_station_page"):
		return []
	var load_result: Dictionary = _vehicle_radio_catalog_store.load_country_station_page(country_code)
	if count_as_browser_load:
		_vehicle_radio_debug_state["browser_station_page_load_count"] = int(_vehicle_radio_debug_state.get("browser_station_page_load_count", 0)) + 1
	var stations := (load_result.get("stations", []) as Array).duplicate(true)
	return [] if _looks_like_vehicle_radio_fixture_station_page(stations) else _build_vehicle_radio_browser_station_rows(stations)

func _should_background_vehicle_radio_catalog_sync() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if _vehicle_radio_catalog_repository == null or not _vehicle_radio_catalog_repository.has_method("supports_background_sync"):
		return false
	return bool(_vehicle_radio_catalog_repository.supports_background_sync())

func _queue_vehicle_radio_catalog_sync_job(kind: String, country_code: String = "", force: bool = false) -> void:
	var job := {
		"kind": kind,
		"country_code": country_code.strip_edges().to_upper(),
		"force": force,
	}
	if _vehicle_radio_catalog_sync_thread != null and _vehicle_radio_catalog_sync_thread.is_alive():
		_vehicle_radio_catalog_sync_queued_job = job.duplicate(true)
		return
	_start_vehicle_radio_catalog_sync_job(job)

func _start_vehicle_radio_catalog_sync_job(job: Dictionary) -> void:
	_vehicle_radio_catalog_sync_job = job.duplicate(true)
	var thread := Thread.new()
	var start_error := thread.start(Callable(self, "_run_vehicle_radio_catalog_sync_job").bind(job.duplicate(true)))
	if start_error != OK:
		_vehicle_radio_catalog_sync_thread = null
		_apply_vehicle_radio_catalog_sync_result(_run_vehicle_radio_catalog_sync_job(job))
		return
	_vehicle_radio_catalog_sync_thread = thread

func _run_vehicle_radio_catalog_sync_job(job: Dictionary) -> Dictionary:
	var kind := str(job.get("kind", ""))
	var country_code := str(job.get("country_code", "")).strip_edges().to_upper()
	var force := bool(job.get("force", false))
	var result := {
		"success": false,
		"error": "repository_unavailable",
	}
	if _vehicle_radio_catalog_repository != null:
		match kind:
			"countries":
				result = _vehicle_radio_catalog_repository.ensure_countries_ready(force)
			"stations":
				result = _vehicle_radio_catalog_repository.ensure_country_station_page_ready(country_code, force)
	return {
		"kind": kind,
		"country_code": country_code,
		"result": result.duplicate(true),
	}

func _collect_completed_vehicle_radio_catalog_sync_job() -> void:
	if _vehicle_radio_catalog_sync_thread != null:
		if _vehicle_radio_catalog_sync_thread.is_alive():
			return
		var thread_result: Variant = _vehicle_radio_catalog_sync_thread.wait_to_finish()
		_vehicle_radio_catalog_sync_thread = null
		if thread_result is Dictionary:
			_vehicle_radio_catalog_sync_pending_result = (thread_result as Dictionary).duplicate(true)
		else:
			_vehicle_radio_catalog_sync_pending_result = {
				"kind": str(_vehicle_radio_catalog_sync_job.get("kind", "")),
				"country_code": str(_vehicle_radio_catalog_sync_job.get("country_code", "")),
				"result": {
					"success": false,
					"error": "invalid_thread_result",
				},
			}
	if not _vehicle_radio_catalog_sync_pending_result.is_empty():
		_apply_vehicle_radio_catalog_sync_result(_vehicle_radio_catalog_sync_pending_result)
		_vehicle_radio_catalog_sync_pending_result.clear()
	if _vehicle_radio_catalog_sync_thread == null and not _vehicle_radio_catalog_sync_queued_job.is_empty():
		var queued_job := _vehicle_radio_catalog_sync_queued_job.duplicate(true)
		_vehicle_radio_catalog_sync_queued_job.clear()
		_start_vehicle_radio_catalog_sync_job(queued_job)

func _apply_vehicle_radio_catalog_sync_result(sync_result_payload: Dictionary) -> void:
	var kind := str(sync_result_payload.get("kind", ""))
	var country_code := str(sync_result_payload.get("country_code", "")).strip_edges().to_upper()
	var result := (sync_result_payload.get("result", {}) as Dictionary).duplicate(true)
	match kind:
		"countries":
			_vehicle_radio_browser_countries_loading = false
			_vehicle_radio_browser_countries_error = str(result.get("error", ""))
			_vehicle_radio_browser_cached_countries = _load_vehicle_radio_browser_countries_from_store(false)
			if bool(result.get("success", false)):
				var synced_countries := (result.get("countries", []) as Array).duplicate(true)
				_vehicle_radio_browser_cached_countries = _resolve_vehicle_radio_browser_country_directory(synced_countries)
			_sync_vehicle_radio_browser()
		"stations":
			_vehicle_radio_browser_stations_loading = false
			_vehicle_radio_browser_station_loading_country_code = country_code
			_vehicle_radio_browser_stations_error = str(result.get("error", ""))
			_vehicle_radio_browser_cached_country_code = country_code
			_vehicle_radio_browser_cached_station_rows = _load_vehicle_radio_browser_station_rows_from_store(country_code, false)
			if bool(result.get("success", false)):
				var synced_stations := (result.get("stations", []) as Array).duplicate(true)
				_vehicle_radio_browser_cached_station_rows = [] if _looks_like_vehicle_radio_fixture_station_page(synced_stations) else _build_vehicle_radio_browser_station_rows(synced_stations)
			_sync_vehicle_radio_browser()

func _build_vehicle_radio_browser_station_rows(stations: Array) -> Array:
	var rows: Array = []
	for station_variant in stations:
		if not (station_variant is Dictionary):
			continue
		rows.append(_build_vehicle_radio_browser_station_row(station_variant as Dictionary))
	return rows

func _build_vehicle_radio_browser_station_row(station_snapshot: Dictionary) -> Dictionary:
	var row := station_snapshot.duplicate(true)
	var station_id := str(row.get("station_id", ""))
	row["favorite_state"] = _find_station_snapshot_index(_vehicle_radio_selection_sources.get("favorites", []) as Array, station_id) >= 0
	row["preset_slot"] = _find_station_snapshot_preset_slot(_vehicle_radio_selection_sources.get("presets", []) as Array, station_id)
	row["availability_hint"] = "cached"
	return row

func _resolve_vehicle_radio_browser_country_directory(countries: Array) -> Array:
	return [] if _looks_like_vehicle_radio_fixture_country_directory(countries) else _decorate_vehicle_radio_browser_countries(countries)

func _decorate_vehicle_radio_browser_countries(countries: Array) -> Array:
	var decorated: Array = []
	for country_variant in countries:
		if not (country_variant is Dictionary):
			continue
		var entry := (country_variant as Dictionary).duplicate(true)
		var country_code := str(entry.get("country_code", "")).strip_edges().to_upper()
		var display_name := str(entry.get("display_name", country_code)).strip_edges()
		var sort_priority := _resolve_vehicle_radio_pinned_country_priority(country_code)
		entry["country_code"] = country_code
		entry["display_name"] = display_name
		entry["display_label"] = "%s  (%d 台)" % [display_name, int(entry.get("station_count", 0))]
		entry["list_section"] = "pinned" if sort_priority < VEHICLE_RADIO_PINNED_COUNTRY_ORDER.size() else "general"
		entry["sort_priority"] = sort_priority
		entry["sort_name"] = display_name.to_lower()
		decorated.append(entry)
	decorated.sort_custom(Callable(self, "_compare_vehicle_radio_browser_country_entries"))
	return decorated

func _compare_vehicle_radio_browser_country_entries(left_variant: Variant, right_variant: Variant) -> bool:
	var left := left_variant as Dictionary
	var right := right_variant as Dictionary
	var left_priority := int(left.get("sort_priority", 999999))
	var right_priority := int(right.get("sort_priority", 999999))
	if left_priority != right_priority:
		return left_priority < right_priority
	var left_name := str(left.get("sort_name", ""))
	var right_name := str(right.get("sort_name", ""))
	if left_name != right_name:
		return left_name.naturalnocasecmp_to(right_name) < 0
	return str(left.get("country_code", "")).naturalnocasecmp_to(str(right.get("country_code", ""))) < 0

func _resolve_vehicle_radio_pinned_country_priority(country_code: String) -> int:
	var normalized_country_code := country_code.strip_edges().to_upper()
	var pinned_index := VEHICLE_RADIO_PINNED_COUNTRY_ORDER.find(normalized_country_code)
	return pinned_index if pinned_index >= 0 else VEHICLE_RADIO_PINNED_COUNTRY_ORDER.size() + 1000

func _filter_vehicle_radio_browser_station_rows(rows: Array) -> Array:
	var filter_text := _vehicle_radio_browser_filter_text.strip_edges().to_lower()
	if filter_text == "":
		return rows.duplicate(true)
	var filtered: Array = []
	for row_variant in rows:
		if not (row_variant is Dictionary):
			continue
		var row := _build_vehicle_radio_browser_station_row(row_variant as Dictionary)
		var haystack := " ".join([
			str(row.get("station_name", "")),
			str(row.get("country", "")),
			str(row.get("language", "")),
			str(row.get("codec", "")),
		]).to_lower()
		if haystack.contains(filter_text):
			filtered.append(row.duplicate(true))
	return filtered

func _is_vehicle_radio_browser_tab_id_valid(tab_id: String) -> bool:
	return tab_id in ["presets", "favorites", "recents", "browse", "proxy"]

func _reload_vehicle_radio_selection_sources_from_store() -> void:
	if _vehicle_radio_user_state_store == null:
		return
	var loaded_presets := _normalize_vehicle_radio_preset_entries((_vehicle_radio_user_state_store.load_presets().get("slots", []) as Array).duplicate(true))
	var loaded_favorites := _sanitize_vehicle_radio_station_list((_vehicle_radio_user_state_store.load_favorites().get("stations", []) as Array).duplicate(true))
	var loaded_recents := _sanitize_vehicle_radio_station_list((_vehicle_radio_user_state_store.load_recents().get("stations", []) as Array).duplicate(true))
	_vehicle_radio_selection_sources = {
		"presets": loaded_presets,
		"favorites": loaded_favorites,
		"recents": loaded_recents,
	}
	if _should_reject_vehicle_radio_fixture_data():
		_vehicle_radio_user_state_store.save_presets(loaded_presets, int(Time.get_unix_time_from_system()))
		_vehicle_radio_user_state_store.save_favorites(loaded_favorites, int(Time.get_unix_time_from_system()))
		_vehicle_radio_user_state_store.save_recents(loaded_recents, int(Time.get_unix_time_from_system()))
	_rebuild_vehicle_radio_quick_slots()

func _restore_vehicle_radio_session_state_from_store() -> void:
	if _vehicle_radio_user_state_store == null or _vehicle_radio_controller == null:
		return
	var session_state: Dictionary = _vehicle_radio_user_state_store.load_session_state()
	_vehicle_radio_browser_selected_tab_id = _restore_vehicle_radio_browser_tab_id(str(session_state.get("browser_selected_tab_id", "browse")))
	_vehicle_radio_browser_selected_country_code = str(session_state.get("browser_selected_country_code", "")).strip_edges().to_upper()
	_vehicle_radio_browser_filter_text = str(session_state.get("browser_filter_text", "")).strip_edges()
	_vehicle_radio_catalog_proxy_mode = _normalize_vehicle_radio_browser_proxy_mode(str(session_state.get("catalog_proxy_mode", _resolve_vehicle_radio_default_proxy_mode())))
	_apply_vehicle_radio_catalog_proxy_settings()
	var selected_station_snapshot := _sanitize_vehicle_radio_station_snapshot((session_state.get("selected_station_snapshot", {}) as Dictionary).duplicate(true))
	var volume_linear := clampf(float(session_state.get("volume_linear", 1.0)), 0.0, 1.0)
	if _vehicle_radio_controller.has_method("set_volume_linear"):
		_vehicle_radio_controller.set_volume_linear(volume_linear)
	_vehicle_radio_power_on = str(session_state.get("power_state", "off")) == "on" and not selected_station_snapshot.is_empty()
	if _vehicle_radio_controller.has_method("set_power_state"):
		_vehicle_radio_controller.set_power_state(_vehicle_radio_power_on)
	if selected_station_snapshot.is_empty():
		if _should_reject_vehicle_radio_fixture_data():
			_vehicle_radio_user_state_store.save_session_state({
				"power_state": "off",
				"selected_station_id": "",
				"selected_station_snapshot": {},
				"volume_linear": volume_linear,
				"browser_selected_tab_id": _vehicle_radio_browser_selected_tab_id,
				"browser_selected_country_code": _vehicle_radio_browser_selected_country_code,
				"browser_filter_text": _vehicle_radio_browser_filter_text,
				"catalog_proxy_mode": _vehicle_radio_catalog_proxy_mode,
			}, int(Time.get_unix_time_from_system()))
		return
	var resolved_stream := _build_vehicle_radio_resolved_stream(selected_station_snapshot)
	if resolved_stream.is_empty():
		return
	if _vehicle_radio_controller.has_method("select_station"):
		_vehicle_radio_controller.select_station(selected_station_snapshot, resolved_stream)

func _persist_vehicle_radio_session_state() -> void:
	if _vehicle_radio_user_state_store == null or _vehicle_radio_controller == null or not _vehicle_radio_controller.has_method("get_runtime_state"):
		return
	var runtime_state: Dictionary = _vehicle_radio_controller.get_runtime_state()
	var selected_station_snapshot := (runtime_state.get("selected_station_snapshot", {}) as Dictionary).duplicate(true)
	_vehicle_radio_user_state_store.save_session_state({
		"power_state": "on" if _vehicle_radio_power_on else "off",
		"selected_station_id": str(runtime_state.get("selected_station_id", "")),
		"selected_station_snapshot": selected_station_snapshot,
		"volume_linear": float(runtime_state.get("volume_linear", 1.0)),
		"browser_selected_tab_id": _vehicle_radio_browser_selected_tab_id,
		"browser_selected_country_code": _vehicle_radio_browser_selected_country_code,
		"browser_filter_text": _vehicle_radio_browser_filter_text,
		"catalog_proxy_mode": _vehicle_radio_catalog_proxy_mode,
	}, int(Time.get_unix_time_from_system()))

func _restore_vehicle_radio_browser_tab_id(tab_id: String) -> String:
	return tab_id if _is_vehicle_radio_browser_tab_id_valid(tab_id) else "browse"

func _normalize_vehicle_radio_browser_proxy_mode(proxy_mode: String) -> String:
	var normalized_proxy_mode := proxy_mode.strip_edges()
	if normalized_proxy_mode not in [VEHICLE_RADIO_DIRECT_PROXY_MODE, VEHICLE_RADIO_SYSTEM_PROXY_MODE, VEHICLE_RADIO_LOCAL_PROXY_MODE]:
		return _resolve_vehicle_radio_default_proxy_mode()
	return normalized_proxy_mode

func _resolve_vehicle_radio_default_proxy_mode() -> String:
	return VEHICLE_RADIO_DIRECT_PROXY_MODE if DisplayServer.get_name() == "headless" else VEHICLE_RADIO_DEFAULT_PROXY_MODE

func _apply_vehicle_radio_catalog_proxy_settings() -> void:
	CityRadioBrowserApi.configure_proxy_settings({
		"proxy_mode": _vehicle_radio_catalog_proxy_mode,
	})

func _save_vehicle_radio_presets(presets: Array) -> Dictionary:
	if _vehicle_radio_user_state_store == null or not _vehicle_radio_user_state_store.has_method("save_presets"):
		return {
			"success": false,
			"error": "store_unavailable",
		}
	return _vehicle_radio_user_state_store.save_presets(presets, int(Time.get_unix_time_from_system()))

func _save_vehicle_radio_favorites(favorites: Array) -> Dictionary:
	if _vehicle_radio_user_state_store == null or not _vehicle_radio_user_state_store.has_method("save_favorites"):
		return {
			"success": false,
			"error": "store_unavailable",
		}
	return _vehicle_radio_user_state_store.save_favorites(favorites, int(Time.get_unix_time_from_system()))

func _save_vehicle_radio_recents(recents: Array) -> Dictionary:
	if _vehicle_radio_user_state_store == null or not _vehicle_radio_user_state_store.has_method("save_recents"):
		return {
			"success": false,
			"error": "store_unavailable",
		}
	return _vehicle_radio_user_state_store.save_recents(recents, int(Time.get_unix_time_from_system()))

func _record_vehicle_radio_recent_station(station_snapshot: Dictionary) -> void:
	if station_snapshot.is_empty():
		return
	var recents: Array = (_vehicle_radio_selection_sources.get("recents", []) as Array).duplicate(true)
	var station_id := str(station_snapshot.get("station_id", ""))
	var existing_index := _find_station_snapshot_index(recents, station_id)
	if existing_index >= 0:
		recents.remove_at(existing_index)
	recents.insert(0, station_snapshot.duplicate(true))
	if recents.size() > 12:
		recents.resize(12)
	var save_result := _save_vehicle_radio_recents(recents)
	if bool(save_result.get("success", false)):
		_reload_vehicle_radio_selection_sources_from_store()

func _normalize_vehicle_radio_preset_entries(presets: Array) -> Array:
	var normalized: Array = []
	for slot_index in range(CityRadioQuickBank.MAX_SLOT_COUNT):
		normalized.append({
			"slot_index": slot_index,
			"station_snapshot": {},
		})
	for entry_variant in presets:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = (entry_variant as Dictionary).duplicate(true)
		var resolved_slot_index := int(entry.get("slot_index", normalized.size()))
		if resolved_slot_index < 0 or resolved_slot_index >= normalized.size():
			continue
		if entry.has("station_snapshot") and entry.get("station_snapshot") is Dictionary:
			normalized[resolved_slot_index] = {
				"slot_index": resolved_slot_index,
				"station_snapshot": _sanitize_vehicle_radio_station_snapshot((entry.get("station_snapshot", {}) as Dictionary).duplicate(true)),
			}
			continue
		normalized[resolved_slot_index] = {
			"slot_index": resolved_slot_index,
			"station_snapshot": _sanitize_vehicle_radio_station_snapshot(entry.duplicate(true)),
		}
	return normalized

func _should_reject_vehicle_radio_fixture_data() -> bool:
	return DisplayServer.get_name() != "headless"

func _looks_like_vehicle_radio_fixture_country_directory(countries: Array) -> bool:
	return _should_reject_vehicle_radio_fixture_data() and not countries.is_empty() and countries.size() < VEHICLE_RADIO_MIN_REAL_COUNTRY_COUNT

func _purge_vehicle_radio_fixture_countries_cache() -> void:
	if _vehicle_radio_catalog_store == null or not _vehicle_radio_catalog_store.has_method("delete_countries_index"):
		return
	_vehicle_radio_catalog_store.delete_countries_index()

func _purge_vehicle_radio_fixture_station_page_cache(country_code: String) -> void:
	if _vehicle_radio_catalog_store == null or not _vehicle_radio_catalog_store.has_method("delete_country_station_page"):
		return
	_vehicle_radio_catalog_store.delete_country_station_page(country_code)

func _looks_like_vehicle_radio_fixture_station_page(stations: Array) -> bool:
	if not _should_reject_vehicle_radio_fixture_data():
		return false
	for station_variant in stations:
		if not (station_variant is Dictionary):
			continue
		if _looks_like_vehicle_radio_fixture_station_snapshot(station_variant as Dictionary):
			return true
	return false

func _looks_like_vehicle_radio_fixture_station_snapshot(station_snapshot: Dictionary) -> bool:
	var station_id := str(station_snapshot.get("station_id", "")).strip_edges()
	return _should_reject_vehicle_radio_fixture_data() and station_id != "" and not station_id.begins_with("radio-browser:")

func _sanitize_vehicle_radio_station_snapshot(station_snapshot: Dictionary) -> Dictionary:
	if station_snapshot.is_empty():
		return {}
	if _looks_like_vehicle_radio_fixture_station_snapshot(station_snapshot):
		return {}
	return station_snapshot.duplicate(true)

func _sanitize_vehicle_radio_station_list(stations: Array) -> Array:
	var sanitized: Array = []
	for station_variant in stations:
		if not (station_variant is Dictionary):
			continue
		var station_snapshot := _sanitize_vehicle_radio_station_snapshot(station_variant as Dictionary)
		if station_snapshot.is_empty():
			continue
		sanitized.append(station_snapshot)
	return sanitized

func _find_vehicle_radio_station_snapshot_by_id(station_id: String) -> Dictionary:
	var normalized_station_id := station_id.strip_edges()
	if normalized_station_id == "":
		return {}
	for source in [
		_filter_vehicle_radio_browser_station_rows(_vehicle_radio_browser_cached_station_rows),
		_vehicle_radio_selection_sources.get("favorites", []),
		_vehicle_radio_selection_sources.get("recents", []),
	]:
		for entry_variant in source:
			if not (entry_variant is Dictionary):
				continue
			var entry: Dictionary = entry_variant as Dictionary
			if str(entry.get("station_id", "")) == normalized_station_id:
				return entry.duplicate(true)
	for preset_variant in _vehicle_radio_selection_sources.get("presets", []):
		if not (preset_variant is Dictionary):
			continue
		var preset_entry: Dictionary = preset_variant as Dictionary
		var preset_snapshot := (preset_entry.get("station_snapshot", {}) as Dictionary).duplicate(true)
		if str(preset_snapshot.get("station_id", "")) == normalized_station_id:
			return preset_snapshot
	var runtime_state := get_vehicle_radio_runtime_state()
	var current_snapshot := (runtime_state.get("selected_station_snapshot", {}) as Dictionary).duplicate(true)
	if str(current_snapshot.get("station_id", "")) == normalized_station_id:
		return current_snapshot
	return {}

func _find_station_snapshot_index(stations: Array, station_id: String) -> int:
	for index in range(stations.size()):
		if not (stations[index] is Dictionary):
			continue
		var station: Dictionary = stations[index] as Dictionary
		if str(station.get("station_id", "")) == station_id:
			return index
	return -1

func _find_station_snapshot_preset_slot(presets: Array, station_id: String) -> int:
	for preset_variant in presets:
		if not (preset_variant is Dictionary):
			continue
		var preset_entry: Dictionary = preset_variant as Dictionary
		var preset_snapshot := preset_entry.get("station_snapshot", {}) as Dictionary
		if str(preset_snapshot.get("station_id", "")) == station_id:
			return int(preset_entry.get("slot_index", -1))
	return -1

func _collect_world_pause_nodes() -> Array[Node]:
	var nodes: Array[Node] = []
	for candidate in [player, generated_city, chunk_renderer, _combat_root, _projectile_root, _grenade_root, _laser_beam_root, _enemy_projectile_root, _enemy_root]:
		var node := candidate as Node
		if node != null:
			nodes.append(node)
	return nodes

func _perform_laser_designator_trace(origin: Vector3, target: Vector3) -> Dictionary:
	if get_world_3d() == null or get_world_3d().direct_space_state == null:
		return {}
	var excluded_rids: Array[RID] = []
	if player is CollisionObject3D:
		excluded_rids.append((player as CollisionObject3D).get_rid())
	for _attempt in range(8):
		var query := PhysicsRayQueryParameters3D.create(origin, target)
		query.collide_with_areas = false
		query.exclude = excluded_rids
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return {}
		var collider := hit.get("collider") as Node
		if _should_skip_laser_designator_collider(collider):
			if collider is CollisionObject3D:
				excluded_rids.append((collider as CollisionObject3D).get_rid())
				continue
			return {}
		return hit
	return {}

func _should_skip_laser_designator_collider(collider: Node) -> bool:
	if collider == null:
		return false
	return generated_city != null and (collider == generated_city or generated_city.is_ancestor_of(collider))

func _commit_laser_designator_clipboard_text(text: String) -> void:
	_last_laser_designator_clipboard_text = text
	if text == "" or DisplayServer.get_name() == "headless":
		return
	DisplayServer.clipboard_set(text)

func _clamp_world_position_to_bounds(world_position: Vector3) -> Vector3:
	if _world_config == null or not _world_config.has_method("get_world_bounds"):
		return world_position
	var bounds: Rect2 = _world_config.get_world_bounds()
	return Vector3(
		clampf(world_position.x, bounds.position.x, bounds.end.x),
		world_position.y,
		clampf(world_position.z, bounds.position.y, bounds.end.y)
	)

func _on_map_world_point_selected(world_position: Vector3) -> void:
	select_map_destination_from_world_point(world_position)

func _step_autodrive(_delta: float) -> void:
	if _autodrive_controller == null or not _autodrive_controller.has_method("is_active") or not _autodrive_controller.is_active():
		return
	if player == null:
		stop_autodrive("failed")
		return
	var manual_input_requested := player.has_method("has_manual_vehicle_input_request") and bool(player.has_manual_vehicle_input_request())
	var update_state: Dictionary = _autodrive_controller.update(get_player_vehicle_state(), manual_input_requested)
	var control: Dictionary = update_state.get("control", {})
	var state := str(update_state.get("state", "inactive"))
	if player.has_method("set_vehicle_autodrive_input") and state == "following_route":
		player.set_vehicle_autodrive_input(
			float(control.get("throttle", 0.0)),
			float(control.get("steer", 0.0)),
			bool(control.get("brake", false))
		)
	else:
		if player.has_method("clear_vehicle_autodrive_input"):
			player.clear_vehicle_autodrive_input()

func _step_active_route_refresh(delta: float) -> void:
	if _navigation_runtime == null or _active_destination_target.is_empty() or _active_route_result.is_empty():
		_active_route_refresh_elapsed_sec = 0.0
		return
	if player == null or not player.has_method("is_driving_vehicle") or not bool(player.is_driving_vehicle()):
		_active_route_refresh_elapsed_sec = 0.0
		return
	if is_autodrive_active():
		_active_route_refresh_elapsed_sec = 0.0
		return
	_active_route_refresh_elapsed_sec += maxf(delta, 0.0)
	var refresh_interval_sec := MANUAL_ROUTE_REFRESH_INTERVAL_SEC
	if _active_route_refresh_elapsed_sec < refresh_interval_sec:
		return
	var refresh_anchor := _get_route_refresh_anchor_position()
	var moved_since_last_refresh := refresh_anchor.distance_to(_active_route_refresh_anchor)
	var route_origin: Vector3 = _active_route_result.get("snapped_origin", refresh_anchor)
	var moved_since_route_origin := refresh_anchor.distance_to(route_origin)
	if moved_since_last_refresh < ACTIVE_ROUTE_REFRESH_MIN_MOVEMENT_M and moved_since_route_origin < ACTIVE_ROUTE_REFRESH_MIN_ORIGIN_DELTA_M:
		return
	_active_route_refresh_elapsed_sec = 0.0
	_active_route_refresh_anchor = refresh_anchor
	var rerouted: Dictionary = _navigation_runtime.reroute_from_world_position(refresh_anchor, _active_destination_target, int(_active_route_result.get("reroute_generation", 0)))
	if rerouted.is_empty():
		return
	_apply_active_route_result(rerouted, {}, is_autodrive_active(), str(_active_route_result.get("route_style_id", ROUTE_STYLE_DESTINATION)))

func _apply_active_route_result(route_result: Dictionary, destination_target: Dictionary = {}, accept_autodrive_reroute: bool = false, route_style_id: String = ROUTE_STYLE_DESTINATION) -> void:
	if route_result.is_empty():
		return
	if not destination_target.is_empty():
		_active_destination_target = destination_target.duplicate(true)
		_destination_world_marker_dismissed_route_id = ""
	_invalidate_destination_world_marker_cache()
	_active_route_result = route_result.duplicate(true)
	_active_route_result["route_style_id"] = _sanitize_route_style_id(route_style_id)
	_minimap_route_world_positions = (route_result.get("polyline", []) as Array).duplicate(true)
	_active_route_refresh_elapsed_sec = 0.0
	_active_route_refresh_anchor = _get_route_refresh_anchor_position()
	if accept_autodrive_reroute and _autodrive_controller != null and _autodrive_controller.has_method("accept_reroute") and _autodrive_controller.is_active():
		_autodrive_controller.accept_reroute(_active_route_result)
	_update_destination_world_marker(0.0)
	_sync_navigation_consumers(true)

func _resolve_task_route_style_id(task_snapshot: Dictionary) -> String:
	match str(task_snapshot.get("status", "available")):
		"active":
			return ROUTE_STYLE_TASK_ACTIVE
		"available":
			return ROUTE_STYLE_TASK_AVAILABLE
	return ROUTE_STYLE_DESTINATION

func _sanitize_route_style_id(route_style_id: String) -> String:
	match route_style_id:
		ROUTE_STYLE_TASK_AVAILABLE, ROUTE_STYLE_TASK_ACTIVE:
			return route_style_id
	return ROUTE_STYLE_DESTINATION

func _is_task_route_style_id(route_style_id: String) -> bool:
	return route_style_id == ROUTE_STYLE_TASK_AVAILABLE or route_style_id == ROUTE_STYLE_TASK_ACTIVE

func _get_route_refresh_anchor_position() -> Vector3:
	var vehicle_state: Dictionary = get_player_vehicle_state()
	if not vehicle_state.is_empty() and bool(vehicle_state.get("driving", false)):
		return vehicle_state.get("world_position", _get_active_anchor_position())
	return _get_active_anchor_position()

func _resolve_target_identity(target: Dictionary) -> String:
	var place_id := str(target.get("place_id", ""))
	if place_id != "":
		return place_id
	var anchor: Vector3 = target.get("routable_anchor", target.get("world_anchor", Vector3.ZERO))
	return "raw:%d:%d:%d" % [int(round(anchor.x)), int(round(anchor.y)), int(round(anchor.z))]

func _ensure_destination_world_marker() -> void:
	if _destination_world_marker != null and is_instance_valid(_destination_world_marker):
		return
	_destination_world_marker = get_node_or_null("DestinationWorldMarker") as Node3D
	if _destination_world_marker == null:
		_destination_world_marker = CityDestinationWorldMarker.new()
		_destination_world_marker.name = "DestinationWorldMarker"
		add_child(_destination_world_marker)
	if _destination_world_marker.has_method("set_marker_radius"):
		_destination_world_marker.set_marker_radius(DESTINATION_WORLD_MARKER_RADIUS_M)
	if _destination_world_marker.has_method("set_marker_visible"):
		_destination_world_marker.set_marker_visible(false)

func _update_destination_world_marker(delta: float) -> void:
	_ensure_destination_world_marker()
	if _destination_world_marker == null:
		return
	var route_id := str(_active_route_result.get("route_id", ""))
	if route_id == "" or _active_destination_target.is_empty():
		_destination_world_marker_dismissed_route_id = ""
		if _destination_world_marker.has_method("set_marker_visible"):
			_destination_world_marker.set_marker_visible(false)
		return
	var route_style_id := str(_active_route_result.get("route_style_id", ROUTE_STYLE_DESTINATION))
	if _is_task_route_style_id(route_style_id):
		if _destination_world_marker.has_method("set_marker_visible"):
			_destination_world_marker.set_marker_visible(false)
		return
	var marker_position := _resolve_destination_world_marker_world_position()
	if _has_reached_destination_world_marker(marker_position):
		_clear_active_navigation_state(true)
		return
	if route_id == _destination_world_marker_dismissed_route_id:
		if _destination_world_marker.has_method("set_marker_visible"):
			_destination_world_marker.set_marker_visible(false)
		return
	if _destination_world_marker.has_method("set_marker_radius"):
		_destination_world_marker.set_marker_radius(DESTINATION_WORLD_MARKER_RADIUS_M)
	if _destination_world_marker.has_method("set_marker_world_position"):
		_destination_world_marker.set_marker_world_position(marker_position)
	if _destination_world_marker.has_method("set_marker_visible"):
		_destination_world_marker.set_marker_visible(true)
	if _destination_world_marker.has_method("tick"):
		_destination_world_marker.tick(delta)

func _resolve_destination_world_marker_world_position() -> Vector3:
	var route_id := str(_active_route_result.get("route_id", ""))
	var anchor: Vector3 = _active_route_result.get(
		"snapped_destination",
		_active_destination_target.get("routable_anchor", _active_destination_target.get("world_anchor", Vector3.ZERO))
	)
	if route_id != "" and route_id == _destination_world_marker_cached_route_id and anchor == _destination_world_marker_cached_anchor:
		return _destination_world_marker_cached_world_position
	var surface_position := _resolve_surface_world_position(anchor, DESTINATION_WORLD_MARKER_SURFACE_OFFSET_M)
	surface_position.y += 0.03
	_destination_world_marker_cached_route_id = route_id
	_destination_world_marker_cached_anchor = anchor
	_destination_world_marker_cached_world_position = surface_position
	_destination_world_marker_surface_resolve_count += 1
	return surface_position

func _has_reached_destination_world_marker(marker_position: Vector3) -> bool:
	var subject_position := _get_route_refresh_anchor_position()
	var planar_distance := Vector2(subject_position.x - marker_position.x, subject_position.z - marker_position.z).length()
	return planar_distance <= DESTINATION_WORLD_MARKER_CLEAR_DISTANCE_M

func _clear_active_navigation_state(clear_selection_contract: bool = false) -> void:
	_active_destination_target.clear()
	_active_route_result.clear()
	_minimap_route_world_positions.clear()
	_active_route_refresh_elapsed_sec = 0.0
	_active_route_refresh_anchor = _get_route_refresh_anchor_position()
	_destination_world_marker_dismissed_route_id = ""
	_invalidate_destination_world_marker_cache()
	if clear_selection_contract:
		_last_map_selection_contract.clear()
	if player != null and player.has_method("clear_vehicle_autodrive_input"):
		player.clear_vehicle_autodrive_input()
	if is_autodrive_active():
		stop_autodrive("arrived")
	if _map_pin_registry != null and _map_pin_registry.has_method("upsert_destination_pin"):
		_map_pin_registry.upsert_destination_pin({})
	if _destination_world_marker != null and _destination_world_marker.has_method("set_marker_visible"):
		_destination_world_marker.set_marker_visible(false)
	_sync_navigation_consumers(true)

func _invalidate_destination_world_marker_cache() -> void:
	_destination_world_marker_cached_route_id = ""
	_destination_world_marker_cached_anchor = Vector3.INF
	_destination_world_marker_cached_world_position = Vector3.ZERO

func _orient_player_to_heading(heading: Vector3) -> void:
	if player == null:
		return
	var planar_heading := heading
	planar_heading.y = 0.0
	if planar_heading.length_squared() <= 0.0001:
		return
	player.rotation.y = _yaw_from_vehicle_heading(planar_heading.normalized())

func _resolve_route_target(target_or_world_position: Variant) -> Dictionary:
	if target_or_world_position is Dictionary:
		return (target_or_world_position as Dictionary).duplicate(true)
	if target_or_world_position is Vector3:
		var raw_world_position: Vector3 = target_or_world_position
		var vehicle_query = _world_data.get("vehicle_query")
		var routable_anchor := CityPlaceIndexBuilder.snap_world_anchor_to_driving_lane(vehicle_query, raw_world_position)
		return CityResolvedTarget.build_raw_world_point(raw_world_position, routable_anchor)
	return {}

func _is_minimap_crowd_debug_enabled() -> bool:
	return hud != null and hud.has_method("is_debug_expanded") and bool(hud.is_debug_expanded())

func _invalidate_minimap_cache() -> void:
	_minimap_cache_key = ""
	_minimap_snapshot_cache.clear()

func _should_refresh_hud() -> bool:
	var now_usec := Time.get_ticks_usec()
	var refresh_interval_usec := _resolve_hud_refresh_interval_usec(DisplayServer.get_name() == "headless")
	return _last_hud_refresh_tick_usec < 0 or now_usec - _last_hud_refresh_tick_usec >= refresh_interval_usec

func _should_build_hud_snapshot_refresh(is_headless: bool, hud_refresh_allowed: bool, hud_debug_expanded: bool, debug_expanded: bool) -> bool:
	if debug_expanded:
		return true
	if is_headless:
		return false
	return hud_refresh_allowed and hud_debug_expanded

func _should_refresh_hud_minimap(is_headless: bool) -> bool:
	if _minimap_request_count == 0 or _last_minimap_hud_refresh_tick_usec < 0:
		return true
	var now_usec := Time.get_ticks_usec()
	return now_usec - _last_minimap_hud_refresh_tick_usec >= _resolve_minimap_refresh_interval_usec(is_headless)

func _resolve_hud_refresh_interval_usec(is_headless: bool) -> int:
	var refresh_interval_usec := 0
	if _has_streaming_backpressure():
		refresh_interval_usec = HEADLESS_HUD_REFRESH_INTERVAL_FAST_USEC if is_headless else HUD_REFRESH_INTERVAL_FAST_USEC
	else:
		refresh_interval_usec = HEADLESS_HUD_REFRESH_INTERVAL_USEC if is_headless else HUD_REFRESH_INTERVAL_USEC
	if not is_headless and _control_mode == CONTROL_MODE_INSPECTION:
		refresh_interval_usec = maxi(refresh_interval_usec, INSPECTION_HUD_REFRESH_INTERVAL_USEC)
	return refresh_interval_usec

func _resolve_minimap_refresh_interval_usec(is_headless: bool) -> int:
	var refresh_interval_usec := 0
	if _has_streaming_backpressure():
		refresh_interval_usec = HEADLESS_MINIMAP_HUD_REFRESH_INTERVAL_FAST_USEC if is_headless else MINIMAP_HUD_REFRESH_INTERVAL_FAST_USEC
	else:
		refresh_interval_usec = HEADLESS_MINIMAP_HUD_REFRESH_INTERVAL_USEC if is_headless else MINIMAP_HUD_REFRESH_INTERVAL_USEC
	if not is_headless and _control_mode == CONTROL_MODE_INSPECTION:
		refresh_interval_usec = maxi(refresh_interval_usec, INSPECTION_MINIMAP_HUD_REFRESH_INTERVAL_USEC)
	return refresh_interval_usec

func _has_streaming_backpressure() -> bool:
	if chunk_renderer == null or not chunk_renderer.has_method("get_streaming_budget_stats"):
		return false
	var stats: Dictionary = chunk_renderer.get_streaming_budget_stats()
	return int(stats.get("pending_prepare_count", 0)) > 0 \
		or int(stats.get("pending_surface_async_count", 0)) > 0 \
		or int(stats.get("queued_surface_async_count", 0)) > 0 \
		or int(stats.get("pending_terrain_async_count", 0)) > 0 \
		or int(stats.get("queued_terrain_async_count", 0)) > 0 \
		or int(stats.get("pending_mount_count", 0)) > 0

func _record_update_streaming_sample(duration_usec: int) -> void:
	_update_streaming_sample_count += 1
	_update_streaming_total_usec += duration_usec
	_update_streaming_max_usec = maxi(_update_streaming_max_usec, duration_usec)
	_update_streaming_last_usec = duration_usec

func _record_update_streaming_chunk_streamer_sample(duration_usec: int) -> void:
	_update_streaming_chunk_streamer_sample_count += 1
	_update_streaming_chunk_streamer_total_usec += duration_usec
	_update_streaming_chunk_streamer_max_usec = maxi(_update_streaming_chunk_streamer_max_usec, duration_usec)
	_update_streaming_chunk_streamer_last_usec = duration_usec

func _record_update_streaming_renderer_sync_sample(duration_usec: int) -> void:
	_update_streaming_renderer_sync_sample_count += 1
	_update_streaming_renderer_sync_total_usec += duration_usec
	_update_streaming_renderer_sync_max_usec = maxi(_update_streaming_renderer_sync_max_usec, duration_usec)
	_update_streaming_renderer_sync_last_usec = duration_usec

func _record_hud_refresh_sample(duration_usec: int) -> void:
	_hud_refresh_sample_count += 1
	_hud_refresh_total_usec += duration_usec
	_hud_refresh_max_usec = maxi(_hud_refresh_max_usec, duration_usec)
	_hud_refresh_last_usec = duration_usec

func _record_frame_step_sample(duration_usec: int) -> void:
	_frame_step_sample_count += 1
	_frame_step_total_usec += duration_usec
	_frame_step_max_usec = maxi(_frame_step_max_usec, duration_usec)
	_frame_step_last_usec = duration_usec

func _record_minimap_build_sample(duration_usec: int) -> void:
	_minimap_build_total_usec += duration_usec
	_minimap_build_max_usec = maxi(_minimap_build_max_usec, duration_usec)
	_minimap_build_last_usec = duration_usec

func _average_usec(total_usec: int, sample_count: int) -> int:
	if sample_count <= 0:
		return 0
	return int(round(float(total_usec) / float(sample_count)))

func _reload_building_override_registry() -> Dictionary:
	if _building_override_registry == null:
		return {}
	var registry_config := _resolve_building_override_registry_config()
	var primary_registry_path := str(registry_config.get("primary_registry_path", ""))
	var load_registry_paths: Array[String] = []
	for path_variant in registry_config.get("load_registry_paths", []):
		var path := _normalize_serviceability_resource_path(str(path_variant))
		if path == "" or load_registry_paths.has(path):
			continue
		load_registry_paths.append(path)
	_building_override_registry.configure(primary_registry_path, load_registry_paths)
	var entries: Dictionary = _building_override_registry.load_registry()
	_sync_building_override_entries(entries)
	return entries

func _reload_scene_landmark_registry() -> Dictionary:
	if _scene_landmark_registry == null:
		return {}
	var load_registry_paths: Array[String] = [SCENE_LANDMARK_REGISTRY_PATH]
	_scene_landmark_registry.configure(SCENE_LANDMARK_REGISTRY_PATH, load_registry_paths)
	var entries: Dictionary = _scene_landmark_registry.load_registry()
	_sync_scene_landmark_entries(entries)
	return entries

func _reload_scene_interactive_prop_registry() -> Dictionary:
	if _scene_interactive_prop_registry == null:
		return {}
	var load_registry_paths: Array[String] = [SCENE_INTERACTIVE_PROP_REGISTRY_PATH]
	_scene_interactive_prop_registry.configure(SCENE_INTERACTIVE_PROP_REGISTRY_PATH, load_registry_paths)
	var entries: Dictionary = _scene_interactive_prop_registry.load_registry()
	_sync_scene_interactive_prop_entries(entries)
	return entries

func _reload_scene_minigame_venue_registry() -> Dictionary:
	if _scene_minigame_venue_registry == null:
		return {}
	var load_registry_paths: Array[String] = [SCENE_MINIGAME_VENUE_REGISTRY_PATH]
	_scene_minigame_venue_registry.configure(SCENE_MINIGAME_VENUE_REGISTRY_PATH, load_registry_paths)
	var entries: Dictionary = _scene_minigame_venue_registry.load_registry()
	_sync_scene_minigame_venue_entries(entries)
	return entries

func _reload_terrain_region_feature_registry() -> Dictionary:
	if _terrain_region_feature_registry == null:
		return {}
	var load_registry_paths: Array[String] = [TERRAIN_REGION_REGISTRY_PATH]
	_terrain_region_feature_registry.configure(TERRAIN_REGION_REGISTRY_PATH, load_registry_paths)
	var entries: Dictionary = _terrain_region_feature_registry.load_registry()
	_sync_terrain_region_feature_entries(entries)
	return entries

func _resolve_building_override_registry_config() -> Dictionary:
	var primary_registry_path := _normalize_serviceability_resource_path(_building_serviceability_registry_override_path)
	var load_registry_paths: Array[String] = []
	if primary_registry_path != "":
		load_registry_paths.append(primary_registry_path)
		return {
			"primary_registry_path": primary_registry_path,
			"load_registry_paths": load_registry_paths,
		}
	var preferred_registry_path := CityBuildingSceneExporter.build_registry_path(_building_serviceability_preferred_scene_root)
	var fallback_registry_path := CityBuildingSceneExporter.build_registry_path(_building_serviceability_fallback_scene_root)
	for path in [preferred_registry_path, fallback_registry_path]:
		var normalized_path := _normalize_serviceability_resource_path(str(path))
		if normalized_path == "" or load_registry_paths.has(normalized_path):
			continue
		load_registry_paths.append(normalized_path)
	if primary_registry_path == "" and not load_registry_paths.is_empty():
		primary_registry_path = load_registry_paths[0]
	return {
		"primary_registry_path": primary_registry_path,
		"load_registry_paths": load_registry_paths,
	}

func _sync_building_override_entries(entries: Dictionary) -> void:
	if chunk_renderer != null and chunk_renderer.has_method("set_building_override_entries"):
		chunk_renderer.set_building_override_entries(entries.duplicate(true))
	if _service_building_map_pin_runtime != null and _service_building_map_pin_runtime.has_method("configure"):
		_service_building_map_pin_runtime.configure(entries.duplicate(true))
	_sync_service_building_pin_registry()

func _sync_scene_landmark_entries(entries: Dictionary) -> void:
	if _scene_landmark_runtime != null and _scene_landmark_runtime.has_method("configure"):
		_scene_landmark_runtime.configure(entries.duplicate(true))
	var runtime_entries: Dictionary = entries.duplicate(true)
	if _scene_landmark_runtime != null and _scene_landmark_runtime.has_method("get_entries_snapshot"):
		runtime_entries = _scene_landmark_runtime.get_entries_snapshot()
	if _music_road_runtime != null and _music_road_runtime.has_method("configure"):
		_music_road_runtime.configure(runtime_entries.duplicate(true))
	if chunk_renderer != null and chunk_renderer.has_method("set_scene_landmark_entries"):
		chunk_renderer.set_scene_landmark_entries(runtime_entries)
	if _map_pin_registry != null and _map_pin_registry.has_method("replace_scene_landmark_pins"):
		var pins: Array = []
		if _scene_landmark_runtime != null and _scene_landmark_runtime.has_method("get_full_map_pins"):
			pins = _scene_landmark_runtime.get_full_map_pins()
		_map_pin_registry.replace_scene_landmark_pins(pins)
	if _full_map_open and _map_screen != null and _map_screen.has_method("set_pins"):
		_map_screen.set_pins(_get_map_pins("full_map"))

func _sync_scene_interactive_prop_entries(entries: Dictionary) -> void:
	if _scene_interactive_prop_runtime != null and _scene_interactive_prop_runtime.has_method("configure"):
		_scene_interactive_prop_runtime.configure(entries.duplicate(true))
	var runtime_entries: Dictionary = entries.duplicate(true)
	if _scene_interactive_prop_runtime != null and _scene_interactive_prop_runtime.has_method("get_entries_snapshot"):
		runtime_entries = _scene_interactive_prop_runtime.get_entries_snapshot()
	if chunk_renderer != null and chunk_renderer.has_method("set_scene_interactive_prop_entries"):
		chunk_renderer.set_scene_interactive_prop_entries(runtime_entries)

func _sync_scene_minigame_venue_entries(entries: Dictionary) -> void:
	if _scene_minigame_venue_runtime != null and _scene_minigame_venue_runtime.has_method("configure"):
		_scene_minigame_venue_runtime.configure(entries.duplicate(true))
	var runtime_entries: Dictionary = entries.duplicate(true)
	if _scene_minigame_venue_runtime != null and _scene_minigame_venue_runtime.has_method("get_entries_snapshot"):
		runtime_entries = _scene_minigame_venue_runtime.get_entries_snapshot()
	if _soccer_venue_runtime != null and _soccer_venue_runtime.has_method("configure"):
		_soccer_venue_runtime.configure(runtime_entries.duplicate(true))
	if _tennis_venue_runtime != null and _tennis_venue_runtime.has_method("configure"):
		_tennis_venue_runtime.configure(runtime_entries.duplicate(true))
	if _missile_command_venue_runtime != null and _missile_command_venue_runtime.has_method("configure"):
		_missile_command_venue_runtime.configure(runtime_entries.duplicate(true))
	if _fishing_venue_runtime != null and _fishing_venue_runtime.has_method("configure"):
		_fishing_venue_runtime.configure(runtime_entries.duplicate(true))
	if chunk_renderer != null and chunk_renderer.has_method("set_scene_minigame_venue_entries"):
		chunk_renderer.set_scene_minigame_venue_entries(runtime_entries)
	if _map_pin_registry != null and _map_pin_registry.has_method("replace_scene_minigame_venue_pins"):
		var pins: Array = []
		if _scene_minigame_venue_runtime != null and _scene_minigame_venue_runtime.has_method("get_full_map_pins"):
			pins = _scene_minigame_venue_runtime.get_full_map_pins()
		_map_pin_registry.replace_scene_minigame_venue_pins(pins)
	if _full_map_open and _map_screen != null and _map_screen.has_method("set_pins"):
		_map_screen.set_pins(_get_map_pins("full_map"))

func _sync_terrain_region_feature_entries(entries: Dictionary) -> void:
	if _terrain_region_feature_runtime != null and _terrain_region_feature_runtime.has_method("configure"):
		_terrain_region_feature_runtime.configure(entries.duplicate(true))
	var runtime_entries: Dictionary = entries.duplicate(true)
	if _terrain_region_feature_runtime != null and _terrain_region_feature_runtime.has_method("get_entries_snapshot"):
		runtime_entries = _terrain_region_feature_runtime.get_entries_snapshot()
	if chunk_renderer != null and chunk_renderer.has_method("set_terrain_region_entries"):
		chunk_renderer.set_terrain_region_entries(runtime_entries)
	if _lake_fish_school_runtime != null and _lake_fish_school_runtime.has_method("configure"):
		var lake_runtimes: Array = []
		if _terrain_region_feature_runtime != null and _terrain_region_feature_runtime.has_method("get_lake_runtimes"):
			lake_runtimes = _terrain_region_feature_runtime.get_lake_runtimes()
		_lake_fish_school_runtime.configure(lake_runtimes)
	if _fishing_venue_runtime != null and _fishing_venue_runtime.has_method("set_lake_context"):
		_fishing_venue_runtime.set_lake_context(_terrain_region_feature_runtime, _lake_fish_school_runtime)

func _update_lake_player_water_state() -> void:
	var next_state := {
		"in_water": false,
		"underwater": false,
		"region_id": "",
		"water_level_y_m": 0.0,
		"depth_m": 0.0,
		"floor_y_m": 0.0,
		"world_position": player.global_position if player != null else Vector3.ZERO,
	}
	if player != null and _terrain_region_feature_runtime != null and _terrain_region_feature_runtime.has_method("query_water_state"):
		var player_chunk_key := CityChunkKey.world_to_chunk_key(_world_config, player.global_position)
		var player_chunk_id: String = _world_config.format_chunk_id(player_chunk_key)
		var can_skip_query: bool = _terrain_region_feature_runtime.has_method("has_entries_for_chunk") \
			and not bool(_terrain_region_feature_runtime.has_entries_for_chunk(player_chunk_id)) \
			and not bool(_lake_player_water_state.get("in_water", false))
		if can_skip_query:
			if next_state == _lake_player_water_state:
				return
			_lake_player_water_state = next_state.duplicate(true)
			if player != null and player.has_method("set_lake_water_state"):
				player.set_lake_water_state(_lake_player_water_state)
			return
		next_state = _terrain_region_feature_runtime.query_water_state(player.global_position)
	if next_state == _lake_player_water_state:
		return
	_lake_player_water_state = next_state.duplicate(true)
	if player != null and player.has_method("set_lake_water_state"):
		player.set_lake_water_state(_lake_player_water_state)

func _update_minigame_venue_runtimes(delta: float) -> void:
	var soccer_runtime_state: Dictionary = {}
	var tennis_runtime_state: Dictionary = {}
	var missile_command_runtime_state: Dictionary = {}
	var fishing_runtime_state: Dictionary = {}
	if _soccer_venue_runtime != null and _soccer_venue_runtime.has_method("update"):
		soccer_runtime_state = _soccer_venue_runtime.update(chunk_renderer, player, delta)
	if _tennis_venue_runtime != null and _tennis_venue_runtime.has_method("update"):
		tennis_runtime_state = _tennis_venue_runtime.update(chunk_renderer, player, delta)
	if _missile_command_venue_runtime != null and _missile_command_venue_runtime.has_method("update"):
		missile_command_runtime_state = _missile_command_venue_runtime.update(chunk_renderer, player, delta)
	if _fishing_venue_runtime != null and _fishing_venue_runtime.has_method("update"):
		fishing_runtime_state = _fishing_venue_runtime.update(chunk_renderer, player, delta)
	_sync_player_fishing_state(fishing_runtime_state)
	var ambient_simulation_frozen := bool(soccer_runtime_state.get("ambient_simulation_frozen", false)) \
		or bool(tennis_runtime_state.get("ambient_simulation_frozen", false)) \
		or bool(missile_command_runtime_state.get("ambient_simulation_frozen", false)) \
		or bool(fishing_runtime_state.get("ambient_simulation_frozen", false))
	if chunk_renderer != null and chunk_renderer.has_method("set_ambient_simulation_frozen"):
		chunk_renderer.set_ambient_simulation_frozen(ambient_simulation_frozen)
	if hud != null and hud.has_method("set_soccer_match_hud_state"):
		var soccer_hud_state: Dictionary = (soccer_runtime_state.get("match_hud_state", {}) as Dictionary).duplicate(true)
		if soccer_hud_state.is_empty():
			soccer_hud_state = _build_default_soccer_match_hud_state()
		hud.set_soccer_match_hud_state(soccer_hud_state)
	if hud != null and hud.has_method("set_tennis_match_hud_state"):
		var tennis_hud_state: Dictionary = (tennis_runtime_state.get("match_hud_state", {}) as Dictionary).duplicate(true)
		if tennis_hud_state.is_empty():
			tennis_hud_state = _build_default_tennis_match_hud_state()
		hud.set_tennis_match_hud_state(tennis_hud_state)
	if hud != null and hud.has_method("set_missile_command_hud_state"):
		var missile_hud_state: Dictionary = (missile_command_runtime_state.get("match_hud_state", {}) as Dictionary).duplicate(true)
		if missile_hud_state.is_empty():
			missile_hud_state = _build_default_missile_command_hud_state()
		hud.set_missile_command_hud_state(missile_hud_state)
	if hud != null and hud.has_method("set_fishing_hud_state"):
		var fishing_hud_state: Dictionary = fishing_runtime_state.get("match_hud_state", {})
		if fishing_hud_state.is_empty():
			fishing_hud_state = _build_default_fishing_hud_state()
		hud.set_fishing_hud_state(fishing_hud_state)
	_apply_fishing_feedback_from_state(fishing_runtime_state)
	if hud != null and hud.has_method("set_crosshair_state"):
		hud.set_crosshair_state(_build_crosshair_state())

func _update_music_road_runtime(_delta: float) -> void:
	_advance_music_road_runtime(_delta)

func _advance_music_road_runtime(delta_sec: float, vehicle_state_override: Dictionary = {}) -> Dictionary:
	if _music_road_runtime == null or not _music_road_runtime.has_method("update"):
		return {}
	var runtime_vehicle_state := _build_music_road_runtime_vehicle_state(vehicle_state_override)
	_music_road_runtime_time_sec += maxf(delta_sec, 0.0)
	_music_road_runtime.update(chunk_renderer, runtime_vehicle_state, _music_road_runtime_time_sec)
	return _music_road_runtime.get_state()

func _build_music_road_runtime_vehicle_state(vehicle_state_override: Dictionary = {}) -> Dictionary:
	if not vehicle_state_override.is_empty():
		return vehicle_state_override.duplicate(true)
	var runtime_vehicle_state := {
		"driving": false,
		"world_position": player.global_position if player != null else Vector3.ZERO,
	}
	if player != null and player.has_method("get_driving_vehicle_state") and player.has_method("is_driving_vehicle") and bool(player.is_driving_vehicle()):
		return player.get_driving_vehicle_state()
	if player != null:
		runtime_vehicle_state["world_position"] = player.global_position
	return runtime_vehicle_state

func _collect_completed_building_export_job() -> void:
	if _building_export_thread != null:
		if _building_export_thread.is_alive():
			return
		var thread_result: Variant = _building_export_thread.wait_to_finish()
		_building_export_thread = null
		if thread_result is Dictionary:
			_building_export_pending_result = (thread_result as Dictionary).duplicate(true)
		else:
			_building_export_pending_result = {
				"success": false,
				"status": "failed",
				"building_id": str(_building_export_request.get("building_id", "")),
				"display_name": str(_building_export_request.get("display_name", "")),
				"error": "invalid_thread_result",
			}
	if _building_export_pending_result.is_empty():
		return
	if Engine.get_process_frames() <= _building_export_started_process_frame + 1:
		return
	_finalize_building_export_result(_building_export_pending_result)
	_building_export_pending_result.clear()

func _finalize_building_export_result(result: Dictionary, emit_toast: bool = true, sync_runtime_entries: bool = true) -> Dictionary:
	var resolved_state := {
		"running": false,
		"status": str(result.get("status", "failed")),
		"building_id": str(result.get("building_id", "")),
		"display_name": str(result.get("display_name", "")),
		"scene_root": str(result.get("scene_root", "")),
		"scene_path": str(result.get("scene_path", "")),
		"manifest_path": str(result.get("manifest_path", "")),
		"error": str(result.get("error", "")),
		"export_root_kind": str(result.get("export_root_kind", "")),
	}
	if bool(result.get("success", false)):
		var registry_entry: Dictionary = (result.get("registry_entry", {}) as Dictionary).duplicate(true)
		var registry_path := _normalize_serviceability_resource_path(str(result.get("registry_path", "")))
		if registry_entry.is_empty() or registry_path == "" or _building_override_registry == null:
			resolved_state["status"] = "failed"
			resolved_state["error"] = "registry_persist_unavailable"
		else:
			_building_override_registry.set_primary_registry_path(registry_path)
			var save_result: Dictionary = _building_override_registry.save_entry(registry_entry)
			if bool(save_result.get("success", false)):
				if sync_runtime_entries:
					var entries: Dictionary = _building_override_registry.load_registry()
					_sync_building_override_entries(entries)
			else:
				resolved_state["status"] = "failed"
				resolved_state["error"] = str(save_result.get("error", "registry_save_failed"))
	if emit_toast:
		if str(resolved_state.get("status", "")) == "completed":
			_show_building_export_toast(_build_building_export_success_message(resolved_state), BUILDING_EXPORT_TOAST_DURATION_SEC)
		else:
			_show_building_export_toast(_build_building_export_failure_message(resolved_state), BUILDING_EXPORT_TOAST_DURATION_SEC)
	_building_export_state = resolved_state
	_building_export_request.clear()
	_building_export_started_process_frame = -1
	return resolved_state.duplicate(true)

func _build_building_export_success_message(state: Dictionary) -> String:
	var display_name := str(state.get("display_name", ""))
	if display_name != "":
		return "建筑重构完成：%s" % display_name
	var building_id := str(state.get("building_id", ""))
	if building_id != "":
		return "建筑重构完成：%s" % building_id
	return "建筑重构完成"

func _build_building_export_started_message(state: Dictionary) -> String:
	var display_name := str(state.get("display_name", ""))
	if display_name != "":
		return "建筑重构开始：%s" % display_name
	var building_id := str(state.get("building_id", ""))
	if building_id != "":
		return "建筑重构开始：%s" % building_id
	return "建筑重构开始"

func _build_building_export_failure_message(state: Dictionary) -> String:
	var error_text := str(state.get("error", "")).strip_edges()
	if error_text == "":
		error_text = "unknown_error"
	return "建筑重构失败：%s" % error_text

func _show_building_export_toast(text: String, duration_sec: float = BUILDING_EXPORT_TOAST_DURATION_SEC) -> void:
	var resolved_text := text.strip_edges()
	if resolved_text == "":
		return
	if hud != null and hud.has_method("set_focus_message"):
		hud.set_focus_message(resolved_text, duration_sec)

func _describe_building_export_request_error(error_code: String) -> String:
	match error_code:
		"export_running":
			return "建筑重构正在进行中"
		"override_exists":
			return "建筑已存在功能场景，拒绝覆盖"
		"missing_exportable_building":
			return "最近 10 秒内没有可重构建筑"
		"missing_building_contract":
			return "当前建筑缺少可重构生成参数"
	return ""

func _update_exportable_building_inspection_result(inspection_result: Dictionary) -> void:
	if str(inspection_result.get("inspection_kind", "")) != "building":
		_clear_exportable_building_inspection_window()
		return
	var building_id := str(inspection_result.get("building_id", ""))
	if building_id == "":
		_clear_exportable_building_inspection_window()
		return
	var building_contract := get_building_generation_contract(building_id)
	if building_contract.is_empty():
		_clear_exportable_building_inspection_window()
		return
	_exportable_building_inspection_result = inspection_result.duplicate(true)
	_exportable_building_inspection_result["building_id"] = building_id
	_exportable_building_inspection_result["display_name"] = str(_exportable_building_inspection_result.get("display_name", building_contract.get("display_name", "")))
	_exportable_building_inspection_result["generation_locator"] = (building_contract.get("generation_locator", {}) as Dictionary).duplicate(true)
	_exportable_building_inspection_result["source_building_contract"] = building_contract.duplicate(true)
	_exportable_building_inspection_expire_usec = Time.get_ticks_usec() + int(round(BUILDING_EXPORT_WINDOW_SEC * 1000000.0))

func _expire_exportable_building_inspection_window() -> void:
	if _exportable_building_inspection_result.is_empty():
		return
	if _exportable_building_inspection_expire_usec <= 0:
		_clear_exportable_building_inspection_window()
		return
	if Time.get_ticks_usec() < _exportable_building_inspection_expire_usec:
		return
	_clear_exportable_building_inspection_window()

func _clear_exportable_building_inspection_window() -> void:
	_exportable_building_inspection_result.clear()
	_exportable_building_inspection_expire_usec = 0

func _build_building_export_request(source_result: Dictionary) -> Dictionary:
	return {
		"building_id": str(source_result.get("building_id", "")),
		"display_name": str(source_result.get("display_name", "")),
		"generation_locator": (source_result.get("generation_locator", {}) as Dictionary).duplicate(true),
		"building_contract": (source_result.get("source_building_contract", {}) as Dictionary).duplicate(true),
		"requested_at_unix_sec": int(Time.get_unix_time_from_system()),
		"scene_root_attempts": _resolve_building_export_scene_root_attempts(),
		"registry_override_path": _normalize_serviceability_resource_path(_building_serviceability_registry_override_path),
	}

func _resolve_building_export_scene_root_attempts() -> Array[Dictionary]:
	var attempts: Array[Dictionary] = []
	for candidate in [
		{"scene_root": _building_serviceability_preferred_scene_root, "export_root_kind": "preferred"},
		{"scene_root": _building_serviceability_fallback_scene_root, "export_root_kind": "fallback"},
	]:
		var scene_root := _normalize_serviceability_resource_path(str(candidate.get("scene_root", "")))
		if scene_root == "":
			continue
		var duplicate_root := false
		for existing in attempts:
			if str(existing.get("scene_root", "")) == scene_root:
				duplicate_root = true
				break
		if duplicate_root:
			continue
		attempts.append({
			"scene_root": scene_root,
			"export_root_kind": str(candidate.get("export_root_kind", "preferred")),
		})
	return attempts

func _run_building_export_thread(request: Dictionary) -> Dictionary:
	var exporter := CityBuildingSceneExporter.new()
	var building_id := str(request.get("building_id", ""))
	var display_name := str(request.get("display_name", ""))
	var building_contract: Dictionary = (request.get("building_contract", {}) as Dictionary).duplicate(true)
	var generation_locator: Dictionary = (request.get("generation_locator", {}) as Dictionary).duplicate(true)
	var registry_override_path := _normalize_serviceability_resource_path(str(request.get("registry_override_path", "")))
	var requested_at_unix_sec := int(request.get("requested_at_unix_sec", 0))
	var last_failure := {
		"success": false,
		"status": "failed",
		"building_id": building_id,
		"display_name": display_name,
		"scene_root": "",
		"scene_path": "",
		"manifest_path": "",
		"error": "missing_export_root",
		"export_root_kind": "",
	}
	for attempt_variant in request.get("scene_root_attempts", []):
		var attempt: Dictionary = attempt_variant
		var scene_root := _normalize_serviceability_resource_path(str(attempt.get("scene_root", "")))
		if scene_root == "":
			continue
		var export_root_kind := str(attempt.get("export_root_kind", "preferred"))
		var prepared := exporter.prepare_export_payload({
			"building_id": building_id,
			"display_name": display_name,
			"scene_root": scene_root,
			"export_root_kind": export_root_kind,
			"requested_at_unix_sec": requested_at_unix_sec,
			"building_contract": building_contract,
			"generation_locator": generation_locator,
		})
		if not bool(prepared.get("success", false)):
			last_failure = {
				"success": false,
				"status": "failed",
				"building_id": building_id,
				"display_name": display_name,
				"scene_root": scene_root,
				"scene_path": "",
				"manifest_path": "",
				"error": str(prepared.get("error", "prepare_failed")),
				"export_root_kind": export_root_kind,
			}
			continue
		var committed := exporter.commit_export(prepared)
		if bool(committed.get("success", false)):
			committed["registry_path"] = registry_override_path if registry_override_path != "" else CityBuildingSceneExporter.build_registry_path(scene_root)
			return committed
		last_failure = committed.duplicate(true)
	return last_failure.duplicate(true)

func _normalize_serviceability_resource_path(path: String) -> String:
	return path.replace("\\", "/").trim_suffix("/").strip_edges()

func _configure_environment() -> void:
	if world_environment == null:
		return
	var environment := world_environment.environment
	if environment == null:
		environment = Environment.new()
		world_environment.environment = environment

	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.168627, 0.270588, 0.431373, 1.0)
	sky_material.sky_horizon_color = Color(0.580392, 0.737255, 0.839216, 1.0)
	sky_material.ground_horizon_color = Color(0.627451, 0.654902, 0.615686, 1.0)
	sky_material.ground_bottom_color = Color(0.137255, 0.164706, 0.145098, 1.0)
	sky_material.sky_curve = 0.22
	sky_material.ground_curve = 0.08
	sky_material.sun_angle_max = 18.0

	var sky := Sky.new()
	sky.sky_material = sky_material

	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.75
	environment.ambient_light_sky_contribution = 0.8
	environment.fog_enabled = true
	environment.fog_density = 0.00065
	environment.fog_aerial_perspective = 0.55
	environment.fog_light_color = Color(0.643137, 0.741176, 0.803922, 1.0)
	environment.fog_light_energy = 0.8
	environment.fog_sky_affect = 1.0
	environment.fog_sun_scatter = 0.18
