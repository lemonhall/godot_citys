# V52 Artillery Gameplay Ballistic Solver

## Goal

把 howitzer 的弹道主链从“会飞会炸”推进到“有正式射程 envelope、能正解落点、能反解诸元，而且 live shell 与 solver 同口径”。

## Dependencies

- howitzer runtime：
  - `res://city_game/combat/artillery/CityM777Howitzer.gd`
- live shell runtime：
  - `res://city_game/combat/artillery/CityArtilleryShell.gd`
- 主世界 host：
  - `res://city_game/scripts/CityPrototype.gd`
- shared north/bearing：
  - `res://city_game/world/navigation/CityWorldOrientation.gd`

## Contract Freeze

- default shell profile：
  - `m795_he`
  - `min_range_m = 1500`
  - `max_range_m = 22500`
- ballistic model：
  - gameplay point-mass
  - no wind
  - no Coriolis
  - no charge table
- shared solver：
  - `CityArtilleryBallistics.gd`

## PRD Trace

- `REQ-0029-014`
- `REQ-0029-015`
- `REQ-0029-016`
- `REQ-0029-017`

## Scope

做什么：

- 新建 shared artillery ballistic utility
- 冻结正式 ammo profile / range envelope
- 实现 forward impact prediction
- 实现 inverse target solve
- 让 howitzer firing solution payload 与 live shell runtime 接到 shared utility
- 补 focused tests、research markdown/pdf 与 verification 文档

不做什么：

- 不做军规级气象/风偏/装药号
- 不做预测落点 HUD
- 不做任务化目标点选取 UI
- 不做高级精确弹、增程弹与多弹种切换体验

## Acceptance

1. 自动化测试必须证明：shared ballistic utility 存在，并暴露正式 ammo profile / forward / inverse API。
2. 自动化测试必须证明：默认 `m795_he` profile 的最小/最大射程冻结为 `1500m / 22500m`。
3. 自动化测试必须证明：forward prediction 在 `45°` 级别 shot 上的极限射程与 `22500m` envelope 共线。
4. 自动化测试必须证明：inverse solver 对 in-range 目标给出 bearing / pitch，对过近或过远目标明确返回 `out_of_range`。
5. 自动化测试必须证明：`target -> solve -> predict` round-trip 保持在正式误差阈值内。
6. 自动化测试必须证明：howitzer firing solution payload 与 live shell runtime 使用 shared ballistic utility 的求解速度与 launch 语义，而不是旧的私有速度口径。

## Files

- Update: `docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md`
- Create: `docs/ecn/ECN-0036-artillery-gameplay-ballistic-solver.md`
- Create: `docs/plans/2026-03-25-v52-artillery-gameplay-ballistic-solver-design.md`
- Create: `docs/plan/v52-index.md`
- Create: `docs/plan/v52-artillery-gameplay-ballistic-solver.md`
- Create: `city_game/combat/artillery/CityArtilleryBallistics.gd`
- Update: `city_game/combat/artillery/CityM777Howitzer.gd`
- Update: `city_game/combat/artillery/CityArtilleryShell.gd`
- Create: `tests/world/test_city_artillery_ammo_profile_contract.gd`
- Create: `tests/world/test_city_artillery_ballistics_forward_solver_contract.gd`
- Create: `tests/world/test_city_artillery_ballistics_inverse_solver_contract.gd`
- Create: `tests/world/test_city_artillery_ballistics_round_trip_contract.gd`
- Create: `tests/world/test_city_m777_howitzer_ballistic_profile_payload_contract.gd`
- Create: `tests/world/test_city_artillery_shell_shared_ballistic_model_contract.gd`
- Create: `docs/plan/v52-m3-verification-2026-03-25.md`

## Steps

1. Analysis / Doc Freeze
   - 冻结 ammo profile、forward / inverse / shared-model 与非目标边界。
2. TDD Red
   - 先写六条 tests：
     - `test_city_artillery_ammo_profile_contract.gd`
     - `test_city_artillery_ballistics_forward_solver_contract.gd`
     - `test_city_artillery_ballistics_inverse_solver_contract.gd`
     - `test_city_artillery_ballistics_round_trip_contract.gd`
     - `test_city_m777_howitzer_ballistic_profile_payload_contract.gd`
     - `test_city_artillery_shell_shared_ballistic_model_contract.gd`
3. Run Red
   - 预期第一轮红灯原因：
     - shared ballistic utility 尚不存在；
     - ammo profile 尚未正式冻结；
     - forward / inverse solver 尚未实现。
4. TDD Green
   - 实现 shared utility，并接到 howitzer / shell runtime。
5. Refactor
   - 收口 howitzer payload 与 shell runtime 的 ballistic source，避免旧 velocity path 残留。
6. Verification
   - 跑 focused tests、世界 ballistic 回归、项目解析检查；
   - 生成 research markdown/pdf；
   - 回填 `v52-m3-verification-2026-03-25.md`。

## Risks

- 如果 solver / live shell 继续保留两套 velocity 语义，后面 HUD prediction 一接进来就会立即分叉。
- 如果直接追求带阻力数值积分，这轮很容易滑向“过于硬核”，违背当前用户范围冻结。
