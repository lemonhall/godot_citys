# V6 M7 Status And Next Rounds

## Update

- `2026-03-13` 同日 closeout 已完成：`M7` 现已 fresh isolated `PASS`，允许把 `docs/plan/v6-index.md`、`REQ-0002-010`、`REQ-0002-011` 写成完成态。
- 本轮按用户手玩口径重新确认后的 `M7` 真实行为不是“有一点点 witness state flip”，而是以下三条同时成立：
  - `gunshot / grenade explosion / casualty -> 500m` 内 witness 会进入 `panic / flee`
  - `panic / flee` 速度倍率为 `4x base speed`
  - 单次逃散必须至少跑满 `500m` 才允许停止
- 最新 isolated 证据：
  - `tests/e2e/test_city_pedestrian_performance_profile.gd`
    - warm `wall_frame_avg_usec = 16048`
    - first-visit `wall_frame_avg_usec = 13507`
  - `tests/e2e/test_city_runtime_performance_profile.gd`
    - warm `wall_frame_avg_usec = 12339`
- witness / density 两份 `M7` 子文档与 `v6-index` 完成态证据已写回；剩余未处理项只包括本轮 debug 探针脚本是否清理，按仓库偏好暂不擅自删除。
- 本文以下内容保留的是 closeout 之前的历史阻塞诊断，用于追溯这轮为什么先写“状态说明文档”、后做真正收口；以下章节不代表当前实时状态。

## Fresh Behavior Verification After Hand-Play Feedback

### 1. 500m 半径已经被边界值钉死

- `tests/world/test_city_pedestrian_audible_radius_boundary.gd`
  - `PASS x3`
  - 证明 `499.5m` 与 `500.0m` 都会触发 `panic / flee`
  - 证明 `500.5m` 保持 `reaction_state = none`

### 2. 4x 速度与跑满 500m 已被独立钉死

- `tests/world/test_city_pedestrian_flee_pathing.gd`
  - `PASS x3`
  - 断言逃散前 `1s` 位移达到 `4x base speed`
  - fresh 输出：`displacement_a_m = 500.000030517578`
  - fresh 输出：`displacement_b_m = 500.000030517578`
  - 断言 witness 最终停下前不会少跑于 `500m`

### 3. 枪声 / 爆炸的 world 与 live 链路都已经被重新验过

- `tests/world/test_city_pedestrian_wide_area_audible_threat.gd`
  - `PASS x3`
  - fresh 输出：gunshot / grenade witness 在约 `359.7069m` 触发
  - fresh 输出：outsider 在约 `522.4133m` 保持 calm
- `tests/e2e/test_city_pedestrian_live_wide_area_threat_chain.gd`
  - `PASS x3`
  - 证明真实玩家开枪与投雷链路里，`500m` 见证范围内会 panic/flee，而 `>500m` outsider 不会被误带入
- `tests/e2e/test_city_pedestrian_live_combat_chain.gd`
  - `PASS`
  - 证明 live projectile casualty / grenade kill + witness flee 链路继续成立

## Historical Status Before Closeout

- 截至 `2026-03-13`，`v6` 的 `M7` 仍处于 `in progress`，不得标记为 `done`。
- 当前结论不是“功能没做完”，而是“功能侧大体落地，但 fresh isolated performance closeout 还没过”。
- 在 fresh isolated profiling 重新变绿之前，不得把 `docs/plan/v6-index.md` 中的 `M7`、`REQ-0002-010`、`REQ-0002-011` 改成 `done`。

## Scope

- `REQ-0002-010`
- `REQ-0002-011`

## What Is Already Landed

### 1. Witness flee 行为已经落地

本轮已经把目击暴力后的 pedestrian 逃散行为推进到如下口径：

- gunshot、grenade explosion 与 casualty 都按 `500m` 半径传播
- panic / flee 的位移速度为 `4x base speed`
- flee 方向必须先远离 `player`
- witness 必须四散而逃，而不是同向挤成一束
- flee 至少跑出 `500m` 才允许停止

对应证据：

- `tests/world/test_city_pedestrian_flee_pathing.gd`
  - fresh `PASS`
  - 输出证据：`displacement_a_m = 500.000030517578`
  - 输出证据：`displacement_b_m = 500.000030517578`
- `tests/world/test_city_pedestrian_witness_flee_response.gd`
  - fresh `PASS`
  - 证明 direct-hit casualty 与 explosion / casualty witness ring 都会触发局部 `panic` / `flee`
- `tests/world/test_city_pedestrian_wide_area_audible_threat.gd`
  - fresh `PASS x3`
  - 证明 gunshot 声本身与 grenade / explosion 的 `500m` witness 生效，`>500m` outsider 保持 calm
- `tests/e2e/test_city_pedestrian_combat_flow.gd`
  - fresh `PASS`
  - 证明 mixed combat flow 下 witness flee 可见，且未扩大成全图 panic
- `tests/e2e/test_city_pedestrian_live_wide_area_threat_chain.gd`
  - fresh `PASS x3`
  - 证明真实手玩链路下 `500m / 4x / 500m` 行为不会在 live world 中丢失
- `tests/e2e/test_city_pedestrian_travel_flow.gd`
  - fresh `PASS`
  - 证明 mixed travel + combat 下 local casualty / witness panic 仍不破坏 travel continuity

