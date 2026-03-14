# V8 Ambient Traffic Layered Runtime

## Goal

在 deterministic `vehicle_query` / lane graph 的基础上，建立和 pedestrian 类似但不复制实现的 layered traffic runtime：让城市在默认 `vehicle_mode = lite` 下出现可见车流，同时继续服从 chunk streaming、node budget 与 profile guard。

## PRD Trace

- REQ-0003-004
- REQ-0003-005
- REQ-0003-008
- REQ-0003-009

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

1. 默认 `vehicle_mode = lite` 下，Tier 1 `<= 160`、Tier 2 `<= 48`、Tier 3 `<= 12`。
2. 自动化测试必须证明：Tier 1 使用 batched representation，不把每台 farfield 车辆做成复杂节点树。
3. 自动化测试必须证明：玩家跨越至少 `8` 个 chunk 的 travel flow 中，不出现 traffic count leak、page cache 重复抖动或 spawn storm。
4. 自动化测试必须证明：profile 输出中存在 `veh_tier1_count`、`veh_tier2_count`、`veh_tier3_count`、`traffic_update_avg_usec`、`traffic_spawn_avg_usec`、`traffic_render_commit_avg_usec`。
5. 自动化测试必须证明：默认 `vehicle_mode = lite` 下，isolated e2e runtime warm / first-visit `veh_tier1_count >= 48`，且 combined runtime `wall_frame_avg_usec <= 16667`。
6. 反作弊条款：不得通过把车辆塞进不可见 tier、关闭 traffic renderer、降低 density 到近乎 `0`、或用 profiling 专用配置宣称完成。

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
   - 先把 `vehicle_lod_contract`、`vehicle_batch_rendering`、`vehicle_streaming_budget`、`vehicle_runtime_node_budget`、`vehicle_profile_stats` 写成失败测试。
2. 运行到红
   - 失败原因必须明确落在“当前没有 traffic runtime / renderer / budget guard”。
3. 实现（绿）
   - 先建 vehicle state / budget / streamer。
   - 再接 tier controller 与 renderer。
   - 最后补 profile 字段与 node budget guard。
4. 运行到绿
   - world tests 与 `test_city_vehicle_travel_flow.gd` 全部通过。
5. 必要重构（仍绿）
   - 避免 `CityVehicleTierController` 长成新的巨型总控类。
6. E2E
   - fresh isolated 串行跑 `test_city_vehicle_performance_profile.gd`，并与现有 `test_city_runtime_performance_profile.gd`、`test_city_first_visit_performance_profile.gd` 组合验证。

## Risks

- 如果 farfield traffic 不是 batched representation，车辆数量稍微上来就会比 pedestrian 更快打穿 runtime node budget。
- 如果 runtime 不走 page/cache，而是每次切 chunk 全量重建，first-visit cold path 会非常脆。
- 如果 traffic profile 不单独拆项，后续无法判断是 query、step 还是 render commit 在吃预算。
