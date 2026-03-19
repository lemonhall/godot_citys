# V28 M5 Verification - 2026-03-19

## Status Note

- 本文记录 `v28` 在 `2026-03-19` 针对“球拍视觉 + 挥拍音效 + tennis HUD Coach/Assist 增强”之后的 fresh profiling rerun。
- 这一轮 touch 到了：
  - `PlayerController.gd`
  - `PrototypeHud.gd`
  - `CityTennisVenueRuntime.gd`
  - `TennisRacketVisualRig.gd`
- 因此按仓库硬规则，必须重跑 ordered profiling three-piece，而不是口头宣称“感觉没变慢”。

## Scope

- ordered profiling three-piece rerun
  - `res://tests/world/test_city_chunk_setup_profile_breakdown.gd`
  - `res://tests/e2e/test_city_first_visit_performance_profile.gd`
  - `res://tests/e2e/test_city_runtime_performance_profile.gd`
- 记录 HUD / audio polish 之后的性能口径

## Commands

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_chunk_setup_profile_breakdown.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_first_visit_performance_profile.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_runtime_performance_profile.gd'
```

## Fresh Results

### 1. Chunk Setup

- Command:
  - `res://tests/world/test_city_chunk_setup_profile_breakdown.gd`
- Result:
  - `PASS`
- Key profile:
  - `total_usec = 3551`
  - `ground_mask_cache_hit = true`
  - `ground_runtime_page_hit = true`

### 2. First Visit

- Command:
  - `res://tests/e2e/test_city_first_visit_performance_profile.gd`
- Result:
  - `PASS`
- Key profile:
  - `streaming_mount_setup_avg_usec = 4719`
  - `streaming_prepare_profile_avg_usec = 6388`
  - `update_streaming_avg_usec = 12220`
  - `wall_frame_avg_usec = 14997`
  - `wall_frame_max_usec = 73431`
- Interpretation:
  - 首访口径本轮在 guard 内通过
  - 仍可见首访尖峰，但没有把本轮 HUD / audio polish 推过测试护栏

### 3. Warm Runtime

- Command:
  - `res://tests/e2e/test_city_runtime_performance_profile.gd`
- Result:
  - `PASS`
- Key profile:
  - `streaming_mount_setup_avg_usec = 3001`
  - `streaming_prepare_profile_avg_usec = 5198`
  - `update_streaming_avg_usec = 6418`
  - `wall_frame_avg_usec = 10488`
  - `hud_refresh_avg_usec = 345`

## Interpretation

- 这轮 tennis 表现增强没有把 profiling 三件套打红。
- `HUD Coach/Assist` 与 `swing audio` 目前没有表现出明显的持续型热路径退化：
  - warm runtime `hud_refresh_avg_usec = 345`
  - warm runtime `wall_frame_avg_usec = 10488`
- 首访仍有正常范围内的 mount / frame 尖峰，但此次结果已通过现有 guard。

## Closeout Call

- `chunk setup`: green
- `first-visit`: green
- `warm runtime`: green
- 结论：
  - 对于“球拍视觉 + 挥拍音效 + HUD 指令增强”这一轮局部改动，profiling evidence 已 fresh capture
  - 这证明本轮 polish 没有把 `v28` 拉出当前性能护栏
  - 但 `v28` 整体是否 closeout，仍要看更广的玩法范围是否继续调整
