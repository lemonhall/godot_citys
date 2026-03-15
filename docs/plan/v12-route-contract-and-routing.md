# V12 Route Contract and Routing

## Goal

把当前 chunk-level `plan_macro_route()` 升级成正式 lane-based route contract，输出可供 minimap、HUD、瞬移和自动驾驶共用的 `route_result`。

## PRD Trace

- Direct: REQ-0006-004
- Consumer foundation: REQ-0006-005
- Consumer foundation: REQ-0006-007
- Guard / Cache / Performance: REQ-0006-008

## Dependencies

- 依赖 M2 已交付正式 `resolved_target / route_target_index / routable_anchor`。
- 本计划完成前，M4/M5 不允许把 HUD / auto-drive 建在旧 `plan_macro_route()` 或 chunk Manhattan 结果之上。

## Contract Freeze

- `route_result` 的正式最小字段冻结为：`route_id`、`origin_target_id`、`destination_target_id`、`snapped_origin`、`snapped_destination`、`polyline`、`steps`、`maneuvers`、`distance_m`、`estimated_time_s`、`reroute_generation`、`source_version`。
- `route_step / maneuver` 的正式最小字段冻结为：`turn_type`、`distance_to_next_m`、`road_name_from`、`road_name_to`、`world_anchor`、`instruction_short`。
- route planner 的唯一正式上游冻结为 `vehicle lane graph + intersection turn contract` 或其正式 driving graph 视图；不允许再派生第二套临时节点网。
- runtime `route cache` 冻结为内存 memoization：key 至少包含 `origin/destination anchor id + graph version + reroute_generation`；一旦 graph version 或 target 变化必须失效。
- 旧 `plan_macro_route()` 只允许保留兼容层，不得继续作为正式导航 consumer 的真源。

## Scope

做什么：

- 用 `vehicle lane graph + intersection turn contract` 构建正式 route planner
- 输出 `polyline + steps + maneuvers + snapped points + reroute_generation`
- 支持偏航重算
- 替换当前 chunk Manhattan 主链

不做什么：

- 不在本计划里完成全屏地图 UI
- 不在本计划里做复杂多候选路线展示

## Acceptance

1. 自动化测试必须证明：正式 route 不再只是 chunk-key 串，而是正式 `route_result` contract。
2. 自动化测试必须证明：route result 至少包含一个带 `turn_type` 与 `road_name` 的 maneuver step，并暴露 `snapped_origin/snapped_destination`。
3. 自动化测试必须证明：偏航后能生成新一代 route result，且 `reroute_generation` 正确递增。
4. 自动化测试必须证明：重复同参 route 查询存在 runtime cache/memoization contract，且 graph version / target 改变时会失效。
5. 自动化测试必须证明：route planner 消费的是 `vehicle lane graph` 或等价 driving graph，而不是另一套临时节点网。
6. 反作弊条款：不得通过继续复用 `CityMacroRouteGraph` 直线/Manhattan 目标、或在 HUD 现场猜 turn type 来宣称完成。

## Files

- Modify: `city_game/world/navigation/CityChunkNavRuntime.gd`
- Modify: `city_game/world/navigation/CityMacroRouteGraph.gd`
- Create: `city_game/world/navigation/CityRoutePlanner.gd`
- Create: `city_game/world/navigation/CityRouteContract.gd`
- Create: `city_game/world/navigation/CityRouteCache.gd`
- Modify: `city_game/world/vehicles/model/CityVehicleQuery.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Create: `tests/world/test_city_route_query_contract.gd`
- Create: `tests/world/test_city_route_reroute.gd`
- Create: `tests/world/test_city_route_result_cache.gd`
- Modify: `tests/e2e/test_city_navigation_flow.gd`
- Modify: `docs/plan/v12-index.md`

## Steps

1. 写失败测试（红）
   - `route contract / reroute / route cache / existing e2e navigation` 四类测试先写。
2. 运行到红
   - 预期失败点是当前 route 只有 chunk Manhattan 结果，没有正式 maneuvers。
3. 实现（绿）
   - 新建 `CityRoutePlanner` 与 route contract。
   - 新建 `CityRouteCache`，把 repeated query 的 runtime memoization 写硬。
   - 让 `CityChunkNavRuntime` 切到 lane-based solver。
   - 暴露 `plan_route()` 的 richer result，并保留旧接口兼容层直到 consumers 迁完。
4. 运行到绿
   - route tests 与 navigation e2e 通过。
5. 必要重构（仍绿）
   - `route_result`、`maneuver formatting`、`reroute policy` 分开。
6. E2E
   - 串行跑 `test_city_navigation_flow.gd` 与性能三件套中受影响部分。

## Risks

- 如果直接在 `CityPrototype` 里堆 route 逻辑，后续 map/HUD/autodrive 会持续耦合。
- 如果 route result 没有正式 `maneuvers`，HUD 最终一定会回到猜测式文本。
- 如果 reroute policy 不显式建模，manual driving 时的路线更新频率会失控。
- 如果 route cache key 没有绑定 graph version / reroute generation，导航会出现陈旧结果复用。
