# ECN-0013: Density-Preserving Crowd Runtime Recovery

## 基本信息

- **ECN 编号**：ECN-0013
- **关联 PRD**：PRD-0002
- **关联 Req ID**：REQ-0002-003、REQ-0002-004、REQ-0002-006、REQ-0002-007、REQ-0002-012、REQ-0002-013、REQ-0002-014、REQ-0002-015、REQ-0002-016
- **发现阶段**：`v6 M9` closeout 与 `M10/M11` 规划阶段
- **日期**：2026-03-13

## 变更原因

`M9` 把 hand-play closeout 的多个产品缺口补上了，但最新 fresh 本地证据证明：当前仓库在同一工作区里仍然只能二选一，要么守住 `16.67ms/frame`，要么把默认 `lite` crowd density 抬到 warm `540` / first-visit `600` 这一数量级，不能同时成立。

2026-03-13 当前工作区 fresh 证据：

- `tests/world/test_city_pedestrian_density_order_of_magnitude.gd`：`FAIL`，warm `tier1_count = 54`
- `tests/e2e/test_city_pedestrian_performance_profile.gd`：`PASS`，warm `wall_frame_avg_usec = 12989`
- `tests/e2e/test_city_runtime_performance_profile.gd`：`PASS`，warm `wall_frame_avg_usec = 15699`

同时，工作区中仍存在为了止血而做的临时参数回退：

- `CityPedestrianConfig.gd` 把 `max_spawn_slots_per_chunk` 回退到 `20`
- `CityPedestrianConfig.gd` 把 `get_spawn_slots_for_edge()` 回退到 `0/1/2/3`
- `CityPedestrianQuery.gd` 把 `lane_slot_budget` 回退到 `floor(lane_length / 90.0)`

这说明当前问题已经不是 `M9` 层面的参数调整，而是 crowd runtime 形态与 `REQ-0002-016` 正面冲突。继续在 `M9` 里做碎片补丁，只会让文档、测试和代码再次漂移，因此需要正式开出 `M10/M11`：

- `M10`：density-preserving crowd runtime recovery
- `M11`：nearfield fidelity restabilization on top of the new runtime

## 变更内容

### 原设计

- `M9` 仍默认沿用当前 crowd runtime 去同时承接 hand-play closeout 与 `10x` density uplift。
- `REQ-0002-003/004/006/007/016` 虽然定义了 tier/budget/profile/density 目标，但没有把“必须避免每帧全量 crowd rebuild”和“必须在高密度合同下继续守线”的架构口径写硬。
- `REQ-0002-012/013/014/015` 的近景高保真合同成立于 `M8/M9` 的旧 runtime 上，但没有写清在 `M10` 的新 runtime 上必须重新做回归验证。

### 新设计

- `v6` 新开 `M10`：把 crowd runtime 从“每帧全量扫描 + 全量排序 + 全量 snapshot rebuild + 全量 Tier1 MultiMesh 重写”升级为“persistent crowd page runtime + incremental scheduler + dirty chunk snapshot cache + dirty Tier1 render commit”。
- `v6` 新开 `M11`：在 `M10` 的新 runtime 上重新托住 `Tier2 + Tier3` 真实模型、death visual、inspection mode、violent reaction 等 hand-play 功能，不允许通过回退这些需求来换性能。
- `REQ-0002-003/004/006/007` 的验收口径补充为：必须能证明 crowd runtime 存在 page-local / chunk-local 的 dirty update 合同，而不是 profiling 靠回退密度或保留全量 rebuild。
- `REQ-0002-016` 的验收口径补充为：必须在 active density target 下继续满足 `wall_frame_avg_usec <= 16667`，且不得维持“density 红、profile 绿”或“density 绿、profile 红”的分裂状态；该 active target 后续已由 `ECN-0015`、`ECN-0016` 继续重定义。
- `REQ-0002-012/013/014/015` 保持原有产品要求不变，但其最终收口点从 `M9` 顺延到 `M11`，必须在 `M10` 新 runtime 上重新验证，不允许拿旧 runtime 的通过记录冒充最终完成。

## 影响范围

- 受影响的 Req ID：
  - REQ-0002-003
  - REQ-0002-004
  - REQ-0002-006
  - REQ-0002-007
  - REQ-0002-012
  - REQ-0002-013
  - REQ-0002-014
  - REQ-0002-015
  - REQ-0002-016
- 受影响的 vN 计划：
  - `docs/plan/v6-index.md`
  - `docs/plan/v6-pedestrian-handplay-closeout.md`
  - `docs/plan/v6-pedestrian-density-preserving-runtime-recovery.md`
  - `docs/plan/v6-pedestrian-nearfield-fidelity-restabilization.md`
- 受影响的测试：
  - `tests/world/test_city_pedestrian_crowd_breakdown.gd`
  - `tests/world/test_city_pedestrian_page_cache.gd`
  - `tests/world/test_city_pedestrian_incremental_scheduler.gd`
  - `tests/world/test_city_pedestrian_chunk_snapshot_cache.gd`
  - `tests/world/test_city_pedestrian_tier1_dirty_commit.gd`
  - `tests/e2e/test_city_pedestrian_performance_profile.gd`
  - `tests/e2e/test_city_runtime_performance_profile.gd`
  - `tests/world/test_city_pedestrian_density_order_of_magnitude.gd`
  - `tests/world/test_city_pedestrian_sustained_fire_reaction.gd`
  - `tests/world/test_city_pedestrian_inspection_mode_non_threat.gd`
  - `tests/world/test_city_pedestrian_death_visual_persistence.gd`
  - `tests/e2e/test_city_pedestrian_character_visual_presence.gd`
  - `tests/e2e/test_city_pedestrian_live_burst_fire_stability.gd`
- 受影响的代码文件：
  - `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
  - `city_game/world/pedestrians/streaming/CityPedestrianStreamer.gd`
  - `city_game/world/pedestrians/rendering/CityPedestrianCrowdRenderer.gd`
  - `city_game/world/pedestrians/rendering/CityPedestrianCrowdBatch.gd`
  - `city_game/world/rendering/CityChunkRenderer.gd`
  - `city_game/scripts/CityPrototype.gd`
  - 以及 `M11` 对近景 fidelity 相关的既有行人视觉/反应文件

## 处置方式

- [x] PRD 已同步更新（标注 ECN-0013）
- [x] v6 计划已同步更新
- [x] 追溯矩阵已同步更新
- [ ] 相关测试已同步更新
