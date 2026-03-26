# 2026-03-26 V60 Robot Dog Locomotion Lab Design

## 背景

用户已经明确把 `v60` 的第一刀范围收窄了：先不要做 walking gait，先只做一个机械狗接到指令后的“爬下”动作，快捷键是 `P`。这不是退而求其次，而是合理缩小边界。因为当前最危险的，不是“怎么排 gait phase”，而是“这只机械狗的 8 个关节到底怎么转、限位怎么写、身体/大腿/小腿这条铰链链路是不是统一”。

## 方案比较

### 方案 A：先做单轴铰链合同 + P 键爬下/起身

推荐方案。

分层冻结为：

- joint constraint table
- pose target solver
- visual hinge apply
- lab input consumer

优点：

- 先把“绕哪根轴转”“角度上限是多少”这些最底层事实冻结；
- 后续 walking gait 只是在这套 joint contract 之上再叠 scheduler；
- 一旦视觉错了，可以明确知道是关节合同错，不是 gait 错。

### 方案 B：直接上 walking gait

拒绝。

- gait、脚点、姿态、关节合同会一起爆炸；
- 一旦视觉错位，很难判断是哪一层的锅；
- 当前用户已经明确要求“第一步啥也别做，就先做爬下动作”。

### 方案 C：手工动画 clip

拒绝。

- 这会直接绕开 joint contract；
- 后面 walking gait 仍然要回到代码关节求解；
- 当前目标是建立机械结构语义，而不是先糊一个能看的动画。

## 决策冻结

- `v60` 第一刀只做 `P` 键爬下/起身。
- 所有关节都只绕编辑器蓝色轴，也就是 local `Z` 轴旋转。
- joint limit 先冻结成配置表，运行时严格 clamp。
- 姿态切换走正式 `CityRobotDog.gd` 主链，`RobotDogLab` 只做输入和 HUD。

## 拟定实现结构

- `CityRobotDog.gd`
  - 关节表
  - pose state
  - 目标角度计算
  - 模型节点同步
- `RobotDogLab.gd`
  - `P` 键切换爬下/起身
  - `F5` reset
  - HUD 刷新

如果 `CityRobotDog.gd` 过长，再拆：

- `CityRobotDogHingePoseRuntime.gd`

但第一刀不强行拆出很多文件。

## 关键建模

每条腿最少维护：

- `hip_joint_name`
- `knee_joint_name`
- `hip_node_path`
- `calf_node_path`
- `hip_limit_deg`
- `knee_limit_deg`
- `hip_crouch_target_deg`

姿态求解首版冻结为：

- 大腿：围绕 local `Z` 轴抬起，直到与身体近似平行；
- 小腿：围绕 local `Z` 轴联动补偿；
- 躯干：按 `crouch_alpha` 做有限下沉；
- 当前不做 gait，不做脚点搜索，不做 terrain follow。

## 测试冻结

最少三类：

1. `joint contract`
   - 锁 8 个 joint 全部是 local `Z`
   - 锁限位存在且可读
2. `crouch pose contract`
   - 锁 `P` 触发后 `crouch_alpha` 推进
   - 锁躯干降低
   - 锁大腿夹角收敛到接近 `0°`
3. `lab flow`
   - 锁 `RobotDogLab` 正确消费正式 runtime
   - 锁 `P` 与 `F5` 输入主链

## 风险

- 如果某条腿的 local `Z` 正方向理解反了，动作会立刻反着走。
- 如果只转大腿不联动小腿，视觉会非常假。
- 如果不把 joint constraint 表作为显式合同暴露出来，后面调 gait 还会继续陷入“猜这个关节到底能不能这么转”。
