# V8 Ambient Traffic Layered Runtime

## Goal

在 deterministic `vehicle_query` / lane graph 的基础上，建立和 pedestrian 类似但不复制实现的 layered traffic runtime：让城市在默认 `vehicle_mode = lite` 下出现可见车流，同时继续服从 chunk streaming、node budget 与 profile guard。

## PRD Trace

- REQ-0003-004
- REQ-0003-005
- REQ-0003-008
- REQ-0003-009

## Current Status

- `2026-03-14` 当前 `M2` 已被手玩反馈阻塞，不能按本文件的旧版 closeout 口径继续推进。
- 正式状态说明见：[v8-m2-handplay-feedback-and-replan.md](./v8-m2-handplay-feedback-and-replan.md)
- 本文件保留为 `M2` 原始 runtime 计划，但以下 acceptance / steps 已按最新 hand-play 结论重写；不得再把 `Tier 1 shadow`、白盒代理或仅靠 density 调参视为完成路径。

## Scope

做什么：

- 建立 `Tier 0-3` 车辆分层表示
- 建立 `CityVehicleBudget`、`CityVehicleStreamer`、`CityVehicleTierController`
- 建立 batched farfield traffic renderer 与近景 lightweight kinematic vehicles
- 输出 traffic profile breakdown 与 runtime node budget guard
- 把 travel flow、page cache、identity continuity 接成正式自动化链路

不做什么：

- 不做全时刚体海
- 不做玩家驾驶
- 不做复杂碰撞破坏或事故求解

## Acceptance

1. 默认 `vehicle_mode = lite` 下，Tier 1 `<= 4`、Tier 2 `<= 2`、Tier 3 `<= 1`，并且 `max_spawn_slots_per_chunk = 2`；同时必须通过更强的近距去重避免连环贴屁股与双车重叠。
2. 自动化测试与手玩验收必须共同证明：`Tier 1` 在中距离看起来仍然是车，不允许再使用显眼白盒或纯地面阴影替代车辆实体。
3. 自动化测试必须证明：`vehicle lane graph`、minimap/debug road snapshot、main scene road overlay 的 coverage 与位置对齐；默认手玩视角下不得出现“车沿草坪行驶但系统判定有路”的错位。
4. 自动化测试必须证明：玩家跨越至少 `8` 个 chunk 的 travel flow 中，不出现 traffic count leak、page cache 重复抖动或 spawn storm。
5. 自动化测试必须证明：profile 输出中存在 `veh_tier1_count`、`veh_tier2_count`、`veh_tier3_count`、`traffic_update_avg_usec`、`traffic_spawn_avg_usec`、`traffic_render_commit_avg_usec`。
6. 自动化测试与默认手玩视角必须共同证明：不会长期只剩单向车流、同模扎堆或贴屁股连环车成为常态。
7. 默认 `vehicle_mode = lite` 下，isolated e2e runtime warm / first-visit 仍需满足 `veh_tier1_count >= 1`，combined runtime `wall_frame_avg_usec <= 16667`；同时 hand-play 不允许出现“只要有车就稳定掉到 30-40 FPS”的产品级回退。
8. 反作弊条款：不得通过把车辆塞进不可见 tier、关闭 traffic renderer、降低 density 到近乎 `0`、只保留单向流量、或用 profiling 专用配置宣称完成。

## Files

- Create: `city_game/world/vehicles/streaming/CityVehicleBudget.gd`
- Create: `city_game/world/vehicles/streaming/CityVehicleStreamer.gd`
- Create: `city_game/world/vehicles/simulation/CityVehicleState.gd`
- Create: `city_game/world/vehicles/simulation/CityVehicleTierController.gd`
- Create: `city_game/world/vehicles/rendering/CityVehicleVisualCatalog.gd`
- Create: `city_game/world/vehicles/rendering/CityVehicleTrafficRenderer.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Create: `tests/world/test_city_vehicle_lod_contract.gd`
- Create: `tests/world/test_city_vehicle_batch_rendering.gd`
- Create: `tests/world/test_city_vehicle_streaming_budget.gd`
- Create: `tests/world/test_city_vehicle_page_cache.gd`
- Create: `tests/world/test_city_vehicle_identity_continuity.gd`
- Create: `tests/world/test_city_vehicle_runtime_node_budget.gd`
- Create: `tests/world/test_city_vehicle_profile_stats.gd`
- Create: `tests/e2e/test_city_vehicle_travel_flow.gd`
- Create: `tests/e2e/test_city_vehicle_performance_profile.gd`

## Steps

1. 写失败测试（红）
   - 先把 `lane graph -> minimap -> road overlay` coverage 对齐诊断、`vehicle_lod_contract`、`vehicle_batch_rendering`、`vehicle_streaming_budget`、`vehicle_runtime_node_budget`、`vehicle_profile_stats` 写成失败测试。
2. 运行到红
   - 失败原因必须明确落在“道路覆盖 consumer 脱节”或“当前没有 traffic runtime / renderer / budget guard”。
3. 实现（绿）
   - 先补道路 coverage diagnostics，并判清楚是 lane graph 走错，还是 road overlay 漏画。
   - 再建 vehicle state / budget / streamer。
   - 随后重做 `Tier 1` 可视策略，保证远中景仍然像车。
   - 最后补 profile 字段、distribution policy 与 node budget guard。
4. 运行到绿
   - world tests、coverage diagnostics 与 `test_city_vehicle_travel_flow.gd` 全部通过。
5. 必要重构（仍绿）
   - 避免 `CityVehicleTierController` 长成新的巨型总控类。
6. E2E
   - fresh isolated 串行跑 `test_city_vehicle_performance_profile.gd`，并与现有 `test_city_runtime_performance_profile.gd`、`test_city_first_visit_performance_profile.gd` 组合验证。
   - 通过后仍需回到默认手玩视角做最终 closeout，确认没有影子代理、草坪行驶、单向偏置和稳定 30-40 FPS 回退。

## Risks

- 如果 farfield traffic 不是 batched representation，车辆数量稍微上来就会比 pedestrian 更快打穿 runtime node budget。
- 如果 `lane graph / minimap / road overlay` 不是同一套道路 coverage consumer，车辆就会继续“逻辑上在路上、画面上在草坪上”。
- 如果 runtime 不走 page/cache，而是每次切 chunk 全量重建，first-visit cold path 会非常脆。
- 如果 traffic profile 不单独拆项，后续无法判断是 query、step 还是 render commit 在吃预算。
- 如果 `Tier 1` 继续采用白盒或纯阴影代理，哪怕 contract 全绿，也会被真实手玩直接否决。
- 如果默认 lite 车流密度、双向覆盖和同路段 spacing 脱离手玩体验约束，哪怕 contract 全绿，也会直接把真实帧率拖穿并制造“城市堵死”或“只剩单向车流”的错误观感。
