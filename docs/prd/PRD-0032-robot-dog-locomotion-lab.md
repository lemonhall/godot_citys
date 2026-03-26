# PRD-0032 Robot Dog Locomotion Lab

## Summary

`v60` 不直接冲整套 walking gait，而是先把机械狗最核心、最容易学炸的那层关节合同做硬：这只机械狗接到指令后，必须能在 `RobotDogLab` 中完成一次“爬下/起身”的姿态切换，快捷键冻结为 `P`。本轮真正要交付的，是一条可验证的单轴铰链主链：`身体 -> 大腿 -> 小腿`，所有关节都只允许绕编辑器里看到的蓝色轴，也就是本地 `Z` 轴旋转，并且每个关节都要有明确角度限位和只读 debug contract。

## Problem

当前机械狗虽然已经在 `v59` 中完成了：

- 正式 creature scene
- 正式 lab
- 8 个 authored 关节锚点

但真正的“机械结构语义”还没有建立起来。现在如果直接去做 walking gait，会立刻遇到这些问题：

- 还没冻结“每个关节到底能绕哪根轴转”；
- 还没冻结“每个关节的旋转限位”；
- 还没冻结“身体、大腿、小腿”这条铰链链路怎么从 scene authoring 走到 runtime；
- 一旦直接上 gait，后面任何视觉异常都分不清是 joint contract 错、pose solver 错，还是 gait scheduler 错。

所以 `v60` 的第一刀先不做 walking，而是先把“接指令 -> 爬下 -> 再起身”这一条机械姿态链做稳。

## Goals

- 在正式 `CityRobotDog.tscn` 主链上冻结 8 个关节的单轴铰链合同。
- 明确写出每个关节：
  - 旋转轴
  - 角度限位
  - 当前角度
  - 目标角度
- 交付一个 `P` 键触发的“爬下/起身”姿态切换。
- 让机械狗在爬下过程中，躯干相对地面明显降低，大腿相对身体的夹角从初始约 `45°~60°` 收到接近 `0°`。
- 保证这条链走正式 `CityRobotDog.gd` 主链，而不是写一份 lab-only 假逻辑。

## Non-Goals

- 不在本轮实现 walking gait、前进、转向、跳跃、奔跑或动态平衡。
- 不在本轮接入主世界、AI、战斗、导航或任务系统。
- 不在本轮引入 GodotIK 或骨骼 rig。
- 不在本轮重做 glb 内部结构或重新绑定骨骼。
- 不在本轮追求足底真实动力学，只解决姿态合同和铰链求解。

## User Experience

1. 开发者打开 `RobotDogLab.tscn` 后，可以看到机械狗处于初始站立姿态。
2. 按下 `P` 后，机械狗会执行一次“爬下”动作，躯干降低，大腿逐渐接近与身体平行，小腿随之联动。
3. 再按一次 `P`，机械狗回到初始站立姿态。
4. 按下 `F5` 后，玩家位置、机械狗姿态和所有 joint runtime 状态都回到初始值。
5. lab HUD 能显示当前姿态状态、`crouch_alpha` 与 joint contract 摘要。

## Requirements

### REQ-0032-001 Formal Hinge Runtime

必须在正式 `CityRobotDog.tscn` / `CityRobotDog.gd` 主链上建立机械狗关节 runtime。最小要求：

- runtime 消费 `v59` 冻结的 8 个 authored 锚点；
- runtime 驱动正式模型节点，而不是只动 debug marker；
- root 至少暴露：
  - `set_crouch_requested(requested: bool)`
  - `toggle_crouch_requested()`
  - `tick_robot_dog(delta: float)`
  - `get_pose_debug_state()`
  - `get_joint_constraint_contract()`

### REQ-0032-002 Single-Axis Joint Contract

8 个关节的旋转轴冻结如下：

| Joint | Axis |
|---|---|
| `lf_hip` | local `Z` |
| `lf_knee` | local `Z` |
| `rf_hip` | local `Z` |
| `rf_knee` | local `Z` |
| `lr_hip` | local `Z` |
| `lr_knee` | local `Z` |
| `rr_hip` | local `Z` |
| `rr_knee` | local `Z` |

这里的 `Z` 指编辑器里看到的蓝色轴。`v60` 不允许任何关节绕 `X/Y` 轴旋转来“补动作”。

### REQ-0032-003 Joint Limit Contract

所有关节都必须有明确角度限位。首版冻结为“相对 editor 初始姿态的本地 `Z` 轴角度偏移”：

| Joint Group | Min Deg | Max Deg |
|---|---:|---:|
| `*_hip` | `-60` | `5` |
| `*_knee` | `-80` | `80` |

最小要求：

- runtime 必须暴露每个 joint 的 axis 与限位；
- 任意 joint 的当前角度都必须被 clamp 在各自限位内；
- 不允许通过偷偷改 authored 锚点位置，绕过限位器。

### REQ-0032-004 Crouch Pose Contract

机械狗必须支持一组正式“爬下”姿态。最小要求：

- 初始站立姿态以 scene authoring 为真源；
- 爬下过程中，大腿相对身体的夹角必须从初始约 `45°~60°` 收到接近 `0°`；
- 目标口径冻结为：爬下结束后，四条大腿的 `body_to_thigh_angle_deg` 平均值不大于 `10°`；
- 躯干在爬下结束后必须明显降低，`body_height_offset_m` 必须大于 `0.10m`；
- 小腿必须联动变化，不允许只转大腿、让小腿保持初始姿态。

### REQ-0032-005 RobotDogLab Input Flow

`RobotDogLab` 必须消费正式 runtime，并提供最小输入流：

- 按下 `P`：
  - 如果当前站立，则切换到“请求爬下”；
  - 如果当前已爬下，则切换回“请求站立”；
- 按下 `F5`：
  - 玩家恢复；
  - 机械狗恢复；
  - joint runtime 状态恢复。

### REQ-0032-006 Debug Contract

正式 runtime 必须暴露只读 debug state，至少包括：

- `species_id`
- `pose_state`
- `crouch_requested`
- `crouch_alpha`
- `body_height_offset_m`
- `joint_constraints`
- `legs`

其中 `legs` 的每条腿至少包括：

- `leg_id`
- `hip_joint_name`
- `knee_joint_name`
- `hip_angle_deg`
- `knee_angle_deg`
- `body_to_thigh_angle_deg`
- `crouch_target_hip_angle_deg`
- `is_crouched`

### REQ-0032-007 Anti-Cheat Contract

本轮不接受以下空壳实现：

- 只移动躯干，不驱动真实大腿/小腿；
- 只播动画 clip，不维护 joint angle/runtime state；
- 关节实际上绕 `X/Y` 轴在补动作；
- 通过修改 authored 锚点位置假装 joint solver 正常；
- 在 `RobotDogLab` 里写一套私有逻辑，绕开正式 `CityRobotDog.gd` 主链。

## Acceptance Summary

- focused tests 必须证明：8 个 joint 的轴向合同都固定为 local `Z`。
- focused tests 必须证明：8 个 joint 都存在明确角度限位，并且当前角度被 clamp。
- focused tests 必须证明：按 `P` 后机械狗会进入爬下姿态；再按一次会回站立姿态。
- focused tests 必须证明：爬下后躯干降低，大腿相对身体夹角收敛到接近 `0°`。
- focused tests 必须证明：`RobotDogLab` 直接消费正式 runtime，`F5` reset 主链仍然成立。
