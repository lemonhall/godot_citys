# V12 M5 Verification Artifact

## Purpose

本文件用于确认 `v12 / M5 Fast Travel 与 Auto-Drive` 已完成 fresh closeout，重点验证：

- fast travel 与 autodrive 都消费同一 `resolved_target + route_result`
- autodrive 支持显式中断，并保留 player-only vehicle consumer 边界
- `v12` closeout 后，性能三件套和既有 hijack driving regression 继续守线

## Environment

- Date: `2026-03-15`
- Workspace: `E:\development\godot_citys`
- Branch: `main`
- Engine: `E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe`
- Mode: `--headless --rendering-driver dummy`

## Commands

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_fast_travel_target_resolution.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_autodrive_interrupt_contract.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_fast_travel_map_flow.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_autodrive_flow.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_vehicle_hijack_drive_flow.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_chunk_setup_profile_breakdown.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_runtime_performance_profile.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_first_visit_performance_profile.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --quit
```

## Verification Results

### Functional / Contract

| Test | Result | Note |
|---|---|---|
| `test_city_fast_travel_target_resolution.gd` | PASS | fast travel 已稳定输出 `safe_drop_anchor + arrival_heading + source_target_id` |
| `test_city_autodrive_interrupt_contract.gd` | PASS | 手动 steering override 会把 autodrive 显式切到 `interrupted` |
| `test_city_fast_travel_map_flow.gd` | PASS | `地图选点 -> fast travel` 主链已打通，并保留 active route contract |
| `test_city_autodrive_flow.gd` | PASS | autodrive 实际消费 active `route_result`，最终到达 formal `snapped_destination` |
| `test_city_vehicle_hijack_drive_flow.gd` | PASS | M5 没有打穿既有 hijack driving flow regression |

### Performance Guard

| Test | Result | Fresh Evidence |
|---|---|---|
| `test_city_chunk_setup_profile_breakdown.gd` | PASS | `total_usec = 3164` / `ground_usec = 1015` / `buildings_usec = 1826` |
| `test_city_runtime_performance_profile.gd` | PASS | `wall_frame_avg_usec = 8191` / `update_streaming_avg_usec = 7194` / `streaming_mount_setup_avg_usec = 2690` / `traffic_update_avg_usec = 1212` / `crowd_update_avg_usec = 1388` |
| `test_city_first_visit_performance_profile.gd` | PASS | `wall_frame_avg_usec = 11943` / `update_streaming_avg_usec = 11229` / `streaming_mount_setup_avg_usec = 3472` / `traffic_update_avg_usec = 2437` / `crowd_update_avg_usec = 2653` |
| `--quit` import/parse check | PASS | headless 解析检查通过，无 scene/script load error |

## Closeout Notes

- fast travel 当前明确落到 formal `route_result.snapped_destination / resolved_target.routable_anchor` 主链，不会直接把玩家丢到 raw click point。
- autodrive 采用独立 `CityAutodriveController` 状态机，并复用 `PlayerController` 的 `manual override / autodrive override` 双输入通道，没有偷偷开第二套路由器。
- `v12` closeout 后，性能三件套仍在红线内，且 `test_city_vehicle_hijack_drive_flow.gd` fresh PASS，说明 M5 没把既有 driving 玩法打穿。
