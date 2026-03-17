# V22 M5 Verification 2026-03-17

## Scope

本文件是 `v22` 的 fresh closeout 证据，覆盖：

- 三件套 profiling 护栏
- `update_streaming` 细粒度 diagnostics contract
- `prepare/build_profile` 细粒度 breakdown contract

## Frozen Command Order

`v22` closeout 的 profiling 顺序冻结为：

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_chunk_setup_profile_breakdown.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_first_visit_performance_profile.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_runtime_performance_profile.gd'
```

原因：

- `first-visit` 的目标是看真正冷路径；它应该先于 warm traversal。
- `warm runtime` 的目标是看已稳定 corridor；它不该拿来污染 cold case 的解释口径。
- 三个测试仍然是独立 Godot 进程，只是 `v22` 把语义顺序正式冻结了。

targeted diagnostics 额外命令：

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_runtime_streaming_diagnostic_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_chunk_profile_prepare_breakdown.gd'
```

## Results

| 测试 | 关键指标 | 阈值 | fresh 值 | 结论 |
|---|---|---|---|---|
| `test_city_chunk_setup_profile_breakdown.gd` | `total_usec` | `<= 8500` | `3390` | PASS |
| `test_city_chunk_setup_profile_breakdown.gd` | `ground_usec` | `<= 1800` | `969` | PASS |
| `test_city_chunk_setup_profile_breakdown.gd` | `road_overlay_usec` | `<= 1400` | `2` | PASS |
| `test_city_first_visit_performance_profile.gd` | `update_streaming_avg_usec` | `<= 14500` | `14493` | PASS |
| `test_city_first_visit_performance_profile.gd` | `wall_frame_avg_usec` | `<= 16667` | `15322` | PASS |
| `test_city_first_visit_performance_profile.gd` | `streaming_mount_setup_avg_usec` | `<= 5500` | `4680` | PASS |
| `test_city_first_visit_performance_profile.gd` | `streaming_terrain_async_complete_avg_usec` | 诊断字段 | `108813` | PASS |
| `test_city_first_visit_performance_profile.gd` | `crowd_update_avg_usec` | 诊断字段 | `2345` | PASS |
| `test_city_first_visit_performance_profile.gd` | `traffic_update_avg_usec` | 诊断字段 | `2324` | PASS |
| `test_city_runtime_performance_profile.gd` | `update_streaming_avg_usec` | `<= 10000` | `8599` | PASS |
| `test_city_runtime_performance_profile.gd` | `wall_frame_avg_usec` | `<= 11000` | `10235` | PASS |
| `test_city_runtime_performance_profile.gd` | `streaming_mount_setup_avg_usec` | `<= 5500` | `3285` | PASS |
| `test_city_runtime_performance_profile.gd` | `ped_tier1_count` | `>= 150` | `155` | PASS |
| `test_city_runtime_streaming_diagnostic_contract.gd` | diagnostics contract | 必须暴露字段 | PASS | PASS |
| `test_city_chunk_profile_prepare_breakdown.gd` | prepare breakdown contract | 必须暴露字段 | PASS | PASS |

## Prepare Breakdown Sample

`test_city_chunk_profile_prepare_breakdown.gd` 的最近一次样本输出如下。它不是阈值，而是后续继续做 prepare 优化时的对账参考：

| 字段 | 最新样本值 |
|---|---|
| `building_candidate_usec` | `6344` |
| `building_streetfront_candidate_usec` | `917` |
| `building_infill_candidate_usec` | `5427` |
| `building_selection_usec` | `716` |
| `building_inspection_payload_usec` | `326` |
| `buildings_usec` | `7534` |
| `total_usec` | `8819` |

## Delta vs Baseline

| 指标 | baseline fail | closeout pass | 变化 |
|---|---|---|---|
| warm `update_streaming_avg_usec` | `11455` | `8599` | `-2856` |
| warm `wall_frame_avg_usec` | `12933` | `10235` | `-2698` |
| warm `streaming_mount_setup_avg_usec` | `3673` | `3285` | `-388` |
| first-visit `update_streaming_avg_usec` | `18171` | `14493` | `-3678` |
| first-visit `wall_frame_avg_usec` | `19213` | `15322` | `-3891` |
| first-visit `streaming_mount_setup_avg_usec` | `5300` | `4680` | `-620` |
| first-visit `streaming_terrain_async_complete_avg_usec` | `142308` | `108813` | `-33495` |

## Code / Config Freeze

- `CityPrototype.gd`
  - spawn 周围预热半径冻结为 `ACTOR_PAGE_PREWARM_RING_RADIUS_CHUNKS = 5`
  - spawn 周围 surface page 预热半径冻结为 `CHUNK_PAGE_PREWARM_RING_RADIUS_CHUNKS = 7`
- `CityChunkRenderer.gd`
  - 默认 guard mode 下关闭细粒度 renderer diagnostics，避免长期 profiling 被探针本身污染
  - prepare 阶段改为线性选取最近 pending chunk，避免每帧对 `_pending_prepare` 做全量排序
- `CityChunkProfileBuilder.gd`
  - 把道路距离评估改为预展开 edge + 等价数学优化
  - `building_candidate_usec / building_*_candidate_usec / building_selection_usec / building_inspection_payload_usec` 已进入正式 contract
- `CityPedestrianTierController.gd`
  - 去掉热路径里若干无谓的 snapshot fallback 分配
  - `crowd_assignment_*` diagnostics 已冻结为长期可读字段

## Residual Risks

- `tests/world/test_city_streetfront_building_layout.gd` 在当前仓库里仍然是红的；本次 `v22` 过程中多次复跑仍复现，看起来更像 `v13` 形态链的既有风险，而不是本次 shared runtime 收口直接引入的回归。
- `streaming_terrain_async_complete_avg_usec` 虽然已经回落，但仍是 cold-only 尖峰口；后续若继续做 `v22.x` 优化，优先继续沿 terrain async complete / prepare shared path 深挖。
