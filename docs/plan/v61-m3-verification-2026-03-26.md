# V61 M3 Verification - 2026-03-26

## Scope

验证 `v61` 正式交付链：

- 小键盘 `4` 召唤 / 回收机械狗
- 主世界第三人称镜头接管、`Player` freeze、输入所有权切换
- `idle / walk / run / backward / turn_left / turn_right / turn_move / prone` 地面 locomotion
- `A = 左转`、`D = 右转` 的输入 / locomotion / gait 符号统一
- 机械狗鼠标视角、俯仰限位，以及共享指南针 / 小地图朝向跟随机械狗
- 机械狗正式尺寸抬回到更大的可读量级，第三人称相机抬高到更明显的俯视机位
- `W` 常速提升到旧 sprint 档位附近，`Shift+W` 保留更快 sprint
- `W` 改为单腿依次换步的四拍 crawl，`Shift+W` 保留更快的对角 trot，不再出现“左右前腿一起迈”的假步态
- `RobotDogLab` 与主世界共用同一条正式控制 runtime
- `v60` 的 joint / pivot / crouch / lab contract 不回退

## Commands

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

$tests=@(
  'res://tests/world/test_city_player_robot_dog_toggle_contract.gd',
  'res://tests/world/test_city_player_robot_dog_camera_takeover_contract.gd',
  'res://tests/world/test_city_player_robot_dog_ground_locomotion_contract.gd',
  'res://tests/world/test_city_player_robot_dog_presentation_contract.gd',
  'res://tests/world/test_robot_dog_lab_control_contract.gd',
  'res://tests/world/test_city_navigation_compass_hud_contract.gd',
  'res://tests/e2e/test_city_player_robot_dog_flow.gd',
  'res://tests/world/test_robot_dog_scene_contract.gd',
  'res://tests/world/test_robot_dog_joint_contract.gd',
  'res://tests/world/test_robot_dog_crouch_pose_contract.gd',
  'res://tests/world/test_robot_dog_leg_visual_pivot_contract.gd',
  'res://tests/world/test_robot_dog_lab_scene_contract.gd',
  'res://tests/e2e/test_robot_dog_lab_prone_flow.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}

& $godot --headless --rendering-driver dummy --path $project --quit
```

## Results

| Command / Test | Result | Notes |
|---|---|---|
| `test_city_player_robot_dog_toggle_contract.gd` | PASS | `KP_4` 召唤 / 回收、2m 前向生成、朝向继承成立 |
| `test_city_player_robot_dog_camera_takeover_contract.gd` | PASS | 主世界第三人称镜头接管、`Player` freeze、鼠标 yaw/pitch、共享 compass/minimap 朝向跟随机械狗成立 |
| `test_city_player_robot_dog_ground_locomotion_contract.gd` | PASS | `walk / run / backward / turn / turn_move / prone`、`A=左/D=右`、更快常速、body heave/pitch/roll 与四拍 walk / 更快 trot 合同成立 |
| `test_city_player_robot_dog_presentation_contract.gd` | PASS | 机械狗视觉尺寸已放大一倍量级，相机抬高到更明显俯视，最低可见点贴地 |
| `test_robot_dog_lab_control_contract.gd` | PASS | `RobotDogLab` 已挂正式 control runtime，并默认进入 dog control |
| `test_city_navigation_compass_hud_contract.gd` | PASS | 共享指南针 HUD 基础合同未回退，主世界玩家链路仍维持正北/正东 bearing 合同 |
| `test_city_player_robot_dog_flow.gd` | PASS | 主世界 `KP_4 -> W -> Shift+W -> P -> KP_4` 整链路成立 |
| `test_robot_dog_scene_contract.gd` | PASS | `v59` formal robot dog scene foundation 未回退 |
| `test_robot_dog_joint_contract.gd` | PASS | `v60` 单轴 `Z` joint / limit 合同未回退 |
| `test_robot_dog_crouch_pose_contract.gd` | PASS | `v60` crouch / stand pose 合同未回退 |
| `test_robot_dog_leg_visual_pivot_contract.gd` | PASS | `LegPivotRoot -> HipPivot / CalfPivot` visual rig 未回退 |
| `test_robot_dog_lab_scene_contract.gd` | PASS | lab scene-first hierarchy 与 visual debug contract 兼容 |
| `test_robot_dog_lab_prone_flow.gd` | PASS | lab 中 `P / F5` 基础流仍成立 |
| headless parse check | PASS with warning | 存在 1 条与 `CityM777Howitzer.tscn` 相关的既有 UID warning，未在本轮处理 |

## Traceability

| Req ID | Evidence |
|---|---|
| REQ-0033-001 | `test_city_player_robot_dog_toggle_contract.gd` |
| REQ-0033-002 | `test_city_player_robot_dog_camera_takeover_contract.gd`, `test_city_player_robot_dog_presentation_contract.gd` |
| REQ-0033-003 | `test_city_player_robot_dog_camera_takeover_contract.gd`, `test_city_player_robot_dog_flow.gd` |
| REQ-0033-004 | `test_city_player_robot_dog_ground_locomotion_contract.gd`, `test_city_player_robot_dog_flow.gd` |
| REQ-0033-005 | `test_city_player_robot_dog_ground_locomotion_contract.gd`, `test_robot_dog_lab_control_contract.gd`, `test_robot_dog_leg_visual_pivot_contract.gd` |
| REQ-0033-006 | `test_city_player_robot_dog_camera_takeover_contract.gd`, `test_city_player_robot_dog_ground_locomotion_contract.gd`, `test_robot_dog_lab_control_contract.gd` |
| REQ-0033-007 | 上述 focused tests 与 `v60` regression suite 共同约束 |

## Notes

- `CityRobotDogControlRuntime` 现已成为主世界与 lab 共用的正式控制壳；`CityRobotDog.gd` 保持 visual/pose runtime 职责，只在 `v60` joint/pivot 主链上叠 gait offset。
- `RobotDogLab` 的 `get_robot_dog()` 继续返回 formal `CityRobotDog.tscn` visual scene，避免旧 debug / contract tests 断链；新增 `get_robot_dog_runtime()` 暴露正式控制 runtime。
- 主世界 `CityPrototype.gd` 现在会把 `W/A/S/D/Shift/P` 以及机械狗控制态下的鼠标事件转发给 active robot dog runtime，因此真实用户流和 headless e2e 走的是同一条输入链。
- 2026-03-26 追加修复：`CityRobotDogControlRuntime` 已把 `A=左转 / D=右转` 与 `CityRobotDog.gd` 的 locomotion/gait 符号重新统一，避免“输入左转、视觉却像右转”的双重合同漂移。
- 2026-03-26 追加修复：机械狗控制态已把 shared compass / minimap heading / world focus 从冻结的 `Player` 身上切到 active robot dog runtime，鼠标右移会让 shared bearing 顺时针增加。
- 2026-03-26 追加修复：`CityRobotDogControlRuntime.tscn` 已把 `visual_scale` 提回 `4.0`，并把第三人称相机抬到更高的俯视机位，解决“机械狗过小、相机过低”的表现问题。
- 2026-03-26 追加修复：`W` 常速已提升到旧 sprint 档位附近，`Shift+W` 继续保留更快 sprint；`CityRobotDog.gd` 的 walk gait 也从两拍对角节奏切成单腿依次换步的四拍 crawl，避免低速前进时出现“左右前腿一起迈”的假步态。
