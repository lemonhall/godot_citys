# V2 Chunk Streaming

## Goal

把城市运行时从“单场景常驻”升级为“玩家在普通/高速巡检模式下周围有限窗口活跃”，建立大城市底盘最关键的生命周期约束。

## PRD Trace

- REQ-0001-003
- REQ-0001-006

## Scope

做什么：

- 计算玩家所在 chunk
- 维护 `5x5` 高成本活跃窗口
- 提供后台准备 + 主线程挂载的 chunk 生命周期
- 输出 debug 指标：当前 chunk、活跃 chunk 数、最近 prepare / mount 耗时

不做什么：

- 不做最终资源预取策略
- 不做多人同步
- 不做车辆或 NPC streaming

## Acceptance

1. 任意时刻高成本活跃 chunk 数 `<= 25`。
2. 自动化 travel 测试中，玩家在普通或高速巡检模式下跨越至少 8 个 chunk 时，不能出现重复加载同一 chunk ID、卸载遗漏或空节点引用。
3. debug 输出必须包含 `current_chunk_id`、`active_chunk_count` 和至少一个耗时字段。
4. 反作弊条款：禁止通过锁死玩家位置、关闭 chunk 切换或只加载一个 chunk 来满足上限。

## Files

- Create: `city_game/world/streaming/CityChunkKey.gd`
- Create: `city_game/world/streaming/CityChunkStreamer.gd`
- Create: `city_game/world/streaming/CityChunkLifecycle.gd`
- Create: `city_game/world/debug/CityDebugOverlay.gd`
- Create: `tests/world/test_city_chunk_streamer.gd`
- Create: `tests/world/test_city_debug_overlay.gd`
- Create: `tests/e2e/test_city_travel_streaming_flow.gd`
- Modify: `city_game/scripts/PlayerController.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/scenes/CityPrototype.tscn`

## Steps

1. 写失败测试（红）
   - `test_city_chunk_streamer.gd` 断言玩家坐标变化会导致活跃 chunk 集合变化，且集合大小不超过 25。
   - `test_city_debug_overlay.gd` 断言 debug 输出字段齐全。
   - `test_city_travel_streaming_flow.gd` 模拟玩家直线 travel 并记录 chunk 迁移日志。
2. 跑到红
   - 运行三个测试脚本，预期 FAIL，原因是 streamer 和 overlay 尚不存在。
3. 实现（绿）
   - 建立 chunk key、活跃窗口计算、生命周期状态机和 debug overlay。
   - 让 `CityPrototype` 使用 streamer 驱动近区 chunk 的进入和退出。
4. 跑到绿
   - world 测试与 travel streaming 测试均输出 `PASS`。
5. 必要重构（仍绿）
   - 把 `prepare`、`mount`、`retire` 事件统一成稳定日志格式，供 E2E 解析。
6. E2E 测试
   - 重跑 `tests/e2e/test_city_travel_streaming_flow.gd`，确认跨 chunk travel 日志完整。

## Risks

- 如果 streamer 在主线程里直接重建大量 chunk 节点，会导致明显卡顿。
- debug 输出格式如果不稳定，后续 trace matrix 很难落证据。
- 如果 streaming 不能在高速巡检模式下保持稳定，人工大范围验收会很低效。
