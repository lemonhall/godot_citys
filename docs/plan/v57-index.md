# V57 Index

## 愿景

PRD 入口：

- [PRD-0027 Drone Flight Foundation](../prd/PRD-0027-drone-flight-foundation.md)

设计入口：[2026-03-26-v57-drone-squadron-strike-orders-design.md](../plans/2026-03-26-v57-drone-squadron-strike-orders-design.md)

依赖入口：

- [v56-index.md](./v56-index.md)

`v57` 的目标不是把机群瞬间做成“完整战术 AI”，而是先把机群攻击命令正式合同化：左键优先派单架僚机冲锋、长机保留观察位；中键下达面域阶梯式僚机冲锋；只有真正只剩长机时，才回退到旧的 leader kamikaze + `NO SIGNAL` 链。

## 决策冻结

- left click：
  - `FPV ADS + active wingman >= 1`
  - 派 1 架僚机冲锋
  - 长机不自爆
  - 长机不播 `NO SIGNAL`
- fallback：
  - `active wingman == 0`
  - 左键回退到 leader 自杀式冲锋旧链
- middle click：
  - `FPV ADS + idle wingman >= 1`
  - 下达 area strike
  - 半径 `12m`
  - 波次 `1 -> 2 -> 3` 循环
  - 批次间隔 `0.6s`
- ownership：
  - 长机继续保持 camera / input / FPV owner
  - 僚机不得抢镜头

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | PRD / ECN / v57 plan 全链冻结 | 左键单架僚机 dispatch、中键 area strike、`12m` 半径、`0.6s` 间隔、leader fallback 边界全部落文档 | `rg -n "REQ-0027-010|REQ-0027-011|12m|0.6s|MOUSE_BUTTON_LEFT|MOUSE_BUTTON_MIDDLE|NO SIGNAL" docs/prd/PRD-0027-drone-flight-foundation.md docs/ecn/ECN-0041-drone-squadron-strike-orders.md docs/plan/v57-index.md docs/plan/v57-drone-squadron-strike-orders.md docs/plans/2026-03-26-v57-drone-squadron-strike-orders-design.md` | done |
| M1 red tests | 单架僚机冲锋 + 面域波次红测 | 至少锁住 left-click single wingman dispatch、middle-click wave queue、leader-only fallback | `tests/world/test_city_player_drone_squadron_single_strike_dispatch_contract.gd`; `tests/world/test_city_player_drone_squadron_area_strike_command_contract.gd`; `tests/e2e/test_city_player_drone_squadron_strike_flow.gd` | done |
| M2 implementation | squadron strike order runtime | 有僚机时左键不再让长机送死；中键 area strike 按波次发令；旧 leader-only kamikaze 不回退 | 同上 + 既有 kamikaze/squadron regressions | done |
| M3 verification | focused + e2e + 解析检查 | fresh verification 文档回填追溯矩阵 | `docs/plan/v57-m3-verification-2026-03-26.md` | done |

## 计划索引

- [v57-drone-squadron-strike-orders.md](./v57-drone-squadron-strike-orders.md)

## 追溯矩阵

| Req ID | V57 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0027-010 | `v57-drone-squadron-strike-orders.md` | `tests/world/test_city_player_drone_squadron_single_strike_dispatch_contract.gd`; `tests/world/test_city_player_drone_suicide_strike_contract.gd` | `tests/e2e/test_city_player_drone_squadron_strike_flow.gd`; `docs/plan/v57-m3-verification-2026-03-26.md` | `v57-m3-verification-2026-03-26.md` | done |
| REQ-0027-011 | `v57-drone-squadron-strike-orders.md` | `tests/world/test_city_player_drone_squadron_area_strike_command_contract.gd` | `tests/e2e/test_city_player_drone_squadron_strike_flow.gd`; `docs/plan/v57-m3-verification-2026-03-26.md` | `v57-m3-verification-2026-03-26.md` | done |

## Closeout 证据口径

- `v57` 不接受“左键只是把 leader 的 `strike_committed` 改名成 wingman”的空壳实现。
- 必须同时证明：
  - 有僚机时左键确实派的是僚机，不是长机；
  - 长机在僚机 strike 期间仍保留 FPV 观察位，且不播 `NO SIGNAL`；
  - 中键 area strike 不是全部飞向同一个点，也不是一次全冲；
  - 只剩长机时，旧 leader kamikaze + `NO SIGNAL` 旧链仍保留。

## ECN 索引

- [ECN-0041-drone-squadron-strike-orders.md](../ecn/ECN-0041-drone-squadron-strike-orders.md)

## 差异列表

- 当前无；后续若要加入“玩家选择僚机编号”“更复杂的编队战术命令”“威胁规避”或“多区域连锁 strike plan”，进入 `v58+`。
