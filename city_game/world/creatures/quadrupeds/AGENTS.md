# Quadruped Agent Notes

本文件只作用于 `city_game/world/creatures/quadrupeds/` 及其子目录；若与仓库根 `AGENTS.md` 冲突，以本文件为准。

## Overview

- 本目录承载机械狗的正式 creature scene 与 control runtime，不是一次性 lab 草稿区。
- 当前冻结范围来自 `v59-v61`：正式 visual scene、8 个 joint anchors、`P` 键 prone、主世界 `KP4` 召唤/回收、`Insert` 跟随 / 接管切换、`idle / walk / run / backward / turn / prone`。
- `pounce / jump / landing / attack` 仍属于 `v62+`，不要在这里偷渡。

## Quick Commands

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
```

- visual / joint / pose focused contract：

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_robot_dog_scene_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_robot_dog_joint_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_robot_dog_crouch_pose_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_robot_dog_leg_visual_pivot_contract.gd'
```

- lab focused contract：

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_robot_dog_lab_scene_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_robot_dog_lab_control_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_robot_dog_lab_prone_flow.gd'
```

- 主世界 focused contract：

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_player_robot_dog_toggle_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_player_robot_dog_camera_takeover_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_player_robot_dog_ground_locomotion_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_player_robot_dog_flow.gd'
```

## Architecture

- `CityRobotDog.tscn`
  - 正式 visual scene；真实模型来自 `res://city_game/assets/environment/source/creatures/robot_dog_02/robot_dog_02.glb`
  - scene 中必须保留 `BodyPivot`、`LegPivotRoot`、`JointAnchors/*`
- `CityRobotDog.gd`
  - 8 个关节 anchor / constraint、`P` 键 prone pose、ground locomotion gait、pose debug state
- `CityRobotDogControlRuntime.tscn`
  - 正式 control runtime scene，挂载 visual dog、相机与移动壳体
- `CityRobotDogControlRuntime.gd`
  - `Insert` 控制权切换、第三人称接管、Player freeze、跟随 / controlled 双模式、输入消费与 streaming focus
- lab：
  - `res://city_game/scenes/labs/RobotDogLab.tscn`
  - 只允许复用正式 `CityRobotDogControlRuntime.tscn`
- 主世界 wrapper：
  - `res://city_game/scripts/CityPrototype.gd`
  - `KP4` 负责召唤 / 回收；不在本目录另起第二套召唤状态机

## Safety & Contracts

- 不要绕过正式 visual scene
  - 为什么：`CityRobotDog.tscn` 才是 8 个 `Marker3D` anchors 与 visual hierarchy 的真源
  - 替代：lab 和主世界都挂正式 scene / runtime，不要直接挂 glb
  - 验证：`test_robot_dog_scene_contract.gd`、`test_robot_dog_lab_scene_contract.gd`

- 不要破坏 `LegPivotRoot -> HipPivot / CalfPivot` 语义
  - 为什么：`v60` 已冻结“pivot 旋转，保留 imported mesh authored offset”的修法
  - 替代：只转 pivot，不直接重写可见大腿 / 小腿 mesh 的 authored local offset
  - 验证：`test_robot_dog_leg_visual_pivot_contract.gd`

- 不要把 joint 轴向和限位改成别的语义
  - 为什么：当前正式 contract 是 8 个关节全部绕 local `Z` 轴、带显式限位
  - 替代：若要扩动作，仍在既有约束上迭代，必要时先更新计划文档
  - 验证：`test_robot_dog_joint_contract.gd`

- 不要让 lab 和主世界各写一套控制逻辑
  - 为什么：输入、相机、follow / controlled、pose state 会迅速漂移
  - 替代：shared logic 留在 `CityRobotDog.gd` 与 `CityRobotDogControlRuntime.gd`，lab / 主世界只做 wrapper
  - 验证：lab focused tests 与主世界 focused tests 同时通过

- 不要偷渡 `v62+` 能力
  - 为什么：`pounce / jump / landing / attack` 还未进入当前冻结范围
  - 替代：当前只围绕 `idle / walk / run / backward / turn / prone` 与控制权切换迭代
  - 验证：`v61-index.md` 与现有 tests 口径一致

## Testing Rules

- 改 visual scene、anchors、pivot、pose 时，至少跑：
  - `test_robot_dog_scene_contract.gd`
  - `test_robot_dog_joint_contract.gd`
  - `test_robot_dog_crouch_pose_contract.gd`
  - `test_robot_dog_leg_visual_pivot_contract.gd`

- 改 control runtime、跟随 / 接管、第三人称相机时，至少跑：
  - `test_robot_dog_lab_control_contract.gd`
  - `test_city_player_robot_dog_toggle_contract.gd`
  - `test_city_player_robot_dog_camera_takeover_contract.gd`
  - `test_city_player_robot_dog_ground_locomotion_contract.gd`
  - `tests/e2e/test_city_player_robot_dog_flow.gd`

- 改 lab wrapper 时，再补：
  - `test_robot_dog_lab_scene_contract.gd`
  - `tests/e2e/test_robot_dog_lab_prone_flow.gd`
