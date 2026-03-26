# V61 M4 Verification - 2026-03-26

## Scope

验证 `v61` 在 2026-03-26 的主世界 companion 语义追加收口：

- 小键盘 `4` 召唤 / 回收机械狗维持正式热键
- 主世界 `KP_4` 默认进入右侧伴随态，不立刻接管镜头和控制权
- `Insert` 在 `follow <-> controlled` 间切换
- 伴随态下 `Player` 保持输入与镜头所有权；控制态下恢复旧版 dog-control 语义
- 伴随态保持“跟随玩家，但不锁头盯玩家”的右侧 slot 行为
- 机械狗展示尺寸小幅回调，不回退 `v59/v60/v61-m3` 既有 joint / pose / locomotion / lab 合同

## Commands

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

$tests=@(
  'res://tests/world/test_city_player_robot_dog_toggle_contract.gd',
  'res://tests/world/test_city_player_robot_dog_camera_takeover_contract.gd',
  'res://tests/world/test_city_player_robot_dog_follow_contract.gd',
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
| `test_city_player_robot_dog_toggle_contract.gd` | PASS | `KP_4` 只认小键盘、召唤后默认进入 `follow`、右侧 slot 生成、再次 `KP_4` 收回 |
| `test_city_player_robot_dog_camera_takeover_contract.gd` | PASS | summon 默认不接管；`Insert` 进入 dog-control；再次 `Insert` 退回 follow；camera / freeze / compass / minimap 所有权切换成立 |
| `test_city_player_robot_dog_follow_contract.gd` | PASS | 伴随态能收敛到玩家右侧 slot，朝向大体与玩家前向一致，且不会像敌对目标那样锁头盯玩家 |
| `test_city_player_robot_dog_ground_locomotion_contract.gd` | PASS | 既有 `walk / run / backward / turn / turn_move / prone` 合同未回退 |
| `test_city_player_robot_dog_presentation_contract.gd` | PASS | 机械狗尺寸小幅回调后仍处于 formal presentation envelope 内 |
| `test_robot_dog_lab_control_contract.gd` | PASS | `RobotDogLab` 继续走 formal control runtime，lab 默认 dog-control 语义不回退 |
| `test_city_navigation_compass_hud_contract.gd` | PASS | 共享 compass HUD 主链未被 companion 语义破坏 |
| `test_city_player_robot_dog_flow.gd` | PASS | 主世界 `KP_4 -> Insert -> W -> Shift+W -> P -> Insert -> KP_4` 整链路成立 |
| `test_robot_dog_scene_contract.gd` | PASS | `v59` formal robot dog scene foundation 未回退 |
| `test_robot_dog_joint_contract.gd` | PASS | `v60` 单轴 `Z` joint / limit 合同未回退 |
| `test_robot_dog_crouch_pose_contract.gd` | PASS | `v60` crouch / stand pose 合同未回退 |
| `test_robot_dog_leg_visual_pivot_contract.gd` | PASS | `LegPivotRoot -> HipPivot / CalfPivot` visual rig 未回退 |
| `test_robot_dog_lab_scene_contract.gd` | PASS | lab scene-first hierarchy 与 visual debug contract 兼容 |
| `test_robot_dog_lab_prone_flow.gd` | PASS | lab 中 `P / F5` 基础流仍成立 |
| headless parse check | PASS with warning | 仍存在既有 `CityM777Howitzer.tscn` invalid UID warning，本轮未处理 |

## Traceability

| Req ID | Evidence |
|---|---|
| REQ-0033-001 | `test_city_player_robot_dog_toggle_contract.gd` |
| REQ-0033-002 | `test_city_player_robot_dog_toggle_contract.gd`, `test_city_player_robot_dog_camera_takeover_contract.gd`, `test_city_player_robot_dog_follow_contract.gd` |
| REQ-0033-003 | `test_city_player_robot_dog_camera_takeover_contract.gd`, `test_city_player_robot_dog_flow.gd` |
| REQ-0033-004 | `test_city_player_robot_dog_ground_locomotion_contract.gd`, `test_city_player_robot_dog_flow.gd` |
| REQ-0033-005 | `test_city_player_robot_dog_ground_locomotion_contract.gd`, `test_robot_dog_lab_control_contract.gd`, `test_robot_dog_leg_visual_pivot_contract.gd` |
| REQ-0033-006 | `test_city_player_robot_dog_camera_takeover_contract.gd`, `test_city_player_robot_dog_follow_contract.gd`, `test_city_navigation_compass_hud_contract.gd` |
| REQ-0033-007 | 上述 focused tests 与 `v59/v60/v61` regression suite 共同约束 |

## Notes

- `CityRobotDogControlRuntime.gd` 现已显式区分 `follow` 与 `controlled` 两个正式模式；主世界 consumer 默认走 `follow`，lab 继续走 `controlled`。
- 伴随 slot 使用玩家右侧编队位，远距丢失时允许 recover，近距时速度按 slot 误差自动减小，避免满速冲过头。
- `CityPrototype.gd` 已在 summon / mode-toggle 上接入 focus message，给用户一个轻量的 `Insert / KP4` 提示，而不引入第二套 HUD 状态机。
