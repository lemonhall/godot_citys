# PRD-0031 Robot Dog Scene Foundation

## Summary

在当前手工拆分过的 `robot dog_02.glb` 资产基础上，建立一条正式、可复用、可继续扩展的机械狗资产主链。此次交付的目标不是立刻做出会跑会扑的 locomotion，而是先把机械狗从“根目录里的一份散装 glb”正式提升为 `creature asset -> formal creature scene -> standalone lab` 的 scene-first 资产：模型必须进入正规生物资产目录，必须拥有独立 `CityRobotDog.tscn` 包装场景，必须拥有独立 `RobotDogLab.tscn` 调试环境，并且在正式 creature scene 中 author 出 8 个可见、可手调、可被后续程序消费的腿部关节锚点。

## Problem

当前仓库里只有用户刚放到根目录的：

- `robot dog_02.glb`
- `robot dog_02_militaryquadrobot3dmodel_basecolor.jpg`

这意味着：

- 机械狗没有正式资产目录，不符合仓库当前 `scene-first + lab-first` 的 creature 组织方式；
- 没有 formal creature scene，后续任何关节控制、腿部程序驱动、命中盒、主世界接入都会直接绑死在散装导入结果上；
- 没有独立 lab，后续调模型、调锚点、调程序时，会把“模型 scene contract 问题”和“未来 locomotion/runtime 问题”搅在一起；
- 8 个腿部活动关节没有正式 authoring contract，后续程序无法稳定知道哪些锚点才是人类在编辑器里定义的真源。

## Goals

- 把机械狗模型与其外部贴图移入正式 creature 资产目录。
- 建立正式 creature scene：`res://city_game/world/creatures/quadrupeds/CityRobotDog.tscn`。
- 在 creature scene 中 author：
  - `BodyPivot`
  - `BodyPivot/Model`
  - `JointAnchors`
  - 8 个腿部关节 `Marker3D`
- 建立独立 lab 场景：`res://city_game/scenes/labs/RobotDogLab.tscn`。
- 建立最小 debug/reset API，供后续 locomotion/IK 版本复用。

## Non-Goals

- 不在本轮实现机械狗 locomotion、IK、步态调度、足底落点搜索、地形跟随或身体 solver。
- 不在本轮把机械狗接入主世界、任务系统、敌对 AI、战斗、伤害或 HUD 交互。
- 不在本轮修改 glb 内部模型结构、重新拓扑、重新绑定骨骼或重做贴图。
- 不在本轮发明第二套 arthropod runtime 的换皮版本；如果未来需要程序控制，必须以当前 scene contract 为真源再设计 quadruped runtime。

## User Experience

1. 开发者可以在正式 creature 资产目录里找到机械狗模型，而不是继续去仓库根目录捞散装文件。
2. 开发者可以直接打开 `CityRobotDog.tscn`，看见被正式包装好的机械狗 scene。
3. 开发者可以在 `CityRobotDog.tscn` 中直接看到 8 个腿部关节锚点，并继续手工微调它们的位置。
4. 开发者打开 `RobotDogLab.tscn` 后，可以用正式 `PlayerController` 在独立环境里观察机械狗、靠近它、围着它看 scene contract。
5. lab 和 creature scene 必须是后续程序控制版本的正式真源，而不是临时预览壳。

## Requirements

### REQ-0031-001 Formal Asset Relocation

必须把机械狗资产从仓库根目录收口进正式 creature 资产目录，并满足：

- 正式 glb 路径冻结为：
  - `res://city_game/assets/environment/source/creatures/robot_dog_02/robot_dog_02.glb`
- glb 所依赖的外部贴图必须和 glb 一起进入同目录，保持 Godot 可正常导入；
- 仓库根目录里的原始 glb 不再作为正式引用源；
- 后续正式 scene 与测试都必须引用正式 creature 资产目录，而不是继续引用根目录路径。

### REQ-0031-002 Formal Creature Scene Wrapper

必须提供正式 creature scene：

- `res://city_game/world/creatures/quadrupeds/CityRobotDog.tscn`

该 scene 必须满足：

- 由专用脚本驱动，而不是纯粹依赖导入结果；
- 必须把 glb 挂在：
  - `BodyPivot/Model`
- scene root 至少暴露：
  - `get_debug_state()`
  - `get_joint_anchor_state()`
  - `get_joint_anchor_names()`
  - `reset_robot_dog_pose()`
- `get_debug_state()` 至少返回：
  - `species_id`
  - `model_scene_path`
  - `joint_anchor_count`
  - `joint_anchor_names`

### REQ-0031-003 Eight Joint Anchor Contract

正式 creature scene 必须 author 一组人类可见、可手调的关节锚点。最小合同冻结为：

- 根节点：
  - `JointAnchors`
- 子锚点共 `8` 个，分别为：
  - `lf_hip`
  - `lf_knee`
  - `rf_hip`
  - `rf_knee`
  - `lr_hip`
  - `lr_knee`
  - `rr_hip`
  - `rr_knee`

语义冻结为：

- `hip` 代表“大腿根部 / 上段腿”的活动关节参考点；
- `knee` 代表“小腿 / 下段腿”的活动关节参考点；
- 这些锚点是后续 quadruped 程序控制的 authored 真源，禁止在 runtime 中额外再造第二套隐藏关节补偿坐标系。

### REQ-0031-004 Standalone Lab Scene Contract

必须提供独立 lab 场景：

- `res://city_game/scenes/labs/RobotDogLab.tscn`

该 lab 必须满足：

- 挂载正式 `CityRobotDog.tscn`，而不是直接挂 glb；
- 具备基础地面、至少一组静态 fixture、正式 `PlayerController`、当前玩家相机与最小 HUD；
- lab root 至少暴露：
  - `get_robot_dog()`
  - `get_robot_dog_debug_state()`
  - `reset_lab_state()`
- lab 的目标是隔离 scene/anchor 调试，不得演变成一份 lab-only 的 creature 实现。

### REQ-0031-005 Scene-First Anti-Cheat Contract

本轮不接受以下空壳实现：

- 只把 glb 拷进目录，但不创建正式 creature scene；
- 只创建 lab，内部直接挂 glb，绕开正式 creature scene；
- 只在脚本里返回“有 8 个锚点”的假数据，但 scene 里没有真实 `Marker3D`；
- 把 8 个锚点做成 runtime 动态生成，而不是 authored scene 节点。

## Acceptance Summary

- 机械狗 glb 已进入正式 creature 资产目录。
- `CityRobotDog.tscn` 已存在并能挂载正式 glb。
- `CityRobotDog.tscn` 已 author `JointAnchors` 与 8 个腿部关节锚点。
- `RobotDogLab.tscn` 已存在并挂载正式 creature scene。
- focused contract tests 能证明 scene-first 层级和最小 API 已冻结。
