# V42 Index

## 愿景

PRD 入口：[PRD-0027 Drone Flight Foundation](../prd/PRD-0027-drone-flight-foundation.md)

设计入口：[2026-03-24-v42-drone-flight-foundation-design.md](../plans/2026-03-24-v42-drone-flight-foundation-design.md)

依赖入口：

- [v37-index.md](./v37-index.md)
- [v39-index.md](./v39-index.md)
- [v40-index.md](./v40-index.md)
- [v41-index.md](./v41-index.md)

`v42` 的目标不是把无人机临时塞成一个 inspection camera，也不是把现有 `CityDroneGunship.tscn` 再继续绑在直升机炮艇 runtime 上；它要正式建立一条**玩家自有无人机 foundation**。入口冻结为**小键盘 `5` (`KEY_KP_5`)**：当系统处于 `stowed` 时，按下它会触发约 `2.0s` 的放飞 sequence，无人机从玩家身旁升空，玩家在整个过渡期间被完全锁住；只有当 transition 结束后，视角才正式切到无人机第三人称 chase camera。进入 `active` 后，无人机采用第三人称自稳定飞行：`W/A/S/D` 平面移动，`E` 与 `Space` 上升，`Q` 下降，松手 hover；机体 heading 默认保持稳定，不再按速度方向自动扭头，`W/S` 负责前后 pitch，`A/D` 负责左右 bank，鼠标水平滑动负责温和的 yaw 转向，垂直机动速度也必须满足快速上升/下降观感。正式 third-person presentation 同时冻结为放大后的可读体量，机身与四个 rotor blur 共享同一套倾斜姿态。再次按下同一个小键盘 `5` 后，系统进入 `recovering`，无人机自动飞回玩家身旁；只有当回收动画结束后，玩家控制权与相机 ownership 才被恢复。

## 决策冻结

- 正式入口键：
  - `KEY_KP_5`
- 非入口键：
  - `KEY_5`
- 正式无人机视觉资产：
  - `res://city_game/assets/environment/source/aircraft/drone_a.glb`
- 正式无人机场景：
  - `res://city_game/combat/drone/CityDroneGunship.tscn`
- 推荐正式 drone runtime：
  - `res://city_game/combat/drone/CityPlayerDroneRuntime.gd`
- 推荐正式 flight controller：
  - `res://city_game/combat/drone/CityPlayerDroneFlightController.gd`
- 推荐正式 camera rig：
  - `res://city_game/combat/drone/CityPlayerDroneCameraRig.tscn`
- 正式状态机：
  - `stowed`
  - `deploying`
  - `active`
  - `recovering`
- 正式 ownership 语义：
  - `stowed`: player input + player camera
  - `deploying`: no input + player camera
  - `active`: drone input + drone camera
  - `recovering`: no input + drone camera

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | PRD / design / v42 plan 全链冻结 | `KEY_KP_5`、deploy/recover、ownership、自稳定第三人称与非目标边界全部落文档 | `rg -n "KEY_KP_5|deploying|recovering|camera_owner|input_owner|combat/drone" docs/prd/PRD-0027-drone-flight-foundation.md docs/plan/v42-index.md docs/plan/v42-drone-flight-foundation.md docs/plans/2026-03-24-v42-drone-flight-foundation-design.md` | done |
| M1 toggle + drone-only runtime | 正式 hotkey toggle、drone runtime 脱离 helicopter | `KEY_KP_5` 驱动 `stowed <-> deploying/recovering`；runtime path 留在 `combat/drone/` | `tests/world/test_city_player_drone_toggle_contract.gd`、`tests/world/test_city_drone_gunship_scene_contract.gd` | done |
| M2 transition + player lock | deploy / recover sequence、玩家冻结 / 恢复 | camera/input ownership 在正确时刻切换，玩家位置与武器输入在 transition 中完全冻结 | `tests/world/test_city_player_drone_camera_takeover_contract.gd` | done |
| M3 active flight foundation | 第三人称自稳定 hover flight | `W/A/S/D` 平面移动、`E/Space` 上升、`Q` 下降、松手 hover 与平滑姿态成立；机体默认 stable heading，不按平面速度自动扭 yaw；鼠标水平滑动可温和控制 yaw；前冲速度/垂直机动/前倾姿态与 enlarged third-person presentation 达到正式飞行器观感 | `tests/world/test_city_player_drone_flight_input_contract.gd`、`tests/world/test_city_player_drone_speed_and_attitude_contract.gd`、`tests/world/test_city_player_drone_presentation_contract.gd` | done |
| M4 world wrapper + portability | `CityPrototype` 正式接入，future lab portability contract 锁定 | `get_player_drone_debug_state()` 成立，主世界 wrapper 可驱动完整放飞/飞行/回收链，drone active 时 streaming/minimap focus 跟随无人机，且不分叉第二套 lab runtime | `tests/world/test_city_player_drone_portability_contract.gd`、`tests/world/test_city_player_drone_streaming_anchor_contract.gd`、`tests/e2e/test_city_player_drone_flow.gd` | done |

