# V50 Index

## 愿景

PRD 入口：[PRD-0029 Artillery Howitzer Scene Foundation](../prd/PRD-0029-artillery-howitzer-scene-foundation.md)

设计入口：[2026-03-24-v50-artillery-firing-solution-hud-design.md](../plans/2026-03-24-v50-artillery-firing-solution-hud-design.md)

依赖入口：

- [v45-index.md](./v45-index.md)
- [v49-index.md](./v49-index.md)

`v50` 的目标不是一口气把火炮做成硬核火控系统，而是把 howitzer 从“能转、能打、能看提示”推进到“真正有射击诸元语义”。本轮冻结两件事：一是给 `PrototypeHud` 建立正式的 artillery solution HUD consumer，只在操炮态显示炮口世界 bearing 与当前 pitch；二是给正式 howitzer runtime 建立 firing solution payload contract，让每次 accepted fire 都留下未来可供 projectile / 落点 / 反炮兵链路复用的 shot snapshot。弹道积分、落点效果和 projectile 仍然不是本轮目标。

## 决策冻结

- artillery solution HUD 真源：
  - `res://city_game/ui/PrototypeHud.gd`
- artillery solution HUD 视图：
  - `res://city_game/ui/CityArtillerySolutionHud.gd`
- HUD 可见性：
  - 仅 howitzer 操炮态可见
- yaw 语义：
  - 直接显示炮口世界 bearing
  - 共享 `v45` 的 `北=0° / 顺时针增加` contract
- pitch 语义：
  - 继续使用 howitzer 已校准 `0-71°` 仰角口径
- firing solution payload：
  - accepted fire 时生成并落存
  - 暂不生成 projectile
  - 暂不做弹道积分 / 落点 / 爆炸

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | PRD / ECN / v50 plan 全链冻结 | artillery solution HUD 与 firing solution payload contract、共享 bearing 语义和非目标边界全部落文档 | `rg -n "REQ-0029-009|REQ-0029-010|artillery solution|firing solution|world bearing|PrototypeHud|get_firing_solution_snapshot|get_last_fired_solution" docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md docs/ecn/ECN-0034-artillery-firing-solution-hud-and-payload.md docs/plan/v50-index.md docs/plan/v50-artillery-firing-solution-hud.md docs/plans/2026-03-24-v50-artillery-firing-solution-hud-design.md` | done |
| M1 HUD + payload contract | PrototypeHud consumer、howitzer payload snapshot、lab 接线 | focused tests 证明 HUD 可见性、world bearing 语义与 fire payload contract 全部成立 | `tests/world/test_city_artillery_solution_hud_contract.gd`; `tests/world/test_city_m777_howitzer_firing_solution_contract.gd`; `tests/world/test_city_m777_howitzer_lab_artillery_solution_contract.gd` | done |
| M2 verification | focused tests + fresh closeout 文档 | 受影响 tests 全绿，fresh verification 文档回填追溯矩阵 | `docs/plan/v50-m2-verification-2026-03-24.md` | done |

## 计划索引

- [v50-artillery-firing-solution-hud.md](./v50-artillery-firing-solution-hud.md)

## 追溯矩阵

| Req ID | V50 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0029-009 | `v50-artillery-firing-solution-hud.md` | `tests/world/test_city_artillery_solution_hud_contract.gd`; `tests/world/test_city_m777_howitzer_lab_artillery_solution_contract.gd` | `docs/plan/v50-m2-verification-2026-03-24.md` | `v50-m2-verification-2026-03-24.md` | done |
| REQ-0029-010 | `v50-artillery-firing-solution-hud.md` | `tests/world/test_city_m777_howitzer_firing_solution_contract.gd`; `tests/world/test_city_m777_howitzer_lab_artillery_solution_contract.gd` | `docs/plan/v50-m2-verification-2026-03-24.md` | `v50-m2-verification-2026-03-24.md` | done |

## Closeout 证据口径

- `v50` 不接受“反正有 compass 和 debug text，玩家自己换算一下就行”的说法。
- 必须有 fresh test 证明：
  - `PrototypeHud` 已经挂上正式 artillery solution HUD consumer；
  - 该 HUD 只在 howitzer 操炮态可见；
  - HUD 里的 `yaw` 是炮口世界 bearing，而不是相对 yaw；
  - `pitch` 继续复用 `0-71°` 真实仰角口径；
  - accepted fire 会留下正式 firing solution payload；
  - payload 至少包含 world origin、chunk metadata、world bearing、pitch、shell type 与 muzzle velocity。

## ECN 索引

- [ECN-0034-artillery-firing-solution-hud-and-payload.md](../ecn/ECN-0034-artillery-firing-solution-hud-and-payload.md)

## 差异列表

- 当前无；后续 projectile、弹道积分、落点与反炮兵属于新版本范围。
