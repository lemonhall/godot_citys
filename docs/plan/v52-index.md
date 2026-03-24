# V52 Index

## 愿景

PRD 入口：[PRD-0029 Artillery Howitzer Scene Foundation](../prd/PRD-0029-artillery-howitzer-scene-foundation.md)

设计入口：[2026-03-25-v52-artillery-gameplay-ballistic-solver-design.md](../plans/2026-03-25-v52-artillery-gameplay-ballistic-solver-design.md)

依赖入口：

- [v50-index.md](./v50-index.md)
- [v51-index.md](./v51-index.md)

`v52` 的目标不是把 howitzer 做成军规级火控器，而是正式冻结一套 gameplay 级弹道学主链。当前 howitzer 的默认射程包线锁死为 `1.5km~22.5km`；同一套 ballistic model 必须同时服务 ammo profile、正向落点预测、反向目标点求诸元与 live shell runtime。

## 决策冻结

- ballistic utility：
  - `res://city_game/combat/artillery/CityArtilleryBallistics.gd`
- 当前默认弹型：
  - `m795_he`
  - `1.5km~22.5km`
- model 级别：
  - gameplay point-mass
  - no wind / no Coriolis / no charge table
- solver 真源：
  - shared artillery ballistics utility
- runtime 共线：
  - howitzer firing solution
  - forward prediction
  - inverse solve
  - live shell launch

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | PRD / ECN / v52 plan 全链冻结 | `1.5km~22.5km` envelope、shared ballistic utility、forward/inverse/shared-model 非目标边界全部落文档 | `rg -n "REQ-0029-014|REQ-0029-015|REQ-0029-016|REQ-0029-017|1500|22500|CityArtilleryBallistics|forward|inverse|round-trip" docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md docs/ecn/ECN-0036-artillery-gameplay-ballistic-solver.md docs/plan/v52-index.md docs/plan/v52-artillery-gameplay-ballistic-solver.md docs/plans/2026-03-25-v52-artillery-gameplay-ballistic-solver-design.md` | done |
| M1 solver contracts | ammo profile、forward solve、inverse solve、round-trip | focused tests 证明当前 howitzer 拥有 formal ammo profile 与正反解合同 | `tests/world/test_city_artillery_ammo_profile_contract.gd`; `tests/world/test_city_artillery_ballistics_forward_solver_contract.gd`; `tests/world/test_city_artillery_ballistics_inverse_solver_contract.gd`; `tests/world/test_city_artillery_ballistics_round_trip_contract.gd` | done |
| M2 runtime integration | howitzer payload / live shell 与 shared utility 并轨 | focused tests 证明 howitzer payload、shared solver 与 live shell runtime 共线 | `tests/world/test_city_m777_howitzer_ballistic_profile_payload_contract.gd`; `tests/world/test_city_artillery_shell_shared_ballistic_model_contract.gd`; `tests/world/test_city_m777_howitzer_firing_solution_contract.gd`; `tests/world/test_city_world_howitzer_ballistics_contract.gd` | done |
| M3 verification | focused + 解析检查 + research artifact | 受影响 tests 全绿，fresh verification 文档与 research markdown/pdf 回填 | `docs/plan/v52-m3-verification-2026-03-25.md` | done |

## 计划索引

- [v52-artillery-gameplay-ballistic-solver.md](./v52-artillery-gameplay-ballistic-solver.md)

## 追溯矩阵

| Req ID | V52 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0029-014 | `v52-artillery-gameplay-ballistic-solver.md` | `tests/world/test_city_artillery_ammo_profile_contract.gd` | `docs/plan/v52-m3-verification-2026-03-25.md` | `v52-m3-verification-2026-03-25.md` | done |
| REQ-0029-015 | `v52-artillery-gameplay-ballistic-solver.md` | `tests/world/test_city_artillery_ballistics_forward_solver_contract.gd` | `docs/plan/v52-m3-verification-2026-03-25.md` | `v52-m3-verification-2026-03-25.md` | done |
| REQ-0029-016 | `v52-artillery-gameplay-ballistic-solver.md` | `tests/world/test_city_artillery_ballistics_inverse_solver_contract.gd`; `tests/world/test_city_artillery_ballistics_round_trip_contract.gd` | `docs/plan/v52-m3-verification-2026-03-25.md` | `v52-m3-verification-2026-03-25.md` | done |
| REQ-0029-017 | `v52-artillery-gameplay-ballistic-solver.md` | `tests/world/test_city_m777_howitzer_ballistic_profile_payload_contract.gd`; `tests/world/test_city_artillery_shell_shared_ballistic_model_contract.gd`; `tests/world/test_city_world_howitzer_ballistics_contract.gd`; `tests/world/test_city_m777_howitzer_firing_solution_contract.gd` | `docs/plan/v52-m3-verification-2026-03-25.md` | `v52-m3-verification-2026-03-25.md` | done |

## Closeout 证据口径

- `v52` 不接受“只是在文档里说可以算落点/诸元”。
- 必须有 fresh tests 证明：
  - 当前弹型的射程 envelope 真被冻结为 `1.5km~22.5km`；
  - solver 真能从 firing solution 预测落点；
  - solver 真能从目标点反算诸元；
  - live shell runtime 与 shared utility 同口径。

## ECN 索引

- [ECN-0036-artillery-gameplay-ballistic-solver.md](../ecn/ECN-0036-artillery-gameplay-ballistic-solver.md)

## 差异列表

- 当前无；预测落点 HUD、完整军规级火控、反炮兵与高级弹种仍属于后续版本范围。
