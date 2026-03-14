# V6 Pedestrian Full-Stack Layered Runtime

## Goal

在 `M10` 已经把默认 `lite` 平台重新托回 `>=250` density + warm/runtime real-scenario redline 的基础上，把当前更偏“显示层分层”的 crowd runtime，升级成覆盖 simulation、assignment、threat routing、snapshot / render commit 的 **全栈分层 runtime**。目标不是单纯再抠几毫秒，而是把 first-visit 冷路径、未来真实建筑和车辆系统会争抢的 CPU 热区，从架构上拆开。

## PRD Trace

- REQ-0002-003
- REQ-0002-004
- REQ-0002-006
- REQ-0002-007
- REQ-0002-010
- REQ-0002-016

## Scope

做什么：

- 把 farfield / midfield / nearfield 从“主要体现在渲染表示”升级为“simulation / assignment / threat / commit 都各自有预算和职责”的分层 runtime
- 让 farfield crowd 不再默认吃近场级 threat routing、snapshot rebuild、dirty commit
- 把 first-visit 冷路径正式并入 `M11` gate，要求在默认 `lite` 与当前 active density 合同下继续守住 `16.67ms/frame`
- 保持 `M10` 已拿到的 density、`inspection` 高速穿行、live gunshot panic chain 不退化
- 输出 layer-aware profiling 字段，证明 runtime 热点已经按层拆开，而不是仍由中央 CPU 调度链一锅端

不做什么：

- 不在本计划里做最终 nearfield fidelity 回归，它们顺延到 `M12`
- 不在本计划里引入车辆玩法、交通规则、wanted system 或 citywide rumor 等新玩法
- 不在本计划里直接做 GPU / compute 迁移；如需原型，只能作为后续增量 ECN
- 不通过降低默认人口、缩小暴力半径、关闭 inspection、关闭真模型链路来伪造 headroom

## DoD 硬度自检

1. 本计划所有 DoD 都可二元判定：layer contract、first-visit redline、real-scenario regression、profiling 字段存在性与数量级都可直接断言。
2. 本计划所有 DoD 都绑定可重复命令：`tests/world/test_city_pedestrian_simulation_layer_contract.gd`、`tests/world/test_city_pedestrian_farfield_budget.gd`、`tests/world/test_city_pedestrian_midfield_assignment_budget.gd`、`tests/world/test_city_pedestrian_layered_threat_runtime.gd`、`tests/world/test_city_pedestrian_layered_event_ttl.gd`、`tests/world/test_city_pedestrian_farfield_assignment_release.gd`、`tests/world/test_city_pedestrian_farfield_step_scheduler.gd`、`tests/world/test_city_pedestrian_nearfield_traversal_assignment_scheduler.gd`、`tests/world/test_city_pedestrian_farfield_render_commit.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd`、`tests/e2e/test_city_pedestrian_performance_profile.gd`、`tests/e2e/test_city_runtime_performance_profile.gd`、`tests/e2e/test_city_pedestrian_high_speed_inspection_performance.gd`、`tests/e2e/test_city_pedestrian_live_gunshot_performance.gd`。
3. 反作弊条款明确：不得通过把更多人塞进不可见 tier、改成 profiling 专用低密度、屏蔽 threat 广播、只在 warm route 过线、或完全冻结 farfield crowd 来宣称完成。
4. 本计划边界明确：它是 runtime layering 升级，不是 fidelity 收口，也不是车辆功能实现。

## Acceptance

1. 自动化测试必须证明：runtime profile 显式输出 `crowd_farfield_count`、`crowd_midfield_count`、`crowd_nearfield_count`、`crowd_farfield_step_usec`、`crowd_midfield_step_usec`、`crowd_nearfield_step_usec`、`crowd_assignment_rebuild_usec`、`crowd_threat_broadcast_usec` 或等价稳定字段。
2. 自动化测试必须证明：位于 violent outer ring 之外且未被 promotion 的 farfield crowd，不再每帧进入近场级 reaction / snapshot rebuild / render commit 热路径。
3. 自动化测试必须证明：nearfield 高成本集合仍受固定预算控制，不能随着 `tier1_count` 或 first-visit cold path 一起线性膨胀。
4. 自动化测试必须证明：`tests/e2e/test_city_first_visit_performance_profile.gd`、`tests/e2e/test_city_pedestrian_performance_profile.gd` 的 first-visit 结果，在默认 `lite` 且 `ped_tier1_count >= 250` 的同一配置下继续满足 `wall_frame_avg_usec <= 16667`。
5. 自动化测试必须证明：`tests/e2e/test_city_runtime_performance_profile.gd`、`tests/e2e/test_city_pedestrian_high_speed_inspection_performance.gd`、`tests/e2e/test_city_pedestrian_live_gunshot_performance.gd` 继续 `PASS`，不得因为 layering 升级而回退 `inspection` 非误触发或 live gunshot 局部 panic 合同。
6. 反作弊条款：不得通过回退 `M10` 已拿到的 density / threat / scenario 口径，或把 nearfield fidelity 整体关掉，来宣称 `M11` 完成。

