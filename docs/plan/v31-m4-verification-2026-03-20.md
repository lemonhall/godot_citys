# V31 M4 Verification 2026-03-20

## Scope

- `addons/scene_preview` editor plugin
- editor eligibility / session builder 服务
- `v30` harness 复用链
- `Missile Command` 真实 preview subject 回归

## Commands

1. PRD / plan traceability

```powershell
rg -n "REQ-0021" docs/prd/PRD-0021-scene-preview-editor-plugin.md docs/plan/v31-index.md docs/plan/v31-scene-preview-editor-plugin.md
```

结果：命中 `REQ-0021-001..005`，`PRD-0021 -> v31 plan -> v31 index` 追溯链存在。

2. Editor plugin load smoke

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
& $godot --editor --headless --rendering-driver dummy --path $project --quit
```

结果：退出码 `0`。Godot 完成插件初始化与 editor layout 加载。

3. V31 contracts + v30/missile regressions

```powershell
$tests=@(
  'res://tests/world/test_scene_preview_editor_plugin_manifest_contract.gd',
  'res://tests/world/test_scene_preview_editor_session_builder_contract.gd',
  'res://tests/world/test_scene_preview_editor_preview_request_contract.gd',
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

结果：10 条测试全部 `PASS`。

## Notes

- `test_scene_preview_editor_preview_request_contract.gd` 在 dummy renderer 下退出时仍会打印 imported missile preview snapshot 的 RID/resource leak 警告，但退出码保持 `0`，且不影响功能合同断言通过。
- `--editor --headless` 输出里还存在两条 editor theme `dummy_color` 警告，以及 `refs/citygen-godot` 嵌套 `project.godot` 的目录忽略提示；这些是现有仓库/editor 环境噪音，不是 `v31` 插件加载失败。

## Result

- M0 docs freeze：done
- M1 session builder：done
- M2 plugin shell：done
- M3 editor play flow：done
- M4 regression：done

`v31` 已把 `v30` 的 preview 主链提升为 editor 内的一键入口：打开 3D 场景后，插件负责当前编辑态 snapshot、临时 wrapper 与正式 harness 播放链，且 `v30`/Missile Command 既有主链保持通过。
