# 2026-03-26 V54 Drone-Assisted Artillery Operation Design

## 背景

`v53` 的 observer closeout 已经能完成 howitzer 的炮击观察闭环，但玩家在实际游玩里发现：如果已经进入 howitzer 操炮态，再放飞无人机，无人机本身就是比 observer closeout 更好用的观察机位。当前真正的阻塞点不是“缺少观察能力”，而是两条链在抢输入、抢镜头：

- active drone 仍把 `Space` 当上升键；
- howitzer 操炮把 `Space` 当击发键；
- accepted fire 后 observer closeout 又会强制接管视角。

## 目标

- 允许 `无人机 active + howitzer 操炮 active` 稳定共存；
- 让 howitzer 继续保有：
  - `J/L`
  - `I/K`
  - `Shift+J/L/I/K`
  - `Space`
  - artillery solution HUD
- 让无人机在复合模式下承担炮击观察职责；
- 不破坏原有“纯无人机”与“纯 howitzer observer closeout”行为。

## 决策

### 采用方案 A

- 无人机垂直输入改为：
  - `E` 上升
  - `Q` 下降
- `Space` 从无人机语义里彻底移除；
- 若 `howitzer operation active && drone system_state == active`：
  - accepted fire 跳过 observer closeout；
  - 仍生成 shell；
  - 仍保留 impact / explosion result；
  - 镜头 ownership 保持在 drone。
- 若 `howitzer operation active && drone system_state == active` 且玩家按下 `E`：
  - `E` 仅驱动 drone 上升；
  - howitzer operation 不得退出。

### 不采用方案 B

- 继续让无人机保留 `Space` 上升，再在 world host 层做复杂优先级特判。

拒绝原因：

- 隐式；
- 难测；
- 后续极易在输入分发上再次炸裂；
- 违背“显式优于隐式”与“修在根因上，不修在症状上”。

## 设计约束

- 不允许通过“复合模式下强行退出操炮”来绕过输入冲突；
- 不允许通过“复合模式下隐藏 artillery HUD”来伪装兼容；
- 不允许修改 howitzer 本体的 firing solution / ballistic / observer 非复合口径；
- 不允许影响纯无人机模式的第三人称 chase flight 手感。

## 实现方案

### 输入层

- 真根因在 `CityPlayerDroneFlightController._read_input_state()`：
  - 去掉 `KEY_SPACE`
  - 去掉 `ui_accept`
  - 只保留 `KEY_E` 上升、`KEY_Q` 下降

### 主世界火炮 host

- 在 `CityPrototype.gd` 增加显式 helper：
  - 判断当前是否处于 drone-assisted artillery composite mode
- `_handle_world_howitzer_fire_input()` 的 firing path 调整为：
  - accepted fire
  - 读取 firing solution
  - 若非复合模式：
    - 走既有 observer closeout
    - 回填 observer-related firing solution fields
  - 若复合模式：
    - 不启动 observer closeout
    - 直接 spawn shell
- `_unhandled_input()` / primary interaction path 需要显式识别：
  - 当当前已经是复合模式时，`KEY_E` 不能再进入 howitzer enter/exit toggle；
  - 让事件语义留给 drone flight input。

### HUD / 操炮状态

- 不新增第二套 HUD；
- 继续复用 `CityM777HowitzerOperationController -> PrototypeHud` 的共享 consumer；
- 只要操炮态没被释放，HUD 必须持续可见。

## 测试策略

### Focused Contract

- `test_city_player_drone_space_input_contract.gd`
  - active drone 下 `Space` 不再抬升
  - `E` 仍可抬升
- `test_city_world_howitzer_drone_composite_contract.gd`
  - 操炮中放飞无人机后，操炮态保持
  - HUD 仍可见
  - `E` 不会退出操炮，且仍能抬升无人机
  - `L/I` 与 `Shift+L/I` 仍有效
  - `Space` 仍可击发
  - accepted fire 不触发 observer closeout

### E2E

- `test_city_drone_assisted_artillery_operation_flow.gd`
  - 主世界走一遍“召唤火炮 -> E 操炮 -> KP_5 放飞无人机 -> Space 击发”的完整链
  - 证明镜头不被 observer runtime 抢走，shell impact 仍发生

## 风险

- 如果只是屏蔽 observer camera，但没有从 drone 里移除 `Space`，复合模式仍会残留抬升副作用；
- 如果复合模式判断写散在多个调用点，后续 map mission / free fire 很容易再次分叉；
- 如果只测 contract 不测一条 e2e，输入 ownership 的真实回归很容易漏掉。
