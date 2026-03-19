# V28 Index

## 愿景

PRD 入口：[PRD-0018 Tennis Singles Minigame](../prd/PRD-0018-tennis-singles-minigame.md)

研究入口：[2026-03-19-v28-tennis-singles-minigame-research.md](../plans/2026-03-19-v28-tennis-singles-minigame-research.md)

研究 PDF：[2026-03-19-v28-tennis-singles-minigame-research.pdf](../plans/2026-03-19-v28-tennis-singles-minigame-research.pdf)

设计入口：[2026-03-19-v28-tennis-singles-minigame-design.md](../plans/2026-03-19-v28-tennis-singles-minigame-design.md)

交互/UI 研究入口：[2026-03-19-v28-tennis-input-ui-ux-research.md](../plans/2026-03-19-v28-tennis-input-ui-ux-research.md)

交互/UI 研究 PDF：[2026-03-19-v28-tennis-input-ui-ux-research.pdf](../plans/2026-03-19-v28-tennis-input-ui-ux-research.pdf)

反馈/音效研究入口：[2026-03-19-v28-tennis-feedback-audio-research.md](../plans/2026-03-19-v28-tennis-feedback-audio-research.md)

反馈/音效研究 PDF：[2026-03-19-v28-tennis-feedback-audio-research.pdf](../plans/2026-03-19-v28-tennis-feedback-audio-research.pdf)

依赖入口：

- [PRD-0015 Soccer Ball Interactive Prop](../prd/PRD-0015-soccer-ball-interactive-prop.md)
- [PRD-0016 Soccer Minigame Venue Foundation](../prd/PRD-0016-soccer-minigame-venue-foundation.md)
- [PRD-0017 Soccer 5v5 Match](../prd/PRD-0017-soccer-5v5-match.md)
- [v25-index.md](./v25-index.md)
- [v26-index.md](./v26-index.md)
- [v27-index.md](./v27-index.md)

`v28` 的目标是在用户给定的 `chunk_158_140` ground probe 上落成第二套正式 sports minigame：网球单打。推荐路线不是把足球 `5v5` runtime 改名，也不是新开第三条 authored feature family，而是继续沿 `scene_minigame_venue + scene_interactive_prop` 主链扩展：新增 `venue:v28:tennis_court:chunk_158_140` 与 `prop:v28:tennis_ball:chunk_158_140`，author 一座 third-person 可玩的 arcade-scale tennis court、net、start ring、AI 对手、HUD 与世界计分板，并把 `CityPrototype` 从“足球单 runtime 入口”提升成“soccer + tennis 双 runtime 聚合层”。比赛规则冻结为：正式单打 court 语义、对角发球、单次 bounce、in/out、不过网/双误判分，以及紧凑单盘短局制；但玩家与 AI 的击球表现必须受 tennis runtime 的合法规则约束，不能再退回成 generic impulse 乱飞。

当前状态：`M0` 文档冻结已经落地，deep-research Markdown/PDF、design、PRD、`v28-index` 与 `v28` plan 已全部写入仓库；后续按塔山循环执行 `Red -> Green -> Refactor -> E2E -> Verification`。本版默认不打折扣：若要改动规则口径、DoD 或赛制简化边界，必须先改 `PRD-0018` 与本 index，再动代码。

## 决策冻结

- `v28` 正式场馆 `venue_id` 冻结为 `venue:v28:tennis_court:chunk_158_140`。
- `v28` 正式网球 `prop_id` 冻结为 `prop:v28:tennis_ball:chunk_158_140`。
- 锚点冻结为：
  - `chunk_id = chunk_158_140`
  - `chunk_key = (158,140)`
  - `world_position = (5489.46, 20.62, 1029.73)`
