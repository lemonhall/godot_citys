# V9 Vehicle Hijack Driving

## Goal

在不回退 `v8` ambient traffic runtime 和性能资产的前提下，交付一条完整的 `截停 -> F 接管 -> 驾驶` 玩家主链。

## PRD Trace

- REQ-0004-001
- REQ-0004-002
- REQ-0004-003
- REQ-0004-004

## Scope

做什么：

- 为 `Tier 2 / Tier 3` 近景车辆新增 projectile / grenade 截停判定
- 为近距已截停车辆新增 `F` 接管行为
- 为玩家新增最小 driving mode、车辆视觉挂载和基础驾驶运动
- 暴露 hijack / driving runtime snapshot，补齐 world/e2e 测试

不做什么：

- 不做全城刚体车
- 不做下车、开门、座位、车辆生命值
- 不做复杂碰撞破坏、撞击伤害或 wanted 系统

## Acceptance

1. 自动化测试必须证明：projectile 命中近景车辆后，目标 `vehicle_id` 进入 `interaction_state = "stopped"`，并且后续帧不再沿 lane 前进。
2. 自动化测试必须证明：grenade explosion 命中近景车辆后，目标 `vehicle_id` 进入 `interaction_state = "stopped"`，并且不会把窗口内所有车辆都一锅端冻结。
3. 自动化测试必须证明：只有已截停且距玩家不超过近距阈值的车辆才能被 `F` 接管；接管成功后，玩家 driving state 保留同一 `vehicle_id / model_id`。
4. 自动化测试必须证明：接管成功后，同一 `vehicle_id` 会从 ambient runtime 可见集合移除，不允许“一边玩家在开，一边 ambient 里还在跑第二台同 ID 车”。
5. 自动化测试必须证明：driving mode 下，玩家步行模型隐藏、车辆模型显示，持续输入若干帧后世界位置和朝向都有显著变化。
6. 自动化测试必须证明：driving mode 下不会继续触发步行射击、手榴弹、跳跃、攀墙和 ground slam。
7. `tests/world/test_city_vehicle_runtime_node_budget.gd`、`tests/e2e/test_city_runtime_performance_profile.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd` 必须继续通过。
8. 反作弊条款：不得通过把交通密度降为 `0`、命中后直接删车、为驾驶单独开 profiling 配置、或把玩家切回 inspection “飞车”速度来宣称完成。

## Files

- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/scripts/PlayerController.gd`
- Modify: `city_game/combat/CityProjectile.gd`
- Modify: `city_game/combat/CityGrenade.gd`
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `city_game/world/vehicles/simulation/CityVehicleState.gd`
- Modify: `city_game/world/vehicles/streaming/CityVehicleStreamer.gd`
- Modify: `city_game/world/vehicles/simulation/CityVehicleTierController.gd`
- Create: `tests/world/test_city_vehicle_hijack_contract.gd`
- Create: `tests/world/test_city_vehicle_grenade_stop_contract.gd`
- Create: `tests/world/test_city_player_vehicle_drive_mode.gd`
- Create: `tests/e2e/test_city_vehicle_hijack_drive_flow.gd`
- Modify: `docs/plan/v9-index.md`

## Steps

1. 写失败测试（红）
   - 先补 `test_city_vehicle_hijack_contract.gd`，覆盖 projectile 截停、近距 `F` 接管、ID continuity 与 ambient runtime 去重。
   - 再补 `test_city_vehicle_grenade_stop_contract.gd`，覆盖 grenade 截停。
   - 最后补 `test_city_player_vehicle_drive_mode.gd` 与 `test_city_vehicle_hijack_drive_flow.gd`，覆盖 driving mode 运动、模型切换和用户流程。
2. 运行到红
   - 预期失败点必须明确落在“当前 vehicle runtime 不支持 interaction state / hijack / driving mode”，而不是测试本身写错。
3. 实现（绿）
   - 先给 `CityVehicleState / TierController / ChunkRenderer` 补 interaction state、近景命中求解、候选查询与 claim。
   - 再把 projectile / grenade combat 链挂到 vehicle resolver。
   - 随后给 `PlayerController` 增加最小 driving mode，并在 `CityPrototype` 接上 `F` 交互与 hijack runtime sync。
4. 运行到绿
   - 新增 world tests 与新 e2e flow 全绿。
5. 必要重构（仍绿）
   - 避免把 `PlayerController` 写成同时负责 traffic querying 的巨型类；车辆交互判定留在 vehicle runtime，玩家只负责 driving mode。
6. E2E
   - 串行跑 `test_city_vehicle_hijack_drive_flow.gd`、`test_city_vehicle_runtime_node_budget.gd`、`test_city_runtime_performance_profile.gd`、`test_city_first_visit_performance_profile.gd`。

## Risks

- 如果车辆截停判定直接扫全量 vehicle state，会把 `v8` 的近景预算优势抹平；因此默认只对 `Tier 2 / Tier 3` 近景状态做交互求解。
- 如果 hijack 只是“生成一辆玩家车”而不 claim 原 traffic state，就会立刻出现 duplicate vehicle continuity bug。
- 如果驾驶模式复用 inspection 飞行式移动而不是最小车辆转向/加减速，手感虽然快，但需求语义不成立。
- 如果 driving mode 侵入 chunk streaming 主链太深，combined runtime profiling 很容易回退。
