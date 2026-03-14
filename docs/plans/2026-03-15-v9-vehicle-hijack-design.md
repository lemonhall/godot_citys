# V9 Vehicle Hijack Design

## Summary

`v9` 只做一条最小玩家载具玩法链：玩家先把近景车辆打停，再在近距离按 `F` 接管，随后以最小驾驶模式开走这辆车。核心约束不是“功能尽量多”，而是“绝不破坏 `v8` 的 ambient traffic foundation 和性能红线”。

## Approach Options

### 方案 A：把全城车辆升级成 PhysicsBody3D / 刚体可命中体

优点：

- 命中、阻挡、撞击语义最直观
- 后续想做碰撞破坏、交通事故时看似延展性强

缺点：

- 直接违背 `v8` 的 layered runtime 和 runtime guard
- 会把 `Tier 1 / Tier 2 / Tier 3` 区分打穿，性能和节点数都会失控
- 对当前需求明显过度设计

结论：拒绝。

### 方案 B：保持 ambient traffic 底盘不动，只给近景 `Tier 2 / Tier 3` 增加 interaction state，再让玩家复用现有 CharacterBody 进入 driving mode

优点：

- 直接复用 `v8` 的 `vehicle_query -> streamer -> tier controller -> renderer`
- 只把交互求解限定在近景窗口，成本可控
- 玩家 driving mode 只增加一台 hijacked vehicle 的视觉与运动成本

缺点：

- 不是完整载具体系，碰撞/下车/车辆 damage 以后还要补
- 命中判定只能先做近景近似体

结论：推荐，满足当前需求且成本最低。

### 方案 C：接管时删除原车辆，玩家侧再新生成一台“玩法车”

优点：

- 实现很快
- 玩家驾驶逻辑和 ambient runtime 可以完全解耦

缺点：

- continuity 会断，`vehicle_id / model_id` 追溯不可信
- 很容易出现“ambient 旧车还在跑、玩家又生成一台新车”的重复状态 bug

结论：只可作为最后兜底；当前不选。

## Recommended Architecture

推荐采用方案 B：

1. 在 `CityVehicleState` 中增加 `interaction_state`，区分 `ambient / stopped / hijacked`。
2. 由 `CityVehicleTierController` 负责近景车辆命中求解、截停、hijack candidate 查询与 claim；也就是“玩法消费 traffic runtime”，而不是“玩家脚本直接操纵 traffic 状态表”。
3. `CityProjectile` 与 `CityGrenade` 继续保留当前 combat 行为，但在 enemy / pedestrian 命中链之后再接 vehicle resolver。
4. `CityPrototype` 作为编排层，负责把 `F` 输入翻译为 `try_hijack_nearby_vehicle()`，并在接管成功后切玩家 driving mode。
5. `PlayerController` 不接管 traffic 查询；它只负责 driving mode 本身：隐藏步行模型、挂载被接管车辆模型、处理基础车辆移动和相机。

## Data Flow

`projectile/grenade`
-> `CityChunkRenderer.resolve_vehicle_*`
-> `CityVehicleTierController`
-> target `CityVehicleState.interaction_state = stopped`
-> `F`
-> `CityPrototype.try_hijack_nearby_vehicle()`
-> `CityVehicleTierController.claim_vehicle()`
-> `PlayerController.enter_vehicle_drive_mode(vehicle_snapshot)`

## Guardrails

- 只对 `Tier 2 / Tier 3` 做交互求解，避免全量扫描 traffic state。
- hijack 后必须复用原 `vehicle_id / model_id`，不能凭空刷一台“玩家车”。
- driving mode 只新增一台玩家持有车辆模型；不得改写 ambient traffic renderer 为 per-vehicle node 海。
- `test_city_vehicle_runtime_node_budget.gd`、`test_city_runtime_performance_profile.gd`、`test_city_first_visit_performance_profile.gd` 是硬 gate。
