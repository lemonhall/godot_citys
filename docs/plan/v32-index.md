# V32 Index

## 愿景

PRD 入口：[PRD-0022 Player Missile Launcher Weapon](../prd/PRD-0022-player-missile-launcher.md)

设计入口：[2026-03-20-v32-player-missile-launcher-design.md](../plans/2026-03-20-v32-player-missile-launcher-design.md)

依赖入口：

- [PRD-0008 Laser Designator World Inspection](../prd/PRD-0008-laser-designator-world-inspection.md)
- [PRD-0019 Missile Command Defense Minigame](../prd/PRD-0019-missile-command-defense-minigame.md)
- [v15-index.md](./v15-index.md)
- [v29-index.md](./v29-index.md)

`v32` 的目标不是再做一把“只是换皮”的爆炸武器，而是把 `v29` 已验证过的导弹视觉资产正式引入玩家武器系统：按 `8` 切到 `missile_launcher`，左键发射一枚带尾焰和轻微摇摆感的 live missile；导弹触碰命中会爆炸，飞行超过 `500m` 也会自爆，并继续沿现有爆炸主链影响敌人、行人和车辆，同时不打坏 `rifle / grenade / laser_designator`。

## 决策冻结

- `v32` 的正式 weapon mode 冻结为：`missile_launcher`
- 热键冻结为：`8`
- 导弹最大飞行距离冻结为：`500m`
- 导弹视觉正式复用 `InterceptorMissileVisual.tscn`
- live missile 的 sway 必须体现到真实飞行路径，而不是只转模型
- 爆炸必须复用既有 explosion resolver，不新增第二套 crowd / vehicle damage 系统

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 武器模式与发射链 | `8` 键切换、formal request、CombatRoot/Missiles | `missile_launcher` 成为正式 mode；左键 request 会生成 missile；不会继续生成 projectile/grenade/laser | `tests/world/test_city_player_missile_launcher.gd` | todo |
| M2 导弹飞行与爆炸合同 | visual reuse、sway、impact explode、500m self-destruct | live missile 复用正式导弹视觉；飞行存在可观测 sway；近距命中会爆炸；超过 `500m` 自爆 | `tests/world/test_city_player_missile_launcher.gd` | todo |
| M3 回归与 closeout | 旧武器 / explosion 回归 | 现有 grenade / laser / crosshair / explosion 主链继续通过 | `tests/world/test_city_player_grenade.gd`、`tests/world/test_city_player_laser_designator.gd`、相关 explosion 回归 | todo |

## 计划索引

- [v32-player-missile-launcher.md](./v32-player-missile-launcher.md)

## 追溯矩阵

| Req ID | v32 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0022-001 | `v32-player-missile-launcher.md` | `tests/world/test_city_player_missile_launcher.gd` | `--script res://tests/world/test_city_player_missile_launcher.gd` | — | todo |
| REQ-0022-002 | `v32-player-missile-launcher.md` | `tests/world/test_city_player_missile_launcher.gd` | `--script res://tests/world/test_city_player_missile_launcher.gd` | — | todo |
| REQ-0022-003 | `v32-player-missile-launcher.md` | `tests/world/test_city_player_missile_launcher.gd` | `--script res://tests/world/test_city_player_missile_launcher.gd` | — | todo |
| REQ-0022-004 | `v32-player-missile-launcher.md` | `tests/world/test_city_player_grenade.gd`、`tests/world/test_city_player_laser_designator.gd`、`tests/world/test_city_player_missile_launcher.gd` | `--script res://tests/world/test_city_player_grenade.gd`、`--script res://tests/world/test_city_player_laser_designator.gd` | — | todo |

## Closeout 证据口径

- `v32` closeout 必须以 fresh tests 为准，统一落到 `docs/plan/v32-mN-verification-YYYY-MM-DD.md`
- 不接受“手感看起来差不多”作为 sway / explosion 完成证据
- 旧武器回归必须跑 fresh，不接受口头“理论上没改到”

## ECN 索引

- 暂无

## 差异列表

- `v32` 首版不做锁定/追踪/弹药库存
- `v32` 首版不做 missile-only HUD 面板
