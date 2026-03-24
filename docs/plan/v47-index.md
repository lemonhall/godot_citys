# V47 Index

## 愿景

PRD 入口：[PRD-0029 Artillery Howitzer Scene Foundation](../prd/PRD-0029-artillery-howitzer-scene-foundation.md)

设计入口：[2026-03-24-v47-artillery-fire-presentation-design.md](../plans/2026-03-24-v47-artillery-fire-presentation-design.md)

依赖入口：

- [v44-index.md](./v44-index.md)
- [v45-index.md](./v45-index.md)
- [v46-index.md](./v46-index.md)

`v47` 的目标不是进入真实火控或弹道世界，而是把 M777 从“能调角”推进到“能正式开火演出”。正式范围冻结为：`Space` 触发 howitzer fire、`6s` 冷却、拉火绳/炮口火光/烟尘/轻微后坐/weapon fire audio，以及 lab 内清晰的冷却 HUD；正式非目标同样冻结为：不做 projectile、弹道、落点、爆炸、伤害判定与世界 bearing 火控换算。

## 决策冻结

- fire runtime 真源：
  - `res://city_game/combat/artillery/CityM777Howitzer.tscn`
  - `res://city_game/combat/artillery/CityM777Howitzer.gd`
- lab fire trigger：
  - `Space`
- fire cooldown：
  - `6.0s`
- fire 演出组成：
  - 炮口火光
  - 炮口烟尘
  - 拉火绳常显 + 瞬时绷紧
  - 轻微后坐
  - formal weapon fire audio
- HUD 冷却文案：
  - 冷却中：`装填中 X.Xs...`
  - 冷却完成：`可击发`
- 正式交互边界：
  - 仍沿用 `v46` 的 `5m` 进入、`20m` 自动退出
  - 玩家在操炮态内继续自由移动
- 正式非目标：
  - 不生成 projectile / grenade / missile
  - 不做弹道、落点、爆炸、伤害判定
  - 不做 yaw 与世界 bearing 的换算

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | PRD / ECN / v47 plan 全链冻结 | `Space`、`6.0s`、fire 演出组成、HUD 冷却文案与非目标边界全部落文档 | `rg -n "REQ-0029-008|Space|6.0s|装填中 X.Xs|可击发|MuzzleFxAnchor|LanyardAnchor|projectile / grenade / missile" docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md docs/ecn/ECN-0031-artillery-fire-presentation.md docs/plan/v47-index.md docs/plan/v47-artillery-fire-presentation.md docs/plans/2026-03-24-v47-artillery-fire-presentation-design.md` | done |
| M1 fire runtime + lab trigger | formal fire API、scene nodes、lab `Space` 交互与 HUD | focused tests 证明 howitzer fire contract 与 lab fire interaction 全部成立 | `tests/world/test_city_m777_howitzer_scene_contract.gd`; `tests/world/test_city_m777_howitzer_lab_scene_contract.gd`; `tests/world/test_city_m777_howitzer_fire_contract.gd`; `tests/world/test_city_m777_howitzer_lab_fire_interaction_contract.gd` | done |
| M2 verification | focused tests + fresh closeout 文档 | 受影响 tests 全绿，fresh verification 文档回填追溯矩阵 | `docs/plan/v47-m2-verification-2026-03-24.md` | done |
| M3 live-regression hardening | 修复实机反馈的 Space jump leak 与 fire anchor drift | red-green tests 证明操炮态 `Space` 不再串跳，fire presentation 跟随完整 anchor transform，fresh verification 文档回填 | `docs/plan/v47-m3-verification-2026-03-24.md` | done |

## 计划索引

- [v47-artillery-fire-presentation.md](./v47-artillery-fire-presentation.md)

## 追溯矩阵

| Req ID | V47 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0029-008 | `v47-artillery-fire-presentation.md` | `tests/world/test_city_m777_howitzer_scene_contract.gd`; `tests/world/test_city_m777_howitzer_fire_contract.gd` | `docs/plan/v47-m3-verification-2026-03-24.md` | `v47-m3-verification-2026-03-24.md` | done |
| REQ-0029-007 | `v47-artillery-fire-presentation.md` | `tests/world/test_city_m777_howitzer_lab_scene_contract.gd`; `tests/world/test_city_m777_howitzer_lab_fire_interaction_contract.gd` | `docs/plan/v47-m3-verification-2026-03-24.md` | `v47-m3-verification-2026-03-24.md` | done |

## Closeout 证据口径

- `v47` 不接受“先在 lab 里播个假特效，之后再下沉到 howitzer runtime”的说法。
- 必须有 fresh test 证明：
  - fire anchors 与 fire presentation nodes 是正式 howitzer scene contract；
  - accepted fire 会进入 `6s` 冷却，并触发火光、烟尘、拉火绳、后坐与音频；
  - 冷却期间重复请求被拒绝；
  - lab 中只有进入操炮态后 `Space` 才有效；
  - HUD 能明确显示 `装填中 X.Xs...` 与 `可击发`；
  - fire 期间没有偷生 projectile / grenade / missile 节点。

## ECN 索引

- [ECN-0031-artillery-fire-presentation.md](../ecn/ECN-0031-artillery-fire-presentation.md)

## 差异列表

- 当前无；真实炮击解算、绝对 bearing、落点/爆炸链与主世界接入留给后续版本。
