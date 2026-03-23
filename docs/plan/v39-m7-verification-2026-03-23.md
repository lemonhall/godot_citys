# V39 M7 Verification 2026-03-23

## Scope

本次验证覆盖 spider 第二轮 reference 对齐，也就是把 scheduler 从“phase window 选 A/B 组”继续收口到 `PhilS94/Unity-Procedural-IK-Wall-Walking-Spider` 的 `IKStepManager.AlternatingTetrapodGait()` 风格：

- spider debug state 现在明确暴露 `step_scheduler_id = reference_tetrapod_timer_v2`
- gait scheduler 现在维护显式的：
  - `active_step_group_id`
  - `next_group_switch_time`
  - `group_step_time_seconds`
  - `group_switch_count`
  - `step_clock_seconds`
- group 切换 cadence 改为 timer-based，而不是继续由 `gait_phase_duration_seconds` 的 phase window 决定
- 同一轮 tetrapod group 内真正起步的腿共享同一组 `group_step_time_seconds`
- 继续保留上一轮已经修掉的 body 瞬移 / 腿拉伸视觉稳定性

## Command

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

& $godot --headless --rendering-driver dummy --path $project --quit
if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }

$tests=@(
  'res://tests/world/test_spider_crawler_reference_scheduler_contract.gd',
  'res://tests/world/test_spider_crawler_reference_step_contract.gd',
  'res://tests/world/test_spider_crawler_body_target_stability_contract.gd',
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
| reference scheduler id | PASS | spider debug state 现在暴露 `step_scheduler_id = reference_tetrapod_timer_v2` |
| timer-based tetrapod cadence | PASS | `test_spider_crawler_reference_scheduler_contract.gd` 证明两次组切换之间的时间间隔跟随上一轮 `group_step_time_seconds`，而不是固定 phase half-window |
| shared group duration | PASS | 同一轮 scheduler group 内 active stepping legs 共享同一组 `step_duration_seconds` |
| body stability | PASS | `test_spider_crawler_body_target_stability_contract.gd` 继续通过，未回退到躯干瞬移 / 腿瞬时拉长 |
| spider focused suite | PASS | reference scheduler / reference step / body stability / leg visual / scene / demo / gait / terrain / e2e 全部 fresh 通过 |

## Notes

- 这轮仍然是 spider-only reference alignment，不改 lobster gait。
- 第二轮真正新增的不是“又调了一批参数”，而是把 reference repo 里最关键的 scheduler contract 也落到了当前仓库。
- 如果下一轮还要继续往“更像活物”推进，优先级应是：
  - 3-link spider proxy
  - 更真实的 body sway / centroid filtering
  - workspace exhaustion / IK error 驱动的 step desire
