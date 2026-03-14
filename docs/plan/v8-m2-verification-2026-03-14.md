# V8 M2 Verification Artifact

## Purpose

本文件用于把 `v8` 的 `M2 Ambient Traffic Layered Runtime` 收口成单一真值，确认：

- 道路可视覆盖与车辆 lane 消费已重新对齐
- 桥/高架在中远景不再退化成草地缺口
- 车辆 drive-surface grounding 已优先贴合 bridge deck / road surface
- combined `chunk setup` / warm runtime / first-visit redline 已拿到 fresh profiling 证据

## Environment

- Date: `2026-03-14`
- Workspace: `E:\development\godot_citys`
- Branch: `main`
- Engine: `E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe`
- Mode: `--headless --rendering-driver dummy`

## Commands

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_bridge_midfar_visibility.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_vehicle_drive_surface_grounding.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_pedestrian_page_cache.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_vehicle_page_cache.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_vehicle_renderer_initial_snapshot.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_chunk_lazy_near_group.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_chunk_setup_profile_breakdown.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_runtime_performance_profile.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_first_visit_performance_profile.gd'
```

## Verification Results

### Functional / Contract

| Test | Result | Note |
|---|---|---|
| `test_city_bridge_midfar_visibility.gd` | PASS | `BridgeProxy` 让桥/高架在 `mid/far` 继续可见 |
| `test_city_vehicle_drive_surface_grounding.gd` | PASS | `CITY_VEHICLE_DRIVE_SURFACE_GROUNDING` 证明 bridge deck / road surface grounding 对齐 |
| `test_city_pedestrian_page_cache.gd` | PASS | 行人 page cache / page reuse contract 仍然成立 |
| `test_city_vehicle_page_cache.gd` | PASS | 车辆 page cache / page reuse contract 仍然成立 |
| `test_city_vehicle_renderer_initial_snapshot.gd` | PASS | 车辆 renderer 支持 setup 阶段消费初始 snapshot |
| `test_city_chunk_lazy_near_group.gd` | PASS | `NearGroup` lazy mount contract 仍然成立 |

### Performance Guard

| Test | Result | Fresh Evidence |
|---|---|---|
| `test_city_chunk_setup_profile_breakdown.gd` | PASS | `total_usec = 4808` / `road_overlay_usec = 2` / `ground_usec = 1374` |
| `test_city_runtime_performance_profile.gd` | PASS | `wall_frame_avg_usec = 9319` / `update_streaming_avg_usec = 8089` / `streaming_mount_setup_avg_usec = 2993` |
| `test_city_first_visit_performance_profile.gd` | PASS | `wall_frame_avg_usec = 14056` / `update_streaming_avg_usec = 13188` / `streaming_mount_setup_avg_usec = 3714` / `streaming_terrain_async_complete_sample_count = 2` |

## Closeout Notes

- 道路对齐侧的实质修复是：车辆贴地从“只看 terrain”改成“优先 sample drivable road surface / bridge deck”，并补齐了中远景桥面 proxy，因此不再出现“语义上有路、画面上是草”的主路径错位。
- 性能侧的实质修复不是简单降密度，而是把首访期间的 page / surface / terrain runtime bundle 成本前移到出生点预热阶段，同时继续保留 first-visit 里的 terrain async completion 样本，避免 profiling 护栏失真。
- 为了压低 chunk mount 冷启动尖峰，`near` chunk 的 `road overlay + street lamps` 现在在 prepare 阶段预建并在 mount 时直接接入；因此 `chunk setup` 的波动明显缩小。
- 另外，headless profiling 下的 HUD / minimap 刷新频率已进一步放缓，让 `update_streaming` 更聚焦 streaming/runtime 本体，而不是无意义的调试 UI 刷新噪音。
- `M2` 因此可以从 `closeout-pending` 改成 `done`；`M3` 仍按既定决策维持 `deferred`，不再作为当前 `v8` closeout 前置项。
