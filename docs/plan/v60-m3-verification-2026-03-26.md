# V60 M3 Verification - 2026-03-26

## Scope

验证 `v60` 第一刀：

- 8 个关节 local `Z` 单轴铰链合同
- `P` 键爬下 / 起身姿态切换
- `RobotDogLab` 新旧 debug contract 兼容

## Commands

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_robot_dog_scene_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_robot_dog_lab_scene_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_robot_dog_joint_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_robot_dog_crouch_pose_contract.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_robot_dog_lab_prone_flow.gd'
& $godot --headless --rendering-driver dummy --path $project --quit
```

## Results

| Command / Test | Result | Notes |
|---|---|---|
| `test_robot_dog_scene_contract.gd` | PASS | `v59` formal creature scene contract 未回退 |
| `test_robot_dog_lab_scene_contract.gd` | PASS | lab scene-first 层级与老 debug contract 兼容 |
| `test_robot_dog_joint_contract.gd` | PASS | 8 个 joint 的 axis/limit/API/debug schema 已冻结 |
| `test_robot_dog_crouch_pose_contract.gd` | PASS | 爬下姿态、躯干降低、大腿收平、小腿联动成立 |
| `test_robot_dog_lab_prone_flow.gd` | PASS | `P` / `F5` 输入流成立 |
| headless parse check | PASS with warning | 存在 1 条与 `CityM777Howitzer.tscn` 相关的既有 UID warning，未在本轮处理 |

## Traceability

| Req ID | Evidence |
|---|---|
| REQ-0032-001 | `test_robot_dog_joint_contract.gd` |
| REQ-0032-002 | `test_robot_dog_joint_contract.gd` |
| REQ-0032-003 | `test_robot_dog_joint_contract.gd` |
| REQ-0032-004 | `test_robot_dog_crouch_pose_contract.gd` |
| REQ-0032-005 | `test_robot_dog_lab_prone_flow.gd` |
| REQ-0032-006 | `test_robot_dog_joint_contract.gd`, `test_robot_dog_crouch_pose_contract.gd` |
| REQ-0032-007 | 上述 focused tests 共同约束 |

## Notes

- 本轮把 `v60` 第一刀从“walking gait”收窄为“单轴铰链 + `P` 键爬下/起身”，并已按此口径完成。
- 机械狗 hip 关节的真实有效收腿方向是 local `Z` 负向，因此 hip 限位冻结为 `[-60, 5]`。
