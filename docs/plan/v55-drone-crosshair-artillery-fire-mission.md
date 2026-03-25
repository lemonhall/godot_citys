# V55 Drone Crosshair Artillery Fire Mission

## Goal

让玩家在无人机 FPV 观察态里，直接按 `T` 把准星落点写进正式炮击黄叉主链，形成“无人机校准炮击”的最短路径，同时保持 map-side 与 howitzer-side 的同口径诸元更新。

## Dependencies

- drone runtime：
  - `res://city_game/combat/drone/CityPlayerDroneRuntime.gd`
- artillery fire mission：
  - `res://city_game/combat/artillery/CityArtilleryFireMissionRuntime.gd`
- 主世界 host：
  - `res://city_game/scripts/CityPrototype.gd`
- map consumer：
  - `res://city_game/ui/CityMapScreen.gd`

## Contract Freeze

- trigger：
  - `player drone active`
  - `FPV ADS active`
  - `KEY_T`
- host：
  - reuse `request_artillery_fire_mission_from_world_point()`
- marker：
  - single active yellow cross
  - repeated `T` replaces target
- solution：
  - live howitzer operation active -> solved now
  - no live operation -> pending now
- compatibility：
  - non-drone-FPV `T` keeps existing meaning

## PRD Trace

- `REQ-0029-019`
- `REQ-0029-020`
- `REQ-0029-024`

## Scope

做什么：

- 在 `CityPrototype.gd` 给 `KEY_T` 增加无人机炮击标定优先分支
- 读取 drone FPV 准星 world target
- 复用正式 artillery fire mission request host
- 保证重复标定只更新单个黄叉
- 补 focused tests、e2e 与 verification 文档

不做什么：

- 不新增 drone-only artillery marker
- 不改 ballistic solver 本体
- 不改 full map 右键菜单表现
- 不做自动开图、自动拨炮或自动击发
- 不改 observer / shell / explosion 既有逻辑

## Acceptance

1. 自动化测试必须证明：`player drone active + FPV ADS active` 下按 `T` 会创建正式 artillery fire mission，而不是静默无事发生。
2. 自动化测试必须证明：新 mission 的 `target_world_position` 与无人机准星 `world_target` 对齐，而不是落到另一个私有坐标系。
3. 自动化测试必须证明：未操炮时，`T` 标定后的 fire mission 仍保持 `requires_live_howitzer_operation` pending 口径。
4. 自动化测试必须证明：重复按 `T` 只更新单个 active 黄叉，不会累积多个 artillery fire mission pin。
5. 自动化测试必须证明：在 live howitzer 操炮 active 时，按 `T` 更新 target 会立刻刷新 solved bearing / pitch。
6. 自动化测试必须证明：无人机重标定后，howitzer 操炮 ownership 与 artillery HUD 仍保持。
7. 自动化测试必须证明：非无人机 FPV 场景下，`T` 的既有 fast-travel shortcut 不回退。

## Files

- Update: `docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md`
- Create: `docs/ecn/ECN-0039-drone-crosshair-artillery-fire-mission.md`
- Create: `docs/plans/2026-03-26-v55-drone-crosshair-artillery-fire-mission-design.md`
- Create: `docs/plan/v55-index.md`
- Create: `docs/plan/v55-drone-crosshair-artillery-fire-mission.md`
- Update: `city_game/scripts/CityPrototype.gd`
- Create: `tests/world/test_city_drone_artillery_target_marking_contract.gd`
- Create: `tests/e2e/test_city_drone_artillery_recalibration_flow.gd`
- Create: `docs/plan/v55-m3-verification-2026-03-26.md`

## Steps

1. Analysis / Doc Freeze
   - 冻结 `drone + FPV + T`、shared host、single-marker replace 与 compatibility 边界。
2. TDD Red
   - 先写：
     - `test_city_drone_artillery_target_marking_contract.gd`
     - `test_city_drone_artillery_recalibration_flow.gd`
3. Run Red
   - 预期第一轮红灯原因：
     - `T` 仍只走既有快捷语义
     - drone crosshair 尚未接入 artillery fire mission host
4. TDD Green
   - 最小实现 `CityPrototype.gd` 的 `KEY_T` 优先级与 host helper。
5. Verification
   - 跑新 tests + 既有 artillery / drone / fast travel regressions；
   - 回填 `v55-m3-verification-2026-03-26.md`。

## Risks

- 如果把 world target 到 fire mission 的桥接写在 map screen 层，会把 UI 变成状态真源。
- 如果 drone `T` 入口不要求 FPV ADS，可见准星与实际落点之间的心智模型会变脏。
- 如果只测 mission state 不测 fast travel regression，`T` 的既有快捷语义可能被无意踩坏。