- 首版玩法冻结为 `player vs AI opponent` 的单打 minigame。
- court 几何冻结为 `official tennis proportions * 7.5` 的 arcade-scale 场地，而不是现实米制 1:1 直落。
- 平台总抬高量相对原始 authored 基线累计冻结为 `+2.0m`，避免被地形吞没（[ECN-0026](../ecn/ECN-0026-v28-tennis-playability-replan.md)）。
- start ring 必须贴近 home/player side serve setup zone，不能再落到远离可玩区的偏移角落（[ECN-0026](../ecn/ECN-0026-v28-tennis-playability-replan.md)）。
- tennis ball 必须按 third-person readability 做 oversize，且 visual mesh 必须跟随 `target_diameter_m` 一起缩放（[ECN-0026](../ecn/ECN-0026-v28-tennis-playability-replan.md)）。
- tennis ball 还必须提供最小 third-person 可读性 cue：高对比度球体辅助视觉、高速来球 trail、弹地/碰撞 impact audio，且不得在热路径里每帧重复播音。
- 规则主链冻结为：对角发球、单次 bounce、不过网、出界、双误、point / game progression。
- 计分冻结为 `no-ad` 的紧凑单盘制，不做完整职业长盘。
- `CityPrototype.gd` 必须支持 soccer + tennis 双 runtime 聚合。
- 手动球交互事件必须按 `prop_id` 分发给正确 runtime。
- 玩家 `E` 击球必须进入 tennis runtime 的合法 shot planner：默认发球落到对角合法 service box，默认回球落到对方半场安全区；不得继续沿用通用球 prop 的裸前向 impulse。
- AI 回球后，玩家侧至少要有 `landing marker + auto-footwork assist + strike window feedback` 这一档基础接球 UX；共享 `E` 提示半径必须与合法击球窗口收敛到同一条入口链路（[ECN-0026](../ecn/ECN-0026-v28-tennis-playability-replan.md)）。
- 网球 full map pin 若显示，`icon_id = tennis` 必须有正式 glyph。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | `PRD-0018`、research、design、`v28-index`、`v28` plan、traceability | 5 份文档全部落地且 `REQ-0018-*` 可追溯 | `rg -n "REQ-0018" docs/prd/PRD-0018-tennis-singles-minigame.md docs/plan/v28-index.md docs/plan/v28-tennis-singles-minigame.md` | done |
| M1 authored asset mount | tennis venue / ball manifest、registry、scene mount、map pin glyph | `chunk_158_140` near mount 后能找到正式 tennis venue 与 tennis ball，map pin icon 支持 `tennis` | `tests/world/test_city_tennis_minigame_venue_manifest_contract.gd`、`tests/world/test_city_tennis_ball_prop_manifest_contract.gd`、`tests/world/test_city_scene_minigame_venue_registry_runtime.gd`、`tests/world/test_city_scene_interactive_prop_registry_runtime.gd` | todo |
| M2 court + runtime entry | arcade-scale court geometry、平台抬高、net、start ring、AI anchor、runtime 接线、HUD 面板 | 场馆暴露可玩的第三人称 court / net / service box contract；match 可从 idle 进入 pre_serve / rally；平台不被地形吞没；start ring 位于 home serve setup zone 附近 | `tests/world/test_city_tennis_court_geometry_contract.gd`、`tests/world/test_city_tennis_match_start_contract.gd` | todo |
| M3 serve / point / score progression | 合法发球、回球规划、bounce、in/out、double fault、point/game 计分、AI 回球 | 玩家 `E` 发球/回球默认 obey tennis legality；至少一条正式 point 能从 serve 走到 winner side；scoreboard 与 HUD 同步推进；`strike_window_state = ready` 时共享 `E` 提示可稳定进入 return planner | `tests/world/test_city_tennis_scoring_contract.gd`、`tests/world/test_city_tennis_runtime_aggregate_contract.gd`、`tests/e2e/test_city_tennis_singles_match_flow.gd` | todo |
| M4 receive UX + reset + regressions | landing marker、auto-footwork assist、strike window feedback、出圈 reset、ambient freeze 聚合、足球回归、玩家/AI 挂拍与挥拍视觉、Coach/Assist HUD、挥拍音效、ready/result 事件反馈、轻量 AI 长回合失误、球体 glow/trail/impact cue | “进场 -> 开赛 -> 合法发球 -> AI 回球 -> 玩家可接球 -> 得分 -> reset” 整链路可玩；足球关键 tests 继续通过；玩家与 AI 都具备可观测的 racket visual / swing visual；HUD 能给出中文动作指令与窗口反馈；`ready / point result / final` 具备事件驱动的 focus/audio cue；正式 tennis ball 具备 third-person 可读性视觉与 impact audio cue；AI 不再表现为长回合永不失误 | `tests/world/test_city_tennis_reset_on_exit_contract.gd`、`tests/world/test_city_tennis_runtime_aggregate_contract.gd`、`tests/world/test_city_tennis_ball_feedback_contract.gd`、`tests/e2e/test_city_tennis_singles_match_flow.gd`、受影响 soccer tests | in_progress |
| M5 profiling + closeout | 如触及 HUD / mount / tick，则 profiling 三件套 fresh rerun 并落档 | ordered profiling three-piece fresh rerun；closeout 证据落到 `docs/plan/` | `tests/world/test_city_chunk_setup_profile_breakdown.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd`、`tests/e2e/test_city_runtime_performance_profile.gd` | todo |

