# V49 Index

## 愿景

PRD 入口：[PRD-0029 Artillery Howitzer Scene Foundation](../prd/PRD-0029-artillery-howitzer-scene-foundation.md)

设计入口：[2026-03-24-v49-artillery-fire-cooldown-retune-design.md](../plans/2026-03-24-v49-artillery-fire-cooldown-retune-design.md)

依赖入口：

- [v47-index.md](./v47-index.md)
- [v48-index.md](./v48-index.md)

`v49` 的目标很窄，只做一件事：把正式 howitzer fire cooldown 从 `6.0s` 调整为 `2.0s`，让 lab 操炮节奏更爽一些。其余 fire presentation contract、HUD 文案、交互 ownership 和非目标边界全部保持不变。

## 决策冻结

- fire cooldown：
  - `2.0s`
- fire key：
  - `Space`
- HUD 文案：
  - `装填中 X.Xs...`
  - `可击发`
- 非目标：
  - 不新增 projectile / 弹道 / 爆炸
  - 不重做 fire presentation

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | PRD / ECN / v49 plan 全链冻结 | `2.0s` cooldown 与既有 fire contract 边界全部落文档 | `rg -n "2.0s|2\\.0|REQ-0029-008|cooldown" docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md docs/ecn/ECN-0033-artillery-fire-cooldown-retune.md docs/plan/v49-index.md docs/plan/v49-artillery-fire-cooldown-retune.md docs/plans/2026-03-24-v49-artillery-fire-cooldown-retune-design.md` | done |
| M1 cooldown retune | 正式 howitzer 默认 cooldown 调整 | focused tests 证明默认 cooldown 已变为 `2.0s` 且 fire contract 其余部分不回退 | `tests/world/test_city_m777_howitzer_scene_contract.gd`; `tests/world/test_city_m777_howitzer_fire_contract.gd` | done |
| M2 verification | focused tests + fresh closeout 文档 | 受影响 tests 全绿，fresh verification 文档回填追溯矩阵 | `docs/plan/v49-m2-verification-2026-03-24.md` | done |

## 计划索引

- [v49-artillery-fire-cooldown-retune.md](./v49-artillery-fire-cooldown-retune.md)

## 追溯矩阵

| Req ID | V49 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0029-008 | `v49-artillery-fire-cooldown-retune.md` | `tests/world/test_city_m777_howitzer_scene_contract.gd`; `tests/world/test_city_m777_howitzer_fire_contract.gd` | `docs/plan/v49-m2-verification-2026-03-24.md` | `v49-m2-verification-2026-03-24.md` | done |

## ECN 索引

- [ECN-0033-artillery-fire-cooldown-retune.md](../ecn/ECN-0033-artillery-fire-cooldown-retune.md)

## 差异列表

- 当前无；如果未来要往“更写实装填节奏”回拉，应单独开新版本，不要再把当前 `2.0s` 试玩节奏偷偷改回去。
