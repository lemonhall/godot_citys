# V21 M4 Verification Artifact

## Purpose

本文件记录 `v21` 在 `2026-03-17` 的 fresh verification，重点覆盖两件事：

- `ground_probe` 现在不仅返回 `world_position`，还会显式输出 `surface_y_m`，并把 `y=` 打到 HUD / clipboard，避免后续 authored landmark 摆放漏掉高程。
- 喷泉地标的 manifest / mount / visual envelope / full-map pin 口径已经统一到真实地表高度，不再停留在旧的 `y=0` 测试假设。

`v21` 的 profiling closeout 本轮没有被重新收口；`M4` 仍保持 `blocked`。

## Environment

- Date: `2026-03-17`
- Workspace: `E:\development\godot_citys`
- Branch: `main`
- Engine: `E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe`
- Mode: `--headless --rendering-driver dummy`

## Commands

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
$tests=@(
  'res://tests/world/test_city_ground_probe_inspection_contract.gd',
  'res://tests/world/test_city_player_laser_designator.gd',
  'res://tests/world/test_city_fountain_landmark_manifest_contract.gd',
  'res://tests/world/test_city_fountain_landmark_visual_envelope.gd',
  'res://tests/e2e/test_city_scene_landmark_mount_flow.gd',
  'res://tests/e2e/test_city_fountain_landmark_full_map_flow.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

## Verification Results

### Functional / Contract

| Test | Result | Note |
|---|---|---|
| `test_city_ground_probe_inspection_contract.gd` | PASS | `ground_probe` 现在显式暴露 `surface_y_m`，并要求其与 `world_position.y` 一致 |
| `test_city_player_laser_designator.gd` | PASS | ground hit 的 HUD focus message / clipboard 现在显式包含 `y=...`，方便人工复制高程 |
| `test_city_fountain_landmark_manifest_contract.gd` | PASS | 喷泉 manifest 的 `world_position.y` 固定为采样后的真实地表高度 `14.545391` |
| `test_city_fountain_landmark_visual_envelope.gd` | PASS | 喷泉视觉包围盒仍具可读体量，且 visual bottom 与 manifest 地表高度对齐 |
| `test_city_scene_landmark_mount_flow.gd` | PASS | `chunk_129_142` 进入 near range 后能挂载喷泉，离开后能 retire |
| `test_city_fountain_landmark_full_map_flow.gd` | PASS | full map 上继续显示 `fountain -> ⛲`，minimap 不泄漏 |

### Notes

- 本轮 headless 运行里，`fountain_landmark.tscn` 对 `Santo Spirito Fountain.glb` 的 ext_resource 报了 `invalid UID` warning，但 Godot 已自动 fallback 到文本路径并完成加载，功能测试未受影响。
- 这说明喷泉链当前的 blocker 已不在“是否挂载成功”，而是资源引用是否需要后续用编辑器再规范化一次。

### Performance Guard

| Test | Result | Note |
|---|---|---|
| `test_city_chunk_setup_profile_breakdown.gd` | not rerun | 本次 slice 只修 inspection 文案 contract 与喷泉测试常量，没有 fresh 重跑 profiling |
| `test_city_runtime_performance_profile.gd` | not rerun | `M4` 继续保持 blocked，不在本次 closeout 内宣称恢复 |
| `test_city_first_visit_performance_profile.gd` | blocked | `2026-03-17` 既有 fresh fail 仍是：`streaming_mount_setup_avg_usec = 5739`、`update_streaming_avg_usec = 18022` |

## Closeout Notes

- `ground_probe` 现在正式把“绝对高度”提升为 contract，而不是只把它埋在 `world_position` 的第二个分量里等人肉解析。
- 后续用户如果用激光指示器对着地面打点，只要把 HUD / clipboard 里的 `y=...` 一起给 AI，就不会再出现“x/z 对了、地标埋地了”的重复错误。
- `v21` 当前功能链可认为已覆盖 `M1-M3`；`M4` 仍旧因为 profiling 红线未收口而维持 `blocked`。
