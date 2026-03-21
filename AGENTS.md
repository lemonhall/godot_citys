# AGENTS.md

本文件是仓库级 AI/新人协作规约。它描述的是当前 `E:\development\godot_citys` 的工程现实，而不是抽象口号。

## 项目概览

### 项目摘要

- 本项目是一个 Godot `4.6` 的 `70km x 70km` low poly 城市运行时原型，目标是稳定的大世界流式体验，不是高模展示工程。
- 当前主线已经不只是 `v7` 的道路基础设施：仓库里已有 `v12` 的 `place_index / resolved_target / route_result / full map / minimap / fast travel / autodrive`，`v13` 的多中心城市形态与 PNG 验收链，`v14` 的任务 catalog/runtime/map pin/world ring/trigger 主链，以及后续的 `service building / scene landmark / interactive prop / authored minigame venue / radio / missile launcher / building collapse / v37 helicopter gunship encounter` 等正式增量。
- `v12`、`v13` 的 verification artifacts 已落在 `docs/plan/` 与 `reports/v13/`；`v14` 虽然代码和测试已经进仓库，但是否 closeout 仍必须以 fresh rerun 证据和新的 `docs/plan/v14-mN-verification-YYYY-MM-DD.md` 为准，不能只看旧文档的 `todo/done` 文字。

### 沟通约定

- 默认用中文与用户沟通：分析、计划、review、总结、提交说明都用中文。
- 只有代码标识符、文件名、命令、测试名必须保留时才写英文。
- 提到未来方向时，优先用中文：`交通标识系统`、`车辆系统`、`更丰富的行人系统`；如需对应英文，只在第一次出现时括号补充。

### 分支与工作区约定

- 本仓库默认直接在 `main` 上连续推进，不再默认创建或切换 `git worktree`。
- 除非用户在当前对话里明确要求隔离工作区，否则不要再使用 `using-git-worktrees` 工作流，也不要把某个 worktree 当作真实源码主线。
- 如果历史上遗留了本仓库的 worktree，以当前主工作目录 `E:\development\godot_citys` 为真源，避免出现“代码改在 worktree、游戏却从主目录运行”的错位。

### 文档与计划链

- `docs/prd/`：产品目标与范围基线。
- `docs/plans/`：设计稿、研究沉淀、实现前方案。
- `docs/plan/vN-*.md`：版本化执行计划、里程碑、verification artifacts 回链；这里才是 closeout 口径真源。
- `docs/ecn/`：范围变更、冻结口径变化、重规划说明。
- 如果你需要调整 DoD、冻结口径、性能红线、里程碑范围或“fully / 全套”的定义，先更新对应 `docs/plan/vN-index.md`，必要时补 `docs/ecn/`，再改代码；不要先改实现、最后再补文档。

## 快速命令

命令默认在 PowerShell 中执行。先统一两个变量：

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
```

- 项目导入/解析检查：

```powershell
& $godot --headless --rendering-driver dummy --path $project --quit
```

- 本地运行主场景：

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64.exe' --path $project
```

- 冒烟测试：

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/test_city_skeleton_smoke.gd'
```

- 单个 world 测试模板：

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/<test-name>.gd'
```

