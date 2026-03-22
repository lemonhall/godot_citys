# V38 Post-Closeout Lake Lab Scene-First Authoring Verification 2026-03-22

> 注意：本 artifact 仅覆盖当时的 lab scene-first 回收工作。fishing 入口语义已在 `ECN-0028` 与 [v38-post-closeout-fishing-pole-interaction-verification-2026-03-22.md](./v38-post-closeout-fishing-pole-interaction-verification-2026-03-22.md) 中被后续 closeout 正式改写；其中涉及 `MatchStartRing` 的 fishing 入口描述不再是当前口径。

## Scope

上一轮 [v38-post-closeout-lake-lab-bugfix-verification-2026-03-22.md](./v38-post-closeout-lake-lab-bugfix-verification-2026-03-22.md) 已经修掉了两条真实功能缺口：

- 湖盆不再是平盒子，水面/地面 fighting 被消除
- 玩家入水后可以自然下潜，`Space` 可以上浮

但用户随后指出，`LakeFishingLab` 仍然违反了 scene-first authoring 的冻结口径，主要有两层问题：

- `LakeFishingLab.gd` 仍然在运行时硬造湖盆、水面和 green ring，而不是把这些静态可视内容 author 到 scene
- 即使把静态节点写进了 `.tscn`，如果继续把整套 lab 摆在正式世界坐标 `(~2834, ~11546)`，Godot 编辑器打开时依然会像一张“空荒野”地图，无法像 `v37` 那样在原点附近直接看到地面、湖面、钓鱼平台和起始绿圈

本轮目标是把 `LakeFishingLab` 收回到真正的 scene-first authoring：

- scene 拥有湖盆 mesh/collision、水面 mesh、钓鱼平台和 `MatchStartRing`
- `LakeFishingLab.gd` 只保留 runtime state / HUD / fish / fishing 更新
- lab 在编辑器里以**本地原点附近**的 authoring 坐标呈现，而 shared lake contract 继续维持正式 `v38` 世界坐标真源

## Code Delta

- 新增 `tools/scene_preview/export_v38_lake_fishing_lab_static_assets.gd`
  - 从正式 `region:v38:fishing_lake:chunk_147_181` lake contract 导出 `LakeFishingLab` 静态 ground mesh / concave shape / localized water surface mesh
  - 导出产物落在 `city_game/scenes/labs/generated/`
- 新增静态资源
  - `city_game/scenes/labs/generated/lake_fishing_lab_ground_mesh.res`
  - `city_game/scenes/labs/generated/lake_fishing_lab_ground_shape.res`
  - `city_game/scenes/labs/generated/lake_fishing_lab_water_surface_mesh.res`
- 修改 `city_game/scenes/labs/LakeFishingLab.tscn`
  - `GroundBody` / `CollisionShape3D` / `MeshInstance3D` / `LakeRoot/WaterSurface/SurfaceMesh` 变为正式 scene-authored 静态层级
  - lab authoring 原点收回到平台附近：
    - `VenueRoot = (0, 0, 0)`
    - `Player = (0, 1.1, 8)`
    - `GroundBody = (5, 0, -39)`
- 修改 `city_game/scenes/labs/LakeFishingLab.gd`
  - 删除运行时重建湖盆/水面的逻辑
  - 新增 lab local `<->` formal lake world origin 映射，使 editor authoring 坐标留在原点附近，而水体观察/下潜仍继续消费正式 lake runtime
  - 为 lab fishing runtime 提供 localized fish school adapter，保证 `bite_zone` 与 fish school 继续在同一坐标系下匹配
- 修改 `city_game/serviceability/minigame_venues/generated/venue_v38_lakeside_fishing_chunk_147_181/lake_fishing_minigame_venue.tscn`
  - `MatchStartRing` 变为正式 scene-authored 节点
- 修改 `city_game/serviceability/minigame_venues/generated/venue_v38_lakeside_fishing_chunk_147_181/LakeFishingMinigameVenue.gd`
  - 删除 `CityWorldRingMarker.new()` fallback
  - script 改为只解析/同步 scene 里 author 的 ring
- 修改 `city_game/world/navigation/CityWorldRingMarker.gd`
  - 改为 `@tool`
  - 支持 scene-authoring 的 `marker_theme_id` / `marker_radius_m`
  - `_ready()` 保留 authored `visible`，让 ring 在编辑器里可预览
- 修改回归测试
  - `tests/world/test_city_lake_lab_scene_contract.gd`
    - 要求 `GroundBody` / `SurfaceMesh` / `MatchStartRing` 真实写在 scene 文本里
    - 新增“lab 内容必须靠近编辑器原点”的回归断言
  - `tests/world/test_city_lake_lab_observer_contract.gd`
  - `tests/world/test_city_lake_lab_water_traversal_contract.gd`
    - teleport 常量改为 lab 本地 authoring 坐标

## Verification

执行：

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

& $godot --headless --rendering-driver dummy --path $project --quit
& $godot --headless --rendering-driver dummy --path $project --script 'res://tools/scene_preview/export_v38_lake_fishing_lab_static_assets.gd'

$tests=@(
  'res://tests/world/test_city_lake_lab_scene_contract.gd',
  'res://tests/world/test_city_lake_lab_observer_contract.gd',
  'res://tests/world/test_city_lake_lab_water_traversal_contract.gd',
  'res://tests/world/test_city_fishing_venue_cast_loop_contract.gd',
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
| project parse | PASS | `--quit` 通过，scene/script/resource 可正常加载 |
| static asset export | PASS | exporter 成功输出 localized water mesh，并确认 `ground_body_local_position = (5, 0, -39)` |
| lab scene-first contract | PASS | `GroundBody` / `SurfaceMesh` / `MatchStartRing` 均为 scene-authored；`Player` 与 `VenueRoot` 已收回编辑器原点附近 |
| lab water observer | PASS | 本地 authoring 坐标下仍能进入 formal lake region，并保持 `region_id = region:v38:fishing_lake:chunk_147_181` |
| lab water traversal | PASS | 下潜/上浮链未因 local `<->` formal 映射回退 |
| lab fishing cast loop | PASS | localized fish school adapter 仍能正确选中 bite/catch school |
| lab fishing e2e | PASS | 进圈 -> 坐下 -> 抛竿 -> bite -> catch -> reset 整链继续通过 |
| main-world port | PASS | 主世界 fishing venue / HUD / interaction 主链未回退 |
| main-world fishing e2e | PASS | local lab authoring 收口没有污染正式主世界入口 |

## Notes

- 本轮关注的是 lab authoring ownership 与 editor 可见性，不是 shared runtime 性能修复，因此**没有新增 profiling 过线声明**
- 这份 artifact 证明的是：
  - `LakeFishingLab` 现在确实是 scene-first
  - 打开 scene 时可以在原点附近直接看到正式 lake basin / water surface / dock / start ring
  - shared lake/fishing runtime 仍然没有从 formal `v38` contract 上分叉
