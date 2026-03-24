# V49 Artillery Fire Cooldown Retune

## Goal

把 howitzer 的默认 fire cooldown 从 `6.0s` 调整为 `2.0s`，提升当前 lab 操炮节奏，同时不改变 fire API、HUD 冷却语义与非目标边界。

## Dependencies

- 正式 howitzer runtime：
  - `res://city_game/combat/artillery/CityM777Howitzer.gd`
- focused tests：
  - `res://tests/world/test_city_m777_howitzer_scene_contract.gd`
  - `res://tests/world/test_city_m777_howitzer_fire_contract.gd`

## Contract Freeze

- 默认 fire cooldown：
  - `2.0s`
- rejected fire error：
  - `cooldown_active`
- HUD 状态：
  - `装填中 X.Xs...`
  - `可击发`

## PRD Trace

- `REQ-0029-008`

## Scope

做什么：

- 更新 howitzer 默认 cooldown 到 `2.0s`
- 同步 focused contract tests
- 补 fresh verification 文档

不做什么：

- 不改 `Space` 交互语义
- 不改 fire presentation 节点与 shader
- 不改 `SHORT_TEST_COOLDOWN_SEC=0.25` 的 lab interaction test 加速口径
- 不做弹道 / projectile / 爆炸

## Acceptance

1. 自动化测试必须证明：fresh howitzer runtime 的 `cooldown_duration_sec` 默认值为 `2.0s`。
2. 自动化测试必须证明：accepted fire 后 howitzer 进入 `2.0s` 冷却，冷却期间再次 fire 请求仍被拒绝。
3. 自动化测试必须证明：fire contract 的火光、烟尘、拉火绳、后坐和音频行为没有因为 cooldown retune 而回退。

## Files

- Update: `docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md`
- Create: `docs/ecn/ECN-0033-artillery-fire-cooldown-retune.md`
- Create: `docs/plans/2026-03-24-v49-artillery-fire-cooldown-retune-design.md`
- Create: `docs/plan/v49-index.md`
- Create: `docs/plan/v49-artillery-fire-cooldown-retune.md`
- Update: `tests/world/test_city_m777_howitzer_scene_contract.gd`
- Update: `tests/world/test_city_m777_howitzer_fire_contract.gd`
- Update: `city_game/combat/artillery/CityM777Howitzer.gd`
- Create: `docs/plan/v49-m2-verification-2026-03-24.md`

## Steps

1. Analysis / Doc Freeze
   - 冻结 `2.0s` cooldown 与既有 fire contract 边界。
2. TDD Red
   - 先把 focused tests 的默认 cooldown 期望改到 `2.0s`，并确认红灯来自 howitzer 仍然输出 `6.0s`。
3. TDD Green
   - 更新正式 howitzer runtime 默认 cooldown。
4. Refactor
   - 只做必要清理，不顺手扩 scope。
5. Verification
   - 跑 focused tests 与解析检查；
   - 回填 `v49-m2-verification-2026-03-24.md`。

## Risks

- 如果只改代码不改 PRD/plan，后续很容易再次被旧的 `6.0s` 测试或文档拉回去。
- 如果顺手去改 lab test 的 `SHORT_TEST_COOLDOWN_SEC`，会把“默认配置 retune”和“测试加速装置”混在一起。
