# V54 Index

## 愿景

PRD 入口：

- [PRD-0027 Drone Flight Foundation](../prd/PRD-0027-drone-flight-foundation.md)
- [PRD-0029 Artillery Howitzer Scene Foundation](../prd/PRD-0029-artillery-howitzer-scene-foundation.md)

设计入口：[2026-03-26-v54-drone-assisted-artillery-operation-design.md](../plans/2026-03-26-v54-drone-assisted-artillery-operation-design.md)

依赖入口：

- [v53-index.md](./v53-index.md)

`v54` 的目标不是再造一套新观察系统，而是把“无人机观察炮击”正式合同化。范围冻结为：无人机 `Space` 抬升退场、howitzer 操炮与无人机复合模式共存、以及复合模式下 accepted fire 跳过 observer closeout，但保留原有非复合模式 observer 行为。

## 决策冻结

- drone vertical input：
  - `E` 上升
  - `Q` 下降
  - `Space` 退出无人机语义
- composite mode 判定：
  - `drone active`
  - `howitzer operation active`
- composite fire behavior：
  - skip observer closeout
  - keep shell spawn
  - keep artillery HUD
  - keep howitzer operation ownership
- composite `E` behavior：
  - keep howitzer operation active
  - route `E` to drone ascend only
- non-composite compatibility：
  - 纯无人机行为保持
  - 纯 howitzer observer closeout 保持

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | PRD / ECN / v54 plan 全链冻结 | `Space` ownership、composite skip-observer 与非目标边界全部落文档 | `rg -n "REQ-0027-005|REQ-0029-022|REQ-0029-023|composite|observer closeout|Space" docs/prd/PRD-0027-drone-flight-foundation.md docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md docs/ecn/ECN-0038-drone-assisted-artillery-composite-operation.md docs/plan/v54-index.md docs/plan/v54-drone-assisted-artillery-operation.md docs/plans/2026-03-26-v54-drone-assisted-artillery-operation-design.md` | done |
| M1 red tests | focused contract + e2e 红测 | 至少锁住 drone `Space` 退场与 composite fire skip-observer contract | `tests/world/test_city_player_drone_space_input_contract.gd`; `tests/world/test_city_world_howitzer_drone_composite_contract.gd`; `tests/e2e/test_city_drone_assisted_artillery_operation_flow.gd` | done |
| M2 implementation | 输入与 fire host 最小改动实现 | 复合模式链路通过，且不破坏既有 drone/howitzer 行为 | 同上 + howitzer/drone 既有 focused tests | done |
| M3 verification | focused + e2e + 解析检查 | fresh verification 文档回填追溯矩阵；记录一个与 v54 无关的 observer 高度已知红灯 | `docs/plan/v54-m3-verification-2026-03-26.md` | done |

## 计划索引

- [v54-drone-assisted-artillery-operation.md](./v54-drone-assisted-artillery-operation.md)

## 追溯矩阵

| Req ID | V54 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0027-005 | `v54-drone-assisted-artillery-operation.md` | `tests/world/test_city_player_drone_space_input_contract.gd` | `tests/e2e/test_city_drone_assisted_artillery_operation_flow.gd`; `docs/plan/v54-m3-verification-2026-03-26.md` | `v54-m3-verification-2026-03-26.md` | done |
| REQ-0029-022 | `v54-drone-assisted-artillery-operation.md` | `tests/world/test_city_world_howitzer_drone_composite_contract.gd` | `tests/e2e/test_city_drone_assisted_artillery_operation_flow.gd`; `docs/plan/v54-m3-verification-2026-03-26.md` | `v54-m3-verification-2026-03-26.md` | done |
| REQ-0029-023 | `v54-drone-assisted-artillery-operation.md` | `tests/world/test_city_world_howitzer_drone_composite_contract.gd` | `tests/e2e/test_city_drone_assisted_artillery_operation_flow.gd`; `docs/plan/v54-m3-verification-2026-03-26.md` | `v54-m3-verification-2026-03-26.md` | done |

## Closeout 证据口径

- `v54` 不接受“把 observer 直接关掉就算完成”的说法。
- 必须同时证明：
  - drone 不再吃 `Space`；
  - composite mode 下 `E` 不会退出操炮；
  - composite mode 下 howitzer 仍可完整操炮；
  - composite mode 下 accepted fire 不会进 observer closeout；
  - 非复合模式的既有 drone / howitzer 行为没有被带坏。

## ECN 索引

- [ECN-0038-drone-assisted-artillery-composite-operation.md](../ecn/ECN-0038-drone-assisted-artillery-composite-operation.md)

## 差异列表

- 当前无；后续如果要把无人机观察做成专用 HUD / picture-in-picture / 弹着标注，属于新版本范围。
