# V12 Route Contract and Routing

## Goal

把当前 chunk-level `plan_macro_route()` 升级成正式 lane-based route contract，输出可供 minimap、HUD、瞬移和自动驾驶共用的 `route_result`。

## PRD Trace

- REQ-0006-004
- REQ-0006-005
- REQ-0006-007
- REQ-0006-008

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

1. 自动化测试必须证明：正式 route 不再只是 chunk-key 串。
2. 自动化测试必须证明：route result 至少包含一个带 `turn_type` 与 `road_name` 的 maneuver step。
3. 自动化测试必须证明：偏航后能生成新一代 route result。
4. 自动化测试必须证明：route planner 消费的是 `vehicle lane graph` 或等价 driving graph，而不是另一套临时节点网。
5. 反作弊条款：不得通过继续复用 `CityMacroRouteGraph` 直线/Manhattan 目标、或在 HUD 现场猜 turn type 来宣称完成。

## Files

- Modify: `city_game/world/navigation/CityChunkNavRuntime.gd`
- Modify: `city_game/world/navigation/CityMacroRouteGraph.gd`
- Create: `city_game/world/navigation/CityRoutePlanner.gd`
- Create: `city_game/world/navigation/CityRouteContract.gd`
- Modify: `city_game/world/vehicles/model/CityVehicleQuery.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Create: `tests/world/test_city_route_query_contract.gd`
- Create: `tests/world/test_city_route_reroute.gd`
- Modify: `tests/e2e/test_city_navigation_flow.gd`
- Modify: `docs/plan/v12-index.md`

## Steps

1. 写失败测试（红）
   - contract、reroute、existing e2e navigation 三类测试先写。
2. 运行到红
   - 预期失败点是当前 route 只有 chunk Manhattan 结果，没有正式 maneuvers。
3. 实现（绿）
   - 新建 `CityRoutePlanner` 与 route contract。
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
