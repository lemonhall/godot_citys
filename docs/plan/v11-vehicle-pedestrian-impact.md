# V11 Vehicle Pedestrian Impact

## Goal

在不回退 `v6 pedestrian death/flee` 与 `v9 hijack driving` 资产的前提下，交付一条完整的 `驾驶中撞击 -> 行人致死创飞 -> 车辆降速 -> 局部恐慌 -> 继续开走` 玩家主链。

## PRD Trace

- REQ-0005-001
- REQ-0005-002
- REQ-0005-003
- REQ-0005-004

## Scope

做什么：

- 为玩家当前 driving mode 的 hijacked vehicle 增加近景 pedestrian 撞击判定
- 撞击目标时复用既有 `death` 动画/结算，并增加创飞落点 visual
- 撞击成功后把玩家当前车速打到个位数，但不退出 driving mode
- 为撞击事件新增缩小半径、近层限定、约 `60%` 响应的事故恐慌
- 暴露 impact 结果到 runtime snapshot / tests / live flow

不做什么：

- 不做 ambient traffic 撞人
- 不做玩家下车后的空车或 parked hijacked vehicle 撞人
- 不做 ragdoll、尸体碰撞、车损、wanted 或三层事故广播

## Acceptance

1. 自动化测试必须证明：只有玩家当前正在驾驶的车辆能杀死近景 pedestrian；ambient traffic、abandoned parked visual 与玩家下车后的空车都不会触发死亡。
2. 自动化测试必须证明：被撞 pedestrian 会进入与枪击/手雷一致的 `death/dead` 动画链，但 death event 额外带出创飞方向、飞行距离和落点，最终落在车前几米范围内。
3. 自动化测试必须证明：撞击发生后玩家 `speed_mps < 10.0`，但继续正油门若干帧仍可恢复加速并继续前进。
4. 自动化测试必须证明：撞击后的事故恐慌只作用于最近 player 的近层候选，deterministic 响应比例约为 `60%`，且缩小半径外 pedestrian 维持 calm。
5. 自动化测试必须证明：`tests/world/test_city_vehicle_runtime_node_budget.gd`、`tests/e2e/test_city_runtime_performance_profile.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd` 继续通过。
6. 反作弊条款：不得通过“命中后直接删 pedestrian state 不播 death”“把 gunshot 400m panic 原样套过来”“ambient traffic 也能撞死人”“玩家下车后空车还能继续撞死路人”来宣称完成。

## Files

- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/scripts/PlayerController.gd`
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
- Modify: `city_game/world/pedestrians/streaming/CityPedestrianBudget.gd`
- Modify: `city_game/world/pedestrians/rendering/CityPedestrianCrowdRenderer.gd`
- Modify: `city_game/world/pedestrians/rendering/CityPedestrianVisualInstance.gd`
- Create: `tests/world/test_city_player_vehicle_pedestrian_impact.gd`
- Create: `tests/world/test_city_pedestrian_vehicle_impact_panic.gd`
- Create: `tests/world/test_city_player_vehicle_death_visual_launch.gd`
- Create: `tests/e2e/test_city_vehicle_pedestrian_impact_flow.gd`
- Modify: `docs/plan/v11-index.md`

## Steps

1. 写失败测试（红）
   - 先补 `test_city_player_vehicle_pedestrian_impact.gd`，覆盖“只有 driving vehicle 可杀人、命中后减速到个位数、继续油门可恢复加速、下车后空车不生效”。
   - 再补 `test_city_pedestrian_vehicle_impact_panic.gd`，覆盖“缩小半径、只看近层、约 60% 响应、远层 calm”。
   - 最后补 `test_city_player_vehicle_death_visual_launch.gd` 与 `test_city_vehicle_pedestrian_impact_flow.gd`，覆盖 death clip 复用、创飞落点和 live flow。
2. 运行到红
   - 预期失败点必须明确落在“当前 driving mode 没有 pedestrian impact resolver / special panic event / vehicle slowdown feedback”，而不是测试本身写错。
3. 实现（绿）
   - 先把 impact resolver 放进 `CityChunkRenderer + CityPedestrianTierController`，只消费玩家当前 driving state 和近景候选，不碰 ambient traffic。
   - 再给 death event / renderer 增加创飞与落点 visual 信息，但保持 `death/dead` 动画主链不变。
   - 随后在 `PlayerController`/`CityPrototype` 接上撞击后降速和继续驾驶能力。
   - 最后补事故恐慌：只面向最近 player 的 `Tier 2 / Tier 3` 近层候选，约 `60%` deterministic 响应。
4. 运行到绿
   - 新增 world tests 与新 e2e flow 全绿。
5. 必要重构（仍绿）
   - 车辆输入控制、pedestrian impact resolution、crowd response 三层分开，避免把 `PlayerController` 写成巨型事故总控。
6. E2E
   - 串行跑 `test_city_vehicle_pedestrian_impact_flow.gd`、`test_city_vehicle_runtime_node_budget.gd`、`test_city_runtime_performance_profile.gd`、`test_city_first_visit_performance_profile.gd`。

## Risks

- 如果撞击判定直接扫全量 pedestrian state，会抹平 layered runtime 的预算优势；默认只能查 `Tier 2 / Tier 3` 近景状态。
- 如果把“玩家开车撞人”和“任意空车 / ambient traffic 触碰到人”共用同入口，玩法语义会立刻漂移。
- 如果创飞 visual 依赖复杂物理节点或 ragdoll，会直接破坏红线；本轮必须保持 death visual 级别的轻量实现。
- 如果事故恐慌直接复用 gunshot/explosion 的大半径广播，真实手感与预算都会错位。
