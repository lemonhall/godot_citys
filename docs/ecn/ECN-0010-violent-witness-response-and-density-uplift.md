# ECN-0010: Violent Witness Response and Density Uplift

## 基本信息

- **ECN 编号**：ECN-0010
- **关联 PRD**：PRD-0002
- **关联 Req ID**：REQ-0002-005、REQ-0002-007、REQ-0002-009、新增 REQ-0002-010、新增 REQ-0002-011
- **发现阶段**：v6 M6 推送后的手玩验收 / 用户反馈
- **日期**：2026-03-13

## 变更原因

`M6` 已经把 “direct-hit victim 会死亡” 和 “爆炸 threat ring 内存在 flee state” 这条底线补上，但 2026-03-13 推送后的真实手玩反馈又暴露出两项新的产品级缺口：

- automatic rifle 与 grenade 在真实运行期里，周围 pedestrian 仍然没有形成玩家可感知的四散逃离；当前 response 更像“受害者或极小 threat ring 生效”，而不是“目击暴力的人群会逃散”。
- 默认 `pedestrian_mode = lite` 虽然守住了红线，但街道整体观感仍然偏稀疏，主街和核心区的人流存在感不足，世界显得过于空旷。

这说明 `PRD-0002` 现有口径还缺两块：一是 violence-driven witness flee propagation，二是 density uplift under redline。如果不把这两项正式写进需求与计划，`v6` 就会停留在“自动化过线，但手玩产品感不够”的状态。

## 变更内容

### 原设计

- `REQ-0002-009` 已要求 casualty 与 threat-radius 内 flee，但没有把“对枪杀 / 爆炸有目击关系的周边 pedestrian 必须形成可见的局部逃散”写成独立需求。
- `REQ-0002-001` 与 `REQ-0002-007` 虽然定义了 density profile 与 redline guard，但没有把“当前默认 lite density 仍然过稀，需要继续抬升”写成正式 DoD。

### 新设计

- 新增 `REQ-0002-010`：把 violent-event witness response 单独立项，要求 gunfire、casualty 与 grenade / explosion 会把 `500m` 内 witness 推入 `panic / flee`，并以 `4x` 速度至少跑满 `500m`，而不只影响受害者本身。
- 新增 `REQ-0002-011`：把 `pedestrian_mode = lite` 的默认 crowd density uplift 单独立项，要求在不打穿红线的前提下提升主街与核心区的人流存在感。
- `v6` 新开 `M7`，专门承载上述两项差异；在 `M7` 完成前，`v6` 不再视为完全收口。
- `M7` 的 density uplift 优先消化当前 Tier 1 headroom；除非后续另行开 ECN，否则不把“继续抬高 Tier 2 / Tier 3 hard cap”作为默认解法。

## 影响范围

- 受影响的 Req ID：
  - REQ-0002-005
  - REQ-0002-007
  - REQ-0002-009
  - 新增 REQ-0002-010
  - 新增 REQ-0002-011
- 受影响的 vN 计划：
  - `docs/plan/v6-index.md`
  - `docs/plan/v6-m7-status-and-next-rounds.md`
  - `docs/plan/v6-pedestrian-witness-flee-response.md`
  - `docs/plan/v6-pedestrian-density-uplift.md`
- 受影响的测试：
  - `tests/world/test_city_pedestrian_audible_radius_boundary.gd`
  - `tests/world/test_city_pedestrian_flee_pathing.gd`
  - `tests/world/test_city_pedestrian_wide_area_audible_threat.gd`
  - `tests/world/test_city_pedestrian_witness_flee_response.gd`
  - `tests/world/test_city_pedestrian_density_profile.gd`
  - `tests/world/test_city_pedestrian_lite_density_uplift.gd`
  - `tests/e2e/test_city_pedestrian_live_wide_area_threat_chain.gd`
  - `tests/e2e/test_city_pedestrian_live_combat_chain.gd`
  - `tests/e2e/test_city_pedestrian_combat_flow.gd`
  - `tests/e2e/test_city_pedestrian_travel_flow.gd`
  - `tests/e2e/test_city_pedestrian_performance_profile.gd`
  - `tests/e2e/test_city_runtime_performance_profile.gd`
- 受影响的代码文件：
  - `city_game/world/pedestrians/simulation/CityPedestrianReactionModel.gd`
  - `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
  - `city_game/world/pedestrians/streaming/CityPedestrianStreamer.gd`
  - `city_game/world/pedestrians/model/CityPedestrianConfig.gd`
  - `city_game/world/pedestrians/model/CityPedestrianQuery.gd`
  - `city_game/world/rendering/CityChunkRenderer.gd`
  - `city_game/scripts/CityPrototype.gd`
  - 以及后续 `projectile / grenade / crowd profiling` 相关文件

## 处置方式

- [x] PRD 已同步更新（标注 ECN-0010）
- [x] v6 计划已同步更新
- [x] 追溯矩阵已同步更新
- [x] 相关测试已同步更新
