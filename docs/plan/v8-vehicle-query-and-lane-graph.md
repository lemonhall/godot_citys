# V8 Vehicle Query And Lane Graph

## Goal

基于 `v7` 已经收口的 shared road semantics，建立 deterministic 的 `vehicle_query` 与 drivable lane / turn graph，让车辆系统的数据真源正式落在 `road_graph` contract 上，而不是退回到 chunk 几何现场猜测。

## PRD Trace

- REQ-0003-002
- REQ-0003-003
- REQ-0003-006

## Scope

做什么：

- 建立 `CityVehicleConfig.gd`
- 建立 `CityVehicleLaneGraph.gd` 与 `CityVehicleQuery.gd`
- 从 `section_semantics.lane_schema` 派生 drivable lane
- 从 `intersection_type`、`ordered_branches`、`branch_connection_semantics` 派生 turn contract
- 输出按 chunk / rect 查询的 deterministic spawn slot 与 roster signature

不做什么：

- 不做玩家驾驶控制
- 不做 traffic signal phase 系统
- 不做高级变道、超车与事故绕行

## Acceptance

1. 固定 seed 下，`vehicle_query` 的 `lane_ids`、`spawn_slot_ids`、roster signature 连续两次运行完全一致。
2. 自动化测试必须证明：vehicle lane graph 只消费 shared road semantics，不依赖 chunk 侧随机 spline 或临时局部路段猜测。
3. 自动化测试必须证明：交叉口至少提供 `straight / left_turn / right_turn / u_turn` 四类基础 turn contract。
4. 自动化测试必须证明：spawn anchor 只落在 drivable lane，不落到 sidewalk / crossing lane。
5. 反作弊条款：不得通过复用 render mesh 几何或 surface mask 直接反推 lane，当成正式 world contract。

## Files

- Create: `city_game/world/vehicles/model/CityVehicleConfig.gd`
- Create: `city_game/world/vehicles/model/CityVehicleLaneGraph.gd`
- Create: `city_game/world/vehicles/model/CityVehicleQuery.gd`
- Create: `city_game/world/vehicles/generation/CityVehicleWorldBuilder.gd`
- Modify: `city_game/world/generation/CityWorldGenerator.gd`
- Modify: `city_game/world/model/CityRoadGraph.gd`
- Create: `tests/world/test_city_vehicle_world_model.gd`
- Create: `tests/world/test_city_vehicle_lane_graph.gd`
- Create: `tests/world/test_city_vehicle_query_chunk_contract.gd`
- Create: `tests/world/test_city_vehicle_intersection_turn_contract.gd`
- Create: `tests/world/test_city_vehicle_headway_contract.gd`

## Steps

1. 写失败测试（红）
   - 先把 `vehicle_world_model`、`vehicle_lane_graph`、`vehicle_query_chunk_contract`、`vehicle_intersection_turn_contract` 写成失败测试。
2. 运行到红
   - 失败原因必须明确落在“当前还没有正式 vehicle query / lane graph / turn contract”。
3. 实现（绿）
   - 先建 config 和 query schema。
   - 再从 `road_graph` 语义 contract 派生 drivable lane / turn links。
   - 最后补 deterministic spawn slot 与 roster signature。
4. 运行到绿
   - 上述 world tests 全部通过，且不需要实例化 `CityPrototype.tscn` 才能查询 vehicle world data。
5. 必要重构（仍绿）
   - 收敛 schema 命名，避免 future `vehicle_query` 与 `pedestrian_query` 的口径漂移。
6. E2E
   - 本阶段以 world / integration contract 为主，不单独要求运行期 E2E。

## Risks

- 如果 lane / turn graph 不是 shared road semantics 的正式 consumer，`v8` 会回到“几何看着像有路，但系统不知道怎么开”的旧问题。
- 如果 turn contract 只到 `intersection_type` 而没有 branch-level turn link，运行时车辆会被迫再次猜转向。
- 如果 query schema 不稳定，后续 layered runtime 与 renderer 会一起漂。
