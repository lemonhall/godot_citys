# V28 M6 Verification - 2026-03-19

## Status Note

- 本文记录 `v28` 在 `2026-03-19` 针对“tennis ball third-person readability / impact feedback”增强之后的 fresh verification。
- 这一轮 touch 到了：
  - `city_game/serviceability/interactive_props/generated/prop_v28_tennis_ball_chunk_158_140/TennisBallProp.gd`
  - `tests/world/test_city_tennis_ball_feedback_contract.gd`
  - `docs/prd/PRD-0018-tennis-singles-minigame.md`
  - `docs/plan/v28-index.md`
  - `docs/plan/v28-tennis-singles-minigame.md`
- 核心目标不是改动网球规则，而是补齐 third-person 可读性 cue：
  - glow shell
  - motion trail
  - impact audio

## Scope

- fresh parse / contract / e2e rerun
- soccer 关键回归
- ordered profiling three-piece rerun

## Commands

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

& $godot --headless --rendering-driver dummy --path $project --quit

$tests=@(
  'res://tests/world/test_city_tennis_minigame_venue_manifest_contract.gd',
  'res://tests/world/test_city_tennis_ball_prop_manifest_contract.gd',
  'res://tests/world/test_city_tennis_ball_feedback_contract.gd',
  'res://tests/world/test_city_tennis_court_geometry_contract.gd',
  'res://tests/world/test_city_tennis_match_start_contract.gd',
  'res://tests/world/test_city_tennis_runtime_aggregate_contract.gd',
  'res://tests/world/test_city_tennis_ai_return_contract.gd',
  'res://tests/world/test_city_tennis_ai_pressure_error_contract.gd',
  'res://tests/world/test_city_tennis_scoring_contract.gd',
  'res://tests/world/test_city_tennis_reset_on_exit_contract.gd',
  'res://tests/e2e/test_city_tennis_singles_match_flow.gd',
  'res://tests/e2e/test_city_soccer_minigame_goal_flow.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}

& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_chunk_setup_profile_breakdown.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_first_visit_performance_profile.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_runtime_performance_profile.gd'
```

## Fresh Results

### 1. Parse / Functional Regressions

- Parse check:
  - `--quit`
  - exit `0`
- Fresh passing tests:
  - `test_city_tennis_minigame_venue_manifest_contract.gd`
  - `test_city_tennis_ball_prop_manifest_contract.gd`
  - `test_city_tennis_ball_feedback_contract.gd`
  - `test_city_tennis_court_geometry_contract.gd`
  - `test_city_tennis_match_start_contract.gd`
  - `test_city_tennis_runtime_aggregate_contract.gd`
  - `test_city_tennis_ai_return_contract.gd`
  - `test_city_tennis_ai_pressure_error_contract.gd`
  - `test_city_tennis_scoring_contract.gd`
  - `test_city_tennis_reset_on_exit_contract.gd`
  - `test_city_tennis_singles_match_flow.gd`
  - `test_city_soccer_minigame_goal_flow.gd`

### 2. Chunk Setup

- Command:
  - `res://tests/world/test_city_chunk_setup_profile_breakdown.gd`
- Result:
  - `PASS`
- Key profile:
  - `total_usec = 2874`
  - `ground_mask_cache_hit = true`
  - `ground_runtime_page_hit = true`

### 3. First Visit

- Command:
  - `res://tests/e2e/test_city_first_visit_performance_profile.gd`
- Result:
  - `FAIL`
- Fresh fail sample A:
  - `streaming_mount_setup_avg_usec = 6175`
  - `update_streaming_avg_usec = 16203`
  - `wall_frame_avg_usec = 19656`
- Fresh fail sample B:
  - `streaming_mount_setup_avg_usec = 5310`
  - `update_streaming_avg_usec = 13736`
  - `wall_frame_avg_usec = 16892`
- Interpretation:
  - 这不是单一阈值的偶发一次越线，而是 first-visit 当前在不同 rerun 中会踩中不同 guard，表现为 cold-path 不稳定。

### 4. Warm Runtime

- Command:
  - `res://tests/e2e/test_city_runtime_performance_profile.gd`
- Result:
  - `FAIL`
- Key profile:
  - `streaming_mount_setup_avg_usec = 3486`
  - `update_streaming_avg_usec = 7518`
  - `wall_frame_avg_usec = 12864`
  - `hud_refresh_avg_usec = 2081`
- Interpretation:
  - warm runtime 当前主要失守在 `wall_frame_avg_usec`，不是 mount/setup 或 update_streaming 平均值。

## Interpretation

- 这轮针对 tennis ball readability / impact feedback 的功能链路是绿的：
  - 新增 ball feedback contract 已通过
  - tennis 核心 contract / e2e 继续通过
  - soccer 关键 e2e 回归继续通过
- 但 ordered profiling three-piece 没有完全收口：
  - `chunk setup`: green
  - `first-visit`: red
  - `warm runtime`: red
- 从本轮改动范围看，新增代码只落在 tennis ball authored prop 与对应测试/文档；而 profiling 失败的 warm / first-visit 采样走的是默认世界 traversal corridor，不依赖 `chunk_158_140` 网球场馆被 mount。
- 因此，这轮没有证据表明 tennis ball feedback enhancement 是当前 profiling 红线的直接根因；但同样没有 fresh 证据允许把 `v28` 的 closeout 说成绿。

## Closeout Call

- 功能口径：
  - green
- profiling 口径：
  - blocked
- 结论：
  - `v28` 这轮 ball readability / impact feedback enhancement 已完成并有 fresh functional evidence
  - `v28` 的 profiling closeout 当前不能宣称通过，仍需后续单独处理 first-visit / warm runtime redline
