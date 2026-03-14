# V8 Pedestrian Vehicle Conflict Guard

## Goal

让 `v8` 的车辆系统与现有行人系统形成最小必要但正式的人车关系：车辆不再把 crossing candidate 当空气，行人也不因为车辆引入而失去既有的 lane / spawn / redline contract。

## PRD Trace

- REQ-0003-007
- REQ-0003-008
- REQ-0003-009

## Scope

做什么：

- 为 nearfield 车辆建立 crossing yield contract
- 让 traffic 与 pedestrian 共用同一份 road / crossing 语义真源
- 为人车共存补 profile / budget guard
- 把 warm / first-visit / real-scenario 的同配置红线写硬

不做什么：

- 不做人车碰撞伤害
- 不做全图级交通事故系统
- 不做复杂警车、鸣笛或路怒逻辑

## Acceptance

1. 自动化测试必须证明：crossing candidate 被行人占用时，nearfield 车辆会 stop / yield，而不是直接穿过。
2. 自动化测试必须证明：traffic 引入后，pedestrian spawn 与 crossing lane contract 仍然成立，不回退成“人长在车道上”。
3. 自动化测试必须证明：人车 conflict 处理不会把 Tier 3 车辆或 Tier 3 行人一起拉爆预算。
4. 自动化测试必须证明：同一默认配置下，`test_city_vehicle_performance_profile.gd`、`test_city_runtime_performance_profile.gd`、`test_city_first_visit_performance_profile.gd` 全部继续满足 `wall_frame_avg_usec <= 16667`。
5. 反作弊条款：不得通过全局冻结车辆、全局冻结行人、关闭 crossing、或仅在空场景跑 profile 来宣称人车共存成立。

## Files

- Create: `city_game/world/vehicles/simulation/CityVehicleInteractionModel.gd`
- Modify: `city_game/world/vehicles/simulation/CityVehicleTierController.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
- Modify: `city_game/world/pedestrians/model/CityPedestrianQuery.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Create: `tests/world/test_city_vehicle_crossing_yield.gd`
- Create: `tests/world/test_city_vehicle_pedestrian_conflict_budget.gd`
- Create: `tests/e2e/test_city_vehicle_pedestrian_travel_flow.gd`
- Verify: `tests/e2e/test_city_vehicle_performance_profile.gd`
- Verify: `tests/e2e/test_city_runtime_performance_profile.gd`
- Verify: `tests/e2e/test_city_first_visit_performance_profile.gd`

## Steps

1. 写失败测试（红）
   - 先写 `vehicle_crossing_yield` 和 `vehicle_pedestrian_conflict_budget`，把 stop / yield 与 budget guard 同时写硬。
2. 运行到红
   - 失败原因必须明确落在“当前车辆还不存在 crossing-aware behavior”。
3. 实现（绿）
   - 先接 interaction model。
   - 再接 pedestrian / vehicle runtime 的最小必要同步。
   - 最后补 combined profile guard。
4. 运行到绿
   - world conflict tests、travel flow 和 combined profile 全部通过。
5. 必要重构（仍绿）
   - 收敛人车接口，不让两个 tier controller 互相变成强耦合总控。
6. E2E
   - fresh isolated 串行跑 `test_city_vehicle_pedestrian_travel_flow.gd`、`test_city_vehicle_performance_profile.gd`、`test_city_runtime_performance_profile.gd`、`test_city_first_visit_performance_profile.gd`。

## Risks

- 如果 crossing yield 不是 shared lane / crossing contract 的 consumer，就会再造一套冲突世界观。
- 如果人车 conflict 处理直接把 nearfield 全部拉成高成本 agent，预算会比“完全没交互”更糟。
- 如果 combined redline 不和 pedestrian 同配置一起测，最终只会得到“车辆单独绿、真实场景红”的假完成。
