# V38 Post-Closeout Lake Lab Bugfix Verification 2026-03-22

## Scope

本次 verification 针对 `v38` closeout 后暴露的两条真实缺口：

- `LakeFishingLab.tscn` 的湖盆 carrier 仍然是平盒子，导致水面与地面 carrier 共面/近共面，岸边出现 visual fighting，玩家也会像站在平地上一样“站在水上”
- `PlayerController.gd` 虽然已经接入 `lake_water_state` 观察，但并没有把它接进正式运动学，因此玩家无法自然下潜，`Space` 也没有上浮语义

本轮目标不是重做 `v38` 范围，而是把缺失的 shared layer `1/2` 补齐到和文档冻结口径一致：

- lab 继续消费正式 `terrain_region_feature -> lake runtime -> fish runtime`
- lab 的湖盆 carrier 来自 shared layer `2` 的正式 basin builder，而不是 `LakeFishingLab.gd` 本地手搓平盒子
- 玩家入水后进入高阻力水体运动，默认自然下沉，`Space` 上浮

## Code Delta

- 新增 `city_game/world/rendering/CityLakeBasinCarrierBuilder.gd`
  - 用 shared lake contract 生成 standalone basin ground mesh + concave collision
  - 用同一套 polygon/waterline 真源生成水面 mesh
- 修改 `city_game/scenes/labs/LakeFishingLab.gd`
  - 改为通过 `CityTerrainRegionFeatureRegistry.gd` + `CityTerrainRegionFeatureRuntime.gd` 取正式 `lake runtime`
  - lab ground carrier 改为消费 `CityLakeBasinCarrierBuilder.gd`
  - 水面 mesh 改为消费 shared builder，不再本地重写 triangulate 逻辑
- 修改 `city_game/scripts/PlayerController.gd`
  - `lake_water_state` 接进 `_physics_process()`
  - 入水后启用高阻力水体运动
  - 默认存在下沉速度，`Space`/synthetic vertical input 可上浮
- 新增回归测试
  - `tests/world/test_city_lake_basin_carrier_contract.gd`
  - `tests/world/test_city_lake_lab_water_traversal_contract.gd`

## Functional Verification

执行命令：

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
$tests=@(
  'res://tests/world/test_city_lake_water_surface_contract.gd',
  'res://tests/world/test_city_lake_swim_observer_contract.gd',
  'res://tests/world/test_city_lake_basin_carrier_contract.gd',
  'res://tests/world/test_city_lake_lab_scene_contract.gd',
  'res://tests/world/test_city_lake_lab_observer_contract.gd',
  'res://tests/world/test_city_lake_lab_water_traversal_contract.gd',
  'res://tests/world/test_city_lake_main_world_port_contract.gd',
  'res://tests/world/test_player_controller.gd',
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
| shared basin carrier | PASS | `test_city_lake_basin_carrier_contract.gd` 证明 standalone carrier 的 ray hit 与 shared bathymetry floor 对齐，不再停在 `y=0` 平盒顶面 |
| main-world water observer | PASS | `test_city_lake_swim_observer_contract.gd` 继续通过，主世界 `water/underwater` contract 未回退 |
| lab scene + observer | PASS | `LakeFishingLab.tscn` 继续能加载正式 player / lake / fish / venue，并保留 formal observer contract |
| lab water traversal | PASS | `test_city_lake_lab_water_traversal_contract.gd` 证明玩家会自然下潜，且 vertical input 可上浮 |
| lab fishing flow | PASS | `test_city_lake_lab_fishing_flow.gd` 继续通过，未因换 carrier/water movement 打断 minigame |
| main-world fishing flow | PASS | `test_city_lake_fishing_flow.gd` 继续通过，主世界 port 未分叉 |

## Real Render Check

额外使用真实渲染（非 headless）抓取 `LakeFishingLab.tscn` 实景截图，产物落在：

- `reports/v38/lake_lab_capture_2026-03-22.png`

观察结果：

- 湖盆已经是连续下切曲面，不再是整块平盒 carrier
- 水面与湖盆存在稳定高度分离，未再看到之前那种浅岸共面 fighting 的典型表现
- 玩家胶囊已位于水体内部，而不是停在整块平盒顶面

## Profiling Guard Rerun

由于本轮实际补到了 shared rendering-side lake carrier，按仓库规约补跑 profiling 三件套。

执行：

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_chunk_setup_profile_breakdown.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_first_visit_performance_profile.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_runtime_performance_profile.gd'
```

结果：

| Profile | Result | Notes |
|---|---|---|
| `test_city_chunk_setup_profile_breakdown.gd` | PASS | `total_usec = 691` |
| `test_city_first_visit_performance_profile.gd` | FAIL | fresh rerun 两次都高于红线：`wall_frame_avg_usec = 17535`、`19332` |
| `test_city_runtime_performance_profile.gd` | PASS | `wall_frame_avg_usec = 9462` |

说明：

- 本次 bugfix 的功能链和实渲染问题已经被修正
- 但 fresh `first-visit` profiling 在当前机器/当前仓库状态下未能维持 `<= 16.67ms` 的正式红线
- 因此这份 artifact 只证明“湖盆/入水体验 bug 已修”，**不宣称 profiling closeout 重新全绿**

## Conclusion

- `LakeFishingLab` 的“平盒子 + 假水面 + 站在水上”问题已被真实修掉
- 修复路径符合 `v38` 文档口径：补 shared layer `1/2`，让 lab 继续只做 consumer
- 玩家现在会自然下潜，`Space` 上浮
- profiling 三件套中仍残留 `first-visit` redline failure，需要单独性能轮次处理
