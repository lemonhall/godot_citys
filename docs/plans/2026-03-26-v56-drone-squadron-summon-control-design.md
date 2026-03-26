# 2026-03-26 V56 Drone Squadron Summon Control Design

## 背景

当前无人机链路已经把“单架长机的 deploy / active / recover”稳定了下来，但它的 `KP_5` 心智模型还停留在单机 toggle：第一次按放飞，第二次按回收。用户现在要的不是完整战术无人机系统，而是一条更自然的机群入口：

- `KP_5` 继续作为无人机系统键
- 短按一次，多一架
- 长按一次，全部收回
- 长机继续承担现有 camera / input / FPV / artillery composite 真源
- 僚机首版只负责“看起来像个机群”，不要挤成一团

这意味着本轮的核心不是“给每架无人机都塞一套 full runtime”，而是把“长机真源”和“僚机呈现”严格分层。

## 方案比较

### 方案 A：保留现有长机 runtime，新增 squadron manager 管僚机

推荐方案。

- 现有 `CityPlayerDroneRuntime` 继续只代表长机
- 新增 `CityPlayerDroneSquadronRuntime` 作为 world-owned manager
- manager 负责：
  - `KP_5` 长短按语义
  - 总机群数
  - 僚机 spawn / clear
  - 默认分散 slot

优点：

- 不会把现有长机 runtime 改成“大杂烩”
- howitzer 复合态、FPV、suicide strike 都继续挂在长机上
- 僚机可以先做轻量 visual/follow，占位清晰

### 方案 B：把每架僚机也做成完整 `CityPlayerDroneRuntime`

拒绝。

- 每架都会带 camera / input / player lock / FPV / strike 语义
- 很容易互相抢 owner
- 首版成本和风险都过高

### 方案 C：只在 debug state 里记“机群数”，不真正生成模型

拒绝。

- 这直接违反了“模型层面不挤在一块”的可见诉求
- 也会让后续战术命令完全失去物理落点

## 决策冻结

- `KP_5` 继续是无人机系统唯一正式入口
- `短按 KP_5`：
  - `0 -> 1` 时放飞长机并保持当前 takeover 语义
  - `1 -> N` 时只增援 1 架僚机，不切 camera / input
- `长按 KP_5`：
  - 一键全收回
  - 普通模式下回到玩家
  - `howitzer 操炮 + drone` 复合态下回到 howitzer 操炮态
- 首版总机群上限：
  - `10` 架总数，含长机
- 僚机首版只做默认分散 slot，不做正式 flocking / 战术命令 / 独立 FPV

## 实现落点

### 输入层

`CityPrototype.gd`

- 从“按下即 toggle”改成：
  - `KP_5 pressed` -> 开始计时
  - `KP_5 released` -> 判定短按或长按
- 这样不会把“长按全收”误识别成“先加一架再收回”

### Runtime 分层

- `CityPlayerDroneRuntime.gd`
  - 继续只做长机
  - 补最小 deploy/recover 显式 API，避免 squadron manager 反射内部私有状态
- `CityPlayerDroneSquadronRuntime.gd`
  - world-owned squad manager
  - 管 `desired_total_count / wingman_count / max_total_count / last_action`
  - 管 wingman spawn / clear / formation slot
- `CityPlayerDroneWingman.gd`
  - 轻量 visual follow node
  - 不拥有 camera / input / strike

## 默认编队

首版用最朴素、最稳的交错楔形：

- 左右交替
- 每一排离长机更远一些
- 轻微高度错层

这版不追求 flocking，只追求：

- 玩家一眼能看出“机群”
- 僚机不会和长机、彼此长期重叠
- 长机急转弯时，僚机仍能平滑回到自己的 slot

## 测试策略

### Focused Contract

- `test_city_player_drone_toggle_contract.gd`
  - 更新为长短按合同
- 新增 `test_city_player_drone_squadron_summon_contract.gd`
  - 机群数递增
  - 上限 `10`
  - 分散位置不重叠

### 既有链回归

- `test_city_player_drone_camera_takeover_contract.gd`
  - 回收动作改为长按后仍恢复 player
- `test_city_player_drone_flow.gd`
  - e2e 改为长按全收
- `test_city_drone_assisted_artillery_operation_flow.gd`
  - 验证复合态下机群回收不会丢 howitzer context

## 风险

- 如果把僚机也做成 full runtime，owner 冲突会非常难 debug
- 如果长按判定写在 `pressed` 时刻，误触会非常多
- 如果复合态下全收回直接粗暴 `set_control_enabled(true)`，howitzer 操炮 ownership 会被意外释放
