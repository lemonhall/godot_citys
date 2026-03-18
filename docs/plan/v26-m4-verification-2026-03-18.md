# V26 M4 Verification 2026-03-18

验证日期：`2026-03-18`（Asia/Shanghai）

## Scope

本次 verification 覆盖 `v26 M1-M4` 全链：

- `scene_minigame_venue` registry/runtime 与 `chunk_129_139` mount chain
- 足球场馆 manifest / scene / playable floor / goal volumes / scoreboard
- `goal_scored / out_of_bounds / resetting` 回合状态与同球 reset loop
- `ambient_simulation_freeze` 对 crowd / ambient traffic 的冻结与 release hysteresis
- 受影响旧链回归：`v25` 足球交互、`v24` radio quick overlay / quick switch、`v21` landmark mount
- profiling 三件套：`chunk setup -> first-visit -> warm runtime`

## Environment

- Workspace: `E:\development\godot_citys`
- Engine: `E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe`
- Mode: `--headless --rendering-driver dummy`

## Verification Commands

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
$tests=@(
  'res://tests/world/test_city_scene_minigame_venue_registry_runtime.gd',
  'res://tests/world/test_city_soccer_minigame_venue_manifest_contract.gd',
  'res://tests/world/test_city_soccer_pitch_play_surface_contract.gd',
  'res://tests/world/test_city_soccer_goal_detection_contract.gd',
  'res://tests/world/test_city_soccer_scoreboard_contract.gd',
  'res://tests/world/test_city_soccer_scoreboard_visual_contract.gd',
  'res://tests/world/test_city_soccer_ball_reset_contract.gd',
  'res://tests/world/test_city_soccer_venue_ambient_freeze_contract.gd',
  'res://tests/world/test_city_soccer_venue_ambient_freeze_hysteresis_contract.gd',
  'res://tests/world/test_city_soccer_venue_radio_survives_ambient_freeze.gd',
  'res://tests/world/test_city_soccer_ball_kick_contract.gd',
  'res://tests/e2e/test_city_soccer_ball_interaction_flow.gd',
  'res://tests/e2e/test_city_soccer_minigame_goal_flow.gd',
  'res://tests/world/test_city_vehicle_radio_quick_overlay_contract.gd',
  'res://tests/e2e/test_city_vehicle_radio_quick_switch_flow.gd',
  'res://tests/e2e/test_city_scene_landmark_mount_flow.gd',
  'res://tests/world/test_city_chunk_setup_profile_breakdown.gd',
  'res://tests/e2e/test_city_first_visit_performance_profile.gd',
  'res://tests/e2e/test_city_runtime_performance_profile.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

## Functional Results

### M1 minigame venue mount chain

- `PASS` `test_city_scene_minigame_venue_registry_runtime.gd`
- `PASS` `test_city_soccer_minigame_venue_manifest_contract.gd`

结论：

- `scene_minigame_venue` family 已正式接入
- `venue:v26:soccer_pitch:chunk_129_139` 能按 registry / manifest / scene path 一致口径被挂载
- `primary_ball_prop_id = prop:v25:soccer_ball:chunk_129_139` 保持正式绑定

### M2 pitch / goals / scoring

- `PASS` `test_city_soccer_pitch_play_surface_contract.gd`
- `PASS` `test_city_soccer_goal_detection_contract.gd`
- `PASS` `test_city_soccer_scoreboard_contract.gd`
- `PASS` `test_city_soccer_scoreboard_visual_contract.gd`

结论：

- 球场使用 venue-owned `PlayableFloor`，不是把 terrain 假装成比赛地面
- 两侧球门、goal volume、score state 与大型场边计分板全部正式存在
- 合法入门方向计分、背后穿门不计分、同一 goal hit 不会重复累加

### M3 reset / ambient freeze / e2e

- `PASS` `test_city_soccer_ball_reset_contract.gd`
- `PASS` `test_city_soccer_venue_ambient_freeze_contract.gd`
- `PASS` `test_city_soccer_venue_ambient_freeze_hysteresis_contract.gd`
- `PASS` `test_city_soccer_venue_radio_survives_ambient_freeze.gd`
- `PASS` `test_city_soccer_ball_kick_contract.gd`
- `PASS` `test_city_soccer_ball_interaction_flow.gd`
- `PASS` `test_city_soccer_minigame_goal_flow.gd`

结论：

- “进场 -> 踢球 -> 进球/出界 -> 记分/重置 -> 再开球”整链已打通
- `ambient_simulation_freeze` 只冻结 crowd / ambient traffic，不走 `world_simulation_pause`
- radio 在 ambient freeze 期间保持播放
- reset 仍然复用正式 `v25` 足球 prop，不生成隐藏比赛球

## Guard Regression

- `PASS` `test_city_vehicle_radio_quick_overlay_contract.gd`
- `PASS` `test_city_vehicle_radio_quick_switch_flow.gd`
- `PASS` `test_city_scene_landmark_mount_flow.gd`

结论：

- `v24` radio quick overlay / quick switch 旧链未被 `ambient_simulation_freeze` 破坏
- `v21` landmark mount chain 未被 `scene_minigame_venue` 新 family 回归打穿

## Performance Guard

### Chunk Setup

- `PASS` `test_city_chunk_setup_profile_breakdown.gd`

关键结果：

- `total_usec = 2690`
- `ground_usec = 473`
- `buildings_usec = 1947`
- `props_usec = 9`
- `proxies_usec = 92`

### First Visit

- `PASS` `test_city_first_visit_performance_profile.gd`

关键结果：

- `streaming_mount_setup_avg_usec = 5315`
- `update_streaming_avg_usec = 14022`
- `wall_frame_avg_usec = 16409`

### Warm Runtime

- `PASS` `test_city_runtime_performance_profile.gd`

关键结果：

- `streaming_mount_setup_avg_usec = 2991`
- `update_streaming_avg_usec = 6251`
- `wall_frame_avg_usec = 9664`

## Implementation Notes

- 为了处理“world 仍有 terrain 系统”对足球玩法的污染，足球与 `PlayableFloor` 现在走专用 collision island；球场内的正式比赛面不再和底层 terrain / road collision 互相打架。
- `kickoff_ball_offset` 现在只接受“可信测量”，否则回退到冻结的球心高度偏移，避免物理漂移把 reset 锚点污染成错误位置。
- `SoccerMinigameVenue.gd` 已收敛成一次性 layout build，并共享 box mesh / shape / material 资源，避免每次 mount 重复分配同类资源，恢复 profiling guard。

## Closeout

- `v26 M1-M4` 已有 fresh 自动化证据
- 当前 `v26` 可视为基础版足球场馆 closeout：范围仍严格限定在场馆基础设施、比分/重置、ambient freeze 与 guard verification
- `11v11`、AI 球员、裁判、完整比赛规则仍然不在本文件 closeout 范围内
