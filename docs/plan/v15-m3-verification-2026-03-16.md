# V15 M3 Verification - 2026-03-16

## Scope

本次验证覆盖：

- `v15` 激光指示器主链
- `building_id / unique display_name / clipboard` contract
- `grenade / crosshair` 旧 combat 回归
- 性能三件套串行复核

说明：

- 性能三件套按单项独立进程执行取证。
- 调试过程中出现过边缘波动样本；本文件只记录最终用于 closeout 的 fresh isolated rerun 结果。

## Functional Verification

| Command | Result | Evidence |
|---|---|---|
| `--script res://tests/world/test_city_player_laser_designator.gd` | PASS | building hit 返回非空 `building_id / display_name / address_label`；第二次 inspection 会刷新 HUD/clipboard；`building_id` 可回查 generation contract |
| `--script res://tests/e2e/test_city_laser_designator_flow.gd` | PASS | 实际激光请求链、HUD focus message、clipboard building_id、10 秒自动清空均通过 |
| `--script res://tests/world/test_city_player_grenade.gd` | PASS | 顺带修复近处高屋顶误导短抛目标的问题，低头短抛重新落在近地面范围 |
| `--script res://tests/world/test_city_combat_crosshair.gd` | PASS | rifle / ADS / crosshair 旧 HUD contract 未回退 |

## Performance Verification

| Command | Result | Key Metrics |
|---|---|---|
| `--script res://tests/world/test_city_chunk_setup_profile_breakdown.gd` | PASS | `ground_usec=988`，`total_usec=2997` |
| `--script res://tests/e2e/test_city_runtime_performance_profile.gd` | PASS | `wall_frame_avg_usec=9148`，`update_streaming_avg_usec=7715`，`streaming_prepare_profile_avg_usec=10593` |
| `--script res://tests/e2e/test_city_first_visit_performance_profile.gd` | PASS | `wall_frame_avg_usec=14117`，`update_streaming_avg_usec=13363`，`streaming_prepare_profile_avg_usec=11080` |

## Outcome

- `v15` 现在正式承诺唯一建筑名字与 `building_id`，不再保留“只是 inspection label”的口径。
- inspection 结果会立即刷新 HUD 与 Windows 剪贴板。
- 运行时已暴露 `building_id -> generation contract` 的最小查询口，为后续建筑替换链保留锚点。
- 相关 combat/HUD/performance 护栏在本次 fresh rerun 下均通过。
