# V58 Drone Wingman Strike Presentation

## Goal

把 `v57` 的“机群命令链正确”提升到“机群命中反馈可信”：僚机撞地时有正式爆炸环/爆炸球/爆炸音效；俯冲路径有 deterministic 弧线和小幅机间差异，但仍严格命中原目标点。

## Dependencies

- strike runtime：
  - `res://city_game/combat/drone/CityPlayerDroneWingman.gd`
- squadron manager：
  - `res://city_game/combat/drone/CityPlayerDroneSquadronRuntime.gd`
- shared impact FX：
  - `res://city_game/combat/CitySurfaceExplosionFx.gd`
- 既有 strike contracts：
  - `res://tests/world/test_city_player_drone_squadron_single_strike_dispatch_contract.gd`
  - `res://tests/world/test_city_player_drone_squadron_area_strike_command_contract.gd`
  - `res://tests/e2e/test_city_player_drone_squadron_strike_flow.gd`

## PRD Trace

- `REQ-0027-012`
- `REQ-0027-013`

## Scope

做什么：

- 给僚机 impact 增加正式地面爆炸 FX 与爆炸音效
- 给僚机 strike 增加 deterministic dive curve 与非恒速 profile
- 把 impact/path summary 暴露到 debug/event payload，便于自动化验证

不做什么：

- 不改左键/中键命令语义
- 不改 leader fallback / `NO SIGNAL`
- 不做完整空气动力学
- 不做避障
- 不做新粒子系统

## Acceptance

1. 自动化测试必须证明：僚机 strike resolved event 会记录 `impact_fx_played = true`。
2. 自动化测试必须证明：僚机 strike resolved event 会记录至少一次爆炸音效触发，以及非空音频资源路径。
3. 自动化测试必须证明：僚机 strike resolved event 会记录非零 `path_seed`。
4. 自动化测试必须证明：僚机 strike resolved event 会记录非零曲线路径偏移指标，而不是 `0`。
5. 自动化测试必须证明：僚机 strike resolved event 会记录非零速度变化区间，而不是严格恒速。
6. 自动化测试必须证明：同一轮 area strike 的多架僚机，其 `path_seed` 或曲线路径参数不完全相同。
7. 自动化测试必须证明：加入 presentation 增强后，`v57` 的 single/area/fallback 命令合同不回退。

## Files

- Update: `docs/prd/PRD-0027-drone-flight-foundation.md`
- Create: `docs/ecn/ECN-0042-drone-wingman-strike-presentation.md`
- Create: `docs/plans/2026-03-26-v58-drone-wingman-strike-presentation-design.md`
- Create: `docs/plan/v58-index.md`
- Create: `docs/plan/v58-drone-wingman-strike-presentation.md`
- Create: `city_game/combat/CitySurfaceExplosionFx.gd`
- Update: `city_game/combat/drone/CityPlayerDroneWingman.gd`
- Update: `city_game/combat/drone/CityPlayerDroneSquadronRuntime.gd`
- Create: `tests/world/test_city_player_drone_squadron_wingman_impact_presentation_contract.gd`
- Create: `tests/world/test_city_player_drone_squadron_wingman_dive_profile_contract.gd`
- Create: `tests/e2e/test_city_player_drone_squadron_strike_presentation_flow.gd`
- Create: `docs/plan/v58-m3-verification-2026-03-26.md`

## Steps

1. Docs Freeze
   - 冻结 impact FX / 音效 / deterministic dive path / seed 差异合同。
2. TDD Red
   - 先写：
     - `test_city_player_drone_squadron_wingman_impact_presentation_contract.gd`
     - `test_city_player_drone_squadron_wingman_dive_profile_contract.gd`
     - `test_city_player_drone_squadron_strike_presentation_flow.gd`
3. Run Red
   - 预期第一轮红灯原因：
     - 僚机 impact 没有正式 FX / 音效 summary
     - strike path 仍是直线恒速
     - recent strike events 还没有 resolved presentation payload
4. TDD Green
   - 实现 shared impact FX、wingman dive profile、event summary。
5. Verification
   - 跑 focused tests + `v57` regressions；
   - 回填 `v58-m3-verification-2026-03-26.md`。

## Risks

- 如果 FX summary 不暴露给事件 payload，测试只能靠肉眼。
- 如果曲线路径做得太大，会把命中点合同打坏。
- 如果音效用真正随机 pitch 且不留 seed，回归会变得不稳定。
