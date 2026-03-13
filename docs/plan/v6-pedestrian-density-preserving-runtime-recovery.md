# V6 Pedestrian Density-Preserving Runtime Recovery

## Goal

把 pedestrian crowd 从“只能在较低密度平台下守住红线”的状态，推进到“默认 `lite` 配置下，world contract warm / first-visit `tier1_count >= 300`，fresh isolated e2e runtime warm `ped_tier1_count >= 240` / first-visit `>= 280`，并且 `wall_frame_avg_usec <= 16667` 在同一工作区、同一默认配置下同时成立”的状态；该目标以 `ECN-0015` 的 vehicle-aware 重定义为准，明确为未来车辆系统保留预算。

## PRD Trace

- REQ-0002-010
- REQ-0002-003
- REQ-0002-004
- REQ-0002-006
- REQ-0002-007
- REQ-0002-016

## Scope

做什么：

- 把 crowd runtime 从“每帧全量扫描 + 全量排序 + 全量 snapshot rebuild + 全量 Tier 1 MultiMesh 重写”升级为 density-preserving runtime
- 把 violent witness response 从 `500m` 全量广播 + `>=500m` flee，重平衡为 `0-200m` 必逃、`200-400m` deterministic `40%` 抽样、`>400m` calm，以及 `20s-35s` flee tick budget
- 引入 persistent crowd page runtime、incremental scheduler、dirty chunk snapshot cache、Tier 1 dirty render commit
- 补齐 crowd breakdown profiling 字段，用证据证明热点已经被拆开
- 在新 runtime 上恢复 `REQ-0002-016` 的 vehicle-aware 默认 `lite` 活力合同，而不是继续靠参数回退止血或重回旧的 `540/600` 纯 pedestrian 目标

不做什么：

- 不在本计划里解决近景真实模型、death visual、inspection、violent reaction 的最终重回归，它们在 `M11`
- 不靠继续提高 `Tier2 / Tier3` 上限来堆人口
- 不新增与性能恢复无关的大功能面
- 不通过保留 profiling 专用低密度配置来伪造过线

## DoD 硬度自检

1. 本计划所有 DoD 都可二元判定：高密度数量级、profile 红线、breakdown 字段、dirty commit 行为，全部有明确阈值或存在性断言。
2. 本计划所有 DoD 都绑定可重复命令：`tests/world/test_city_pedestrian_crowd_breakdown.gd`、`tests/world/test_city_pedestrian_page_runtime_contract.gd`、`tests/world/test_city_pedestrian_incremental_scheduler.gd`、`tests/world/test_city_pedestrian_chunk_snapshot_cache.gd`、`tests/world/test_city_pedestrian_tier1_dirty_commit.gd`、`tests/world/test_city_pedestrian_density_order_of_magnitude.gd`、`tests/e2e/test_city_pedestrian_performance_profile.gd`、`tests/e2e/test_city_runtime_performance_profile.gd`。
3. 本计划反作弊条款明确：不得接受“density 红 / profile 绿”或“density 绿 / profile 红”的双配置分裂状态；不得通过回退 `max_spawn_slots_per_chunk`、`lane_slot_budget`、debug 路线或临时关闭真实更新成本来宣称完成。
4. 本计划边界明确：只处理 crowd runtime recovery，不在本轮顺手扩需求。

## Acceptance

