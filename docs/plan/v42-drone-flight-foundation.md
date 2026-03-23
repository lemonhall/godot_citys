# V42 Drone Flight Foundation

## Goal

建立第一条正式的玩家无人机基础链：在 `CityPrototype` 中按下**小键盘 `5`** 即可触发无人机放飞；放飞期间玩家与武器输入被冻结，约 `2.0s` 的 deploy sequence 结束后自动切到无人机第三人称 chase camera；活跃阶段提供自稳定 hover flight；再次按下**同一个小键盘 `5`** 时，进入回收 sequence，无人机飞回玩家身边并在结束后恢复玩家控制。整个系统必须是 `drone-only runtime`，不得继续依赖直升机炮艇 combat semantics。

## Dependencies

- 依赖 `PlayerController` 已存在的：
  - `_movement_locked`
  - `_control_enabled`
  - `_process_water_traversal(delta)`
  - `_read_move_input()`
- 依赖 `CityPrototype` 已存在的：
  - `_unhandled_input(event)`
  - `handle_debug_keypress(keycode, physical_keycode)`
- 依赖正式 drone scene / asset：
  - `res://city_game/combat/drone/CityDroneGunship.tscn`
  - `res://city_game/assets/environment/source/aircraft/drone_a.glb`

## Contract Freeze

- 正式入口键：
  - `KEY_KP_5`
- 非正式入口：
  - `KEY_5` 不触发
- 正式 drone scene：
  - `res://city_game/combat/drone/CityDroneGunship.tscn`
- 建议正式 runtime：
  - `res://city_game/combat/drone/CityPlayerDroneRuntime.gd`
- 建议正式 flight controller：
  - `res://city_game/combat/drone/CityPlayerDroneFlightController.gd`
- 建议正式 camera rig：
  - `res://city_game/combat/drone/CityPlayerDroneCameraRig.tscn`
- 正式状态机：
  - `stowed`
  - `deploying`
  - `active`
  - `recovering`
- 正式 debug getter：
  - `CityPrototype.get_player_drone_debug_state()`
- 正式 debug fields：
  - `system_state`
  - `camera_owner`
  - `input_owner`
  - `transition_progress`
  - `player_locked`
  - `drone_visible`
  - `drone_world_position`
  - `body_yaw_deg`
  - `presentation_scale`
  - `planar_velocity_mps`
  - `vertical_velocity_mps`
  - `visual_pitch_deg`
  - `visual_roll_deg`
  - `rotor_blur_pitch_deg`
  - `rotor_blur_roll_deg`
  - `last_reject_reason`

## PRD Trace

- `REQ-0027-001`
- `REQ-0027-002`
- `REQ-0027-003`
- `REQ-0027-004`
- `REQ-0027-005`
- `REQ-0027-006`

## Scope

做什么：

- 冻结 drone-only runtime 边界，彻底脱离 helicopter combat runtime
- 在 `CityPrototype` 接入 `KEY_KP_5` deploy / recover toggle
- 建立 formal deploy / recover sequence
- 建立 third-person chase camera ownership contract
- 建立自稳定 hover flight foundation
- 建立 stable-heading rotorcraft strafe 语义、鼠标 yaw 转向与更高前冲速度
- 建立 enlarged third-person presentation 与 rotor blur 姿态同步 contract
- 建立 player lock / restore contract
- 规划 focused tests 与 portability contract

不做什么：

- 不做武器挂载或 drone fire input
- 不做 FPV / acro / 穿越机模式
- 不做 battery、信号丢失、风场、失控返航
- 不做拍照、录像、侦察面板或 picture-in-picture
- 不做 obstacle avoidance 或 autonomous waypoint
- 不做任务系统、地图 pin、world ring 接入

## Acceptance

