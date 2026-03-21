# V36 Nearfield Runtime Data / Batching / Parallelization

## Goal

把主世界“沿街走就飘、靠近动态街道就抖、靠近静态楼群反而稳”的问题，从 `v35` 的 diagnostics 结论推进到一轮正式架构治理：将近场 `crowd`、`traffic` 与它们的 `renderer_sync` 热路径，按 `数据化`、`批处理化`、`并行化` 三个阶段逐步减重，优先消除近场街道运行期的主线程肥路径与 frame-time 抖动。

## PRD Trace

- REQ-0001-006
- REQ-0001-008
- REQ-0001-009
- REQ-0002-003
- REQ-0002-004
- REQ-0002-006
- REQ-0002-007
- REQ-0002-010
- REQ-0002-012
- REQ-0002-016
- REQ-0003-004
- REQ-0003-005
- REQ-0003-008
- REQ-0003-009

## Dependencies

- `v22` 已冻结 shared runtime profiling 三件套与 diagnostics 词典。
- `v35` 已给出 fresh rendered 证据，确认这不是“楼多所以卡”，而是近场 `crowd/traffic + renderer_sync` 热路径问题。
- 当前已知 artifact：
  - `reports/v35/runtime_jitter/diagnostics/inspection_high_speed_diagnostics_windows.json`
  - `reports/v35/runtime_jitter/diagnostics/live_gunshot_diagnostics_headless.json`
  - `v35-runtime-jitter-full-diagnostic.md`

## Scope

做什么：

- 把近场人车 runtime 的每帧核心逻辑从“散落在 Node / snapshot / renderer sync 的混合式路径”进一步收束成可量测的纯数据相位
- 让 `crowd` 与 `traffic` 各自具备更严格的 dirty-batch commit 语义，减少每帧全量同步与无效回写
- 为 inspection / panic 两条链补足足够细的 before/after 对账字段
- 在不触碰非线程安全 SceneTree 操作的前提下，把一部分纯数据相位迁移到线程池或等价 worker 机制
- 为 closeout 保留真实渲染下的 density / visual / gameplay 守线

不做什么：

- 本轮不承诺“所有街道场景永远 16.67ms 以下”
- 本轮不把建筑坍塌、导弹、RPG 等其它玩法链混入主问题
- 本轮不靠把城市变空、把恐慌反应做没、把 minimap/hud 彻底关掉来“修性能”
- 本轮不将 `v35` 的 diagnostics 重新包装成 `v36` 成果

## Acceptance

1. `v36` 必须拿出至少一条明确的近场人车热路径 before/after 证据，能证明“热路径形态变了”，而不仅是参数变了。
2. `inspection` fresh rendered rerun 中，至少以下字段必须出现并能与 `v35` 对账：
   - `wall_frame_avg_usec`
   - `update_streaming_renderer_sync_avg_usec`
   - `update_streaming_renderer_sync_crowd_avg_usec`
   - `update_streaming_renderer_sync_traffic_avg_usec`
   - `crowd_update_avg_usec`
   - `traffic_update_avg_usec`
   - `hud_refresh_avg_usec`
   - `minimap_build_avg_usec`
3. `live gunshot` fresh rendered rerun 中，至少以下字段必须出现并能与 `v35` 对账：
   - `wall_frame_avg_usec`
   - `frame_step_avg_usec`
   - `crowd_update_avg_usec`
   - `traffic_update_avg_usec`
   - `update_streaming_renderer_sync_avg_usec`
   - `scenario_max_violent_count`
4. crowd 数据化 / batching 阶段完成后，必须继续守住：
   - inspection 场景不是空街
   - 恐慌链不是假事件
   - 中距离 visual 不能退化成肉眼明显离谱的灰模
5. traffic 数据化 / batching 阶段完成后，必须继续守住：
   - drive / hijack / impact 基本行为 contract
   - 车辆 identity / lane / budget contract
6. 并行化阶段不得把以下操作搬到线程里：
   - `add_child` / `remove_child`
   - 直接遍历并修改 active scene tree
   - 非线程安全的渲染资源创建/销毁
7. 反作弊条款：
   - 不得通过再次大幅降低 density、移除 panic 链、将 inspection 模式改成空载走廊、或只保留 headless 验证来宣称 `v36` closeout。

## Files

