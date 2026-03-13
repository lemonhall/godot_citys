# V6 Pedestrian Density-Preserving Runtime Recovery

## Goal

把 pedestrian crowd 从“只能在低密度下守住红线，或在高密度下打穿红线”的分裂状态，推进到“默认 `lite` 配置下，warm `tier1_count >= 540` / first-visit `>= 600` 与 `wall_frame_avg_usec <= 16667` 在同一工作区、同一默认配置下同时成立”的状态。

## PRD Trace

- REQ-0002-003
- REQ-0002-004
- REQ-0002-006
- REQ-0002-007
- REQ-0002-016

## Scope

做什么：

- 把 crowd runtime 从“每帧全量扫描 + 全量排序 + 全量 snapshot rebuild + 全量 Tier 1 MultiMesh 重写”升级为 density-preserving runtime
- 引入 persistent crowd page runtime、incremental scheduler、dirty chunk snapshot cache、Tier 1 dirty render commit
- 补齐 crowd breakdown profiling 字段，用证据证明热点已经被拆开
- 在新 runtime 上恢复 `REQ-0002-016` 的默认 `lite` 高密度合同，而不是继续靠参数回退止血

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
4. 自动化测试必须证明：默认 `lite` 配置下，warm traversal 的 `tier1_count >= 540`，first-visit traversal 的 `tier1_count >= 600`，且 district / road class 排序继续成立。
5. `tests/e2e/test_city_pedestrian_performance_profile.gd` 与 `tests/e2e/test_city_runtime_performance_profile.gd` 必须在上述高密度默认配置下继续 `PASS`，并且 `wall_frame_avg_usec <= 16667`。
6. 反作弊条款：不得通过 profile 时临时关闭 pedestrians、改用专用低密度配置、降低测试阈值、把大量 pedestrian 塞进不可见 tier、或只在单个 demo chunk 上做 dirty commit 假实现来宣称 `M10` 完成。

## Files

- Modify: `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
- Modify: `city_game/world/pedestrians/streaming/CityPedestrianStreamer.gd`
- Modify: `city_game/world/pedestrians/rendering/CityPedestrianCrowdRenderer.gd`
- Modify: `city_game/world/pedestrians/rendering/CityPedestrianCrowdBatch.gd`
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/world/pedestrians/model/CityPedestrianConfig.gd`
- Modify: `city_game/world/pedestrians/model/CityPedestrianQuery.gd`
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

## Risks

- 如果只补 profile breakdown 而不改 runtime 结构，`M10` 会变成“更详细地看着自己慢”。
- 如果 page runtime 只是换了个类名，内部仍每帧重建 state arrays，性能不会有本质变化。
- 如果 Tier 1 dirty commit 没有固定 slot contract，后续继续扩容时仍会回到全量重写。
- 如果在恢复高密度之前就过早庆祝 profile 变绿，最终只会再次回到“低密度保线”的假完成状态。
