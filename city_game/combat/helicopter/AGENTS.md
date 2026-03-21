# Helicopter Combat Agent Notes

本文件只作用于 `city_game/combat/helicopter/` 及其子目录；若与仓库根 `AGENTS.md` 冲突，以本文件为准。

## Overview

- 本目录承载 `v37 helicopter gunship encounter` 的正式 scene-first 实现，不是一次性 lab 特效脚本区。
- 这里的核心目标是：`lab runtime` 与 `main-world runtime` 保持同一条遭遇战主链，只允许 wrapper 和接线不同，不允许行为分叉。

## Quick Commands

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
```

- 直升机场景 contract：

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_helicopter_gunship_scene_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_helicopter_gunship_weapon_audio_contract.gd'
```

- lab 回归：

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_helicopter_gunship_lab_scene_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_helicopter_gunship_lab_completion_cleanup_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_helicopter_gunship_lab_repeatable_combat_contract.gd'
```

- 主世界 task 回归：

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_task_helicopter_gunship_event_completion.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_task_helicopter_gunship_repeatable_reset.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_task_helicopter_gunship_pin_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_task_helicopter_gunship_flow.gd'
```

## Architecture

- `CityHelicopterGunship.tscn`
  - 正式炮艇 scene；视觉、命中盒、rotor blur、音频都应优先在 scene 内 author，而不是在脚本里临时造 mesh。
- `CityHelicopterGunship.gd`
  - 炮艇生命值、盘旋、无限导弹、风压扰动、空爆坠落、closeout 前的 crash sequence。
- `CityHelicopterGunshipEncounterRuntime.gd`
  - 共享遭遇战 runtime；负责 start/active/idle、spawn、敌方导弹根节点管理、completion/cleanup。
- `CityHelicopterGunshipWorldEncounter.tscn`
  - 主世界 wrapper；只负责把 shared runtime 接进 `CityPrototype` 的玩家与 combat roots。
- lab 场景：
  - `res://city_game/scenes/labs/HelicopterGunshipLab.tscn`
  - 允许 authoring 差异，但行为 contract 必须复用同一 encounter runtime。

## Code Style

- 继续遵守 scene-first：命中盒、rotor blur 位置、anchor、音频节点优先在 `.tscn` author。
- 视觉包装可以用少量 shader，但不要把“整架直升机的视觉存在”退回成纯脚本即时绘制。
- 新增资源如果 Godot 生成 `.uid` / `.import`，应一起提交，避免 `ext_resource invalid UID` warning 漫灌测试输出。

## Safety & Contracts

- 不要把 lab 和主世界拆成两套行为逻辑。
  - 为什么：数值、closeout、repeatable 行为会迅速漂移。
  - 替代：shared logic 留在 `CityHelicopterGunship.gd` 和 `CityHelicopterGunshipEncounterRuntime.gd`，主世界只做 wrapper 接线。
  - 验证：同时跑 lab 三条回归和主世界四条回归。

- 不要把“击落事件”和“绿圈重新出现”绑定成同一时刻。
  - 为什么：`v37` 已冻结为先空爆/坠落，再 cleanup，最后返绿圈；主世界与 lab 必须一致。
  - 替代：任务可在正式 defeat/completion event 时完成，但 repeatable reset 与返绿圈必须等 `encounter phase == idle`。
  - 验证：`test_city_helicopter_gunship_lab_repeatable_combat_contract.gd`、`test_city_task_helicopter_gunship_repeatable_reset.gd`、`test_city_task_helicopter_gunship_flow.gd`

- 不要给炮艇加玩家失败态或实际掉血。
  - 为什么：当前版本冻结为“敌方攻击只制造压力，不造成失败”。
  - 替代：敌方导弹继续复用 `CityMissile` scene，但 `explosion_damage = 0`，只保留相机震动/近失反馈。
  - 验证：lab repeatable combat contract 与主世界 flow contract

- 不要把主世界起始圈/地图图标做成 gunship-only 私有 UI 旁路。
  - 为什么：会破坏 `v14` 的 shared task pin / route / world ring 主链。
  - 替代：task definition 继续走 `task_catalog -> task_runtime -> CityTaskPinProjection / CityTaskWorldMarkerRuntime / CityMapScreen`
  - 验证：`test_city_task_helicopter_gunship_pin_contract.gd`、`test_city_task_world_ring_marker_contract.gd`

## Testing Rules

- 改 `CityHelicopterGunship.tscn`、命中盒、rotor blur、音频绑定时，至少跑：
  - `test_city_helicopter_gunship_scene_contract.gd`
  - `test_city_helicopter_gunship_weapon_audio_contract.gd`

- 改共享 encounter/runtime、坠落 cleanup、repeatable reset 时，至少跑：
  - `test_city_helicopter_gunship_lab_completion_cleanup_contract.gd`
  - `test_city_helicopter_gunship_lab_repeatable_combat_contract.gd`
  - `test_city_task_helicopter_gunship_event_completion.gd`
  - `test_city_task_helicopter_gunship_repeatable_reset.gd`
  - `test_city_task_helicopter_gunship_flow.gd`

- 改 task icon / map pin / world ring 接线时，至少补跑：
  - `test_city_task_helicopter_gunship_pin_contract.gd`
  - `test_city_task_world_ring_marker_contract.gd`
  - `test_city_task_route_hides_destination_world_marker.gd`
