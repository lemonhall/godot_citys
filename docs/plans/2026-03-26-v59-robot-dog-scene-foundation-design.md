# 2026-03-26 V59 Robot Dog Scene Foundation Design

## 背景

这只机械狗已经完成了“模型拆件”这一半的人类工作，但还没有进入仓库正式资产链。当前真正缺的不是 gait，而是 scene contract：如果现在直接围绕根目录的 glb 开始写程序，后面一旦要调关节、补锚点、加 hurtbox 或接回主世界，就会再次陷入“模型导入结果就是 runtime 真相”的泥潭。

## 方案比较

### 方案 A：新建 quadruped 正式目录，先做 static creature scene + standalone lab

推荐方案。

- 资产进入：
  - `res://city_game/assets/environment/source/creatures/robot_dog_02/`
- 正式 creature scene：
  - `res://city_game/world/creatures/quadrupeds/CityRobotDog.tscn`
- 独立 lab：
  - `res://city_game/scenes/labs/RobotDogLab.tscn`
- 只冻结 `BodyPivot/Model + JointAnchors + 8 Marker3D + reset/debug API`

优点：

- 直接对齐仓库已有的 `scene-first + lab-first` 工作流；
- 8 个关节锚点会变成后续程序控制的正式 authoring 真源；
- 当前版本不承担 locomotion 风险，后续再开 quadruped runtime 也不会推翻本轮结构。

### 方案 B：直接把机械狗塞进 arthropod 目录，借蜘蛛/龙虾 runtime 先跑起来

拒绝。

- 机械狗不是 arthropod；
- 会把“多足 crawler runtime”与“机械四足 scene contract”混成一锅；
- 后续很容易被惯性推着走，最后只剩一份名义上的复用。

### 方案 C：只做一个 lab 场景，里面直接挂 glb

拒绝。

- 看起来最快，但 formal creature scene 缺失；
- 后续任何脚本都会被迫直接依赖导入节点层级；
- 8 个锚点也会沦为 lab-only 私货。

## 决策冻结

- 先正式化资产，不提前做 locomotion。
- 正式 creature scene 和 lab scene 都必须存在。
- `JointAnchors` 下必须 author 8 个 `Marker3D`。
- 后续程序控制版本必须以本轮 author 的锚点为真源，而不是再造 runtime 校正层。

## 测试策略

- `test_robot_dog_scene_contract.gd`
  - 锁正式资产路径、creature scene 层级、8 个关节锚点与最小 API。
- `test_robot_dog_lab_scene_contract.gd`
  - 锁 lab scene 是否挂载正式 creature scene，是否提供 ground/player/camera/HUD/reset 合同。

## 风险

- 如果 glb 外部贴图搬运路径不对，Godot 导入会退化或丢材质。
- 如果现在不把锚点 author 成 scene 节点，后续 quadruped runtime 会被迫重新定义“关节真源”。
- 如果 lab 直接挂 glb，不经过 `CityRobotDog.tscn`，未来 scene contract 必然分叉。