1. 自动化测试必须证明：运行时 profile 暴露 `crowd_active_state_count`、`crowd_step_usec`、`crowd_reaction_usec`、`crowd_rank_usec`、`crowd_snapshot_rebuild_usec`、`crowd_chunk_commit_usec`、`crowd_tier1_transform_writes` 或等价 breakdown 字段。
2. 自动化测试必须证明：crowd page runtime 在无结构变化时保持可复用，不允许继续每帧清空并重建所有 active chunk snapshots。
3. 自动化测试必须证明：Tier 1 batched representation 支持 page-local 或 chunk-local dirty commit；稳定帧下 `crowd_tier1_transform_writes` 必须小于 `ped_tier1_count`，不能继续整批重写全部 Tier 1 transforms。
4. 自动化测试必须证明：violent witness response 已重平衡为 `<=200m` 必逃、`200m-400m` deterministic `40%` 抽样、`>400m` calm，且 flee 持续时间必须落在 `20s-35s` tick budget 内。
5. 自动化测试必须证明：默认 `lite` 的 world contract 下，warm traversal 与 first-visit traversal 的 `tier1_count` 都 `>= 300`，且 district / road class 排序继续成立。
6. `tests/e2e/test_city_pedestrian_performance_profile.gd` 与 `tests/e2e/test_city_runtime_performance_profile.gd` 必须在同一默认 `lite` 配置下继续 `PASS`；fresh isolated profile 的 warm `ped_tier1_count >= 240`、first-visit `ped_tier1_count >= 280`，并且 `wall_frame_avg_usec <= 16667`。
7. 反作弊条款：不得通过 profile 时临时关闭 pedestrians、改用专用低密度配置、降低测试阈值、把大量 pedestrian 塞进不可见 tier、或只在单个 demo chunk 上做 dirty commit 假实现来宣称 `M10` 完成。

## Files