- 单个 e2e 测试模板：

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/<test-name>.gd'
```

- `v12` 地点/导航/地图/瞬移/自动驾驶快速回归：

```powershell
$tests=@(
  'res://tests/world/test_city_place_query_resolution.gd',
  'res://tests/world/test_city_resolved_target_contract.gd',
  'res://tests/world/test_city_route_query_contract.gd',
  'res://tests/world/test_city_route_reroute.gd',
  'res://tests/world/test_city_route_result_cache.gd',
  'res://tests/world/test_city_map_destination_contract.gd',
  'res://tests/world/test_city_minimap_navigation_hud.gd',
  'res://tests/world/test_city_fast_travel_target_resolution.gd',
  'res://tests/world/test_city_autodrive_interrupt_contract.gd',
  'res://tests/e2e/test_city_navigation_flow.gd',
  'res://tests/e2e/test_city_map_destination_selection_flow.gd',
  'res://tests/e2e/test_city_fast_travel_map_flow.gd',
  'res://tests/e2e/test_city_autodrive_flow.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

- `v14` 任务 runtime / marker / trigger 快速回归：

```powershell
$tests=@(
  'res://tests/world/test_city_task_catalog_contract.gd',
  'res://tests/world/test_city_task_slot_seed_stability.gd',
  'res://tests/world/test_city_task_runtime_state_machine.gd',
  'res://tests/world/test_city_task_map_tab_contract.gd',
  'res://tests/world/test_city_task_pin_projection.gd',
  'res://tests/world/test_city_task_brief_view_model.gd',
  'res://tests/world/test_city_task_world_ring_marker_contract.gd',
  'res://tests/world/test_city_task_route_hides_destination_world_marker.gd',
  'res://tests/world/test_city_task_world_marker_runtime_refresh_reuse.gd',
  'res://tests/world/test_city_world_ring_marker_task_theme_profile.gd',
  'res://tests/world/test_city_world_ring_marker_task_shader_profile.gd',
  'res://tests/world/test_city_task_trigger_start_contract.gd',
  'res://tests/world/test_city_task_vehicle_trigger_start_contract.gd',
  'res://tests/e2e/test_city_task_tab_selection_flow.gd',
  'res://tests/e2e/test_city_task_start_flow.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

- `v13` 世界形态与 PNG 验收：

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_overview_png_export.gd'
```

- `v37` 直升机炮艇主世界 + lab 快速回归：

```powershell
$tests=@(
  'res://tests/world/test_city_task_helicopter_gunship_event_completion.gd',
  'res://tests/world/test_city_task_helicopter_gunship_repeatable_reset.gd',
  'res://tests/world/test_city_task_helicopter_gunship_pin_contract.gd',
  'res://tests/e2e/test_city_task_helicopter_gunship_flow.gd',
  'res://tests/world/test_city_helicopter_gunship_lab_scene_contract.gd',
  'res://tests/world/test_city_helicopter_gunship_lab_completion_cleanup_contract.gd',
  'res://tests/world/test_city_helicopter_gunship_lab_repeatable_combat_contract.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

- 性能护栏三件套，必须隔离顺序执行：

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_chunk_setup_profile_breakdown.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_first_visit_performance_profile.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_runtime_performance_profile.gd'
```

说明：

- closeout 默认顺序冻结为 `chunk setup -> first-visit -> warm runtime`
- 原因：`first-visit` 必须尽量保持“真正冷路径”的解释口径，不要先跑 warm traversal 再回来看 cold case
- 如需边界定位，额外使用 `tests/world/test_city_runtime_streaming_diagnostic_contract.gd` 与 `tests/world/test_city_chunk_profile_prepare_breakdown.gd`

- 慢速全量回归模板：

```powershell
rg --files tests -g *.gd | ForEach-Object {
  $script='res://'+($_ -replace '\\','/')
  & $godot --headless --rendering-driver dummy --path $project --script $script
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

说明：

- 当前仓库没有独立的 `npm` / `uv` 安装步骤，也没有正式导出流水线；不要编造 `build` / `lint` 命令。
- 当前最低可执行验证单元就是 Godot headless 测试；`tests/world` 偏 contract / unit-ish，`tests/e2e` 偏整链路玩法回归。

## 架构概览

### 子系统

- 运行时入口：
  - 主场景：`res://city_game/scenes/CityPrototype.tscn`
  - 主脚本：`res://city_game/scripts/CityPrototype.gd`
  - 玩家控制：`res://city_game/scripts/PlayerController.gd`
- 世界生成：
  - 配置：`res://city_game/world/model/CityWorldConfig.gd`
  - 总生成入口：`res://city_game/world/generation/CityWorldGenerator.gd`
  - 正式输出：`road_graph`、`block_layout`、`pedestrian_query`、`vehicle_query`、`task_catalog`、`task_slot_index`、`task_runtime`
  - 延迟/缓存化输出：`street_cluster_catalog`、`place_index`、`place_query`、`route_target_index`
- 导航、地点解析与地图：
  - 目标 contract：`res://city_game/world/model/CityResolvedTarget.gd`
  - route planner：`res://city_game/world/navigation/CityRoutePlanner.gd`
  - runtime：`res://city_game/world/navigation/CityChunkNavRuntime.gd`
  - route consumers：`CityFastTravelResolver.gd`、`CityAutodriveController.gd`
  - map/minimap：`res://city_game/ui/CityMapScreen.gd`、`res://city_game/world/map/CityMapPinRegistry.gd`、`res://city_game/world/map/CityMinimapProjector.gd`
- 任务系统：
  - catalog 生成：`res://city_game/world/tasks/generation/CityTaskCatalogBuilder.gd`
  - runtime 模型：`res://city_game/world/tasks/model/CityTaskCatalog.gd`、`CityTaskSlotIndex.gd`、`CityTaskRuntime.gd`
  - presentation：`res://city_game/world/tasks/presentation/CityTaskBriefViewModel.gd`、`CityTaskPinProjection.gd`
  - world runtime：`res://city_game/world/tasks/runtime/CityTaskTriggerRuntime.gd`、`CityTaskWorldMarkerRuntime.gd`
  - UI：`res://city_game/ui/CityTaskBriefPanel.gd`
- Streaming 与渲染：
  - 活跃窗口：`res://city_game/world/streaming/CityChunkStreamer.gd`
  - 渲染总控：`res://city_game/world/rendering/CityChunkRenderer.gd`
  - chunk 场景：`res://city_game/world/rendering/CityChunkScene.gd`
  - 地形/道路页面：`CityTerrainPageProvider.gd`、`CityRoadSurfacePageProvider.gd`
- 行人系统：
  - 生成入口：`res://city_game/world/pedestrians/generation/CityPedestrianWorldBuilder.gd`
  - 查询层：`res://city_game/world/pedestrians/model/CityPedestrianQuery.gd`
  - 分层运行时：`res://city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
  - 渲染层：`res://city_game/world/pedestrians/rendering/CityPedestrianCrowdRenderer.gd`
- 车辆系统：
  - 生成入口：`res://city_game/world/vehicles/generation/CityVehicleWorldBuilder.gd`
  - 查询层：`res://city_game/world/vehicles/model/CityVehicleQuery.gd`
  - 分层运行时：`res://city_game/world/vehicles/simulation/CityVehicleTierController.gd`
  - 渲染层：`res://city_game/world/vehicles/rendering/CityVehicleTrafficRenderer.gd`
- 战斗与玩家交互：
  - 投射物：`res://city_game/combat/CityProjectile.gd`、`CityGrenade.gd`
  - 敌对目标：`res://city_game/combat/CityTraumaEnemy.gd`
  - 直升机炮艇：`res://city_game/combat/helicopter/CityHelicopterGunship.tscn`、`CityHelicopterGunshipEncounterRuntime.gd`、`CityHelicopterGunshipWorldEncounter.tscn`
- 电台系统：
  - runtime：`res://city_game/world/radio/*`
  - 消费入口：`CityPrototype.gd`、HUD、电台 browser/quick overlay
- 服务建筑与作者场景覆盖：
  - 建筑功能化：`res://city_game/world/serviceability/*`
  - authored world features：`res://city_game/world/features/*`
  - exporter / override registry：`res://city_game/world/serviceability/CityBuildingSceneExporter.gd`、`CityBuildingOverrideRegistry.gd`
- 小游戏 runtime：
  - authored venue runtime：`res://city_game/world/features/CitySceneMinigameVenueRuntime.gd`
  - 玩法 runtime：`res://city_game/world/minigames/CitySoccerVenueRuntime.gd`、`CityTennisVenueRuntime.gd`、`CityMissileCommandVenueRuntime.gd`
- 参考仓库：
  - `refs/` 只用于比对/借鉴，默认视为只读参考区。

### 数据流

```text
CityPrototype
  -> CityWorldGenerator
     -> road_graph + block_layout + pedestrian_query + vehicle_query
     -> task_catalog + task_slot_index + task_runtime
     -> deferred street_cluster_catalog/place_index/place_query/route_target_index
  -> CityChunkStreamer + CityChunkRenderer
  -> CityChunkNavRuntime / CityRoutePlanner
     -> resolved_target + route_result
  -> full map / minimap / HUD / fast travel / autodrive
  -> task pin projection / task brief / world ring / trigger runtime
```

### 持久化与产物

- 道路图磁盘缓存：`user://cache/world/road_graph_*.bin`
- 地点索引磁盘缓存：`user://cache/world/place_index/place_index_*.bin`
- 道路表面 mask 磁盘缓存：`user://cache/world/road_surface/road_surface_*.bin`
- terrain page 是运行时内存缓存，主入口在 `CityTerrainPageProvider.gd`
- `reports/v13/test_city_overview_seed_424242.png` 与同名 `.json` 是 `test_city_overview_png_export.gd` 生成的验收产物，不是手工素材
- `.godot/` 是本地编辑器/import 状态，不要手改，不要把临时产物当源码处理

## 代码风格与约定

- 语言：GDScript，目标引擎 Godot `4.6`
- 风格：遵循现有 GDScript 代码风格，不新造另一套
  - 缩进使用 Tab
  - 函数/变量使用 `snake_case`
  - 脚本/场景文件名使用 `PascalCase`
  - 常量使用 `UPPER_SNAKE_CASE`
- 当前仓库没有独立 formatter/linter 配置；最低 correctness gate 是受影响的 headless Godot 测试和相关 profiling 测试
- 固定 seed 下的 deterministic 行为是正式 contract：涉及 `world generation / place index / route_result / task slot / chunk profile / pedestrian query / vehicle query` 的改动，必须保证重复运行可复现
- 跨模块传递 `Dictionary` / `Array` 时，优先保持 schema 稳定；对快照或缓存数据，继续使用 `duplicate(true)` 的防御性复制习惯
- 如果改的是用户可见玩法链路，优先把核心逻辑放在 `city_game/world/*` 或 `city_game/ui/*` 对应模块里，尽量不要继续把 `CityPrototype.gd` 膨胀成总控巨石
- 新增脚本/场景如果 Godot 自动生成了 `.uid`，应一并提交；不要手改 `.uid` 内容来“修引用”
- 优先扩展现有主链，不要并行发明旁路：
  - 世界生成：`CityWorldGenerator -> road_graph/block_layout/vehicle_query/pedestrian_query -> deferred place/query`
  - 导航：`place_query/route_target_index -> CityResolvedTarget -> CityRoutePlanner/CityChunkNavRuntime -> map/minimap/HUD/fast travel/autodrive`
  - 任务：`task_catalog/task_slot_index/task_runtime -> task_pin_projection/task_brief_view_model -> full map/minimap/world ring/trigger`
  - 道路渲染：`CityRoadGraph -> CityRoadLayoutBuilder -> CityRoadMaskBuilder / CityRoadMeshBuilder -> CityChunkRenderer`
  - 行人：`pedestrian_query -> streamer -> tier controller -> renderer`
  - 车辆：`vehicle_query -> streamer -> tier controller -> renderer`

## 导航、任务与世界圈提示 Contract

- 先统一上游 target/route，再区分 UI 或 marker 表现
  - `full map`、`minimap`、`HUD`、`fast travel`、`autodrive`、`task pin`、`world ring` 默认共享同一条 `resolved_target + route_result` 主链
  - 不允许引入 task-only destination state、task-only route solver 或第二套隐藏导航图

- 导航提示先统一语义，再区分颜色
  - `manual destination`、`task available`、`task active` 默认必须共享同一套 marker family / shader profile / 更新语义，只允许颜色、文案、route style 不同
  - 当前冻结色义遵循 `ECN-0020`：`destination = orange/yellow`、`task_available = green`、`task_active = blue`

- 同一个目标只允许一个世界空间提示拥有显示权
  - 任务 route 已经有任务 marker 时，通用 destination world marker 必须隐藏，避免重复 cue、重复 overdraw、重复 tick
  - “同一目标同时画 task marker + destination marker” 视为性能与设计双重缺陷

- world marker 一律按 contract 复用，不允许每帧重建/重采样
  - marker 的最小 contract 至少包括：`route_id / task_id / theme_id / radius_m / anchor / world_position`
  - contract 不变时，禁止重复：
    - ground resolve / surface sample
    - material rebuild / theme reapply
    - transform reapply
    - marker remove + re-add
  - 对手工 destination marker，也要像 task marker runtime 一样做 `unchanged contract reuse`

- 视觉复杂度优先推到 GPU，不要靠一堆透明 mesh 堆“高级感”
  - 需要“火焰圈 / 能量圈 / 远距可见性”时，优先少量承载几何 + shader 驱动的 pulse / glow / flame shell / sweep
  - 默认避免多层透明 flame 柱、dash/cross/flame mesh 并存，以及大量 CPU 侧逐帧 scale / rotation / position 动画

- 区分“事件链路”和“每帧链路”
  - `task pin / minimap / task panel / HUD` 默认按事件刷新理解；它们可能造成瞬时尖峰，但一般不是持续掉 FPS 的首嫌
  - `world marker update / ground resolve / route refresh / renderer tick` 才是持续波动时优先怀疑的每帧链路

- 先排除“payload 膨胀型”每帧成本，再怀疑 shader / 音频 / draw call
  - 对 `get_state() / get_runtime_state() / get_debug_state() / snapshot` 这类每帧可见链路，优先检查是否偷偷 deep-copy 大 `Array/Dictionary`，尤其是累计事件列表、全量 strip/marker/task 列表、全量 runtime snapshot
  - 如果症状是“越到后段越卡 / 时间越久越卡 / 内容越多越卡”，先量 getter/build-state 自身耗时，再去看 shader、音频 overlap、draw call、object count

- 热路径禁止调用 defensive-copy getter；冷热接口要分离
  - `definition / query / registry / catalog` 这类静态或低频数据，允许保留对外 snapshot getter，但热路径必须额外提供 shared view / compact runtime snapshot，不能在 `_process()`、runtime tick、renderer sync 里每帧复制全量数据
  - 一旦某个修复依赖“只给测试/文档方便看”的完整 payload，默认把完整 payload 留在冷路径，把紧凑 summary 留在热路径

- 手工 destination 与 task route 必须做差分验证
  - 只测 task route 或只测 manual destination 都不够；任何 marker / route visual 改动后，至少比较：
    - manual destination
    - tracked available task
    - active task objective
  - 如果其中一个稳、另一个抖，优先检查两者是否存在独有的 per-frame path

- 真实渲染性能优先于 headless 幻觉
  - headless/profile guard 只证明 runtime contract 和预算没有明显退化，不证明真实透明 overdraw / shader / 材质切换一定安全
  - 只要改了 marker、HUD、minimap、材质、shader、透明层，就必须在真实渲染下做一轮对比观察；不要拿 headless `PASS` 直接宣称“实机已修复”

- 这类问题必须补回归测试，不允许只靠肉眼记忆
  - 至少优先补三类测试：
    - `world marker hides duplicate owner`
    - `refresh reuse`
    - `shared profile contract`
  - 如果修复依赖 debug counter，也要暴露只读 debug state，让测试能直接卡住根因

## 安全边界与禁忌

- 禁止：没有 fresh profiling 证据就声称“性能改善了”
  - 为什么：本项目把 `60 FPS = 16.67ms/frame` 当硬门槛，口头判断没有意义
  - 替代：跑 `test_city_chunk_setup_profile_breakdown.gd`、`test_city_runtime_performance_profile.gd`、`test_city_first_visit_performance_profile.gd`
  - 验证：结果要落到 `docs/plan/` 留档，而不是只写在聊天里

- 禁止：并行运行 profiling 套件
  - 为什么：会污染 `wall_frame`、streaming 和 mount 数据
  - 替代：按顺序隔离执行性能三件套
  - 验证：运行时只有一个 Godot profiling 进程

- 禁止：用 diagnostics mode 的细粒度探针数据直接宣称 redline 过线
  - 为什么：`update_streaming_renderer_sync_*`、queue 子相位等字段只用于边界定位；开启探针会改变 profiling 口径，和默认 guard mode 不是一回事
  - 替代：official closeout 一律用默认 guard mode 跑三件套；需要定位时再显式打开 `set_performance_diagnostics_enabled(true)` 或跑 `test_city_runtime_streaming_diagnostic_contract.gd`
  - 验证：过线结论只看三件套与对应 `docs/plan/vN-mN-verification-YYYY-MM-DD.md`

- 禁止：在局部掉帧问题里先怪 shader / 音频 / mesh 数，而不先排查 per-frame deep-copy / full-scan / eager rebuild
  - 为什么：这类仓库里更常见的真根因是 runtime payload 膨胀、全量列表复制、每帧全量 phase/cache 重建；它们会伪装成“到了某段路/某个特效区域才卡”
  - 替代：先做 A/B 定位，再量 `getter/build-state`、`full-scan`、`eager cache rebuild` 的微成本；确认不是 CPU 热路径后，再往 GPU/音频方向下钻
  - 验证：至少留下一组 before/after profiling 证据，能证明根因收敛的是哪条热路径

- 禁止：把导航/任务系统退回成第二套隐藏 target、route、pin 或 marker 栈
  - 为什么：这会直接破坏 `v12` 到 `v14` 收口出来的共享 contract，后续 fast travel、autodrive、task ring 和 HUD 会再次分叉
  - 替代：继续沿 `place_query/route_target_index -> resolved_target -> route_result -> pins/rings/consumers` 主链扩展
  - 验证：至少跑 `test_city_map_destination_contract.gd`、`test_city_task_pin_projection.gd`、`test_city_task_route_hides_destination_world_marker.gd`、相关 e2e

- 禁止：把道路 runtime 退回成 `Path3D`、`RoadLane`、`RoadSegment`、`RoadIntersection`、`RoadManager` 或 per-segment mesh 节点体系
  - 为什么：会直接破坏 `v4-v7` 期间建立的 streaming/perf 资产
  - 替代：继续走 shared graph、surface page、batched mesh、runtime guard
  - 验证：`tests/world/test_city_road_runtime_node_budget.gd`

- 禁止：手改 `reports/v13/*.png`、`reports/v13/*.json` 或其他验收导出物来“更新结果”
  - 为什么：这会让 morphology 验收链失真，人工 review 看见的就不再是代码真实输出
  - 替代：重新运行 `test_city_overview_png_export.gd` 生成 fresh artifact
  - 验证：`git diff -- reports/v13` 只应出现由测试生成、且与你本次改动一致的产物变化

- 禁止：只靠手测回归
  - 为什么：这个仓库的关键风险几乎都在 deterministic data contract、streaming 边界、route/task shared contract 和性能护栏
  - 替代：改什么就补什么测试；至少跑受影响模块测试，用户可见玩法链路再补一个 e2e
  - 验证：相关 headless 测试 `PASS`

- 禁止：擅自修改 `refs/`
  - 为什么：`refs/` 是参考输入，不是当前产品源码
  - 替代：只读取、比对、摘取设计思路；如需改动，必须用户明确要求
  - 验证：`git diff -- refs`

- 禁止：提交 secrets、设备 token、私钥、`user://` 缓存产物或本地临时文件
  - 为什么：会造成泄露或污染仓库
  - 替代：凭据只放环境变量/本地 `.env`；缓存只留在运行时目录
  - 验证：提交前检查 `git status --short`

- 禁止：把基础设施版工作包装成“强可见性功能版”
  - 为什么：会误导里程碑预期，尤其是 profiling/contract/guard 类工作本来就不是体验版 closeout
  - 替代：在文档、review、提交说明里明确“这是基础设施 / 护栏 / 可见功能”哪一种
  - 验证：`docs/plan/vN-*.md` 的范围、测试和实际改动口径一致

## 安全注意事项

- 不要把任何真实密钥、token、私有证书写进仓库、计划文档或测试日志
- 本仓库本地测试默认不依赖线上服务；如果某任务需要联网、代理、API、推送或浏览器自动化，先说明目的，并把新增外部依赖写清楚
- 新增依赖前先确认是否真有必要；当前工程以 Godot/GDScript 自带能力和现有脚本为主，不要顺手引入一堆外围工具
- 真实用户数据、账号信息、设备标识都不应进入测试夹具；如确需构造样本，用合成数据

## 测试策略

### 快速验证

- 冒烟：

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/test_city_skeleton_smoke.gd'
```

### 单测 / E2E 模板

- world：

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/<test-name>.gd'
```

- e2e：

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/<test-name>.gd'
```

### 位置语义 / 导航 / 地图

- 默认优先跑：
  - `test_city_place_query_resolution.gd`
  - `test_city_resolved_target_contract.gd`
  - `test_city_route_query_contract.gd`
  - `test_city_route_reroute.gd`
  - `test_city_route_result_cache.gd`
  - `test_city_map_destination_contract.gd`
  - `test_city_minimap_navigation_hud.gd`
  - `test_city_fast_travel_target_resolution.gd`
  - `test_city_autodrive_interrupt_contract.gd`
  - `tests/e2e/test_city_navigation_flow.gd`
  - `tests/e2e/test_city_map_destination_selection_flow.gd`
  - `tests/e2e/test_city_fast_travel_map_flow.gd`
  - `tests/e2e/test_city_autodrive_flow.gd`

### 任务系统 / task map / world ring

- 默认优先跑：
  - `test_city_task_catalog_contract.gd`
  - `test_city_task_slot_seed_stability.gd`
  - `test_city_task_runtime_state_machine.gd`
  - `test_city_task_map_tab_contract.gd`
  - `test_city_task_pin_projection.gd`
  - `test_city_task_brief_view_model.gd`
  - `test_city_task_world_ring_marker_contract.gd`
  - `test_city_task_route_hides_destination_world_marker.gd`
  - `test_city_task_world_marker_runtime_refresh_reuse.gd`
  - `test_city_world_ring_marker_task_theme_profile.gd`
  - `test_city_world_ring_marker_task_shader_profile.gd`
  - `test_city_task_trigger_start_contract.gd`
  - `test_city_task_vehicle_trigger_start_contract.gd`
  - `tests/e2e/test_city_task_tab_selection_flow.gd`
  - `tests/e2e/test_city_task_start_flow.gd`

### 世界形态 / PNG 验收

- 修改 `road_graph / block_layout / overview export / morphology` 时，默认至少重跑：
  - `test_city_world_generator.gd`
  - `test_city_reference_road_graph.gd`
  - `test_city_road_network_continuity.gd`
  - `test_city_streetfront_building_layout.gd`
  - `test_city_overview_png_export.gd`

### 车辆 / 行人 / 战斗联动

- 修改 `player driving / hijack / pedestrian casualty / crowd reaction / vehicle runtime` 时，默认至少重跑：
  - `test_city_player_vehicle_pedestrian_impact.gd`
  - `test_city_pedestrian_vehicle_impact_panic.gd`
  - `test_city_player_vehicle_death_visual_launch.gd`
  - `test_city_pedestrian_death_visual_persistence.gd`
  - `tests/e2e/test_city_vehicle_pedestrian_impact_flow.gd`
  - `tests/e2e/test_city_vehicle_hijack_drive_flow.gd`

### 作者场景 / 小游戏 / 炮艇遭遇战

- 修改 `service building / scene landmark / interactive prop / authored minigame venue / helicopter gunship` 时，默认至少重跑受影响的 focused contract：
  - `test_city_service_building_full_map_pin_contract.gd`
  - `test_city_world_feature_full_map_pin_contract.gd`
  - `test_city_missile_command_full_map_pin_contract.gd`
  - `test_city_helicopter_gunship_lab_scene_contract.gd`
  - `test_city_helicopter_gunship_lab_completion_cleanup_contract.gd`
  - `test_city_helicopter_gunship_lab_repeatable_combat_contract.gd`
  - `test_city_task_helicopter_gunship_event_completion.gd`
  - `test_city_task_helicopter_gunship_repeatable_reset.gd`
  - `test_city_task_helicopter_gunship_pin_contract.gd`
  - `tests/e2e/test_city_task_helicopter_gunship_flow.gd`

### 性能护栏

- 修改 `world generation / place index / route planner / task runtime / streaming / chunk rendering / terrain / road surface / HUD / minimap / pedestrians / vehicles` 时，默认至少重跑：
  - `test_city_chunk_setup_profile_breakdown.gd`
  - `test_city_runtime_performance_profile.gd`
  - `test_city_first_visit_performance_profile.gd`

### 通用规则

- 改了代码就要补/改测试，即使用户没单独要求
- 文档只改文档时可以不跑运行时测试，但不要顺手声称“功能仍然通过”
- 性能测试必须隔离执行，不与其他 Godot 实例并行
- 改用户可见玩法链路时，优先同时具备一条 contract test 和一条 e2e
- 新的 closeout 证据统一回写到对应 `docs/plan/vN-mN-verification-YYYY-MM-DD.md`

## 当前优先级

- 守住 `60 FPS = 16.67ms/frame` 的硬红线，尤其是 warm runtime、first-visit 和 chunk setup 三条线
- 保住 `v12` 的位置语义主链：`place_query / resolved_target / route_result / full map / minimap / HUD / fast travel / autodrive` 不允许回退成各自一套临时状态
- 保住 `v13` 的世界级形态与 PNG 验收链：任何 road/building morphology 变更，都要能重新导出 deterministic overview artifact
- 继续把 `v14` 任务系统稳定在 shared pin / route / marker / trigger contract 上；不要再分叉出 task-only 地图状态或 route 逻辑
- 保住作者场景覆盖主链：`service building / landmark / interactive prop / minigame venue / helicopter encounter` 优先沿共享 registry / pin / task/runtime 主链扩展，不要回退成各自的私有旁路
- `v37` 炮艇遭遇战当前已正式接入主世界；后续改动默认保持 `lab runtime == main-world runtime`、`event completion != 立即返绿圈`、`空爆坠落 closeout 完成后再返绿圈`
- 后续默认增量方向仍是：`交通标识系统`、`车辆系统`、`更丰富的行人系统`，但前提始终是 tests + profiling guard 全部可复核

## 作用域与优先级

- 根目录 `AGENTS.md` 默认作用于整个仓库
- 当前已有更具体的子目录规约：
  - `city_game/combat/helicopter/AGENTS.md`
- 如果同目录存在 `AGENTS.override.md`，则它优先于 `AGENTS.md`
- 如果未来某个子目录新增自己的 `AGENTS.md`，以更靠近目标文件的那份为准
- 全局 `~/.codex/AGENTS.md` 提供跨项目默认值；本仓库内更具体的规则优先
- 如未来需要让 `refs/` 可编辑，应给 `refs/` 单独放一份 `AGENTS.md`；在那之前，`refs/` 继续视为只读参考区
- 用户在聊天中的显式指令始终优先于本文件
