# V39 M6 Verification 2026-03-23

## Scope

本次验证覆盖 spider 从“手调相位步态”切换到“reference-driven stepper”的增量：

- 参考实现来源冻结为 `PhilS94/Unity-Procedural-IK-Wall-Walking-Spider`
- spider debug state 明确暴露 `step_controller_id = reference_anchor_prediction_v1`
- stepping 主链改为：
  - step desire
  - tetrapod group gating
  - anchor + overshoot + prediction
  - arc stepping
- 继续保留当前 shared arthropod runtime 的 portability 资产，不改 lobster

## Command

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

& $godot --headless --rendering-driver dummy --path $project --quit
if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }

$tests=@(
  'res://tests/world/test_spider_crawler_reference_step_contract.gd',
  'res://tests/world/test_spider_crawler_leg_visual_contract.gd',
  'res://tests/world/test_spider_crawler_lab_scene_contract.gd',
  'res://tests/world/test_spider_crawler_lab_demo_contract.gd',
  'res://tests/world/test_spider_crawler_gait_contract.gd',
  'res://tests/world/test_spider_crawler_terrain_follow_contract.gd',
  'res://tests/e2e/test_spider_crawler_lab_flow.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

## Result

| Area | Result | Notes |
|---|---|---|
| reference step controller | PASS | spider debug state 现在暴露 `step_controller_id = reference_anchor_prediction_v1` |
| step prediction | PASS | 至少一条 active stepping leg 的 `step_goal_world_position` 会落在 `default_anchor_world_position` 前方，而不是直接贴回 anchor |
| arc stepping | PASS | stepping 期间 `display_foot_world_position` 与 `locked_foothold` 解耦，不再是立即瞬移 |
| spider focused suite | PASS | scene/demo/gait/terrain/e2e/visual/reference tests 全部 fresh 通过 |

## Notes

- 这轮是 spider-only reference alignment，不改 lobster gait。
- shared arthropod runtime 仍然保留，因此 future main-world portability contract 没被推翻。
- 如果下一轮用户仍然觉得“不像活物”，下一步不该再乱调参数，而应该继续往 `workspace exhaustion / 3-link leg proxy / body sway` 三个方向下钻。
