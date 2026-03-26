# godot_citys

Godot 4.6 large-world city runtime prototype.

This repository is no longer a small skeleton project. It now contains the active runtime, contract tests, milestone plans, editor tooling, a native radio backend, authored world features, combat systems, and creature runtimes used by the main world.

## What This Project Is

- A `70km x 70km` low poly city runtime prototype built for stable large-world streaming.
- A gameplay sandbox with shared navigation, map, task, marker, and vehicle systems.
- A milestone-driven project whose source of truth lives in `docs/plan/`, not in this README.

Current shipped milestone families include:

- `v12`: place query, resolved targets, route result, map, minimap, fast travel, autodrive
- `v14`: shared task catalog/runtime/pin/world-ring/trigger chain
- `v24`: vehicle radio system and native backend integration
- `v30-v31`: scene preview harness and editor plugin
- `v37`: helicopter gunship encounter
- `v54-v58`: drone-assisted artillery and squadron strike chain
- `v59-v61`: robot dog scene foundation, prone pose, and main-world ground locomotion control

## Requirements

- Windows 11
- PowerShell
- Godot `4.6` console build for headless verification
- Godot `4.6` desktop build for local interactive runs

Example local paths used in this repo:

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
```

## Quick Start

- Parse check:

```powershell
& $godot --headless --rendering-driver dummy --path $project --quit
```

- Run the main world:

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64.exe' --path $project
```

- Run the smoke test:

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/test_city_skeleton_smoke.gd'
```

- Run a single world contract:

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/<test-name>.gd'
```

- Run a single end-to-end test:

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/<test-name>.gd'
```

## Common Verification Sets

- Navigation and map:
  - `test_city_place_query_resolution.gd`
  - `test_city_resolved_target_contract.gd`
  - `test_city_route_query_contract.gd`
  - `test_city_map_destination_contract.gd`
  - `test_city_minimap_navigation_hud.gd`
  - `tests/e2e/test_city_navigation_flow.gd`

- Tasks and world markers:
  - `test_city_task_catalog_contract.gd`
  - `test_city_task_pin_projection.gd`
  - `test_city_task_world_ring_marker_contract.gd`
  - `test_city_task_route_hides_destination_world_marker.gd`
  - `tests/e2e/test_city_task_start_flow.gd`

- Radio and native backend:
  - `test_city_vehicle_radio_backend_interface_contract.gd`
  - `test_city_vehicle_radio_native_bridge_smoke.gd`
  - `test_city_vehicle_radio_native_bridge_playback_contract.gd`
  - `tests/e2e/test_city_vehicle_radio_browser_flow.gd`

- Robot dog:
  - `test_robot_dog_scene_contract.gd`
  - `test_robot_dog_joint_contract.gd`
  - `test_city_player_robot_dog_toggle_contract.gd`
  - `test_city_player_robot_dog_ground_locomotion_contract.gd`
  - `tests/e2e/test_city_player_robot_dog_flow.gd`

- Performance guards:

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_chunk_setup_profile_breakdown.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_first_visit_performance_profile.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_runtime_performance_profile.gd'
```

Run the performance guards in that order and do not run them in parallel.

## Repository Layout

- `city_game/`
  - Main runtime, scenes, UI, world systems, combat systems, native backend, creature runtimes
- `addons/scene_preview/`
  - Scene preview editor plugin
- `tests/world/`
  - Contract and focused runtime tests
- `tests/e2e/`
  - End-to-end gameplay and integration flows
- `tests/tools/`
  - Tooling and environment-sensitive verification
- `docs/prd/`
  - Product requirement documents
- `docs/plans/`
  - Design and implementation planning notes
- `docs/plan/`
  - Versioned milestone plans and verification evidence
- `docs/research/`
  - Research notes and PDFs
- `reports/`
  - Generated acceptance artifacts such as overview PNG exports
- `refs/`
  - Read-only reference material

## Runtime Notes

- The main scene is `res://city_game/scenes/CityPrototype.tscn`.
- The runtime entry script is `res://city_game/scripts/CityPrototype.gd`.
- The project config and input definitions live in `project.godot`.
- World cache artifacts are written under `user://cache/world/`.
- Radio cache and user state are written under `user://cache/radio/` and `user://radio/`.

## Radio Native Backend

The vehicle radio native backend lives under:

- `city_game/native/radio_backend/`

The only oversized FFmpeg runtime DLL, `avfilter-11.dll`, is stored as split archive volumes instead of a raw Git blob. Restore it on a fresh clone with:

```powershell
pwsh -File .\scripts\restore-radio-ffmpeg-avfilter.ps1
```

That script restores:

- `city_game/native/radio_backend/bin/win64/avfilter-11.dll`
- `city_game/native/radio_backend/thirdparty/ffmpeg/windows-x64-shared/ffmpeg-8.1-full_build-shared/bin/avfilter-11.dll`

If you need to rebuild the backend DLL:

```powershell
Push-Location '.\city_game\native\radio_backend'
scons platform=windows target=template_debug
Pop-Location
```

For more detailed rules, see:

- `city_game/native/radio_backend/AGENTS.md`

## Working Notes

- `AGENTS.md` is the repository-level working guide for AI agents and newcomers. It contains the current engineering rules, testing expectations, safety boundaries, and subdirectory precedence rules.
- `docs/plan/vN-index.md` files are the closeout truth source for milestone status.
- `README.md` is intentionally high-level. If this file and `docs/plan/` disagree, trust `docs/plan/`.

## Contributing Expectations

- Do not rely on hand testing alone.
- Add or update tests for changed behavior.
- Do not claim performance improvement without fresh profiling evidence.
- Do not edit generated acceptance artifacts by hand; regenerate them through tests.
- Treat `refs/` as read-only unless explicitly asked otherwise.
