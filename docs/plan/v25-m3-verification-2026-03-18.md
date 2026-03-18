# V25 M3 Verification 2026-03-18

## Scope

本次验证覆盖：

- `scene_interactive_prop` registry/runtime 正式接入
- 足球 manifest / scene / asset 归置
- `E` 键 primary interaction 合流后的 kick 链路
- 受影响 NPC prompt / dialogue 旧链回归

## Verification Commands

### M0 docs freeze

```powershell
rg -n "REQ-0015" docs/prd/PRD-0015-soccer-ball-interactive-prop.md docs/plan/v25-index.md docs/plan/v25-soccer-ball-interactive-prop.md
```

结果：`PASS`

- `PRD-0015` 中存在 `REQ-0015-001` 到 `REQ-0015-004`
- `v25-index` 与 `v25` plan 已回链 `REQ-0015-*`

### M1 interactive prop mount chain

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_scene_interactive_prop_registry_runtime.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_soccer_ball_manifest_contract.gd'
```

结果：`PASS`

- registry/runtime 能读取 `prop:v25:soccer_ball:chunk_129_139`
- manifest / registry / scene path 口径一致
- 足球按 `chunk_129_139` 索引

### M2 kick interaction

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_soccer_ball_visual_envelope.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_soccer_ball_kick_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_soccer_ball_interaction_flow.gd'
```

结果：`PASS`

- 足球 near chunk mount 后可被实例化并可见
- HUD prompt 带 `E` 且明确“踢球”
- `handle_primary_interaction()` 返回 `kick`
- 踢球后球体位移和线速度显著增加
- driving mode 下道具交互被正确屏蔽

### M3 guard verification

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_npc_interaction_prompt_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_dialogue_runtime_contract.gd'
```

结果：`PASS`

- 主交互合流没有回退 NPC prompt owner contract
- 对话打开/关闭仍然正确占用和释放 `E` 键提示

## Notes

- 为了让移动后的足球资产不再引用仓库根目录旧路径，额外执行了一次 Godot 导入流程：

```powershell
& $godot --headless --editor --quit --path $project
```

- 该命令完成了足球 `glb/jpg` 的重新导入；输出中仍出现现有 `radio_backend.gdextension` 缺失告警，但不影响本次 `v25` 足球链路测试结果，后续 world/e2e 验证仍全部通过。
