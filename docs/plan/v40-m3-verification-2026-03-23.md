# V40 M3 Verification 2026-03-23

## Scope

本次 verification 只覆盖 `v40` 的 M1-M3：

- rifle muzzle flash
- invisible projectile body + smoke tracer
- faster / longer rifle ballistics
- spider lab shared consumer

`M4 regression + closeout` 不在本文件中宣称完成。

## Fresh Passed Tests

以下命令在 `2026-03-23` fresh 执行并通过：

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_player_rifle_vfx_and_ballistics.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_player_combat.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_combat_crosshair.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_player_grenade.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_player_missile_launcher.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_spider_crawler_lab_rifle_feedback_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_spider_crawler_lab_combat_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_spider_crawler_lab_combat_flow.gd'
```

## Result Summary

- `test_city_player_rifle_vfx_and_ballistics.gd`
  - 证明主世界步枪已有 formal muzzle flash getter、smoke tracer root、hidden projectile body、920/960 ballistic profile。
- `test_city_player_combat.gd`
  - 证明 live projectile 主链仍保持成立，没有因为 `v40` 视觉升级被打碎。
- `test_city_combat_crosshair.gd`
  - 证明 crosshair / aim target 主链未被 rifle 调整破坏。
- `test_city_player_grenade.gd`
  - 证明 grenade 主链继续通过。
- `test_city_player_missile_launcher.gd`
  - 证明 missile launcher 仍然通过，未被 rifle trace / FX 改动污染。
- `test_spider_crawler_lab_rifle_feedback_contract.gd`
  - 证明 spider lab 已复用同一 rifle muzzle flash / tracer / ballistic profile。
- `test_spider_crawler_lab_combat_contract.gd`
  - 证明 spider lab 里 rifle / grenade / laser / missile 的 formal combat contract 仍然成立。
- `test_spider_crawler_lab_combat_flow.gd`
  - 证明 spider lab 的实战流程仍能跑通。

## Known Unrelated Failure Encountered During Regression

以下测试在本轮额外执行时失败：

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_player_laser_designator.gd'
```

失败信息：

- `Laser designator contract requires at least one nearfield building target`

本轮额外边界定位结果：

- mounted `chunk_scene/NearGroup` 下没有任何 `StaticBody3D` building candidate
- 观测到的 `NearGroup` 只有：
  - `RoadOverlay`
  - `WaterSurfaces`
  - `LakeFishSchools`
  - `Props`
  - `SceneLandmarks`
  - `SceneMinigameVenues`
  - `SceneInteractiveProps`
- 因此该失败点当前表现为“测试对 nearfield building collider 结构的旧假设不再成立”，不是 `v40` rifle tracer / muzzle flash / spider lab 改动直接打坏的数据流证据

## Closeout Decision

- `v40 M1-M3`: 完成，可作为本次 rifle upgrade 的 fresh evidence
- `v40 M4 full regression closeout`: 暂不宣称完成，需另行处理 `laser designator` 的独立失败后再关
