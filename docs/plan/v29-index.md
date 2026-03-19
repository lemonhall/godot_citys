# V29 Index

## 愿景

PRD 入口：[PRD-0019 Missile Command Defense Minigame](../prd/PRD-0019-missile-command-defense-minigame.md)

研究入口：[2026-03-20-v29-missile-command-research.md](../plans/2026-03-20-v29-missile-command-research.md)

设计入口：[2026-03-20-v29-missile-command-design.md](../plans/2026-03-20-v29-missile-command-design.md)

`v29` 的目标是在用户指定的 `chunk_183_152` ground probe 上落成一座正式的 3D `Missile Command` 防空电池。它继续沿 `scene_minigame_venue` 主链挂载，不新增 `interactive_prop` 分叉。玩家走进开赛圈后自动进入炮台防空态，左键向准星落点发射拦截弹，右键放大，`Q` 切换发射井，`Esc` 退出玩法态；敌方弹头按波次落向城市和发射井，玩家要靠爆炸圈链式清场来保住地面目标。`v29` 首版冻结为 `3 silos + 3 cities + 3 waves` 的 deterministic arcade defense 版，不追求复杂军事模拟，也不允许退回“自由人物拿枪打天上目标”的 TPS 变体。

## 决策冻结

- `venue_id = venue:v29:missile_command_battery:chunk_183_152`
- `game_kind = missile_command_battery`
- 锚点冻结为：
  - `chunk_id = chunk_183_152`
  - `chunk_key = (183, 152)`
  - `world_position = (11925.63, -4.74, 4126.84)`
  - `surface_normal = (-0.01, 1.00, -0.00)`
- 正式输入冻结为：
  - 左键：发射拦截弹
  - 右键：zoom
  - `Q`：切换发射井
  - `Esc`：退出玩法态
- 进入 start ring 后自动进入玩法态，不再把主动作绑定为 `E`
- 首版冻结为 `3 silos + 3 cities + 3 waves`
- 场馆采用固定 `gameplay plane`；敌弹、拦截弹和爆炸圈都运行在同一张正式平面上
- full map pin `icon_id` 冻结为 `missile_command`

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | research / design / PRD-0019 / v29-index / v29-plan | 文档链完整，`REQ-0019-*` 可追溯 | `rg -n "REQ-0019" docs/prd/PRD-0019-missile-command-defense-minigame.md docs/plan/v29-index.md docs/plan/v29-missile-command-defense-minigame.md` | todo |
| M1 venue mount | registry / manifest / scene / map pin | `chunk_183_152` near mount 后可找到正式 venue，full map pin 可渲染 | `tests/world/test_city_missile_command_minigame_venue_manifest_contract.gd`、`tests/world/test_city_scene_minigame_venue_registry_runtime.gd`、`tests/world/test_city_missile_command_full_map_pin_contract.gd` | todo |
| M2 gameplay mode | start ring / camera / left-click fire / zoom / cycle silo / exit | 进圈进入玩法态，camera 切换，formal request API 可用，退出恢复玩家控制 | `tests/world/test_city_missile_command_mode_contract.gd` | todo |
| M3 wave combat | enemy waves / interceptor / explosion chain / city+silo damage / game over | 至少一条正式波次能完成发射、拦截、爆炸链和毁伤判定 | `tests/world/test_city_missile_command_wave_contract.gd`、`tests/world/test_city_missile_command_damage_contract.gd` | todo |
| M4 HUD + e2e | HUD / scoreboard / crosshair / final reset | “进圈 -> 发射 -> 击毁 -> 波次推进 -> Esc 退出”整链路跑通 | `tests/world/test_city_missile_command_hud_contract.gd`、`tests/e2e/test_city_missile_command_wave_flow.gd` | todo |
| M5 regression + profiling | soccer / tennis 回归；若触及 HUD / tick / mount，串行 profiling | 受影响链路 fresh rerun 通过，证据落档 | 受影响 tests + profiling 三件套 | todo |

## 计划索引

- [v29-missile-command-defense-minigame.md](./v29-missile-command-defense-minigame.md)

## 追溯矩阵

| Req ID | v29 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0019-001 | `v29-missile-command-defense-minigame.md` | `tests/world/test_city_missile_command_minigame_venue_manifest_contract.gd` | `--script res://tests/world/test_city_missile_command_minigame_venue_manifest_contract.gd` | — | todo |
| REQ-0019-002 | `v29-missile-command-defense-minigame.md` | `tests/world/test_city_missile_command_battery_contract.gd` | `--script res://tests/world/test_city_missile_command_battery_contract.gd` | — | todo |
| REQ-0019-003 | `v29-missile-command-defense-minigame.md` | `tests/world/test_city_missile_command_mode_contract.gd` | `--script res://tests/world/test_city_missile_command_mode_contract.gd` | — | todo |
| REQ-0019-004 | `v29-missile-command-defense-minigame.md` | `tests/world/test_city_missile_command_wave_contract.gd`、`tests/world/test_city_missile_command_damage_contract.gd` | `--script res://tests/e2e/test_city_missile_command_wave_flow.gd` | — | todo |
| REQ-0019-005 | `v29-missile-command-defense-minigame.md` | `tests/world/test_city_missile_command_hud_contract.gd`、`tests/world/test_city_missile_command_full_map_pin_contract.gd` | `--script res://tests/e2e/test_city_missile_command_wave_flow.gd` | — | todo |
| REQ-0019-006 | `v29-missile-command-defense-minigame.md` | 受影响 soccer / tennis tests | 受影响回归 + profiling 三件套（如适用） | — | todo |

## ECN 索引

- 当前无

## 差异列表

- `v29` 不包含奖励城市、复杂特殊弹型、旁白、排行榜与任务接入。
- `v29` 不包含自由步行射击版火箭防空；玩法态冻结为固定 battery mode。
