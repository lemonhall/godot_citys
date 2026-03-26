# V56 Index

## 愿景

PRD 入口：

- [PRD-0027 Drone Flight Foundation](../prd/PRD-0027-drone-flight-foundation.md)
- [PRD-0029 Artillery Howitzer Scene Foundation](../prd/PRD-0029-artillery-howitzer-scene-foundation.md)

设计入口：[2026-03-26-v56-drone-squadron-summon-control-design.md](../plans/2026-03-26-v56-drone-squadron-summon-control-design.md)

依赖入口：

- [v55-index.md](./v55-index.md)

`v56` 的目标不是直接做出“战术无人机 AI”，而是先把机群召唤控制正式合同化：`KP_5` 升级为短按逐架增援、长按全部回收，长机继续保持现有真正的 camera/input/FPV/howitzer 复合 owner，僚机首版只做分散跟随与非重叠呈现。

## 决策冻结

- hotkey ownership：
  - `KEY_KP_5`
  - `short press -> +1 drone`
  - `long press -> recall all`
- max total count：
  - `10`
  - 口径含长机
- ownership：
  - 长机仍是唯一 camera owner / input owner / FPV owner
  - 僚机不得抢 owner
- formation：
  - 首版只做默认分散 slot
  - 不做 flocking / tactics / fire control
- compatibility：
  - 普通回收 -> 回玩家
  - `howitzer + drone` 复合态全收 -> 回 howitzer 操炮态

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | PRD / ECN / v56 plan 全链冻结 | `KP_5` 长短按、总数上限、leader-only ownership、formation 非目标全部落文档 | `rg -n "REQ-0027-007|REQ-0027-008|REQ-0027-009|short press|long press|10|howitzer 操炮" docs/prd/PRD-0027-drone-flight-foundation.md docs/ecn/ECN-0040-drone-squadron-summon-control.md docs/plan/v56-index.md docs/plan/v56-drone-squadron-summon-control.md docs/plans/2026-03-26-v56-drone-squadron-summon-control-design.md` | done |
| M1 red tests | focused + 兼容性红测 | 至少锁住短按增援、长按全收、默认分散编队与复合态 context 保持 | `tests/world/test_city_player_drone_toggle_contract.gd`; `tests/world/test_city_player_drone_squadron_summon_contract.gd`; `tests/world/test_city_player_drone_camera_takeover_contract.gd`; `tests/e2e/test_city_player_drone_flow.gd`; `tests/e2e/test_city_drone_assisted_artillery_operation_flow.gd` | done |
| M2 implementation | squadron hotkey + runtime 分层实现 | 机群召唤通过，且不破坏长机原有飞行/FPV/复合操炮行为 | 同上 + 既有 drone focused regressions | done |
| M3 verification | focused + e2e + 解析检查 | fresh verification 文档回填追溯矩阵 | `docs/plan/v56-m3-verification-2026-03-26.md` | done |

## 计划索引

- [v56-drone-squadron-summon-control.md](./v56-drone-squadron-summon-control.md)

## 追溯矩阵

| Req ID | V56 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0027-002 | `v56-drone-squadron-summon-control.md` | `tests/world/test_city_player_drone_toggle_contract.gd` | `tests/e2e/test_city_player_drone_flow.gd`; `docs/plan/v56-m3-verification-2026-03-26.md` | `v56-m3-verification-2026-03-26.md` | done |
| REQ-0027-004 | `v56-drone-squadron-summon-control.md` | `tests/world/test_city_player_drone_camera_takeover_contract.gd` | `tests/e2e/test_city_player_drone_flow.gd`; `docs/plan/v56-m3-verification-2026-03-26.md` | `v56-m3-verification-2026-03-26.md` | done |
| REQ-0027-007 | `v56-drone-squadron-summon-control.md` | `tests/world/test_city_player_drone_toggle_contract.gd`; `tests/world/test_city_player_drone_squadron_summon_contract.gd` | `tests/e2e/test_city_player_drone_flow.gd`; `docs/plan/v56-m3-verification-2026-03-26.md` | `v56-m3-verification-2026-03-26.md` | done |
| REQ-0027-008 | `v56-drone-squadron-summon-control.md` | `tests/world/test_city_player_drone_squadron_summon_contract.gd` | `docs/plan/v56-m3-verification-2026-03-26.md` | `v56-m3-verification-2026-03-26.md` | done |
| REQ-0027-009 | `v56-drone-squadron-summon-control.md` | `tests/world/test_city_player_drone_squadron_summon_contract.gd` | `tests/e2e/test_city_drone_assisted_artillery_operation_flow.gd`; `docs/plan/v56-m3-verification-2026-03-26.md` | `v56-m3-verification-2026-03-26.md` | done |

## Closeout 证据口径

- `v56` 不接受“只在 debug state 里把机群数改成 3”这种空壳实现。
- 必须同时证明：
  - `KP_5` 已经变成长短按语义；
  - 短按确实逐架增援，且封顶 `10` 架；
  - 僚机在场景里确实存在且不和长机挤成一团；
  - 长按全收不会破坏普通玩家上下文与 howitzer 复合上下文。

## ECN 索引

- [ECN-0040-drone-squadron-summon-control.md](../ecn/ECN-0040-drone-squadron-summon-control.md)

## 差异列表

- 当前无；后续若要做 flocking、战术命令、僚机独立攻击或机群 HUD，进入 `v57+`。
