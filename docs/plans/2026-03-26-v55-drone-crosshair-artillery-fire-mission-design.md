# 2026-03-26 V55 Drone Crosshair Artillery Fire Mission Design

## 背景

当前炮击黄叉已经有一条正式主链：

- full map 右键
- 选择 `炮击标记`
- 创建单个 active fire mission
- 走 shared battery snapshot / solver / marker / focus message

但一旦玩家已经在无人机观察态里，重新打开 full map 去右键，交互上就显得很绕。无人机 FPV 本身已经具备一个稳定的世界落点准星，因此更合理的补全方式不是再造第二套“无人机炮击系统”，而是把无人机准星接入现有的 artillery fire mission 单一真源。

## 方案比较

### 方案 A：无人机 `T` 直接复用正式 fire mission 入口

推荐方案。

- 条件：`drone active + FPV ADS active`
- 动作：读取 drone crosshair `world_target`
- 落地：直接调用现有 `request_artillery_fire_mission_from_world_point(world_target)`

优点：

- 没有第二套 marker / solver / battery snapshot 状态；
- full map 右键与无人机 `T` 自动保持同口径；
- 重复按 `T` 天然就是更新同一个 active mission。

### 方案 B：做一套 drone-only target state，再同步到地图

拒绝。

- 会同时出现 `drone target` 与 `artillery fire mission` 两种状态源；
- 后续非常容易出现 HUD 一套、地图一套、操炮又一套的分叉。

### 方案 C：按 `T` 时自动打开地图并模拟右键

拒绝。

- UI 驱动核心逻辑，方向反了；
- 难测；
- 也违背“协议优于实现”和“等价多态”。

## 决策冻结

- 只有 `player drone active + FPV ADS active` 时，`T` 才切换为炮击标定；
- 标定入口必须复用正式 `request_artillery_fire_mission_from_world_point()` 主链；
- 若当前没有 active mission，则创建单个黄叉；
- 若当前已有 active mission，则更新该 marker 对应 target；
- 若当前 howitzer 操炮 active，则新的 target 必须立刻刷新 solved bearing / pitch；
- 非无人机 FPV 场景下，`T` 的既有快捷语义保持不变。

## 实现落点

### Host 输入层

在 `CityPrototype.gd` 的 `KEY_T` 分支增加显式优先级：

1. 尝试处理 `drone crosshair artillery shortcut`
2. 若未命中，再回退到既有 `_handle_fast_travel_shortcut()`

### Drone -> Artillery 桥接

主世界 host 新增一个最小 helper：

- 验证 drone system state 是否 `active`
- 验证 FPV ADS 是否 active
- 读取 `PlayerDroneRuntime.get_crosshair_state().world_target`
- 调用正式 artillery fire mission request API

### 数据消费者

不新增消费者。

沿用：

- `ArtilleryFireMissionRuntime`
- pin registry
- full map render state
- focus message
- live howitzer solution refresh

## 测试策略

### Focused Contract

`test_city_drone_artillery_target_marking_contract.gd`

- 无人机 active + FPV ADS 下按 `T` 会创建 formal fire mission；
- mission target 与 FPV 准星 world target 对齐；
- 重复按 `T` 只更新单个 active 黄叉，不累积第二个 marker；
- 未操炮时 solution 继续保持 pending。

### E2E

`test_city_drone_artillery_recalibration_flow.gd`

- 召唤 howitzer
- 进入操炮态
- 放飞无人机
- 将无人机前出到可解算距离
- FPV 准星按两次 `T`
- 验证 mission target 与 solved bearing / pitch 被刷新，而 howitzer 操炮 ownership 与 HUD 仍保持。

### 回归

- `test_city_artillery_fire_mission_contract.gd`
- `test_city_fast_travel_shortcut_contract.gd`
- `test_city_world_howitzer_drone_composite_contract.gd`
- `test_city_map_artillery_fire_mission_flow.gd`

## 风险

- 如果从 drone path 新建第二套 mission state，后续 map / HUD / observer 会再次分叉。
- 如果 `T` 的优先级判断写成“先 fast travel，再 drone”，一旦存在 active destination 就会把炮击校准误判成传送。
- 如果只验证 mission target，不验证 single-marker replace，很容易让黄叉 quietly 累积。
