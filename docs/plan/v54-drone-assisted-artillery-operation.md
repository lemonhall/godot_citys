# V54 Drone-Assisted Artillery Operation

## Goal

把 howitzer 与无人机从“各自可用”推进到“复合模式稳定可玩”：玩家在操炮态下放飞无人机后，仍可继续调炮、看诸元、按 `Space` 击发，并直接用无人机观察弹着，而不是再被 observer closeout 抢镜头。

## Dependencies

- drone runtime：
  - `res://city_game/combat/drone/CityPlayerDroneRuntime.gd`
  - `res://city_game/combat/drone/CityPlayerDroneFlightController.gd`
- howitzer runtime：
  - `res://city_game/combat/artillery/CityM777HowitzerOperationController.gd`
  - `res://city_game/combat/artillery/CityArtilleryFireMissionRuntime.gd`
- 主世界 host：
  - `res://city_game/scripts/CityPrototype.gd`
- HUD：
  - `res://city_game/ui/PrototypeHud.gd`

## Contract Freeze

- active drone vertical input：
  - `E` 上升
  - `Q` 下降
  - `Space` 不再抬升
- composite mode：
  - `drone active`
  - `howitzer operation active`
- composite `E` ownership：
  - no exit_operation
  - drone ascend only
- composite accepted fire：
  - keep howitzer fire
  - keep shell impact
  - skip observer closeout
  - keep artillery HUD visible

## PRD Trace

- `REQ-0027-005`
- `REQ-0029-022`
- `REQ-0029-023`

## Scope

做什么：

- 从无人机飞控里移除 `Space` 抬升语义
- 在主世界 fire host 中显式识别 drone-assisted artillery composite mode
- 复合模式下 accepted fire 跳过 observer closeout
- 保证 howitzer 操炮输入、HUD、shell 与 impact 结果保持
- 补 focused tests、e2e 与 verification 文档

不做什么：

- 不改 howitzer ballistic solver
- 不改非复合模式的 observer closeout 视觉与时序
- 不做新的无人机观察 HUD / picture-in-picture / 自动标靶
- 不改无人机相机风格与纯无人机 flight feel

## Acceptance

1. 自动化测试必须证明：active drone 下单独按 `Space` 不再产生无人机抬升，而 `E` 仍可抬升。
2. 自动化测试必须证明：玩家先进入 howitzer 操炮态，再放飞无人机后，操炮态不会被 silently release。
3. 自动化测试必须证明：复合模式下按 `E` 不会退出 howitzer 操炮态，且 `E` 仍可抬升无人机。
4. 自动化测试必须证明：复合模式下 artillery solution HUD 仍然可见，且 `L/I`、`Shift+L/I` 等操炮输入继续生效。
5. 自动化测试必须证明：复合模式下按 `Space` 仍会触发 howitzer accepted fire，而不是被无人机吞掉。
6. 自动化测试必须证明：复合模式下 accepted fire 不会激活 observer closeout。
7. 自动化测试必须证明：即使跳过 observer closeout，shell impact / explosion result 仍然存在。
8. 自动化测试必须证明：非复合模式下原有 drone / howitzer 主链不回退。

## Files

- Update: `docs/prd/PRD-0027-drone-flight-foundation.md`
- Update: `docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md`
- Create: `docs/ecn/ECN-0038-drone-assisted-artillery-composite-operation.md`
- Create: `docs/plans/2026-03-26-v54-drone-assisted-artillery-operation-design.md`
- Create: `docs/plan/v54-index.md`
- Create: `docs/plan/v54-drone-assisted-artillery-operation.md`
- Update: `city_game/combat/drone/CityPlayerDroneFlightController.gd`
- Update: `city_game/scripts/CityPrototype.gd`
- Create: `tests/world/test_city_player_drone_space_input_contract.gd`
- Create: `tests/world/test_city_world_howitzer_drone_composite_contract.gd`
- Create: `tests/e2e/test_city_drone_assisted_artillery_operation_flow.gd`
- Create: `docs/plan/v54-m3-verification-2026-03-26.md`

## Steps

1. Analysis / Doc Freeze
   - 冻结 `Space` ownership、composite mode 定义、skip-observer 边界与非目标范围。
2. TDD Red
   - 先写：
     - `test_city_player_drone_space_input_contract.gd`
     - `test_city_world_howitzer_drone_composite_contract.gd`
     - `test_city_drone_assisted_artillery_operation_flow.gd`
3. Run Red
   - 预期第一轮红灯原因：
     - drone 仍吃 `Space`
     - composite mode 仍进入 observer closeout
4. TDD Green
   - 最小实现输入与 fire host 改动。
5. Verification
   - 跑新 tests + 既有 drone/howitzer focused regressions；
   - 回填 `v54-m3-verification-2026-03-26.md`。

## Risks

- 如果只在 `_unhandled_input()` 层绕开 `Space`，但 drone flight controller 仍读 Input singleton，复合模式仍会残留上升副作用。
- 如果 composite 判定依赖 UI 可见性而不是 runtime state，后续极易出现“HUD 没了但操炮没退”的假通过。
- 如果不跑既有 howitzer observer regression，很容易把非复合模式也一起关闭。
