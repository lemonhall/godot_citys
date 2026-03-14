# V8 M1 Verification Artifact

## Purpose

本文件用于把 `v8` 的 `M1 Vehicle World Model` 收口成单一真值，确认 deterministic `vehicle_query`、drivable lane graph、intersection turn contract 与基础 headway contract 已经正式落地。

## Environment

- Date: `2026-03-14`
- Workspace: `E:\development\godot_citys`
- Branch: `v8-m1-vehicle-world-model-local`
- Engine: `E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe`
- Mode: `--headless --rendering-driver dummy`

## Commands

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_vehicle_world_model.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_vehicle_lane_graph.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_vehicle_query_chunk_contract.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_vehicle_intersection_turn_contract.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_vehicle_headway_contract.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_pedestrian_world_model.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_road_intersection_topology.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_world_generator.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/test_city_skeleton_smoke.gd'
```

## Verification Results

### M1 Vehicle Tests

| Test | Result |
|---|---|
| `test_city_vehicle_world_model.gd` | PASS |
| `test_city_vehicle_lane_graph.gd` | PASS |
| `test_city_vehicle_query_chunk_contract.gd` | PASS |
| `test_city_vehicle_intersection_turn_contract.gd` | PASS |
| `test_city_vehicle_headway_contract.gd` | PASS |

### Regression Checks

| Test | Result |
|---|---|
| `test_city_pedestrian_world_model.gd` | PASS |
| `test_city_road_intersection_topology.gd` | PASS |
| `test_city_world_generator.gd` | PASS |
| `test_city_skeleton_smoke.gd` | PASS |

## Scope Clarification

- 本留档只声明 `M1` 完成：`CityWorldGenerator` 已正式输出 `vehicle_query`，并且 `vehicle_query -> lane_graph -> turn contract` 已成为 shared road semantics 的新 consumer。
- 本留档不声明 `M2/M3` 已开始成立；当前还没有 layered traffic runtime、batched renderer、page cache、crosswalk yield 或 profiling redline 收口。
- `test_city_vehicle_headway_contract.gd` 只覆盖 deterministic spawn/headway contract，不代表近景运行时已经存在跟车求解。
