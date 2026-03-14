# V9 Closeout Verification Artifact

## Purpose

本文件用于把 `v9 vehicle hijack driving` 收口成单一真值，确认：

- 玩家可以把近景车辆打停，再按 `F` 接管并进入最小驾驶模式
- hijack 不会破坏 `vehicle_id / model_id` continuity，也不会把 ambient runtime 留下一辆重复车辆
- page cache / node budget / combined runtime redline 继续成立
- closeout 期间没有靠降 traffic density、关闭 vehicles/pedestrians 或放松阈值来过关

## Environment

- Date: `2026-03-15`
- Workspace: `E:\development\godot_citys`
- Branch: `main`
- Engine: `E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe`
- Mode: `--headless --rendering-driver dummy`

## Commands

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_vehicle_hijack_contract.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_vehicle_grenade_stop_contract.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_player_vehicle_drive_mode.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_player_combat.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_player_traversal.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_vehicle_page_cache.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_pedestrian_page_cache.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_vehicle_runtime_node_budget.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_vehicle_hijack_drive_flow.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_vehicle_performance_profile.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_runtime_performance_profile.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_first_visit_performance_profile.gd'
```

## Verification Results

### Functional / Contract

| Test | Result | Note |
|---|---|---|
| `test_city_vehicle_hijack_contract.gd` | PASS | projectile 命中近景车辆后进入 `stopped`，并保持 `vehicle_id` continuity |
| `test_city_vehicle_grenade_stop_contract.gd` | PASS | grenade 只截停 blast radius 内的近景车辆，不会全局冻结 traffic |
| `test_city_player_vehicle_drive_mode.gd` | PASS | 玩家 driving mode 会隐藏步行模型、挂载车辆模型并持续运动 |
| `test_city_player_combat.gd` | PASS | v9 没有打穿步行 combat contract |
| `test_city_player_traversal.gd` | PASS | v9 没有打穿步行 traversal contract |
| `test_city_vehicle_page_cache.gd` | PASS | 车辆 page cache / page reuse contract 仍成立，`page_build_counts` 仍可追踪 |
| `test_city_pedestrian_page_cache.gd` | PASS | 行人 page cache / page reuse contract 仍成立 |
| `test_city_vehicle_hijack_drive_flow.gd` | PASS | live flow 已证明 `截停 -> F 接管 -> 驾驶` 用户流程打通 |

### Performance Guard

| Test | Result | Fresh Evidence |
|---|---|---|
| `test_city_vehicle_runtime_node_budget.gd` | PASS | hijack / driving 没把 vehicle runtime 退回 node 海 |
| `test_city_vehicle_performance_profile.gd` | PASS | warm `traffic_update_avg_usec = 1082` / `traffic_render_commit_avg_usec = 331`；first-visit `traffic_update_avg_usec = 2828` / `traffic_render_commit_avg_usec = 280` / `update_streaming_avg_usec = 12392` |
| `test_city_runtime_performance_profile.gd` | PASS | `wall_frame_avg_usec = 8468` / `update_streaming_avg_usec = 7295` / `streaming_mount_setup_avg_usec = 3162` |
| `test_city_first_visit_performance_profile.gd` | PASS | `wall_frame_avg_usec = 14536` / `update_streaming_avg_usec = 13726` / `streaming_mount_setup_avg_usec = 4002` / `traffic_update_avg_usec = 3188` / `crowd_update_avg_usec = 3408` |

## Closeout Notes

- closeout 期间真正补的不是“更多玩法”，而是几处热路径浪费：
  - 车辆 cached-assignment 路径不再每帧做无意义的 distance sort。
  - 车辆 render snapshot 收口到渲染真正需要的字段，不再把 interaction/debug 字段带进每帧 chunk commit。
  - streamer 新增轻量 runtime summary，避免把 `page_build_counts` 这种诊断字段深拷贝进每帧 update，同时保留完整 snapshot 给 page-cache tests。
- 为了把 `first-visit` 拉回线内，`tier0 farfield pedestrians` 进一步降到更低频更新，并且不再对远景每一步做地表重采样；近景/中景贴地与玩法链路未被回退。
- 本轮没有放松任何 profiling threshold，也没有降低交通或行人密度；`Tier 1` 车辆依然保持非交互，仅 `Tier 2 / Tier 3` 进入 hijack 玩法层。
