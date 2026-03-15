# V12 M4 Verification Artifact

## Purpose

本文件用于确认 `v12 / M4 Full Map / Minimap / HUD / Pins` 已完成 fresh closeout，重点验证：

- `M` 全屏地图可打开/关闭，并暂停 3D 世界 simulation
- 地图点击会生成正式 destination target，而不是 UI 临时点
- minimap / HUD / full map / pin registry 共享同一 `resolved_target + route_result`

## Environment

- Date: `2026-03-15`
- Workspace: `E:\development\godot_citys`
- Branch: `main`
- Engine: `E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe`
- Mode: `--headless --rendering-driver dummy`

## Commands

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_full_map_pause_contract.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_map_destination_contract.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_map_pin_overlay.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_minimap_navigation_hud.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_map_destination_selection_flow.gd'
```

## Verification Results

| Test | Result | Note |
|---|---|---|
| `test_city_full_map_pause_contract.gd` | PASS | full map 打开后 `player / generated_city / chunk_renderer` 被单独停用，未粗暴暂停整棵树 |
| `test_city_map_destination_contract.gd` | PASS | 地图点击会产出 `selection_mode / raw_world_anchor / resolved_target / route_request_target` |
| `test_city_map_pin_overlay.gd` | PASS | landmark + task pin 能共存，并同步到 full map / minimap overlay |
| `test_city_minimap_navigation_hud.gd` | PASS | HUD `navigation_state.route_id` 与 minimap route overlay 共用同一 active `route_result` |
| `test_city_map_destination_selection_flow.gd` | PASS | `打开地图 -> 选点 -> 关图` 后 route contract 保持有效 |

## Closeout Notes

- `M4` 明确采用“暂停 3D 世界 simulation，但地图 UI 保持交互”的 policy，没有使用 `SceneTree.paused = true` 的粗暴冻结。
- `pin registry` 已作为正式中间层落地，后续 task 系统可以直接复用，不需要再拆 UI。
