# V51 Index

## 愿景

PRD 入口：[PRD-0029 Artillery Howitzer Scene Foundation](../prd/PRD-0029-artillery-howitzer-scene-foundation.md)

设计入口：[2026-03-24-v51-world-howitzer-summon-and-ballistics-design.md](../plans/2026-03-24-v51-world-howitzer-summon-and-ballistics-design.md)

依赖入口：

- [v45-index.md](./v45-index.md)
- [v50-index.md](./v50-index.md)

`v51` 的目标不是再给 howitzer 补一层调试壳，而是把它正式变成主世界里的可用武器平台。冻结三件事：一是 `KP_8` 可以在玩家前方召唤一门当前 howitzer；二是主世界 howitzer 的操炮 ownership / prompt / HUD 与 lab 共线；三是 accepted fire 会在主世界生成 formal artillery shell，按 firing solution payload 做真实 flight，并给出正式 impact / explosion result。

## 决策冻结

- summon 入口：
  - `CityPrototype.handle_debug_keypress()`
  - `KP_8`
- summoned howitzer 实例策略：
  - 同时仅一门当前实例
  - 重复召唤 = 重建/重定位，不无限堆炮
- shared operation controller：
  - `res://city_game/combat/artillery/CityM777HowitzerOperationController.gd`
- shell runtime：
  - `res://city_game/combat/artillery/CityArtilleryShell.gd`
- shell launch 真源：
  - howitzer `firing_solution`
- shell flight：
  - gravity ballistic
  - 允许 formal `ballistic_time_scale`
- impact 消费链：
  - `city_enemy`
  - `city_destructible_building`
  - `resolve_pedestrian_explosion()`
  - `resolve_vehicle_explosion()`

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | PRD / ECN / v51 plan 全链冻结 | 主世界 summon、shared controller、shell ballistic 与非目标边界全部落文档 | `rg -n "REQ-0029-011|REQ-0029-012|REQ-0029-013|KP_8|CityM777HowitzerOperationController|CityArtilleryShell|ballistic|firing_solution" docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md docs/ecn/ECN-0035-world-howitzer-summon-and-ballistics.md docs/plan/v51-index.md docs/plan/v51-world-howitzer-summon-and-ballistics.md docs/plans/2026-03-24-v51-world-howitzer-summon-and-ballistics-design.md` | done |
| M1 world summon + shared operation | summon、唯一实例、主世界 prompt/HUD/ownership、lab 并轨 controller | focused tests 证明主世界 howitzer summon 与 world/lab 共线操作合同成立 | `tests/world/test_city_world_howitzer_spawn_contract.gd`; `tests/world/test_city_world_howitzer_interaction_contract.gd` | done |
| M2 ballistic shell | live shell、impact result、主世界爆炸消费链 | focused tests 证明 accepted fire 会生成 live shell 并留下正式 explosion result | `tests/world/test_city_world_howitzer_ballistics_contract.gd`; `tests/e2e/test_city_world_howitzer_flow.gd` | done |
| M3 verification | focused + e2e + 解析检查 | 受影响 tests 全绿，fresh verification 文档回填追溯矩阵 | `docs/plan/v51-m3-verification-2026-03-24.md` | done |
| M4 live bugfix stabilization | 修复 live shell `look_at()` warning 与主世界 summon 悬空 | 新增回归测试卡住 shell 无效运动向量朝向保护与 summon authored vertical offset；主世界 howitzer focused + e2e + 解析检查 fresh 全绿 | `docs/plan/v51-m4-verification-2026-03-24.md` | done |
| M5 live warning follow-up | 补齐 shell `look_target == origin` 的直接 guard | 新增显式 guard debug contract，验证 shell 在 `look_target` 折叠为 origin 时不会再调用 `look_at()`；主世界 ballistic + e2e + 解析检查 fresh 全绿 | `docs/plan/v51-m5-verification-2026-03-25.md` | done |

## 计划索引

- [v51-world-howitzer-summon-and-ballistics.md](./v51-world-howitzer-summon-and-ballistics.md)

## 追溯矩阵

| Req ID | V51 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0029-011 | `v51-world-howitzer-summon-and-ballistics.md` | `tests/world/test_city_world_howitzer_spawn_contract.gd` | `docs/plan/v51-m3-verification-2026-03-24.md`; `docs/plan/v51-m4-verification-2026-03-24.md` | `v51-m3-verification-2026-03-24.md`; `v51-m4-verification-2026-03-24.md` | done |
| REQ-0029-012 | `v51-world-howitzer-summon-and-ballistics.md` | `tests/world/test_city_world_howitzer_interaction_contract.gd`; 既有 lab focused tests | `tests/e2e/test_city_world_howitzer_flow.gd`; `docs/plan/v51-m3-verification-2026-03-24.md` | `v51-m3-verification-2026-03-24.md` | done |
| REQ-0029-013 | `v51-world-howitzer-summon-and-ballistics.md` | `tests/world/test_city_world_howitzer_ballistics_contract.gd`; `tests/world/test_city_artillery_shell_visual_orientation_contract.gd` | `tests/e2e/test_city_world_howitzer_flow.gd`; `docs/plan/v51-m3-verification-2026-03-24.md`; `docs/plan/v51-m4-verification-2026-03-24.md`; `docs/plan/v51-m5-verification-2026-03-25.md` | `v51-m3-verification-2026-03-24.md`; `v51-m4-verification-2026-03-24.md`; `v51-m5-verification-2026-03-25.md` | done |

## Closeout 证据口径

- `v51` 不接受“主世界里能把 howitzer 摆出来就算接入”的说法。
- 必须有 fresh test 证明：
  - `KP_8` 真能召唤当前 howitzer；
  - 主世界 howitzer 的操炮手感与 lab 共线；
  - accepted fire 真会生成 live shell，而不是只有炮口特效；
  - shell impact 真会留下 formal explosion result，并接入主世界爆炸消费链。

## ECN 索引

- [ECN-0035-world-howitzer-summon-and-ballistics.md](../ecn/ECN-0035-world-howitzer-summon-and-ballistics.md)

## 差异列表

- 当前无；预测落点 HUD、目标点求解、反炮兵和完整火控仍属于后续版本范围。
