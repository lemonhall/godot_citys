# V34 Building Collapse Performance Guard

## Goal

把建筑坍塌性能问题从“主世界里感觉炸楼会卡，而且卡点不稳定”推进到“实验场和主世界都有正式的三段 profiling artifact，能明确回答卡顿主要集中在炸前、炸裂瞬间还是炸后残骸阶段，并能把主嫌疑压到 debris runtime、render/shadow 还是 shared streaming 链”。

## PRD Trace

- REQ-0023-004
- REQ-0023-005
- REQ-0023-006
- REQ-0001-006
- REQ-0001-010
- REQ-0001-011
- REQ-0002-007
- REQ-0002-016
- REQ-0003-009

## Dependencies

- `v22` 已冻结 shared runtime profiling 三件套与字段词典。
- `v33` 已把建筑伤害 / 预碎裂 / 坍塌 / 主世界接入功能链跑通。
- 现有性能接口依赖：
  - `CityPrototype.get_performance_profile()`
  - `CityPrototype.reset_performance_profile()`
  - `CityPrototype.get_streaming_snapshot()`
  - `CityPrototype.set_performance_diagnostics_enabled()`

## Scope

做什么：

- 为 `BuildingCollapseLab` 建立三段炸楼 profiling 报告与 artifact 输出
- 为 `CityPrototype` 主世界近景 destructible building 建立三段炸楼 profiling 报告与 artifact 输出
- 为建筑坍塌 runtime 增加只读 telemetry，至少覆盖 debris 的：
  - live rigid body 数量
  - sleeping 数量
  - mesh / collision 数量
  - shadow caster 数量
  - 线速度统计
- 在主世界 profiling 中把 shared runtime 字段一并采样，便于判断是不是 streaming/crowd/traffic 被连带拖慢
- 形成 fresh verification 文档，冻结首轮基线

不做什么：

- 本计划首轮不直接承诺某个固定 FPS 阈值已经达成
- 本计划首轮不引入新的破坏形态或新的建筑玩法
- 本计划首轮不靠直接削功能来“伪优化”
- 本计划首轮不修改 `v22` 既有 profiling 测试阈值

## Acceptance

1. `tests/e2e/test_building_collapse_lab_performance_profile.gd` 必须输出 JSON artifact，且三段 `pre_collapse / collapse_burst / post_collapse_settle` 全部存在。
2. 实验场 artifact 的每个 segment 至少包含：
   - `wall_frame_avg_usec`
   - `wall_frame_max_usec`
   - `fps_avg`
   - `fps_min`
   - `render_total_draw_calls_in_frame`
   - `render_total_objects_in_frame`
   - `dynamic_chunk_count`
   - `dynamic_chunk_sleeping_count`
   - `dynamic_chunk_shadow_caster_count`
3. `tests/e2e/test_city_building_collapse_performance_profile.gd` 必须输出主世界 JSON artifact，且三段 segment 全部存在。
4. 主世界 artifact 的每个 segment 除实验场字段外，还至少包含：
   - `update_streaming_avg_usec`
   - `update_streaming_renderer_sync_avg_usec`
   - `crowd_update_avg_usec`
   - `traffic_update_avg_usec`
   - `active_rendered_chunk_count`
   - `multimesh_instance_total`
5. 验证文档必须能够明确回答：
   - 卡顿主要是 `collapse_burst` 还是 `post_collapse_settle`
   - `dynamic_chunk_shadow_caster_count`、`dynamic_chunk_sleeping_count`、`render_total_draw_calls_in_frame` 与 `wall_frame_*` 是否同向变化
   - 主世界是否伴随 `update_streaming/crowd/traffic` 的同步抬升
6. 反作弊条款：不得通过减少碎块数量、缩短残骸存活时间、关闭主世界 crowd/traffic、关闭 shared streaming 采样、或只跑 headless dummy 报告就宣称问题已定位完成。

## Files

- Create: `docs/plan/v34-index.md`
- Create: `docs/plan/v34-building-collapse-performance-guard.md`
- Future Create: `docs/plan/v34-mN-verification-YYYY-MM-DD.md`
- Create: `tests/e2e/test_building_collapse_lab_performance_profile.gd`
- Create: `tests/e2e/test_city_building_collapse_performance_profile.gd`
- Modify: `city_game/combat/buildings/CityBuildingCollapseRuntime.gd`
- Optional Modify: `city_game/combat/buildings/CityDestructibleBuildingRuntime.gd`

## Segment Freeze

- `pre_collapse`
  - 定义：建筑已进入 `collapse_ready`，但尚未触发濒毁替换；用于量 intact/crack 状态下的近场成本
- `collapse_burst`
  - 定义：从触发濒毁打击开始，到 `collapsed` 且 debris 大量仍处于运动期的窗口
- `post_collapse_settle`
  - 定义：建筑已完成坍塌，残骸仍保留但大部分已接近静止，清理尚未发生

## Steps

1. Analysis
   - 审计 `v22` profiling 模板、`v33` 建筑坍塌 runtime 和现有 debug state。
   - 明确要采的边界字段，不先猜优化点。
2. Design
   - 选用 `music_road` 风格的 segment artifact，而不是只打印一条总平均值。
   - 把实验场与主世界两条 profiling 链分开，避免主世界 shared runtime 干扰实验场因果。
3. Plan
   - 建立 `v34-index.md` 与本计划文档。
4. TDD Red
   - 新增实验场 profiling 脚本并先跑红，证明当前缺少固定 artifact 与 debris telemetry。
   - 新增主世界 profiling 脚本并先跑红，证明当前缺少主世界炸楼分段报告。
5. TDD Green
   - 为坍塌 runtime 增加只读 telemetry。
   - 实现两条 profiling 脚本、artifact 写盘与结构断言。
6. Refactor
   - 只保留长期有用的只读 telemetry；不残留临时探针。
7. E2E
   - 运行实验场 profiling。
   - 运行主世界 profiling。
   - 补跑 `tests/world/test_building_collapse_lab_flow.gd` 与 `tests/world/test_city_main_world_building_collapse.gd`。
8. Review
   - 把 fresh 报告写回 `v34-mN-verification-YYYY-MM-DD.md`。
9. Ship
   - 文档 / test / instrumentation / verification 分 slice 提交。

## Risks

- 如果只看实验场，可能误判主世界卡顿不是 debris 自身，而是 debris 激活后拖高了 shared runtime。
- 如果只看主世界总平均值，可能看不出真正的 burst 发生在坍塌替换瞬间，还是 30 秒残骸存活期间。
- 如果 telemetry 不记录 sleeping / shadow / draw-call 这些直接线索，后续仍会回到猜阴影、猜物理的老路。