### 2. Density uplift 行为已经落地

当前 `pedestrian_mode = lite` 的 density uplift 行为口径已经进入代码与测试：

- district floor：
  - `core >= 0.78`
  - `mixed >= 0.62`
  - `residential >= 0.46`
  - `industrial >= 0.30`
  - `periphery >= 0.16`
- road floor：
  - `arterial >= 0.45`
  - `secondary >= 0.32`
  - `collector >= 0.20`
  - `local >= 0.12`
  - `expressway_elevated = 0.0`

对应证据：

- `tests/world/test_city_pedestrian_density_profile.gd`
  - fresh `PASS`
- `tests/world/test_city_pedestrian_lite_density_uplift.gd`
  - fresh `PASS`
  - 输出证据：warm `tier1_count = 54`
- `tests/e2e/test_city_pedestrian_combat_flow.gd`
  - fresh `PASS`
- `tests/e2e/test_city_pedestrian_travel_flow.gd`
  - fresh `PASS`

## Historical Blocker Before Closeout

真正阻止 `M7` 收口的不是 flee / witness / density 的功能正确性，而是 fresh isolated performance closeout。

当前阻塞测试：

- `tests/e2e/test_city_pedestrian_performance_profile.gd`

`2026-03-13` 本轮 closeout 中的代表性 fresh 结果：

- warm report：
  - `wall_frame_avg_usec = 11966`
  - `ped_tier1_count = 50`
- first-visit report：
  - `wall_frame_avg_usec = 19208`
  - `update_streaming_avg_usec = 17965`
  - `ped_tier1_count = 62`
  - `ped_tier2_count = 4`

同一轮 closeout 里还出现过 warm spike：

- warm report：
  - `wall_frame_avg_usec = 17044`

这说明：

- `M7` 的主要红线风险集中在 `first-visit` 路径
- 问题核心是 crowd / streaming 的运行期开销，而不是 flee 逻辑本身
- 当前还不能诚实地说 `M7` 已完成

## Why M7 Was Not Marked Done

目前还不能把 `M7`、`REQ-0002-010`、`REQ-0002-011` 标完成，原因是以下闭环尚未成立：

1. `tests/e2e/test_city_pedestrian_performance_profile.gd` 还没有 fresh isolated `PASS`
2. `tests/e2e/test_city_runtime_performance_profile.gd` 还没有在本轮 `M7` closeout 中 fresh isolated 重新验绿
3. `docs/plan/v6-index.md`、`docs/plan/v6-pedestrian-witness-flee-response.md`、`docs/plan/v6-pedestrian-density-uplift.md` 还不能写完成态证据

## Engineering Decision For This Round

本轮决定明确如下：

- 不通过降低 flee 验收口径来换 profile 变绿
- 不通过把“远离 player / 四散而逃 / 至少 500m”打折来宣称 `REQ-0002-010` 完成
- 不通过回退 `core / mixed / arterial` 等 density floor 来伪造 `REQ-0002-011` 完成
- 不把当前 `v6-index` 改成完成态，直到 fresh isolated profiling 真正通过

## Expected Next Rounds Considered Before Closeout

当前判断：`M7` 大概率还需要 `2-3` 轮优化，才有机会诚实收口。

### Round 1: First-Visit 热点再定位

目标：

- 继续把 `first-visit` 的 wall-frame 热点拆清楚
- 明确 crowd update、resident sync、streaming mount、HUD / minimap 在 `M7` 路径上的真实占比

要求：

- 只接受 fresh isolated profiling 证据
- 不凭“看起来是 minimap”或“看起来是 density”做猜测式改动

### Round 2: 修根因，而不是压症状

目标：

- 在不降低 `M7` 行为口径的前提下，把 `first-visit` crowd / streaming 成本压回红线以内

优先方向：

- resident crowd first-visit 更新 / mount / commit 路径
- crowd runtime 与 chunk render 之间的同步成本

暂不接受的取巧方案：

- 直接回退 density floor
- 直接把 witness 行为做弱
- 直接把高成本 tier cap 当作唯一调参手段

### Round 3: 重新做 M7 Closeout

只有在以下条件都满足后，才允许做 `M7` 完成态写回：

1. `tests/e2e/test_city_pedestrian_performance_profile.gd` fresh isolated `PASS`
2. `tests/e2e/test_city_runtime_performance_profile.gd` fresh isolated `PASS`
3. 本轮功能回归继续保持为绿
4. 然后再把 `docs/plan/v6-index.md`、`REQ-0002-010`、`REQ-0002-011` 写成完成态

## Historical Pending Closeout Items

- fresh isolated `tests/e2e/test_city_pedestrian_performance_profile.gd`
- fresh isolated `tests/e2e/test_city_runtime_performance_profile.gd`
- 删除本轮 cluster 探针类 debug 脚本
- 把完成态证据写回 `docs/plan/v6-index.md`
- 把完成态证据写回 witness / density 两份 `M7` 子文档

## Bottom Line At That Time

closeout 前，`M7` 当时的真实状态是：

- flee / witness / density 需求主体已落地
- 但 `first-visit` performance 红线还没被 fresh isolated profiling 证实
- 所以本轮只能落“状态说明文档”，不能落“完成态文档”
