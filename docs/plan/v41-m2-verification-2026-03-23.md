# V41 M2 Verification 2026-03-23

## Scope

本次 verification 覆盖 `v41` 的 M1-M3：

- 正式 rifle fire audio asset 归置
- Player held-fire single-start + manual restitch 语义
- release / weapon switch / control disable / drive-mode context exit stop 语义
- main-world / spider-lab world-side rifle emitter
- rifle / combat / spider lab focused regression

## Fresh Passed Tests

以下命令在 `2026-03-23` fresh 执行并通过：

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_player_rifle_audio_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_player_rifle_world_audio_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_player_rifle_vfx_and_ballistics.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_player_combat.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_player_grenade.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_player_missile_launcher.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_player_vehicle_drive_mode.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_spider_crawler_lab_rifle_audio_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_spider_crawler_lab_rifle_feedback_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_spider_crawler_lab_combat_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_spider_crawler_lab_combat_flow.gd'
```

## Result Summary

- `test_city_player_rifle_audio_contract.gd`
  - 证明正式 M4 长 burst WAV 已绑定到 rifle audio asset path。
  - 证明 PlayerController 本地音频 debug 节点不会再走 Godot WAV loop，也不会偷偷承担可闻播放。
- `test_city_player_rifle_world_audio_contract.gd`
  - 证明主世界 `CityPrototype` 已把 rifle 音频接入 `CombatRoot` 下的 dedicated world-side emitter，并沿 held-fire 语义只在进入时 start 一次、超过窗口后 manual restitch、release stop。
- `test_city_player_rifle_vfx_and_ballistics.gd`
  - 证明 `v40` 冻结的 rifle muzzle flash / smoke tracer / ballistic profile 没被 `v41` 音频接入打坏。
- `test_city_player_combat.gd`
  - 证明 rifle projectile combat 主链仍然成立。
- `test_city_player_grenade.gd`
  - 证明 grenade 主链未被污染。
- `test_city_player_missile_launcher.gd`
  - 证明 missile launcher 主链未被污染。
- `test_city_player_vehicle_drive_mode.gd`
  - 证明玩家 drive-mode 主链仍然成立，`v41` 的 weapon/audio state 清理没有把驾驶接管打坏。
- `test_spider_crawler_lab_rifle_audio_contract.gd`
  - 证明 `SpiderCrawlerLab` 也把 rifle 音频接入 `CombatRoot` 下的 dedicated world-side emitter，并沿 held-fire 语义只在进入时 start 一次、超过窗口后 manual restitch、release stop。
- `test_spider_crawler_lab_rifle_feedback_contract.gd`
  - 证明蜘蛛 lab 的 rifle 发射反馈链仍然保持 projectile / tracer / muzzle flash 合同，没有因为 world-side emitter 接入被打坏。
- `test_spider_crawler_lab_combat_contract.gd`
  - 证明 spider lab 的多武器 combat contract 继续通过。
- `test_spider_crawler_lab_combat_flow.gd`
  - 证明 spider lab 的实战流程继续通过。

## Closeout Decision

- `v41 M1-M3`: 完成，可作为本轮 rifle audio formalization 的 fresh evidence
- 当前没有在本轮 focused regression 中观察到新的失败
