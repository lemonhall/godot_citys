# PRD-0033 Robot Dog Ground Locomotion Control

## Summary

`v61` 的目标不是把机械狗一口气做成完整战斗单位，而是在 `v60` 已经冻结的单轴关节、爬下/起身和 visual pivot 合同之上，先交付一条可靠的地面操控链：玩家按下小键盘 `4` 召唤机械狗，控制权和镜头立即切到机械狗第三人称；再次按下小键盘 `4`，机械狗回收，控制权回到 `Player`。机械狗存在并被接管期间，`W/A/S/D/Shift/P` 只归机械狗消费，用于 `idle / walk / run / backward / turn / prone` 这些地面态。

## Problem

`v60` 解决的是“这条腿怎么转、关节合同是什么、爬下姿态能不能稳定成立”。但它还没有解决：

- 玩家怎么正式接管机械狗，而不是在 lab 里用一套孤立热键；
- 当机械狗开始跑动时，`Player` 的 `W/A/S/D/Shift/P` 冲突怎么处理；
- 世界里如何像无人机、小键盘 `5`，火炮、小键盘 `8` 那样，给机械狗一套正式、稳定、可回收的召唤/控制语义；
- 机械狗的 `walk / run / backward / turn` 如何建立成正式 runtime，而不是一组手工摆 pose。

如果这些问题不先冻结，后面的扑击、跳起、攻击、战斗 AI 都会建立在一套不稳定的输入和 locomotion 主链上。

## Goals

- 建立机械狗正式的召唤/回收控制语义，热键冻结为小键盘 `4`。
- 建立机械狗第三人称控制态，避免与 `Player` 的输入直接冲突。
- 建立机械狗首版地面 locomotion state machine：
  - `idle`
  - `walk`
  - `run`
  - `backward`
  - `turn_left`
  - `turn_right`
  - `turn_move`
  - `prone`
- 保证 `RobotDogLab` 与主世界 consumer 继续走同一条正式 runtime 主链。

## Non-Goals

- 不在 `v61` 做 `pounce / jump / landing / attack hit`。
- 不在 `v61` 做战斗、目标锁定、伤害判定或敌我 AI。
- 不在 `v61` 做复杂 terrain traversal、跨台阶跳跃、空中姿态控制。
- 不在 `v61` 引入骨骼动画 clip 作为 locomotion 主链。

## User Experience

1. 玩家在主世界按下小键盘 `4`，机械狗会生成在 `Player` 前方约 `2m` 处，朝向与 `Player` 当前朝向一致。
2. 机械狗生成后，镜头立即切到机械狗第三人称跟随视角，控制权从 `Player` 切换到机械狗。
3. 机械狗控制态下：
   - `W`：前进步行
   - `Shift + W`：前进跑动
   - `S`：后退
   - `A / D`：原地转向；与 `W/S` 叠加时进入转向移动
   - `P`：机械狗爬下 / 起身
4. 机械狗控制态下，`Player` 留在原地，不再响应这些移动热键。
5. 再按一次小键盘 `4`，机械狗回收，镜头和控制权都回到 `Player`。

## Requirements

### REQ-0033-001 Summon And Recall Contract

正式机械狗控制热键冻结为小键盘 `4`：

- 当机械狗未激活时，按下小键盘 `4` 必须召唤一只正式机械狗；
- 当机械狗已激活时，再按一次小键盘 `4` 必须回收机械狗；
- 不允许使用主键盘 `4` 代替小键盘 `4`。

### REQ-0033-002 Spawn And Takeover Contract

机械狗召唤成功后，必须满足：

- 生成位置在 `Player` 前方约 `2m`；
- 初始朝向与 `Player` 当前朝向一致；
- 镜头切到机械狗第三人称跟随态；
- 控制权立即切换到机械狗；
- `Player` 进入冻结态，不响应 locomotion 热键。

### REQ-0033-003 Input Ownership Contract

机械狗控制态下：

- `W/A/S/D/Shift/P` 只归机械狗消费；
- 同一时间不得同时驱动 `Player` 和机械狗；
- 退出机械狗控制态后，输入所有权必须完整还给 `Player`。

### REQ-0033-004 Ground Locomotion Contract

`v61` 首版地面 locomotion 只处理地面态：

- `idle`
- `walk`
- `run`
- `backward`
- `turn_left`
- `turn_right`
- `turn_move`
- `prone`

最小要求：

- `walk` 和 `run` 必须在速度和步频上有显式差异；
- `backward` 必须是独立语义，而不是简单反向播 forward 动作；
- `turn_left / turn_right` 必须允许原地转向；
- `W + A/D`、`S + A/D` 时必须允许转向移动；
- `P` 在机械狗控制态下仍然能进入/退出 `prone`。

### REQ-0033-005 Runtime Reuse Contract

机械狗 locomotion 必须建立在 `v60` 的正式 `CityRobotDog.gd` 主链上，继续继承：

- 8 个 joint 只绕 local `Z` 轴；
- joint limit 明确存在；
- `LegPivotRoot -> HipPivot / CalfPivot` 是唯一正式 visual rig。

不允许为了 `walk/run` 新起第二套 clip-only 或 mesh-only locomotion 旁路。

### REQ-0033-006 Debug Contract

正式 runtime 至少要暴露：

- `system_state`
- `control_owner`
- `camera_mode`
- `locomotion_state`
- `move_input`
- `turn_input`
- `speed_mps`
- `active_robot_dog`
- `player_frozen`

机械狗自身 pose/joint debug contract 继续沿用 `v60`。

### REQ-0033-007 Anti-Cheat Contract

本轮不接受以下空壳实现：

- 只切镜头，不切控制权；
- 机械狗和 `Player` 同时响应 `W/A/S/D`；
- 只移动根节点滑行，不驱动真实地面 locomotion 状态；
- 只在 lab 中可用，主世界再写一套不同控制逻辑；
- 为了跑步态而破坏 `v60` 已冻结的 joint/pivot 合同。

## Acceptance Summary

- focused tests 必须证明：小键盘 `4` 能正式召唤/回收机械狗。
- focused tests 必须证明：机械狗召唤后，第三人称镜头与控制权都切到机械狗，`Player` 被冻结。
- focused tests 必须证明：机械狗控制态下 `W/A/S/D/Shift/P` 只归机械狗消费。
- focused tests 必须证明：`idle / walk / run / backward / turn / prone` 这些状态都有显式 runtime contract。
- focused tests 必须证明：主世界 consumer 与 `RobotDogLab` 不会分叉出两套不同的机械狗控制主链。