## 计划索引

- [v28-tennis-singles-minigame.md](./v28-tennis-singles-minigame.md)

## Verification Artifacts

- [v28-m4-verification-2026-03-19.md](./v28-m4-verification-2026-03-19.md)
- [v28-m5-verification-2026-03-19.md](./v28-m5-verification-2026-03-19.md)
- [v28-m6-verification-2026-03-19.md](./v28-m6-verification-2026-03-19.md)

## 追溯矩阵

| Req ID | v28 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0018-001 | `v28-tennis-singles-minigame.md` | `tests/world/test_city_tennis_minigame_venue_manifest_contract.gd`、`tests/world/test_city_tennis_ball_prop_manifest_contract.gd` | `--script res://tests/world/test_city_tennis_minigame_venue_manifest_contract.gd` | — | todo |
| REQ-0018-002 | `v28-tennis-singles-minigame.md` | `tests/world/test_city_tennis_court_geometry_contract.gd` | `--script res://tests/world/test_city_tennis_court_geometry_contract.gd` | — | todo |
| REQ-0018-003 | `v28-tennis-singles-minigame.md` | `tests/world/test_city_tennis_scoring_contract.gd`、`tests/world/test_city_tennis_runtime_aggregate_contract.gd` | `--script res://tests/e2e/test_city_tennis_singles_match_flow.gd` | — | todo |
| REQ-0018-003A | `v28-tennis-singles-minigame.md` | `tests/world/test_city_tennis_runtime_aggregate_contract.gd`、`tests/world/test_city_tennis_ball_feedback_contract.gd` | `--script res://tests/e2e/test_city_tennis_singles_match_flow.gd` | [v28-m4-verification-2026-03-19.md](./v28-m4-verification-2026-03-19.md) | in_progress |
| REQ-0018-004 | `v28-tennis-singles-minigame.md` | `tests/world/test_city_tennis_scoring_contract.gd`、`tests/world/test_city_tennis_runtime_aggregate_contract.gd` | `--script res://tests/e2e/test_city_tennis_singles_match_flow.gd` | [v28-m4-verification-2026-03-19.md](./v28-m4-verification-2026-03-19.md) | in_progress |
| REQ-0018-005 | `v28-tennis-singles-minigame.md` | `tests/world/test_city_tennis_reset_on_exit_contract.gd` | `--script res://tests/e2e/test_city_tennis_singles_match_flow.gd` | [v28-m4-verification-2026-03-19.md](./v28-m4-verification-2026-03-19.md) | in_progress |
| REQ-0018-006 | `v28-tennis-singles-minigame.md` | 受影响 soccer tests + `tests/world/test_city_tennis_runtime_aggregate_contract.gd` | 受影响回归 + profiling 三件套（如适用） | — | todo |

## ECN 索引

- [ECN-0026 V28 Tennis Playability Replan](../ecn/ECN-0026-v28-tennis-playability-replan.md)

## 差异列表

- `v28` 不包含双打、球拍可见资产、完整 let / challenge / changeover 规则。
- `v28` 不包含裁判、观众、联网、职业赛事 presentation。
- `v28` 只冻结网球单打 minigame 的正式基础版；更复杂网球系统进入后续版本。
