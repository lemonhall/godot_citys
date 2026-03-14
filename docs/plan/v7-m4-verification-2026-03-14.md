# V7 M4 Verification Artifact

## Purpose

本文件用于把 `v7` closeout 的 fresh rerun 结果钉成单一真值，解决 `v7` 文档中同时存在多组历史 profiling 数字的问题。

## Environment

- Date: `2026-03-14`
- Workspace: `E:\development\godot_citys`
- Engine: `E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe`
- Mode: `--headless --rendering-driver dummy`
- Rule: profiling 命令隔离执行，不与其他 Godot 进程并行

## Commands

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_road_semantic_contract.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_road_intersection_topology.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_road_layout_semantic_takeover.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_road_runtime_node_budget.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_chunk_setup_profile_breakdown.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_runtime_performance_profile.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_first_visit_performance_profile.gd'
```

## Verification Results

### Contract / Guard Tests

| Test | Result |
|---|---|
| `test_city_road_semantic_contract.gd` | PASS |
| `test_city_road_intersection_topology.gd` | PASS |
| `test_city_road_layout_semantic_takeover.gd` | PASS |
| `test_city_road_runtime_node_budget.gd` | PASS |

### Performance Truth Table

| Suite | Key Metrics | Threshold | Result |
|---|---|---|---|
| `test_city_chunk_setup_profile_breakdown.gd` | `total_usec = 4794` `road_overlay_usec = 973` `ground_usec = 1226` | `<= 8500 / 1400 / 1800` | PASS |
| `test_city_runtime_performance_profile.gd` | `wall_frame_avg_usec = 7898` `streaming_mount_setup_avg_usec = 3432` `update_streaming_avg_usec = 7210` | `<= 11000 / 5500 / 10000` | PASS |
| `test_city_first_visit_performance_profile.gd` | `wall_frame_avg_usec = 14041` `streaming_mount_setup_avg_usec = 4746` `update_streaming_avg_usec = 13189` | `<= 16667 / 5500 / 14500` | PASS |

## Scope Clarification

- 本留档证明 `v7` 在本期 scoped acceptance 下已经收口：`edge semantic contract`、`intersection topology upstream contract`、`chunk consumer takeover`、`runtime node guard`、`profiling guard` 均已落地。
- 本留档不声明“所有下游系统都已完整消费交叉口语义”。当前正式 runtime consumer 主要仍是 `pedestrian_crossing_candidate` 这一级 gating；更丰富的 `ordered_branches / branch_connection_semantics` consumerization 仍留给后续 `signage / vehicle / richer pedestrian` 版本。
- `v7-index.md` 与 `v7-road-semantic-runtime-uplift.md` 中保留的其它数字属于阶段性历史快照；如与 closeout 口径冲突，以本文件为准。