## Files

- Modify: `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
- Modify: `city_game/world/pedestrians/streaming/CityPedestrianStreamer.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianReactionModel.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianState.gd`
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `city_game/world/pedestrians/rendering/CityPedestrianCrowdRenderer.gd`
- Modify: `city_game/world/pedestrians/rendering/CityPedestrianCrowdBatch.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Create: `city_game/world/pedestrians/simulation/CityPedestrianLayeredScheduler.gd`
- Create: `city_game/world/pedestrians/simulation/CityPedestrianFarfieldRuntime.gd`
- Create: `city_game/world/pedestrians/simulation/CityPedestrianMidfieldRuntime.gd`
- Create: `city_game/world/pedestrians/simulation/CityPedestrianNearfieldRuntime.gd`
- Create: `tests/world/test_city_pedestrian_simulation_layer_contract.gd`
- Create: `tests/world/test_city_pedestrian_farfield_budget.gd`
- Create: `tests/world/test_city_pedestrian_midfield_assignment_budget.gd`
- Create: `tests/world/test_city_pedestrian_layered_threat_runtime.gd`
- Create: `tests/world/test_city_pedestrian_layered_event_ttl.gd`
- Create: `tests/world/test_city_pedestrian_farfield_assignment_release.gd`
- Create: `tests/world/test_city_pedestrian_farfield_step_scheduler.gd`
- Create: `tests/world/test_city_pedestrian_nearfield_traversal_assignment_scheduler.gd`
- Create: `tests/world/test_city_pedestrian_farfield_render_commit.gd`
- Verify: `tests/e2e/test_city_first_visit_performance_profile.gd`
- Verify: `tests/e2e/test_city_pedestrian_performance_profile.gd`
- Verify: `tests/e2e/test_city_runtime_performance_profile.gd`
- Verify: `tests/e2e/test_city_pedestrian_high_speed_inspection_performance.gd`
- Verify: `tests/e2e/test_city_pedestrian_live_gunshot_performance.gd`

## Steps

1. 写失败测试（红）
   - 先把 simulation layer contract、farfield budget、midfield assignment、layered threat runtime 的断言写成失败测试，并把 first-visit redline 作为必须保留的端到端 gate。
2. 跑到红
   - 失败原因必须明确落在“当前 crowd 仍由中央 CPU 链统一调度、farfield 仍被近场热路径拖着走”上，不能接受空壳测试或 missing-field 假红。
3. 实现（绿）
   - 先拆 layer-aware profile 字段。
   - 再把 farfield / midfield / nearfield 的 step、assignment rebuild、threat routing、snapshot commit 分离。
   - 再把 first-visit 冷路径与 existing real-scenario regression 一起重新守回红线。
4. 跑到绿
   - layer contract / farfield budget / midfield assignment / layered threat runtime / first-visit profile / runtime scenarios 全部 PASS。
5. 必要重构（仍绿）
   - 收敛 runtime layer 边界，避免 `TierController` 继续长成新的总控巨类。
6. E2E / Profiling
   - fresh isolated 串行重跑 `test_city_first_visit_performance_profile.gd`、`test_city_pedestrian_performance_profile.gd`、`test_city_runtime_performance_profile.gd`、`test_city_pedestrian_high_speed_inspection_performance.gd`、`test_city_pedestrian_live_gunshot_performance.gd`。

## Risks

- 如果 farfield 只是换了名字，实际仍在参与近场 threat / snapshot rebuild，`M11` 会再次沦为“更复杂但没更快”的假分层。
- 如果 first-visit 冷路径的主要热点其实仍在世界 / streaming mount，而不是 crowd 分层本身，`M11` 需要与 chunk streaming 热点联动，否则难以单独收口。
- 如果 nearfield fidelity 继续和 runtime layering 混写，`M12` 还会再次被拖回主线程热路径。

## Progress Notes

