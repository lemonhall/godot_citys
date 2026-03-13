# ECN-0014: Layered Violent Witness Response Rebalance

## 基本信息

- **ECN 编号**：ECN-0014
- **关联 PRD**：PRD-0002
- **关联 Req ID**：REQ-0002-010、REQ-0002-016
- **发现阶段**：`v6 M10` runtime recovery
- **日期**：2026-03-14

## 变更原因

`M7` 把 violent witness response 做成了 `500m` 全半径 panic/flee，且单次 flee 必须跑满 `500m`。这满足了当时“玩家可明显看到有人四散而逃”的产品诉求，但最新手玩反馈与当前 `M10` 目标都表明，这个口径过重：

- 视觉上会把过远的 pedestrian 也带入 panic/flee，破坏局部事件感。
- `Tier1` 的棍状 lightweight crowd 也会显著参与 flee，放大 hand-play 中的违和感。
- 对 combat window 的 crowd reaction / rank / snapshot rebuild / render commit 成本形成不必要的广域扇出。
- `500m` 位移在当前 `4x base speed` 下约等于 `100s` 级单次逃跑寿命，长尾成本远高于必要值。

因此需要把 `REQ-0002-010` 从“500m 全量广播 + 跑满 500m”重平衡为“局部硬响应 + 外圈抽样 + 有界 flee tick budget”，并把该重平衡明确归入 `M10`，作为 density-preserving runtime recovery 的一部分，而不是继续记在已经结束的 `M7` 历史口径上。

## 变更内容

### 原设计

- gunshot、casualty 与 explosion witness 采用统一 `500m` 半径。
- 半径内存活 witness 默认都会进入 `panic / flee`。
- 单次 flee 以至少 `4x base speed` 逃跑，并且位移必须 `>= 500m`。
- 相关自动化测试与计划文档都以 `500m / 500m` 为验收口径。

### 新设计

- violent witness response 改为分层半径：
  - `0m - 200m`：`100%` 进入 `panic / flee`
  - `200m - 400m`：仅 `40%` witness 进入 `panic / flee`
  - `> 400m`：保持 ambient
- 外圈 `40%` 采用 deterministic sampling，不允许使用 run-to-run 不稳定的真正随机数。
- flee 持续时间改为 deterministic tick budget：
  - 最短 `20s`
  - 最长 `35s`
  - 基于 `60 ticks/s` 的 simulation tick 语义，而不是直接绑定渲染帧数
- `panic / flee` 继续保留至少 `4x base speed` 的移动速度合同，但不再要求单次位移必须 `>= 500m`。
- `REQ-0002-010` 的当前收口点从 `M7` 历史记录顺延到 `M10`；`M11` 只负责在新 runtime 上回归近景 fidelity，不再承担这组行为重平衡。

## 影响范围

- 受影响的 Req ID：
  - REQ-0002-010
  - REQ-0002-016
- 受影响的 vN 计划：
  - `docs/plan/v6-index.md`
  - `docs/plan/v6-pedestrian-witness-flee-response.md`
  - `docs/plan/v6-pedestrian-density-preserving-runtime-recovery.md`
- 受影响的测试：
  - `tests/world/test_city_pedestrian_audible_radius_boundary.gd`
  - `tests/world/test_city_pedestrian_flee_pathing.gd`
  - `tests/world/test_city_pedestrian_wide_area_audible_threat.gd`
  - `tests/world/test_city_pedestrian_witness_flee_response.gd`
  - `tests/world/test_city_pedestrian_grenade_kill_and_flee.gd`
  - `tests/world/test_city_pedestrian_sustained_fire_reaction.gd`
  - `tests/e2e/test_city_pedestrian_live_wide_area_threat_chain.gd`
  - `tests/e2e/test_city_pedestrian_combat_flow.gd`
  - `tests/e2e/test_city_pedestrian_travel_flow.gd`
- 受影响的代码文件：
  - `city_game/world/pedestrians/streaming/CityPedestrianBudget.gd`
  - `city_game/world/pedestrians/simulation/CityPedestrianReactionModel.gd`
  - `city_game/world/pedestrians/simulation/CityPedestrianState.gd`

## 处置方式

- [x] PRD 已同步更新（标注 ECN-0014）
- [x] v6 计划已同步更新
- [x] 追溯矩阵已同步更新
- [ ] 相关测试已同步更新
