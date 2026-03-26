# V56 Drone Squadron Summon Control

## Goal

把当前单架 `KP_5 toggle` 扩展成正式的机群召唤控制链：短按逐架增援、长按全部回收、总数上限 `10` 架、僚机首版只做分散跟随且不抢长机 owner，同时保证普通飞行链和 howitzer 复合操炮链不回退。

## Dependencies

- player drone runtime：
  - `res://city_game/combat/drone/CityPlayerDroneRuntime.gd`
- 主世界 host：
  - `res://city_game/scripts/CityPrototype.gd`
- 既有 drone tests：
  - `res://tests/world/test_city_player_drone_toggle_contract.gd`
  - `res://tests/world/test_city_player_drone_camera_takeover_contract.gd`
  - `res://tests/e2e/test_city_player_drone_flow.gd`
- 复合操炮回归：
  - `res://tests/e2e/test_city_drone_assisted_artillery_operation_flow.gd`

## PRD Trace

- `REQ-0027-002`
- `REQ-0027-004`
- `REQ-0027-007`
- `REQ-0027-008`
- `REQ-0027-009`

## Scope

做什么：

- 把 `KP_5` 改成短按/长按合同
- 保留现有长机 runtime 为唯一 owner
- 新增 squadron manager 管总数、僚机 spawn/clear 与默认 slot
- 让僚机在场景里以分散位置跟随长机
- 让长按全收在普通态与 howitzer 复合态下都回到正确 context
- 补 focused tests、e2e 与 verification 文档

不做什么：

- 不做 flocking / 避障 / 战术命令
- 不做僚机独立 FPV / 开火 / 自爆
- 不做队形切换 UI
- 不做编队间距可调面板
- 不改既有长机飞控手感

## Acceptance

1. 自动化测试必须证明：`KEY_5` 仍不触发无人机系统，`KEY_KP_5` 才是唯一正式入口。
2. 自动化测试必须证明：`0` 架时短按 `KP_5` 会放飞长机，并保持既有 camera/input takeover 语义。
3. 自动化测试必须证明：长机 engaged 后继续短按 `KP_5`，总机群数会按 `1` 递增，直到 `10` 架封顶。
4. 自动化测试必须证明：召出多架后，场景中的 leader / wingmen 存在明确最小间距，不会长期重叠。
5. 自动化测试必须证明：增援僚机不会改变长机的 `camera_owner` 与 `input_owner`。
6. 自动化测试必须证明：长按 `KP_5` 会把机群总数清回 `0`，并完成正式收回。
7. 自动化测试必须证明：普通飞行态长按全收后，玩家控制和相机归还给玩家。
8. 自动化测试必须证明：`howitzer 操炮 + drone` 复合态下长按全收后，howitzer operation 仍 active，artillery HUD 不消失。

## Files

- Update: `docs/prd/PRD-0027-drone-flight-foundation.md`
- Create: `docs/ecn/ECN-0040-drone-squadron-summon-control.md`
- Create: `docs/plans/2026-03-26-v56-drone-squadron-summon-control-design.md`
- Create: `docs/plan/v56-index.md`
- Create: `docs/plan/v56-drone-squadron-summon-control.md`
- Update: `city_game/scripts/CityPrototype.gd`
- Update: `city_game/combat/drone/CityPlayerDroneRuntime.gd`
- Create: `city_game/combat/drone/CityPlayerDroneSquadronRuntime.gd`
- Create: `city_game/combat/drone/CityPlayerDroneWingman.gd`
- Update: `tests/world/test_city_player_drone_toggle_contract.gd`
- Create: `tests/world/test_city_player_drone_squadron_summon_contract.gd`
- Update: `tests/world/test_city_player_drone_camera_takeover_contract.gd`
- Update: `tests/e2e/test_city_player_drone_flow.gd`
- Update: `tests/e2e/test_city_drone_assisted_artillery_operation_flow.gd`
- Create: `docs/plan/v56-m3-verification-2026-03-26.md`

## Steps

1. Docs Freeze
   - 冻结 `KP_5` 长短按、总数上限、leader-only ownership 与 formation 非目标。
2. TDD Red
   - 先写/改：
     - `test_city_player_drone_toggle_contract.gd`
     - `test_city_player_drone_squadron_summon_contract.gd`
     - `test_city_player_drone_camera_takeover_contract.gd`
     - `test_city_player_drone_flow.gd`
     - `test_city_drone_assisted_artillery_operation_flow.gd`
3. Run Red
   - 预期第一轮红灯原因：
     - `KP_5` 仍只有单架 toggle
     - 没有 squadron count / wingmen runtime
     - 回收仍是第二次短按，而不是长按
4. TDD Green
   - 实现 squadron manager、KP_5 长短按、僚机默认 slot 与 context 恢复。
5. Verification
   - 跑 focused tests + 既有 drone/howitzer regressions；
   - 回填 `v56-m3-verification-2026-03-26.md`。

## Risks

- 如果把僚机做成 full `CityPlayerDroneRuntime`，camera/input owner 很容易互抢。
- 如果长按判定只看 `pressed`，误触召回会非常频繁。
- 如果复合态下全收回直接粗暴解锁 player，howitzer 操炮 ownership 会被意外带坏。