## 计划索引

- [v42-drone-flight-foundation.md](./v42-drone-flight-foundation.md)

## 追溯矩阵

| Req ID | V42 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0027-001 | `v42-drone-flight-foundation.md` | `tests/world/test_city_drone_gunship_scene_contract.gd` | `docs/plan/v42-m4-verification-2026-03-24.md` | `docs/plan/v42-m4-verification-2026-03-24.md` | done |
| REQ-0027-002 | `v42-drone-flight-foundation.md` | `tests/world/test_city_player_drone_toggle_contract.gd` | `docs/plan/v42-m4-verification-2026-03-24.md` | `docs/plan/v42-m4-verification-2026-03-24.md` | done |
| REQ-0027-003 | `v42-drone-flight-foundation.md` | `tests/world/test_city_player_drone_camera_takeover_contract.gd` | `docs/plan/v42-m4-verification-2026-03-24.md` | `docs/plan/v42-m4-verification-2026-03-24.md` | done |
| REQ-0027-004 | `v42-drone-flight-foundation.md` | `tests/world/test_city_player_drone_camera_takeover_contract.gd` | `docs/plan/v42-m4-verification-2026-03-24.md` | `docs/plan/v42-m4-verification-2026-03-24.md` | done |
| REQ-0027-005 | `v42-drone-flight-foundation.md` | `tests/world/test_city_player_drone_flight_input_contract.gd`、`tests/world/test_city_player_drone_speed_and_attitude_contract.gd`、`tests/world/test_city_player_drone_presentation_contract.gd` | `docs/plan/v42-m4-verification-2026-03-24.md` | `docs/plan/v42-m4-verification-2026-03-24.md` | done |
| REQ-0027-006 | `v42-drone-flight-foundation.md` | `tests/world/test_city_player_drone_portability_contract.gd`、`tests/world/test_city_player_drone_streaming_anchor_contract.gd` | `docs/plan/v42-m4-verification-2026-03-24.md` | `docs/plan/v42-m4-verification-2026-03-24.md` | done |

## Closeout 证据口径

- `v42` 不接受“画面上飞起来了”替代 formal contract。
- 必须有 fresh test 证明：
  - `KEY_KP_5` 与 `KEY_5` 被正确区分
  - deploy / recover transition 完整成立
  - player lock / camera ownership 不泄漏
  - drone runtime 正式脱离 helicopter runtime
  - active drone 的 hover / 平滑输入成立
  - active drone 的 stable heading / pitch-roll 语义成立
  - active drone 的 mouse yaw / fast vertical reposition 成立
  - rotor blur 与 enlarged third-person presentation 合同成立

## ECN 索引

- 暂无

## 差异列表

- 当前没有未收口差异；如后续要继续推进 payload / FPV / 任务接入，应新开 `v43+`，不要回头污染 `v42` foundation 口径。