1. 自动化测试必须证明：正式入口只认 `KEY_KP_5`，`KEY_5` 不触发无人机系统。
2. 自动化测试必须证明：正式 drone runtime script path 位于 `combat/drone/`，而不是 `combat/helicopter/`。
3. 自动化测试必须证明：按下 `KEY_KP_5` 后系统进入 `deploying`，并在约 `2.0s` transition 后才把 `camera_owner` 切到 `drone`。
4. 自动化测试必须证明：`deploying` / `active` / `recovering` 三段期间，玩家移动、武器、准星输入全部失效。
5. 自动化测试必须证明：active 阶段 `W/A/S/D` 产生 camera-relative planar control，`E` 与 `Space` 上升，`Q` 下降。
6. 自动化测试必须证明：active 阶段机体默认保持 stable heading，不允许再按平面速度自动扭 `yaw`；`W` 必须 nose-down，`S` 必须 nose-up，`A/D` 必须分别产生左/右 bank。
7. 自动化测试必须证明：鼠标左右滑动会在 active flight 中驱动无人机 yaw 左/右转向，且单次中等幅度 mouse motion 不得过激。
8. 自动化测试必须证明：`E/Q/Space` 的垂直机动速度显著高于初版 slow-hover lift/sink，满足快速上升与下降。
9. 自动化测试必须证明：释放飞行输入后无人机回到 near-zero hover，而不是继续漂移或瞬时硬停。
10. 自动化测试必须证明：第三人称 presentation 至少维持约 `3x` 的正式视觉体量，且 rotor blur 必须跟随机体共享 pitch/roll 姿态。
11. 自动化测试必须证明：active 状态再次按下 `KEY_KP_5` 会进入 `recovering`，并且只有在回收 sequence 结束后玩家 input/camera owner 才恢复。
12. 自动化测试必须证明：`CityPrototype` 暴露 `get_player_drone_debug_state()`，供 focused tests 直接断言 ownership、heading 与 presentation。
13. 反作弊条款：不接受“切一个 inspection camera + 隐藏玩家武器”冒充正式无人机系统。

## Files

- Create: `docs/prd/PRD-0027-drone-flight-foundation.md`
- Create: `docs/plans/2026-03-24-v42-drone-flight-foundation-design.md`
- Create: `docs/plan/v42-index.md`
- Create: `docs/plan/v42-drone-flight-foundation.md`
- Create: `city_game/combat/drone/CityPlayerDroneRuntime.gd`
- Create: `city_game/combat/drone/CityPlayerDroneFlightController.gd`
- Create: `city_game/combat/drone/CityPlayerDroneCameraRig.tscn`
- Modify: `city_game/combat/drone/CityDroneGunship.tscn`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/scripts/PlayerController.gd`
- Create: `tests/world/test_city_player_drone_toggle_contract.gd`
- Create: `tests/world/test_city_player_drone_camera_takeover_contract.gd`
- Create: `tests/world/test_city_player_drone_flight_input_contract.gd`
- Create: `tests/world/test_city_player_drone_speed_and_attitude_contract.gd`
- Create: `tests/world/test_city_player_drone_presentation_contract.gd`
- Create: `tests/world/test_city_player_drone_portability_contract.gd`
- Create: `tests/world/test_city_player_drone_streaming_anchor_contract.gd`
- Create: `tests/e2e/test_city_player_drone_flow.gd`

## Steps

1. Analysis / Doc Freeze
   - 先冻结 `KEY_KP_5`、deploy/recover state machine、third-person ownership 和非目标边界。
2. TDD Red
   - 先写 toggle contract、camera takeover、player lock 和 flight input tests。
   - 预期第一轮红灯原因：
     - `CityPrototype` 尚未接入 `KEY_KP_5`
     - 没有 `get_player_drone_debug_state()`
     - 没有 formal drone runtime
3. TDD Green
   - 新增 drone-only runtime、flight controller、camera rig，并把 toggle 接入 `CityPrototype`。
4. Refactor
   - 清理 player lock glue，确保 player 与 drone ownership 只在一个地方裁决。
5. E2E
   - 跑完整用户流程：
     - `KEY_KP_5` 放飞
     - deploy 完成后切到 drone chase camera
     - 活跃飞行
     - `KEY_KP_5` 回收
     - recover 完成后恢复玩家控制
6. Review / Closeout
   - 写 fresh verification 文档，回填 v42 追溯矩阵与差异列表。

## Risks

- 如果继续把 drone runtime 挂在 helicopter combat 脚本上，后续每个 drone feature 都会被 orbit / missile / destroy 逻辑污染。
- 如果 camera ownership 与 input ownership 没有 formal state，很容易出现 deploy/recover 中途玩家泄漏控制权。
- 如果 active flight 直接照抄 player walk 或 inspection camera，手感会立刻偏离“自稳定摄影无人机”。
- 如果 v42 不冻结 portability contract，后续蜘蛛 lab 很容易再长出一套 lab-only drone runtime。
