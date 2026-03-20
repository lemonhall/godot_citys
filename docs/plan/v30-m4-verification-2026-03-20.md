# V30 M4 Verification 2026-03-20

## Scope

- `ScenePreviewHarness` 通用场景与控制脚本
- `generate_scene_preview_wrapper.gd` wrapper 生成命令
- `InterceptorMissileVisual` shared preview contract 迁移
- `InterceptorMissileVisualPreview.tscn` 真实 wrapper 样例
- `v29` Missile Command 受影响回归

## Commands

1. PRD / plan traceability

```powershell
rg -n "REQ-0020" docs/prd/PRD-0020-scene-preview-harness.md docs/plan/v30-index.md docs/plan/v30-scene-preview-harness.md
```

结果：命中 `REQ-0020-001..005`，`PRD-0020 -> v30 plan -> v30 index` 追溯链存在。

2. Godot headless import / parse

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
& $godot --headless --rendering-driver dummy --path $project --quit
```

结果：退出码 `0`。

3. V30 contracts + affected Missile Command regressions

```powershell
$tests=@(
  'res://tests/world/test_scene_preview_harness_contract.gd',
  'res://tests/world/test_scene_preview_wrapper_generator_contract.gd',
  'res://tests/world/test_scene_preview_subject_activation_contract.gd',
  'res://tests/world/test_city_missile_command_battery_contract.gd',
  'res://tests/world/test_city_missile_command_wave_contract.gd',
  'res://tests/world/test_city_missile_command_damage_contract.gd',
  'res://tests/e2e/test_city_missile_command_wave_flow.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

结果：7 条测试全部 `PASS`。

4. Wrapper CLI smoke

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tools/scene_preview/generate_scene_preview_wrapper.gd' -- --source 'res://city_game/assets/minigames/missile_command/projectiles/InterceptorMissileVisual.tscn' --output 'user://tests/scene_preview/CliGeneratedInterceptorPreview.tscn'
```

结果：输出 `Generated scene preview wrapper: user://tests/scene_preview/CliGeneratedInterceptorPreview.tscn`，退出码 `0`。

## Result

- M0 docs freeze：done
- M1 harness core：done
- M2 wrapper command：done
- M3 sample migration：done
- M4 regression：done

`v30` 已形成正式的 scene-first preview 主链：通用 harness、wrapper 生成命令、shared subject preview contract、真实 missile 样例与回归证据全部齐备。