- Modify: `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianReactionModel.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianState.gd`
- Modify: `city_game/world/pedestrians/streaming/CityPedestrianStreamer.gd`
- Modify: `city_game/world/pedestrians/rendering/CityPedestrianCrowdRenderer.gd`
- Modify: `city_game/world/pedestrians/rendering/CityPedestrianCrowdBatch.gd`
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/world/pedestrians/model/CityPedestrianConfig.gd`
- Modify: `city_game/world/pedestrians/model/CityPedestrianQuery.gd`
- Modify: `city_game/world/pedestrians/streaming/CityPedestrianBudget.gd`
- Create: `city_game/world/pedestrians/simulation/CityPedestrianPageRuntime.gd`
- Create: `city_game/world/pedestrians/simulation/CityPedestrianSimulationScheduler.gd`
- Create: `city_game/world/pedestrians/rendering/CityPedestrianChunkSnapshotCache.gd`
- Create: `city_game/world/pedestrians/rendering/CityPedestrianTier1PageBuffer.gd`
- Create: `tests/world/test_city_pedestrian_crowd_breakdown.gd`
- Create: `tests/world/test_city_pedestrian_page_runtime_contract.gd`
- Create: `tests/world/test_city_pedestrian_incremental_scheduler.gd`
- Create: `tests/world/test_city_pedestrian_chunk_snapshot_cache.gd`
- Create: `tests/world/test_city_pedestrian_tier1_dirty_commit.gd`
- Modify: `tests/world/test_city_pedestrian_page_cache.gd`
- Modify: `tests/world/test_city_pedestrian_batch_rendering.gd`
- Modify: `tests/world/test_city_pedestrian_profile_stats.gd`
- Modify: `tests/world/test_city_pedestrian_audible_radius_boundary.gd`
- Modify: `tests/world/test_city_pedestrian_flee_pathing.gd`
- Modify: `tests/world/test_city_pedestrian_wide_area_audible_threat.gd`
- Modify: `tests/world/test_city_pedestrian_witness_flee_response.gd`
- Verify: `tests/world/test_city_pedestrian_density_order_of_magnitude.gd`
- Verify: `tests/e2e/test_city_pedestrian_performance_profile.gd`
- Verify: `tests/e2e/test_city_runtime_performance_profile.gd`

## Steps

1. 写失败测试（红）
   - 新增 crowd breakdown / page runtime / incremental scheduler / chunk snapshot cache / Tier 1 dirty commit 测试，把 `M10` 的结构性目标先写成失败断言。
2. 跑到红
   - 顺序运行上述测试，预期失败点必须明确落在“当前 crowd 仍是全量 rebuild 路径”上，而不是空洞的 missing-file 或 typo。
3. 实现（绿）
   - 先落 breakdown profiling。
   - 再把 violent witness response 重平衡为 layered radius + deterministic flee tick budget。
   - 再把 page runtime 从临时 state list 升级为 persistent runtime。
   - 再引入 incremental scheduler、dirty chunk snapshot cache、Tier 1 dirty commit。
   - 最后恢复默认 `lite` 的高密度参数合同。
4. 跑到绿
   - crowd breakdown / page runtime / scheduler / snapshot cache / dirty commit / density quantity 测试全部 PASS。
5. 必要重构（仍绿）
   - 收敛 scheduler、snapshot cache、Tier 1 buffer 与 profile 数据结构，避免在 `TierController` 里继续长出巨大分支。
6. E2E / Profiling
   - fresh isolated 运行 `test_city_pedestrian_performance_profile.gd` 与 `test_city_runtime_performance_profile.gd`。
   - 同一轮结果中同时验 `tier1_count` 与 `wall_frame_avg_usec`，禁止拆开宣称完成。

## Progress Notes

- 2026-03-14 本轮先把 violent witness response 收口到 `0-200m` 必逃、`200-400m` deterministic `40%`、`>400m` calm，并把 flee duration 固定为 deterministic `20s-35s` tick budget；相关 world / e2e threat chain 已先行回归通过。
- 2026-03-14 在不抬 `Tier2 / Tier3` 预算的前提下，本轮把 density uplift 聚焦到 spawn candidate 池：`max_spawn_slots_per_chunk = 48`、`get_spawn_slots_for_edge()` 改为 `0..6` 档、更激进的 combined-density 梯度，以及 `lane_slot_budget = ceil(lane_length / 75m)`。
- 2026-03-14 fresh world contract：
  - `tests/world/test_city_pedestrian_density_profile.gd` `PASS`
  - `tests/world/test_city_pedestrian_streaming_budget.gd` `PASS`
  - `tests/world/test_city_pedestrian_lite_density_uplift.gd` `PASS`
  - verified plateau：warm `tier1_count = 208`，first-visit `tier1_count = 201`、`tier2_count = 6`
- 2026-03-14 fresh isolated e2e/profile：
  - `tests/e2e/test_city_pedestrian_performance_profile.gd` `PASS`
  - warm `ped_tier1_count = 166`，`wall_frame_avg_usec = 10124`
  - first-visit `ped_tier1_count = 189`，`ped_tier2_count = 6`，`wall_frame_avg_usec = 12184`
  - `tests/e2e/test_city_runtime_performance_profile.gd` `PASS`
  - warm `ped_tier1_count = 166`，`wall_frame_avg_usec = 9893`
- 2026-03-14 结论：当前 main 工作区已经从 2026-03-13 的 warm `54` / first-visit `60` 量级，抬到 world warm `208` / first-visit `201` 与 e2e warm `166` / first-visit `189`，且 fresh isolated profile 继续守住 `16.67ms/frame`；`ECN-0015` 已把旧的 `540/600` 纯 pedestrian 目标重定义为 vehicle-aware 的 world `300/300` + isolated e2e `240/280`，而当前平台距离这组新 DoD 仍有明确差距，因此本计划继续保持 `in progress`。

## Risks

- 如果只补 profile breakdown 而不改 runtime 结构，`M10` 会变成“更详细地看着自己慢”。
- 如果把 flee budget 直接绑定渲染帧数而不是 simulation tick，掉帧时会把 `20s-35s` 口径拉歪。
- 如果 page runtime 只是换了个类名，内部仍每帧重建 state arrays，性能不会有本质变化。
- 如果 Tier 1 dirty commit 没有固定 slot contract，后续继续扩容时仍会回到全量重写。
- 如果在恢复高密度之前就过早庆祝 profile 变绿，最终只会再次回到“低密度保线”的假完成状态。
