# V40 Index

## 愿景

设计入口：[2026-03-23-v40-rifle-vfx-and-ballistics-design.md](../plans/2026-03-23-v40-rifle-vfx-and-ballistics-design.md)

研究入口：[2026-03-23-v40-rifle-vfx-and-ballistics-research.md](../plans/2026-03-23-v40-rifle-vfx-and-ballistics-research.md)

依赖入口：

- [v15-index.md](./v15-index.md)
- [v32-index.md](./v32-index.md)
- [v39-index.md](./v39-index.md)

`v40` 的目标不是新增一类武器，而是把现有 `rifle` 主链从“可用但观感像蓝色糖丸”推进到“接近 GTA 式可读反馈”的正式状态：开火要有短促枪口火光，子弹本体不再可见，只留下短寿命的烟尘/曳迹；同时保持 live projectile + raycast 命中主链不变，把步枪速度、射程和瞄准 trace 一起提升，并确保蜘蛛 lab 与主世界共用同一条正式实现，而不是 lab 自己再长一套分叉战斗视觉。

## 决策冻结

- `v40` 不把步枪硬切成瞬时 hitscan，继续沿 `live projectile + raycast hit` 主链扩展。
- 玩家步枪的正式视觉反馈冻结为：
  - 枪口火光
  - 不可见弹体
  - 短寿命 smoke tracer
- 正式 rifle projectile profile 冻结为：`rifle_smoke_trace`
- 玩家 rifle ballistic profile 冻结为：
  - `speed_mps = 920`
  - `max_distance_m = 960`
  - `rifle_aim_trace_distance_m = 960`
- `SpiderCrawlerLab` 必须复用与主世界相同的 rifle projectile / tracer / muzzle flash 合同。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs + research | `v40` design / research / plan 冻结 | 文档链完整，方案与实现边界明确 | `rg -n "v40|rifle_smoke_trace|920|960" docs/plan/v40-index.md docs/plan/v40-rifle-vfx-and-ballistics.md docs/plans/2026-03-23-v40-rifle-vfx-and-ballistics-*.md` | done |
| M1 rifle fire feedback | muzzle flash、无可见弹体、smoke tracer | 步枪开火具备正式火光和烟尘轨迹反馈，不再显示蓝色球弹体 | `tests/world/test_city_player_rifle_vfx_and_ballistics.gd`、[v40-m3-verification-2026-03-23.md](./v40-m3-verification-2026-03-23.md) | done |
| M2 rifle ballistics | 更高速度、更远射程、更远瞄准 trace | 步枪 ballistic profile 升级且不打碎现有 projectile 主链 | `tests/world/test_city_player_rifle_vfx_and_ballistics.gd`、`tests/world/test_city_player_combat.gd`、[v40-m3-verification-2026-03-23.md](./v40-m3-verification-2026-03-23.md) | done |
| M3 spider lab integration | `SpiderCrawlerLab` 复用同链路 | 蜘蛛 lab 中步枪也具备相同 FX / tracer / ballistics，并继续有效伤害蜘蛛 | `tests/world/test_spider_crawler_lab_rifle_feedback_contract.gd`、`tests/world/test_spider_crawler_lab_combat_contract.gd`、`tests/e2e/test_spider_crawler_lab_combat_flow.gd`、[v40-m3-verification-2026-03-23.md](./v40-m3-verification-2026-03-23.md) | done |
| M4 regression + closeout | 主世界与既有武器回归 | `rifle / grenade / laser / missile / spider lab` 关键回归 fresh 通过 | fresh verification 文档 | todo |

## 计划索引

- [v40-rifle-vfx-and-ballistics.md](./v40-rifle-vfx-and-ballistics.md)

## 追溯矩阵

| Req ID | V40 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0040-001 | `v40-rifle-vfx-and-ballistics.md` | `tests/world/test_city_player_rifle_vfx_and_ballistics.gd` | `--script res://tests/world/test_city_player_rifle_vfx_and_ballistics.gd` | [v40-m3-verification-2026-03-23.md](./v40-m3-verification-2026-03-23.md) | done |
| REQ-0040-002 | `v40-rifle-vfx-and-ballistics.md` | `tests/world/test_city_player_rifle_vfx_and_ballistics.gd`、`tests/world/test_city_player_combat.gd` | `--script res://tests/world/test_city_player_combat.gd` | [v40-m3-verification-2026-03-23.md](./v40-m3-verification-2026-03-23.md) | done |
| REQ-0040-003 | `v40-rifle-vfx-and-ballistics.md` | `tests/world/test_spider_crawler_lab_rifle_feedback_contract.gd`、`tests/world/test_spider_crawler_lab_combat_contract.gd` | `--script res://tests/e2e/test_spider_crawler_lab_combat_flow.gd` | [v40-m3-verification-2026-03-23.md](./v40-m3-verification-2026-03-23.md) | done |
| REQ-0040-004 | `v40-rifle-vfx-and-ballistics.md` | `tests/world/test_city_player_grenade.gd`、`tests/world/test_city_player_laser_designator.gd`、`tests/world/test_city_player_missile_launcher.gd` | fresh regression run | — | todo |

## Closeout 证据口径

- `v40` 不能只靠肉眼说“现在比较像 GTA 了”；必须有 fresh tests 证明：
  - formal muzzle flash state
  - smoke tracer runtime
  - 无可见弹体
  - 更远 ballistic profile
  - spider lab formal consumer
- `v40` closeout 统一落到 `docs/plan/v40-mN-verification-YYYY-MM-DD.md`

## ECN 索引

- 暂无

## 差异列表

- `v40` 不引入新的武器 mode。
- `v40` 不做弹药系统、装填系统、命中贴花或破片效果。
- `v40` 不把步枪战斗主链改成完全即时 hitscan。
