# V46 Index

## 愿景

PRD 入口：[PRD-0029 Artillery Howitzer Scene Foundation](../prd/PRD-0029-artillery-howitzer-scene-foundation.md)

设计入口：[2026-03-24-v46-artillery-lab-operation-interaction-design.md](../plans/2026-03-24-v46-artillery-lab-operation-interaction-design.md)

依赖入口：

- [v17-index.md](./v17-index.md)
- [v44-index.md](./v44-index.md)
- [v45-index.md](./v45-index.md)

`v46` 的目标不是解决真实炮兵火控，也不是立刻把 M777 接进主世界。它只收口一件事：把 `M777HowitzerLab` 的操炮输入改成和主世界一致的上下文交互模型。玩家必须先靠近火炮约 `5m`，看到 `按 E 操作炮` 提示；按下 `E` 进入操炮态后，HUD 要持续显示 `J/L/I/K` 的控制提示，而且操炮态不能再因为轻微走位立刻丢失，而是采用 `5m` 进入、约 `20m` 才自动脱离的双半径。

## 决策冻结

- 正式交互范围：
  - 仅限 `res://city_game/scenes/labs/M777HowitzerLab.tscn`
- 正式交互半径：
  - `5.0m`
- 正式操炮保活半径：
  - `20.0m`
- 正式进入提示：
  - `按 E 操作炮`
- 正式操炮态提示：
  - `按 E 退出操炮  J/L 方位  I/K 高低  R 复位`
- 正式键位所有权：
  - 未进入操炮态：`J/L/I/K` 不生效
  - 已进入操炮态：`J/L` 控 yaw，`I/K` 控 pitch
  - 离开 `5m` 但未超过 `20m`：继续保持操炮态
- 正式 HUD prompt contract：
  - 复用 `PrototypeHud.gd` 的 `set_interaction_prompt_state()` / `get_interaction_prompt_state()`

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | PRD / ECN / v46 plan 全链冻结 | 5m 进入半径、20m 保活半径、E prompt、操炮态提示与非目标边界全部落文档 | `rg -n "按 E 操作炮|20.0m|5.0m|J/L|I/K|REQ-0029-007|PrototypeHud" docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md docs/ecn/ECN-0030-artillery-lab-operation-interaction.md docs/plan/v46-index.md docs/plan/v46-artillery-lab-operation-interaction.md docs/plans/2026-03-24-v46-artillery-lab-operation-interaction-design.md` | done |
| M1 lab operation interaction | lab prompt + `E` 进入/退出 + `J/L/I/K` gating + 20m 保活 | focused test 证明 5m 进入、控制提示可见、20m 才自动脱离和键位所有权切换全部成立 | `tests/world/test_city_m777_howitzer_lab_interaction_contract.gd` | done |
| M2 verification | focused tests + fresh closeout 文档 | 受影响 tests 全绿，fresh verification 文档回填追溯矩阵 | `docs/plan/v46-m2-verification-2026-03-24.md` | done |

## 计划索引

- [v46-artillery-lab-operation-interaction.md](./v46-artillery-lab-operation-interaction.md)

## 追溯矩阵

| Req ID | V46 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0029-007 | `v46-artillery-lab-operation-interaction.md` | `tests/world/test_city_m777_howitzer_lab_interaction_contract.gd` | `docs/plan/v46-m2-verification-2026-03-24.md` | `v46-m2-verification-2026-03-24.md` | done |

## Closeout 证据口径

- `v46` 不接受“反正 lab 里只有一门炮，全局 `J/L/I/K` 也无所谓”的说法。
- 必须有 fresh test 证明：
  - 玩家在交互半径外时没有 `E` prompt；
  - 玩家进入 `5m` 内后，HUD 出现 `按 E 操作炮`；
  - 未进入操炮态前，`J/L/I/K` 不会动炮；
  - 按 `E` 后进入操炮态，HUD 会持续显示 `J/L/I/K` 与 `E` 的控制提示；
  - 离开 `5m` 但未超过 `20m` 时，操炮态仍保持；
  - 再按 `E` 或离炮超过 `20m` 后，这四个键才释放所有权；
  - prompt 使用的是主世界共享 HUD prompt contract，而不是 lab-only 文本贴片。

## ECN 索引

- [ECN-0030-artillery-lab-operation-interaction.md](../ecn/ECN-0030-artillery-lab-operation-interaction.md)

## 差异列表

- 当前无；火炮绝对 bearing、零位方位、远距炮击交互与火控解算留给后续版本单独设计。
