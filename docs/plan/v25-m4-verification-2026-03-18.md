# V25 M4 Verification 2026-03-18

## Scope

本次验证覆盖 `ECN-0024` 引入的 oversized 足球尺寸 rebaseline：

- 足球 manifest 从真实尺寸重基线到 oversized 玩法尺寸
- `scene_root_offset` 同步抬高，确保不埋地
- 视觉 envelope、kick 行为与 `E` 键主交互继续成立
- NPC prompt / dialogue 旧链不回退

## Frozen Values

- `target_diameter_m = 1.20`
- `scene_root_offset = Vector3(0.0, 0.60, 0.0)`

## Verification Commands

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_scene_interactive_prop_registry_runtime.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_soccer_ball_manifest_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_soccer_ball_visual_envelope.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_soccer_ball_kick_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_soccer_ball_interaction_flow.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_npc_interaction_prompt_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_dialogue_runtime_contract.gd'
```

结果：全部 `PASS`

## Observations

- 足球 authored anchor 仍然保留用户给定的 ground probe：
  - `world_position = (-1877.94, 2.52, 618.57)`
- 运行时尺寸已经不再冻结为 `0.22m` 的真实足球，而是冻结为明显更大的玩法尺寸。
- 视觉 envelope 测试确认 mounted 足球直径进入新的 `1.10m ~ 1.45m` 区间。
- `scene_root_offset.y = 0.60` 后，visual bottom 仍贴近 ground anchor，没有因为放大而埋地。
- kick contract 与 e2e flow 继续通过，说明放大没有把交互链打坏。
- NPC prompt 与 dialogue contract 回归继续通过，说明 primary interaction 合流没有被此次尺寸修正破坏。
