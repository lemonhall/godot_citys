# ECN-0017: M11 Full-Stack Layered Runtime Replan

## 基本信息

- **ECN 编号**：ECN-0017
- **关联 PRD**：PRD-0002
- **关联 Req ID**：REQ-0002-003、REQ-0002-004、REQ-0002-006、REQ-0002-007、REQ-0002-010、REQ-0002-012、REQ-0002-013、REQ-0002-014、REQ-0002-015、REQ-0002-016
- **发现阶段**：`v6 M10` runtime profiling / 架构复盘阶段
- **日期**：2026-03-14

## 变更原因

`M10` 当前 fresh 证据已经证明：默认 `lite` 下的 `>=250` density target、warm runtime redline、`inspection` 高速穿行和 live gunshot panic chain 这几项可以同时成立；但 first-visit 冷路径仍不稳定守住 `16.67ms/frame`，而且当前 crowd tiering 更偏向“显示层分层”，还没有升级成“simulation / assignment / threat / render commit 全栈分层”。

这带来两个直接问题：

1. 继续按旧 `M11` 直接做 nearfield fidelity 重回归，会把真实模型、inspection、death visual 再次绑定在当前中央 CPU 调度链上，等于在 remaining cold-path blocker 尚未收口前继续加重耦合。
2. 用户已经明确把未来城市目标指向“保留当前人口密度，同时还要给真实建筑与车辆系统留预算”。在这种前提下，`M11` 如果仍只是 fidelity 回归，而不先解决全栈分层，就会把未来扩展成本继续锁死在当前 runtime 形态里。

因此，旧 `M11` 的职责顺序需要调整：先做全栈分层 runtime，再在这个新 runtime 上重挂 nearfield fidelity。

## 变更内容

### 原设计

- `ECN-0013` 把 `M11` 定义为：在 `M10` 新 runtime 上重验真模型、尺度、inspection、violent reaction、death visual 等 nearfield fidelity。
- `REQ-0002-012/013/014/015` 的最终收口点直接顺延到旧 `M11`。

### 新设计

- `M11` 重新定义为：**full-stack layered crowd runtime**。目标不是再做一轮“只改显示表现”的 tiering，而是把 farfield / midfield / nearfield 在 simulation、assignment、threat routing、snapshot / commit 上彻底拆层，先把当前 first-visit cold-path blocker 和未来车辆/真实建筑扩展的耦合风险压下去。
- 旧 `M11` 的 nearfield fidelity 重回归整体顺延为 `M12`。`REQ-0002-012/013/014/015` 不删除、不降级，只是把最终收口点从旧 `M11` 顺延到 `M12`。
- `M11` 的核心 DoD 补充为：
  - first-visit 冷路径必须成为显式 gate，而不是只看 warm profile；
  - profiling 必须能区分 farfield / midfield / nearfield 或等价 simulation layer 的数量与耗时；
  - 不能继续让 farfield 页面默认走近场级 threat / snapshot / commit 热路径；
  - 必须在默认 `lite >= 250` 与既有真实场景红线不退化的前提下完成。
- `M12` 的核心 DoD 不变：在 `M11` 的 layered runtime 上重新托住真实模型、尺度、inspection isolation、violent-state continuity、death visual persistence。

## 影响范围

- 受影响的 Req ID：
  - REQ-0002-003
  - REQ-0002-004
  - REQ-0002-006
  - REQ-0002-007
  - REQ-0002-010
  - REQ-0002-012
  - REQ-0002-013
  - REQ-0002-014
  - REQ-0002-015
  - REQ-0002-016
- 受影响的 vN 计划：
  - `docs/plan/v6-index.md`
  - `docs/plan/v6-pedestrian-density-preserving-runtime-recovery.md`
  - `docs/plan/v6-pedestrian-handplay-closeout.md`
  - `docs/plan/v6-pedestrian-full-stack-layered-runtime.md`
  - `docs/plan/v6-pedestrian-nearfield-fidelity-restabilization-after-layered-runtime.md`
- 受影响的测试：
  - `tests/e2e/test_city_first_visit_performance_profile.gd`
  - `tests/e2e/test_city_pedestrian_performance_profile.gd`
  - `tests/e2e/test_city_runtime_performance_profile.gd`
  - `tests/e2e/test_city_pedestrian_high_speed_inspection_performance.gd`
  - `tests/e2e/test_city_pedestrian_live_gunshot_performance.gd`
  - 以及 `M12` 对 nearfield fidelity 相关的既有 world / e2e tests
- 受影响的代码文件：
  - `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
  - `city_game/world/pedestrians/streaming/CityPedestrianStreamer.gd`
  - `city_game/world/pedestrians/simulation/CityPedestrianReactionModel.gd`
  - `city_game/world/pedestrians/simulation/CityPedestrianState.gd`
  - `city_game/world/rendering/CityChunkRenderer.gd`
  - `city_game/scripts/CityPrototype.gd`
  - 以及 `M12` 对近景 fidelity 相关的既有视觉 / 反应文件

## 处置方式

- [x] PRD 已检查：需求口径保持不变，无需改写 Req 内容
- [x] v6 计划已同步更新
- [x] 追溯矩阵已同步更新
- [ ] 相关测试已同步更新
