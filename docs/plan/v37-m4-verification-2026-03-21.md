# V37 M4 Verification 2026-03-21

## Scope

本次验证覆盖 `v37 helicopter gunship encounter` 的正式主世界接入收口：

- `chunk_101_178` 正式任务圈接入共享 `v14` task runtime
- `encounter event -> task completed -> repeatable reset -> fresh re-entry`
- 主世界 closeout 与 lab 保持一致：
  - 空爆
  - 坠落
  - crash cleanup 完成后才返绿圈
- full-map task pin 使用正式 `helicopter` 图标

## Command

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
$tests=@(
  'res://tests/world/test_city_task_helicopter_gunship_event_completion.gd',
  'res://tests/world/test_city_task_helicopter_gunship_repeatable_reset.gd',
  'res://tests/world/test_city_task_helicopter_gunship_pin_contract.gd',
  'res://tests/e2e/test_city_task_helicopter_gunship_flow.gd',
  'res://tests/world/test_city_task_runtime_state_machine.gd',
  'res://tests/world/test_city_task_trigger_start_contract.gd',
  'res://tests/world/test_city_task_world_ring_marker_contract.gd',
  'res://tests/world/test_city_task_route_hides_destination_world_marker.gd',
  'res://tests/world/test_city_task_map_tab_contract.gd',
  'res://tests/world/test_city_task_pin_projection.gd',
  'res://tests/e2e/test_city_task_start_flow.gd',
  'res://tests/world/test_city_helicopter_gunship_lab_scene_contract.gd',
  'res://tests/world/test_city_helicopter_gunship_lab_completion_cleanup_contract.gd',
  'res://tests/world/test_city_helicopter_gunship_lab_repeatable_combat_contract.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

## Result

| Test | Result | Notes |
|---|---|---|
| `tests/world/test_city_task_helicopter_gunship_event_completion.gd` | PASS | 主世界任务使用 `completion_mode = event`，击落即完成任务链 |
| `tests/world/test_city_task_helicopter_gunship_repeatable_reset.gd` | PASS | `completed -> available` 可重复重置，且必须重新出圈再进圈 |
| `tests/world/test_city_task_helicopter_gunship_pin_contract.gd` | PASS | full map 正式显示 `icon_id = helicopter`，UI glyph = `🚁` |
| `tests/e2e/test_city_task_helicopter_gunship_flow.gd` | PASS | 主世界整链：tracking -> start ring -> gunship -> takedown -> crash closeout -> reset -> second run |
| `tests/world/test_city_task_runtime_state_machine.gd` | PASS | 任务状态机基础 contract 未回退 |
| `tests/world/test_city_task_trigger_start_contract.gd` | PASS | start trigger / active objective 主链未回退 |
| `tests/world/test_city_task_world_ring_marker_contract.gd` | PASS | shared world ring family 未分叉；tracked available gunship 也能投 start ring |
| `tests/world/test_city_task_route_hides_destination_world_marker.gd` | PASS | task route 仍会隐藏通用 destination world marker |
| `tests/world/test_city_task_map_tab_contract.gd` | PASS | full map task panel / task selection contract 未回退 |
| `tests/world/test_city_task_pin_projection.gd` | PASS | task pin projection 仍走共享 runtime projection |
| `tests/e2e/test_city_task_start_flow.gd` | PASS | 普通 task 起始/完成主链未被 v37 回归破坏 |
| `tests/world/test_city_helicopter_gunship_lab_scene_contract.gd` | PASS | lab 独立场景 contract 仍通过 |
| `tests/world/test_city_helicopter_gunship_lab_completion_cleanup_contract.gd` | PASS | lab closeout cleanup / repeatable reset 仍通过 |
| `tests/world/test_city_helicopter_gunship_lab_repeatable_combat_contract.gd` | PASS | lab 空战行为、survivability、空爆坠落链仍通过 |

## Notes

- 本轮 headless 验证中仍观察到 `CityHelicopterGunship.tscn` 的两条 `ext_resource invalid UID` warning，但所有受影响测试均 `PASS`，运行时使用 path fallback 成功加载资源。
- 某些 lab 测试在退出时仍出现 `ObjectDB instances leaked at exit` / `1 resources still in use at exit` warning；本轮验证 exit code 仍为 `0`，未阻断 closeout 口径。
