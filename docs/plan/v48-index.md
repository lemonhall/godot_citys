# V48 Index

## 愿景

PRD 入口：[PRD-0029 Artillery Howitzer Scene Foundation](../prd/PRD-0029-artillery-howitzer-scene-foundation.md)

设计入口：[2026-03-24-v48-artillery-interaction-polish-design.md](../plans/2026-03-24-v48-artillery-interaction-polish-design.md)

依赖入口：

- [v46-index.md](./v46-index.md)
- [v47-index.md](./v47-index.md)

`v48` 的目标不是继续扩 scope 去做弹道或世界火控，而是把 M777 的实际操控手感与火绳视觉收口到用户能接受的程度。冻结范围只有两件事：howitzer enter radius 从 `5m` 提升到 `7m`；`LanyardLine` 改成正式 artillery 专用 rope curve，不再出现被父级缩放拉坏的贴地折线。`20m` retention、`E` 进入 / 退出、`J/L/I/K/Space` 所有权和 fire presentation 其他部分都保持既有合同不变。

## 决策冻结

- 正式交互范围：
  - 仅限 `res://city_game/scenes/labs/M777HowitzerLab.tscn`
- 正式交互 enter radius：
  - `7.0m`
- 正式操炮保活半径：
  - `20.0m`
- 正式进入提示：
  - `按 E 操作炮`
- 正式 rope visual 真源：
  - `res://city_game/combat/artillery/CityArtilleryLanyardLine.gd`
- 正式 rope visual 语义：
  - baseline 与 operator rope 都必须是连续曲线
  - 不能退回三点折线
  - 不能因为父级缩放塌成贴地怪线

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | PRD / ECN / v48 plan 全链冻结 | `7.0m` enter radius、`20.0m` retention、专用 artillery rope curve 与非目标边界全部落文档 | `rg -n "7.0m|7m|20.0m|CityArtilleryLanyardLine|连续曲线|贴地折线|REQ-0029-007|REQ-0029-008" docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md docs/ecn/ECN-0032-artillery-interaction-radius-and-lanyard-curve.md docs/plan/v48-index.md docs/plan/v48-artillery-interaction-polish.md docs/plans/2026-03-24-v48-artillery-interaction-polish-design.md` | done |
| M1 interaction polish | `7m` prompt + artillery lanyard curve | focused tests 证明 `7m` 进入与 rope curve contract 全部成立 | `tests/world/test_city_m777_howitzer_scene_contract.gd`; `tests/world/test_city_m777_howitzer_lab_interaction_contract.gd`; `tests/world/test_city_m777_howitzer_fire_contract.gd` | done |
| M2 verification | focused tests + fresh closeout 文档 | 受影响 tests 全绿，fresh verification 文档回填追溯矩阵 | `docs/plan/v48-m2-verification-2026-03-24.md` | done |

## 计划索引

- [v48-artillery-interaction-polish.md](./v48-artillery-interaction-polish.md)

## 追溯矩阵

| Req ID | V48 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0029-007 | `v48-artillery-interaction-polish.md` | `tests/world/test_city_m777_howitzer_lab_interaction_contract.gd` | `docs/plan/v48-m2-verification-2026-03-24.md` | `v48-m2-verification-2026-03-24.md` | done |
| REQ-0029-008 | `v48-artillery-interaction-polish.md` | `tests/world/test_city_m777_howitzer_scene_contract.gd`; `tests/world/test_city_m777_howitzer_fire_contract.gd` | `docs/plan/v48-m2-verification-2026-03-24.md` | `v48-m2-verification-2026-03-24.md` | done |

## Closeout 证据口径

- `v48` 不接受“火绳反正能看见就行”或“5m 也不是不能用”的说法。
- 必须有 fresh test 证明：
  - howitzer enter radius 已升级到 `7m`
  - `7m` 外没有 prompt，`7m` 内 prompt 出现
  - `LanyardLine` 不再引用 fishing minigame rope script
  - 操炮态 rope 是多点采样连续曲线，而不是三点折线
  - rope 最低点不会因为父级缩放畸变而接近地面

## ECN 索引

- [ECN-0032-artillery-interaction-radius-and-lanyard-curve.md](../ecn/ECN-0032-artillery-interaction-radius-and-lanyard-curve.md)

## 差异列表

- 当前无；更远期的 bearing / 火控 / 弹道与世界接入仍留给后续版本。
