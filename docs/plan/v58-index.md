# V58 Index

## 愿景

PRD 入口：

- [PRD-0027 Drone Flight Foundation](../prd/PRD-0027-drone-flight-foundation.md)

设计入口：[2026-03-26-v58-drone-wingman-strike-presentation-design.md](../plans/2026-03-26-v58-drone-wingman-strike-presentation-design.md)

依赖入口：

- [v57-index.md](./v57-index.md)

`v58` 不改 `v57` 已冻结的机群命令语义，只补 strike presentation：僚机撞地时必须有正式爆炸环/爆炸球/爆炸音效；僚机俯冲路径必须是 deterministic 的弧线，而不是完美直线匀速。

## 决策冻结

- impact presentation：
  - 复用正式爆炸语言
  - 必须有爆炸环
  - 必须有爆炸球
  - 必须有爆炸音效
- dive profile：
  - 必须不是完美直线
  - 必须不是严格恒速
  - 不同僚机之间必须存在 deterministic 的轻微差异
  - 命中点合同不变

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | PRD / ECN / v58 plan 全链冻结 | impact FX、爆炸音效、deterministic dive path、seed 差异全部落文档 | `rg -n "REQ-0027-012|REQ-0027-013|impact FX|爆炸音效|path_seed|deterministic|俯冲弧线" docs/prd/PRD-0027-drone-flight-foundation.md docs/ecn/ECN-0042-drone-wingman-strike-presentation.md docs/plan/v58-index.md docs/plan/v58-drone-wingman-strike-presentation.md docs/plans/2026-03-26-v58-drone-wingman-strike-presentation-design.md` | done |
| M1 red tests | impact presentation + dive profile 红测 | 至少锁住 impact FX/audio 存在性、非零曲线路径偏移、非恒速、seed 差异 | `tests/world/test_city_player_drone_squadron_wingman_impact_presentation_contract.gd`; `tests/world/test_city_player_drone_squadron_wingman_dive_profile_contract.gd`; `tests/e2e/test_city_player_drone_squadron_strike_presentation_flow.gd` | done |
| M2 implementation | wingman strike presentation runtime | 僚机 impact 不再静默；strike path 不再完美直线匀速；命中点合同不回退 | 同上 + `v57` regressions | done |
| M3 verification | focused + regressions + 解析检查 | fresh verification 文档回填追溯矩阵 | `docs/plan/v58-m3-verification-2026-03-26.md` | done |

## 计划索引

- [v58-drone-wingman-strike-presentation.md](./v58-drone-wingman-strike-presentation.md)

## 追溯矩阵

| Req ID | V58 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0027-012 | `v58-drone-wingman-strike-presentation.md` | `tests/world/test_city_player_drone_squadron_wingman_impact_presentation_contract.gd` | `tests/e2e/test_city_player_drone_squadron_strike_presentation_flow.gd`; `docs/plan/v58-m3-verification-2026-03-26.md` | `v58-m3-verification-2026-03-26.md` | done |
| REQ-0027-013 | `v58-drone-wingman-strike-presentation.md` | `tests/world/test_city_player_drone_squadron_wingman_dive_profile_contract.gd` | `tests/e2e/test_city_player_drone_squadron_strike_presentation_flow.gd`; `docs/plan/v58-m3-verification-2026-03-26.md` | `v58-m3-verification-2026-03-26.md` | done |

## Closeout 证据口径

- `v58` 不接受“只在 debug state 里写个 `impact_fx_played = true`，但实际没有播放 FX/音效”的空壳实现。
- `v58` 不接受“只是给路径参数起了个曲线名字，但实际仍按直线恒速飞”的空壳实现。
- 必须同时证明：
  - impact FX/音效真的被触发；
  - 路径偏移与速度变化指标都非零；
  - 多架僚机的 path seed 或路径参数不完全相同；
  - `v57` 命令语义与 leader fallback 不回退。

## ECN 索引

- [ECN-0042-drone-wingman-strike-presentation.md](../ecn/ECN-0042-drone-wingman-strike-presentation.md)

## 差异列表

- 当前无；后续若要做更重的粒子特效、地表材质差异爆炸、真实空气动力学或复杂避障，进入 `v59+`。