- 2026-03-14 当前切片已落地 layered runtime 的 threat / assignment / farfield dirty-commit 基线，并补上了 `layered_event_ttl`、`farfield_assignment_release`、`farfield_step_scheduler` 三个退出期/调度期回归，避免只证明“激活期正确”。
- 2026-03-14 当前切片还修正了 4 个具体运行时问题：
  1. threat event 在 `threat_candidate_states` 为空或 assignment 复用早退时也会继续老化；
  2. `yield/sidestep` 这类近身临时反应在离开 nearfield 后会于 demote 时清空，不再拖尾污染 farfield/midfield；
  3. inspection 模式不再把玩家 `200m` core 直接并入 midfield assignment/threat hot path；
  4. farfield step 从整批突刺改成分桶轮转，避免同一帧整批 Tier 1 farfield 一起跳动。
- 2026-03-14 收口阶段新增 `test_city_pedestrian_nearfield_traversal_assignment_scheduler.gd`，专门钉住“same-window + nearfield present + layer counts stable”时不得每帧 full assignment/snapshot rebuild，防止 first-visit 冷路径只靠 profile 碰运气转绿。
- 2026-03-14 最终实现补了两条 runtime 收口线：
  1. `nearfield/midfield` 存在时，同 chunk-window 的 small-move traversal 允许复用 layered assignment，不再被 `0.01m` 阈值逼回每帧全量 rebuild；
  2. farfield runtime 继续分桶推进逻辑步进，但不再把每次 farfield step 都直接放大成 chunk render dirty commit。
- 2026-03-14 提交前 review 收口又补了 3 条硬 guard：
  1. farfield render dirty 现在显式区分为 `farfield-only dirty`，steady-state 仍会在完整 farfield cycle 后 commit，可视 Tier 1 不再冻结；但在 streaming backlog / 高速 traversal 期间，renderer 会暂缓这类纯 farfield refresh，避免 first-visit cold-path 被额外抢占；
  2. assignment rebuild 只要真的进入 rebuild 分支，就会记录 `crowd_assignment_rebuild_usec`，即使最终 candidate set 回到 `0`；
  3. `get_layer_state_ids()` 与 `nearfield_traversal_assignment_scheduler` 现在会直接比较 `midfield/nearfield/assignment` 成员集，而不再只看 count。
- 2026-03-14 fresh world 证据：`test_city_pedestrian_simulation_layer_contract.gd`、`test_city_pedestrian_midfield_assignment_budget.gd`、`test_city_pedestrian_farfield_budget.gd`、`test_city_pedestrian_layered_threat_runtime.gd`、`test_city_pedestrian_layered_event_ttl.gd`、`test_city_pedestrian_farfield_assignment_release.gd`、`test_city_pedestrian_farfield_step_scheduler.gd`、`test_city_pedestrian_nearfield_traversal_assignment_scheduler.gd`、`test_city_pedestrian_identity_continuity.gd`、`test_city_pedestrian_inspection_mode_non_threat.gd`、`test_city_pedestrian_density_order_of_magnitude.gd` 均已本地 headless `PASS`；默认 `lite` density 继续满足 world warm `326` / first-visit `270`。
- 2026-03-14 fresh world 证据已补强 renderer 守护：`test_city_pedestrian_farfield_render_commit.gd`、`test_city_pedestrian_chunk_dirty_skip.gd`、`test_city_pedestrian_batch_rendering.gd`、`test_city_pedestrian_sustained_fire_reaction.gd` 也都本地 headless `PASS`，证明这次 farfield dirty cadence 收口没有把 Tier 1 steady-state commit、stable clean skip、batch 输出或持续枪火状态机打回去。
- 2026-03-14 latest fresh isolated e2e 证据：
  1. `test_city_first_visit_performance_profile.gd` `PASS`，`wall_frame_avg_usec = 13804`，`update_streaming_avg_usec = 12979`，`streaming_prepare_profile_avg_usec = 4100`，`streaming_mount_setup_avg_usec = 4775`；
  2. `test_city_pedestrian_performance_profile.gd` `PASS`，warm `wall_frame_avg_usec = 8135`、first-visit `wall_frame_avg_usec = 15717`，且 `ped_tier1_count = 287 / 270`；
  3. `test_city_runtime_performance_profile.gd` `PASS`，warm `wall_frame_avg_usec = 8191`；
  4. `test_city_pedestrian_high_speed_inspection_performance.gd` `PASS`，`wall_frame_avg_usec = 12561`；
  5. `test_city_pedestrian_live_gunshot_performance.gd` `PASS`，`wall_frame_avg_usec = 10356`。
- 2026-03-14 以上 fresh world + isolated e2e 证据已经同时证明：layer contract、same-window reuse、farfield scheduler、density floor、first-visit cold-path 与两条真实场景红线在同一工作区成立，因此 `M11` 现已完成，不再保留 blocker。
