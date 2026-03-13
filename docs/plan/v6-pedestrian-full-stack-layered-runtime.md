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
2. 本计划所有 DoD 都绑定可重复命令：`tests/world/test_city_pedestrian_simulation_layer_contract.gd`、`tests/world/test_city_pedestrian_farfield_budget.gd`、`tests/world/test_city_pedestrian_midfield_assignment_budget.gd`、`tests/world/test_city_pedestrian_layered_threat_runtime.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd`、`tests/e2e/test_city_pedestrian_performance_profile.gd`、`tests/e2e/test_city_runtime_performance_profile.gd`、`tests/e2e/test_city_pedestrian_high_speed_inspection_performance.gd`、`tests/e2e/test_city_pedestrian_live_gunshot_performance.gd`。
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
