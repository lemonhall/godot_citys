# V34 Index

## 愿景

PRD 入口：

- [PRD-0023 Building Collapse Destruction Lab](../prd/PRD-0023-building-collapse-destruction-lab.md)
- [PRD-0001 Large City Foundation](../prd/PRD-0001-large-city-foundation.md)
- [PRD-0002 Pedestrian Crowd Foundation](../prd/PRD-0002-pedestrian-crowd-foundation.md)
- [PRD-0003 Vehicle Traffic Foundation](../prd/PRD-0003-vehicle-traffic-foundation.md)

依赖入口：

- [v22-index.md](./v22-index.md)
- [v33-index.md](./v33-index.md)

`v34` 的目标不是继续“凭体感猜炸楼为什么卡”，也不是把 `v22` 文档原地复用成另一件事，而是把建筑坍塌这条新玩法链的性能问题拆成一套正式、可重复、可对账的 profiling 守护：先在独立实验场景里量清楚 `炸前 / 炸裂瞬间 / 炸后残骸` 三段的 frame-time、FPS、draw/object 规模和 debris runtime 状态；再把同样的段式 profiling 扩展到主世界，连同 shared streaming / crowd / traffic 字段一起采样，最终回答主世界炸楼掉帧到底主要来自 debris 物理、阴影/绘制、还是 shared runtime 被拖慢。

## 决策冻结

- `v22` 只作为性能治理方法论参考，不回写、不并回、不改写 `v22` 既有 closeout 口径。
- `v34` 首先交付 profiling 与证据链，再根据 fresh 数据决定优化点；不允许先拍脑袋关阴影、砍碎块、缩清理时间来“试试看”。
- profiling 必须至少覆盖三段：
  - `pre_collapse`
  - `collapse_burst`
  - `post_collapse_settle`
- profiling 必须覆盖两条场景：
  - `BuildingCollapseLab`
  - `CityPrototype` 主世界近景 destructible building
- 这轮 closeout 的第一目标是“量测边界和主嫌疑归因”，不是直接承诺所有阈值一次性收口。
- profiling artifact 必须落盘到 `reports/v34/building_collapse/performance/`，不能只在聊天里描述。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 实验场炸楼分段 profiling | `BuildingCollapseLab` 的 `pre / burst / settle` 三段报告、artifact、debris telemetry | 自动化脚本输出可解析 JSON 报告，至少包含 wall-frame、FPS、draw/object、debris chunk/sleep/shadow 统计 | `tests/e2e/test_building_collapse_lab_performance_profile.gd` | done |
| M2 主世界炸楼分段 profiling | `CityPrototype` 近景建筑炸楼链 + shared runtime 指标归因 | 自动化脚本输出主世界 JSON 报告，三段都带 `update_streaming/crowd/traffic` 与渲染/碎块统计 | `tests/e2e/test_city_building_collapse_performance_profile.gd` | done |
| M3 首轮性能收口 | 基于 fresh profiling 的一轮真实优化 | 至少一项主嫌疑链被证据收敛并验证 before/after 改善，且不破坏 `v33` 坍塌功能 contract | `v34` profiling 两条 + `tests/world/test_building_collapse_lab_flow.gd` + `tests/world/test_city_main_world_building_collapse.gd` | doing |

## 计划索引

- [v34-building-collapse-performance-guard.md](./v34-building-collapse-performance-guard.md)
- [v34-m1-verification-2026-03-21.md](./v34-m1-verification-2026-03-21.md)

## 追溯矩阵

| Req ID | v34 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0023-004 | `v34-building-collapse-performance-guard.md` | `tests/world/test_building_collapse_lab_flow.gd` | `tests/e2e/test_building_collapse_lab_performance_profile.gd` | `reports/v34/building_collapse/performance/*.json` | todo |
| REQ-0023-005 | `v34-building-collapse-performance-guard.md` | `tests/world/test_building_collapse_lab_flow.gd` | `tests/e2e/test_building_collapse_lab_performance_profile.gd` | `reports/v34/building_collapse/performance/*.json` | todo |
| REQ-0023-006 | `v34-building-collapse-performance-guard.md` | `tests/world/test_city_main_world_building_collapse.gd` | `tests/e2e/test_city_building_collapse_performance_profile.gd` | `reports/v34/building_collapse/performance/*.json` | todo |
| REQ-0001-006 / REQ-0001-010 / REQ-0001-011 | `v34-building-collapse-performance-guard.md` | profiling structure assertions | `tests/e2e/test_city_building_collapse_performance_profile.gd` | `docs/plan/v34-mN-verification-YYYY-MM-DD.md` | todo |
| REQ-0002-007 / REQ-0002-016 / REQ-0003-009 | `v34-building-collapse-performance-guard.md` | profiling structure assertions | `tests/e2e/test_city_building_collapse_performance_profile.gd` | `docs/plan/v34-mN-verification-YYYY-MM-DD.md` | todo |

## Closeout 证据口径

- `v34` 不接受“我手感 FPS 掉了/好了”作为 closeout 证据。
- `v34` 的第一类证据是 `reports/v34/building_collapse/performance/` 下的 fresh JSON artifact。
- `v34` 的第二类证据是 `docs/plan/v34-mN-verification-YYYY-MM-DD.md` 中对 `pre / burst / settle` 三段数据的对账结论。
- 如果只完成实验场 profiling，没有主世界 profiling，则 `v34` 只能算 M1 完成，不能宣称炸楼性能问题已定位或已收口。

## ECN 索引

- 当前无。

## 差异列表

- `2026-03-21` fresh profiling 已建立实验场与主世界两条 segment-based artifact，路径冻结在 `reports/v34/building_collapse/performance/`。
- `2026-03-21` fresh 证据已把主世界炸楼首嫌疑压到 debris 自身，而不是 shared streaming：
  - `active_rendered_chunk_count` 维持 `25`
  - `multimesh_instance_total` 维持 `448`
  - `update_streaming_avg_usec` 仅在 `4027 -> 4149 -> 4213` 小幅波动
  - `crowd_update_avg_usec` 与 `traffic_update_avg_usec` 也仅小幅变化
- `2026-03-21` 首轮优化已完成：
  - debris 不再 1:1 持有 shadow caster
  - settle 窗口里 debris sleeping ratio 已从接近 `0` 提升到 `1.0`
- 但 `v34` 仍未 closeout：
  - 实验场 `Windows/Vulkan` 下仍基本贴着 `16.67ms` 红线
  - 主世界 `Windows/Vulkan` 下 `pre / burst / settle` 仍约 `17.46 / 18.60 / 18.81 ms`
  - 下一轮应优先处理“残骸视觉实例本身的持续成本”，以及“接近 rubble 时”的 focused traversal profile