- Create: `docs/plan/v36-index.md`
- Create: `docs/plan/v36-nearfield-runtime-data-batching-parallelization.md`
- Future Create: `docs/plan/v36-mN-verification-YYYY-MM-DD.md`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianNearfieldRuntime.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianMidfieldRuntime.gd`
- Modify: `city_game/world/pedestrians/rendering/CityPedestrianCrowdRenderer.gd`
- Modify: `city_game/world/pedestrians/rendering/CityPedestrianCrowdBatch.gd`
- Modify: `city_game/world/vehicles/simulation/CityVehicleTierController.gd`
- Modify: `city_game/world/vehicles/rendering/CityVehicleTrafficRenderer.gd`
- Modify: `city_game/world/vehicles/rendering/CityVehicleTrafficBatch.gd`
- Modify: `tests/e2e/test_city_pedestrian_high_speed_inspection_diagnostics.gd`
- Modify: `tests/e2e/test_city_pedestrian_high_speed_inspection_performance.gd`
- Modify: `tests/e2e/test_city_pedestrian_live_gunshot_diagnostics.gd`
- Modify: `tests/e2e/test_city_pedestrian_live_gunshot_performance.gd`
- Optional Modify: `tests/e2e/test_city_runtime_performance_profile.gd`
- Optional Modify: `tests/e2e/test_city_first_visit_performance_profile.gd`
- Optional Modify: `tests/world/test_city_pedestrian_profile_stats.gd`
- Optional Modify: `tests/world/test_city_vehicle_profile_stats.gd`

## Hot-Path Freeze

`v36` 先把问题拆成四类热路径，不再混着优化：

1. `crowd pure-data update`
   - 候选收集
   - 距离排序 / tier 分配
   - 威胁评估 / reaction 状态推进
   - 路径采样 / 朝向 / step scheduler
2. `traffic pure-data update`
   - 车道跟随 / headway / turn / identity continuity
   - inspection 语义下的分层更新与远场复用
3. `renderer_sync commit`
   - crowd dirty chunk snapshot
   - traffic dirty chunk snapshot
   - minimap / hud 与 runtime snapshot 的耦合回写
4. `main-thread only commit`
   - SceneTree 节点提交
   - `MultiMesh` / renderer resource 写入
   - HUD / minimap 最终 UI 提交

任何优化动作都必须声明自己在打哪一类，不允许“顺手改一堆参数然后看体感”。

## Milestones

### M1 数据边界冻结与 instrumentation 补强

目标：

- 把 crowd / traffic / renderer_sync / hud-minimap 的责任边界再切清楚，补足对账所需的 profile 字段

DoD：

- profile 能区分 pure-data update 与 commit cost
- 有足够的只读 stats 支撑 before/after 比较
- 相关 contract tests 证明 instrumentation 本身不会破坏既有行为

验证：

- `tests/world/test_city_pedestrian_profile_stats.gd`
- `tests/world/test_city_vehicle_profile_stats.gd`
- `tests/world/test_city_runtime_streaming_diagnostic_contract.gd`
- rendered `tests/e2e/test_city_pedestrian_high_speed_inspection_diagnostics.gd`
- rendered `tests/e2e/test_city_pedestrian_live_gunshot_diagnostics.gd`

### M2 crowd 数据化与 dirty-batch commit

目标：

- 先把行人这条最敏感的近场链改成“先算数据，再最小提交”

DoD：

- assignment / threat / step / snapshot 重建有清晰的 shared compact state
- 非 dirty chunk 不做全量 crowd render commit
- fresh rendered `inspection` 或 `live gunshot` 至少一条链上的 `crowd_update` 与 `renderer_sync_crowd` 取得可对账下降
- 不打坏 density / fear / visual contract

验证：

- `tests/world/test_city_pedestrian_chunk_snapshot_cache.gd`
- `tests/world/test_city_pedestrian_tier1_dirty_commit.gd`
- `tests/world/test_city_pedestrian_tier1_reorder_stable_commit.gd`
- `tests/world/test_city_pedestrian_traversal_assignment_scheduler.gd`
- `tests/world/test_city_pedestrian_nearfield_traversal_assignment_scheduler.gd`
- `tests/world/test_city_pedestrian_lite_density_uplift.gd`
- `tests/world/test_city_pedestrian_lod_contract.gd`
- rendered `tests/e2e/test_city_pedestrian_high_speed_inspection_performance.gd`
- rendered `tests/e2e/test_city_pedestrian_live_gunshot_performance.gd`

### M3 traffic 数据化与 dirty-batch commit

目标：

- 把车辆从“每帧 scattered runtime + renderer sync”拉成更紧凑的数据驱动提交链

DoD：

- 车辆近场 update 与 render commit 有独立 dirty 语义
- fresh rerun 中 `traffic_update` 与 `renderer_sync_traffic` 有对账下降
- 不打坏 drive / hijack / collision / traffic continuity

验证：

- `tests/world/test_city_vehicle_profile_stats.gd`
- `tests/world/test_city_vehicle_batch_rendering.gd`
- `tests/world/test_city_vehicle_renderer_initial_snapshot.gd`
- `tests/world/test_city_vehicle_tier1_reorder_stable_commit.gd`
- `tests/world/test_city_vehicle_streaming_budget.gd`
- `tests/world/test_city_vehicle_lod_contract.gd`
- `tests/e2e/test_city_vehicle_performance_profile.gd`
- rendered `tests/e2e/test_city_pedestrian_high_speed_inspection_performance.gd`

### M4 纯数据相位并行化

目标：

- 把已经数据化完成的纯计算部分迁移到 `WorkerThreadPool` 或等价机制

DoD：

- 线程边界明确：线程只产出 compact result，主线程只做 commit
- 不出现“线程里直接碰 active scene tree”的反模式
- rendered diagnostics 能证明 spike 或平均耗时继续下降，至少一条链可对账

验证：

- focused contract tests for thread-safe boundary
- `tests/world/test_city_pedestrian_profile_stats.gd`
- `tests/world/test_city_vehicle_profile_stats.gd`
- rendered `tests/e2e/test_city_pedestrian_high_speed_inspection_diagnostics.gd`
- rendered `tests/e2e/test_city_pedestrian_live_gunshot_diagnostics.gd`
- rendered `tests/e2e/test_city_pedestrian_high_speed_inspection_performance.gd`

### M5 Closeout

目标：

- 以 fresh rendered 证据证明 `v36` 的三化治理确实改善了近场街道抖动，而且没有靠缩水换分

DoD：

- `inspection` 与 `live gunshot` 两条链都完成 before/after 文档对账
- 基础 runtime / first-visit / vehicle / pedestrian profile 没有被连带打穿
- 形成 `docs/plan/v36-mN-verification-YYYY-MM-DD.md`

验证：

- `tests/e2e/test_city_pedestrian_high_speed_inspection_performance.gd`
- `tests/e2e/test_city_pedestrian_live_gunshot_performance.gd`
- `tests/e2e/test_city_pedestrian_performance_profile.gd`
- `tests/e2e/test_city_vehicle_performance_profile.gd`
- `tests/e2e/test_city_runtime_performance_profile.gd`
- `tests/e2e/test_city_first_visit_performance_profile.gd`

## Steps

1. Analysis
   - 以 `v35` artifact 为真源，冻结 crowd / traffic / renderer_sync / hud-minimap 四类热点的边界。
   - 审计现有 `TierController`、`CrowdBatch`、`TrafficBatch`、`CityPrototype` 的 profile 字段与 snapshot 回写路径。
2. Design
   - 为 crowd / traffic 分别定义 `pure-data update result -> dirty batch commit` 的目标形态。
   - 明确哪些字段只能主线程提交，哪些字段允许异步计算。
3. Plan
   - 建立 `v36-index.md` 与本计划文档。
4. TDD Red: instrumentation
   - 先补或收紧 diagnostics / profile contract，确保可以看见 pure-data 与 commit 的边界。
   - 先跑现有 rendered diagnostics / performance，保留 before baseline。
5. TDD Green: crowd datafication
   - 将 crowd 热路径中最贵的每帧逻辑收束为 compact runtime state。
   - 对 render commit 引入更严格的 dirty chunk / dirty tier 提交条件。
6. TDD Green: traffic datafication
   - 将 traffic 热路径中最贵的近场 update 与 render commit 做同样收束。
7. TDD Green: parallelization
   - 仅对已完成数据化的纯计算相位引入线程池。
   - 线程输出 compact result，主线程做最小 commit。
8. Refactor
   - 清理临时探针，保留长期有用的 profile counters 与只读 debug state。
9. E2E
   - 跑 rendered diagnostics / performance 两条主链。
   - 跑 pedestrian / vehicle / runtime / first-visit 回归，证明没有靠缩水换成绩。
10. Review
   - 把 before/after 数字、保留风险与未收口差异写入 `v36-mN-verification-YYYY-MM-DD.md`。
11. Ship
   - 文档、instrumentation、crowd refactor、traffic refactor、parallelization、verification 分 slice 提交。

## Risks

- 如果只做并行化，不先做数据化和 batching，很容易代码更复杂但收益有限。
- 如果把 crowd 做瘦了却让中距离 visual 退回明显离谱 proxy，用户会直接认为这是“拿画质换帧数”。
- 如果 minimap / hud 仍然和高频 inspection snapshot 强耦合，哪怕 crowd/traffic 改好了，也可能留下新的主线程尖峰。
- 如果线程边界设计不干净，Godot 的 SceneTree / render resource 非线程安全问题会引入新的不稳定与诡异 bug。
