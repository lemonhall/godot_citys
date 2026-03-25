# V55 Index

## 愿景

PRD 入口：

- [PRD-0029 Artillery Howitzer Scene Foundation](../prd/PRD-0029-artillery-howitzer-scene-foundation.md)

设计入口：[2026-03-26-v55-drone-crosshair-artillery-fire-mission-design.md](../plans/2026-03-26-v55-drone-crosshair-artillery-fire-mission-design.md)

依赖入口：

- [v54-index.md](./v54-index.md)

`v55` 的目标不是再做一套“无人机专用炮兵 UI”，而是把“无人机 FPV 准星按 `T` 直接校准炮击黄叉”正式合同化，并且强制复用已经存在的 full-map artillery fire mission 主链。

## 决策冻结

- shortcut ownership：
  - `drone active + FPV ADS active + T`
  - 优先归 artillery fire mission calibration
- shared source of truth：
  - 必须复用 `request_artillery_fire_mission_from_world_point()`
  - 不允许新建 drone-only marker state
- marker behavior：
  - single active yellow cross
  - repeated `T` updates target
- solution behavior：
  - live howitzer 操炮 active -> 立即刷新 solved 诸元
  - 非操炮态 -> 保持 pending
- compatibility：
  - 非无人机 FPV 场景下，`T` 保持原语义

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | PRD / ECN / v55 plan 全链冻结 | `drone + FPV + T`、single-marker replace、shared fire-mission host 与非目标边界全部落文档 | `rg -n "REQ-0029-019|REQ-0029-020|REQ-0029-024|drone active|FPV ADS|single active|T" docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md docs/ecn/ECN-0039-drone-crosshair-artillery-fire-mission.md docs/plan/v55-index.md docs/plan/v55-drone-crosshair-artillery-fire-mission.md docs/plans/2026-03-26-v55-drone-crosshair-artillery-fire-mission-design.md` | done |
| M1 red tests | focused contract + e2e 红测 | 至少锁住无人机 `T` 标定/更新黄叉，以及 live howitzer solved refresh | `tests/world/test_city_drone_artillery_target_marking_contract.gd`; `tests/e2e/test_city_drone_artillery_recalibration_flow.gd` | done |
| M2 implementation | `CityPrototype` 最小 host 改动 | `T` 标定链通过，且不破坏 map fire mission / fast travel / composite operation | 同上 + 既有 focused regressions | done |
| M3 verification | focused + e2e + 解析检查 | fresh verification 文档回填追溯矩阵 | `docs/plan/v55-m3-verification-2026-03-26.md` | done |

## 计划索引

- [v55-drone-crosshair-artillery-fire-mission.md](./v55-drone-crosshair-artillery-fire-mission.md)

## 追溯矩阵

| Req ID | V55 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0029-019 | `v55-drone-crosshair-artillery-fire-mission.md` | `tests/world/test_city_drone_artillery_target_marking_contract.gd` | `docs/plan/v55-m3-verification-2026-03-26.md` | `v55-m3-verification-2026-03-26.md` | done |
| REQ-0029-020 | `v55-drone-crosshair-artillery-fire-mission.md` | `tests/world/test_city_drone_artillery_target_marking_contract.gd` | `tests/e2e/test_city_drone_artillery_recalibration_flow.gd`; `docs/plan/v55-m3-verification-2026-03-26.md` | `v55-m3-verification-2026-03-26.md` | done |
| REQ-0029-024 | `v55-drone-crosshair-artillery-fire-mission.md` | `tests/world/test_city_drone_artillery_target_marking_contract.gd` | `tests/e2e/test_city_drone_artillery_recalibration_flow.gd`; `docs/plan/v55-m3-verification-2026-03-26.md` | `v55-m3-verification-2026-03-26.md` | done |

## Closeout 证据口径

- `v55` 不接受“无人机里自己留一个隐形 target 变量就算校准”的说法。
- 必须同时证明：
  - `T` 在无人机 FPV 下能创建正式黄叉；
  - 重复 `T` 只更新单个 active marker；
  - live howitzer 操炮 active 时会刷新 solved 诸元；
  - 非无人机 FPV 场景下 `T` 的原语义没有回退。

## ECN 索引

- [ECN-0039-drone-crosshair-artillery-fire-mission.md](../ecn/ECN-0039-drone-crosshair-artillery-fire-mission.md)

## 差异列表

- 当前无；若后续要加入“自动开图显示校准结果”“无人机弹着修正叠层”或“观察截图回放”，属于新版本范围。
