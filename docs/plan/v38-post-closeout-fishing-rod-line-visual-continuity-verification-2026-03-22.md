# V38 Post-Closeout Fishing Rod-Line Visual Continuity Verification 2026-03-22

## Scope

本次 verification 针对 `v38` fishing pole 交互重构上线后暴露的一条真实视觉缺口：

- 玩家完成甩杆后，鱼竿可视会从短暂的 `cast_swing` 回落到默认 `carry` pose，导致“鱼竿像平放着”的观感
- 湖面上的鱼线虽然仍然存在，但持杆姿态没有继续保持压线状态，第三人称下会产生“鱼竿和鱼线分离了”的错觉

本轮目标不是改 fishing runtime 规则，也不是重做 lab authored scene，而是把已经存在的 `cast_out -> bite_ready` shared runtime 状态，正式同步到 player-held rod visual：

- 只要 `fishing_line_visible = true`，玩家手上的鱼竿就必须保持正式 `line_hold` pose
- `line_start_world_position` 必须继续锚在 held rod tip 附近
- lab 与主世界继续共享同一套 `CityFishingVenueRuntime.gd` 与 `FishingPoleEquippedVisual.gd`

## Root Cause

根因不是 fishing runtime 状态机错误，而是 visual continuity 数据链缺了一段：

- `FishingPoleEquippedVisual.gd` 原先只有 `carry` 与短时 `cast_swing`
- 甩杆动作播放结束后，可视会自动回到默认 `carry`
- `LakeFishingLab.gd` 与 `CityPrototype.gd` 没有把“当前鱼线仍然挂着、鱼漂仍在水面上”这条状态继续同步给 player-held rod visual

因此，真正需要补的是 shared visual state bridge，而不是单独在 lab 里再造一套钓鱼姿态逻辑。

## Code Delta

- 修改 `city_game/assets/minigames/fishing/props/FishingPoleEquippedVisual.gd`
  - 新增 `line_hold` base pose
  - 新增面向鱼漂目标点的 pitch / yaw 微调
  - `cast_swing` 结束后回到当前 base pose，而不是强制回 `carry`
  - 暴露 `line_pose_active` / `pose_name` / `tip_world_position` 给测试与上层同步链
- 修改 `city_game/scripts/PlayerController.gd`
  - 新增 `set_fishing_line_visual_state(active, target_world_position)`
  - 让 player-held rod visual 正式接受 line-engaged 状态
- 修改 `city_game/scenes/labs/LakeFishingLab.gd`
  - `_sync_player_fishing_state()` 继续同步 `fishing_line_visible` 与 `bobber_world_position`
- 修改 `city_game/scripts/CityPrototype.gd`
  - 主世界与 lab 保持相同的 player fishing visual 同步语义
- 修改 `tests/world/test_city_fishing_venue_cast_loop_contract.gd`
  - 新增 `line_hold` pose 与 rod-tip / line-start continuity 回归
  - 修正断言时序：等待若干帧后重新获取同一时刻的 runtime snapshot，再与 visual state 对比

## Verification

执行：

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

$tests=@(
  'res://tests/world/test_city_fishing_venue_cast_loop_contract.gd',
  'res://tests/world/test_city_fishing_pole_visual_contract.gd',
  'res://tests/world/test_city_lake_main_world_port_contract.gd',
  'res://tests/e2e/test_city_lake_lab_fishing_flow.gd',
  'res://tests/e2e/test_city_lake_fishing_flow.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

结果：

| Area | Result | Notes |
|---|---|---|
| lab cast loop contract | PASS | `cast_out` 后 player-held rod 会保持 `line_hold` pose，且 rod tip 与 runtime `line_start` continuity contract 成立 |
| pole visual contract | PASS | player-held rod wrapper scene 仍然存在，未破坏 authored asset chain |
| main-world port contract | PASS | 主世界同样同步 line-engaged visual state，没有回退成 lab-only 修复 |
| lab fishing e2e | PASS | lab 闭环继续可走通，visual continuity 修复未打断钓鱼链路 |
| main-world fishing e2e | PASS | 主世界复用同一套修复后的 runtime + visual bridge |

## Notes

- 额外 probe 显示：在 `cast_out` 后等待 `24` 帧，同一时刻下 `tip_world_position` 与 `line_start_world_position` 的距离为 `0.0`；先前失败来自测试拿了等待前的旧 runtime snapshot，而不是正式 runtime 仍然脱锚。
- 本轮修的是 player-held rod visual continuity，不涉及 streaming / terrain / profiling 热路径，因此没有新增 profiling 过线声明。
