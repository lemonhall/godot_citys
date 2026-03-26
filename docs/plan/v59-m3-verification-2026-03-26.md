# V59 M3 Verification - 2026-03-26

## 范围

- 版本：`v59`
- 需求：
  - `REQ-0031-001`
  - `REQ-0031-002`
  - `REQ-0031-003`
  - `REQ-0031-004`
- 日期：`2026-03-26`

## TDD Red 边界

在实现前，先运行新增 red tests。首个失败边界为：

- 命令：
  - `& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_robot_dog_scene_contract.gd'`
- 失败摘要：
  - `Robot dog scene contract requires the formal robot dog glb under the creature asset directory`

这证明旧状态下机械狗还停留在仓库根目录 staging 状态，正式 creature 资产路径尚未成立。

## Fresh Verification

### M0 Docs Freeze

- 命令：
  - `rg -n "REQ-0031-001|REQ-0031-002|REQ-0031-003|REQ-0031-004|quadrupeds|JointAnchors|lf_hip|rf_hip|RobotDogLab" docs/prd/PRD-0031-robot-dog-scene-foundation.md docs/plan/v59-index.md docs/plan/v59-robot-dog-scene-foundation.md docs/plans/2026-03-26-v59-robot-dog-scene-foundation-design.md`
- 结果：
  - `exit code 0`
  - 命中文档链：`PRD-0031`、`v59-index`、`v59 plan`、`v59 design`

### Focused Scene Contracts

- 命令：
  - `& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_robot_dog_scene_contract.gd'`
  - `& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_robot_dog_lab_scene_contract.gd'`
- 结果：
  - 全部 `PASS`

覆盖点：

- 正式 glb 已进入 `res://city_game/assets/environment/source/creatures/robot_dog_02/robot_dog_02.glb`
- `CityRobotDog.tscn` 已存在，并在 `BodyPivot/Model` 挂载正式 glb
- creature scene 已 author `JointAnchors` 与 8 个真实 `Marker3D`
- creature scene root 已暴露 `get_debug_state()`、`get_joint_anchor_state()`、`get_joint_anchor_names()`、`reset_robot_dog_pose()`
- `RobotDogLab.tscn` 已挂载正式 `CityRobotDog.tscn`
- lab scene 已 author `GroundBody`、`FixtureRoot`、`RampBody`、`StepBody`、`ChannelBody`、`Player`、`Camera3D`、`Hud` 与 `RobotDogRoot`

### Headless Parse Check

- 命令：
  - `& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --quit`
- 结果：
  - `exit code 0`

## 备注

- 为了让新路径下的 glb 正式进入 Godot import 主链，本轮补齐了正式资产目录旁的 `.import` 元数据；根目录下旧路径遗留的 untracked `.import` staging 文件未纳入正式引用链。
- fresh runs 期间仍出现一条既有 warning：
  - `res://city_game/combat/artillery/CityM777Howitzer.tscn:8 - ext_resource, invalid UID ... CityArtilleryLanyardLine.gd`
- 该 warning 与 `v59` 机械狗 scene/lab foundation 无直接耦合；本轮未处理。

## 结论

- `REQ-0031-001`：通过
- `REQ-0031-002`：通过
- `REQ-0031-003`：通过
- `REQ-0031-004`：通过
- `v59` closeout：通过
