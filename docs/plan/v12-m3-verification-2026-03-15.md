# V12 M3 Verification Artifact

## Purpose

本文件用于确认 `v12 / M3 Lane-Based Routing` 已完成 fresh closeout，重点验证：

- 正式 route planner 已切到 `vehicle_lane_graph_view`
- `route_result` contract 已具备 `polyline + steps + maneuvers + reroute_generation`
- reroute 与 runtime cache/memoization contract 已有自动化证据

## Environment

- Date: `2026-03-15`
- Workspace: `E:\development\godot_citys`
- Branch: `main`
- Engine: `E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe`
- Mode: `--headless --rendering-driver dummy`

## Commands

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_route_query_contract.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_route_reroute.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_route_result_cache.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_navigation_flow.gd'
```

## Verification Results

| Test | Result | Note |
|---|---|---|
| `test_city_route_query_contract.gd` | PASS | `route_result` 正式声明 `graph_source = vehicle_lane_graph_view`，并暴露 maneuver contract |
| `test_city_route_reroute.gd` | PASS | origin 改变后会生成新的 `route_id` 与递增的 `reroute_generation` |
| `test_city_route_result_cache.gd` | PASS | 重复同参查询命中 runtime route cache/memoization |
| `test_city_navigation_flow.gd` | PASS | 跨城导航已输出正式 `polyline / steps / maneuvers`，不再退回 chunk Manhattan |

## Closeout Notes

- `M3` 额外补了 raw-world-point origin fallback，解决玩家出生点附近 lane-node 不可达时的 route 空返回问题。
- 该 fallback 只在正式 lane route 失败时触发，结果仍然是正式 `route_result`，没有回退成第二套路由器。
