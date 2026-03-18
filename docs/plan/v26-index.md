# V26 Index

## 愿景

PRD 入口：[PRD-0016 Soccer Minigame Venue Foundation](../prd/PRD-0016-soccer-minigame-venue-foundation.md)

设计入口：[2026-03-18-v26-soccer-minigame-venue-design.md](../plans/2026-03-18-v26-soccer-minigame-venue-design.md)

依赖入口：

- [PRD-0012 World Feature Ground Probe And Landmark Overrides](../prd/PRD-0012-world-feature-ground-probe-and-landmark-overrides.md)
- [PRD-0015 Soccer Ball Interactive Prop](../prd/PRD-0015-soccer-ball-interactive-prop.md)
- [v21-index.md](./v21-index.md)
- [v25-index.md](./v25-index.md)

`v26` 的目标是把 `v25` 的“一个能踢动的足球”扩成第一套正式可玩的足球 minigame 场馆。推荐路线不是把足球继续做胖，也不是把球场塞进 `scene_landmark`，而是新增一个 sibling family：`scene_minigame_venue`。它复用 `registry -> manifest -> near chunk mount -> scene` 的 authored 世界接入模式，但语义明确是“可玩场馆”。[已由 ECN-0025 变更](../ecn/ECN-0025-v26-scoreboard-and-ambient-freeze.md) `v26` 首版现在明确承诺：平整比赛承载层、两侧球门、进球检测、大型场边计分板、比分、出界/进球重置，以及进入场馆有效玩法态后冻结全城 crowd / ambient traffic 模拟，但保持收音机持续运行。`11v11`、门将/队友/对手 AI、完整规则系统不属于本版 DoD。

当前状态：`M1-M4` 已实现并完成 `2026-03-18` fresh verification，证据见 [v26-m4-verification-2026-03-18.md](./v26-m4-verification-2026-03-18.md)。

## 决策冻结

- `v26` 新增 sibling family：`scene_minigame_venue`。
- `v26` 首个场馆正式 `venue_id` 冻结为 `venue:v26:soccer_pitch:chunk_129_139`。
- 足球继续保留为 `scene_interactive_prop`，正式 `prop_id` 继续是 `prop:v25:soccer_ball:chunk_129_139`。
- 场馆与足球的正式绑定字段冻结为 `primary_ball_prop_id`，不生成第二个隐藏比赛球。
- 当前足球 authored anchor `(-1877.94, 2.52, 618.57)` 冻结为场馆 kickoff / 中心锚点。
- `v26` 首版不改 terrain 系统；场馆自带局部平整 playable floor。
- [已由 ECN-0025 变更](../ecn/ECN-0025-v26-scoreboard-and-ambient-freeze.md) `v26` 首版必须包含两侧球门、goal detection、大型场边计分板、比分与 reset loop。
- [已由 ECN-0025 变更](../ecn/ECN-0025-v26-scoreboard-and-ambient-freeze.md) `v26` 首版引入 `ambient_simulation_freeze`，冻结全城行人与 ambient 车辆 simulation，但不得复用 `world_simulation_pause`，也不得把收音机停掉。
- `ambient_simulation_freeze` 的出入场语义冻结为双圈层迟滞：
  - 进入比赛场地有效范围立即冻结
  - 只有离开赛场边界后再退出额外 `24.0m` 的 release buffer 才允许解冻
- `v26` 首版不承诺 `11v11`、完整规则裁判系统、门将/队友/对手 AI。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | `PRD-0016`、design、`v26-index`、`v26` plan、traceability | 4 份文档全部落地且 `REQ-0016-*` 可追溯 | `rg -n "REQ-0016" docs/prd/PRD-0016-soccer-minigame-venue-foundation.md docs/plan/v26-index.md docs/plan/v26-soccer-minigame-venue-foundation.md` | done |
| M1 minigame venue mount chain | 新 family registry/runtime、soccer venue manifest/scene、near chunk mount | 足球场馆可在 `chunk_129_139` 被正式 mounted，并带稳定 `venue_id` 元数据 | `tests/world/test_city_scene_minigame_venue_registry_runtime.gd`、`tests/world/test_city_soccer_minigame_venue_manifest_contract.gd` | done |
| M2 pitch / goals / scoring | playable floor、in-play bounds、goal volumes、score state、大型计分板 | 场馆内存在稳定 playable floor；两侧球门可被检测；进球只计一次；计分板同步更新 | `tests/world/test_city_soccer_pitch_play_surface_contract.gd`、`tests/world/test_city_soccer_goal_detection_contract.gd`、`tests/world/test_city_soccer_scoreboard_contract.gd`、`tests/world/test_city_soccer_scoreboard_visual_contract.gd` | done |
| M3 reset / ambient freeze / e2e | ball binding、goal/out reset、HUD、ambient freeze、完整玩法流程 | 玩家可完成“进场 -> 踢球 -> 进球/出界 -> 记分/重置 -> 再开球”完整链路；crowd/traffic 冻结但 radio 保持运行；边界出入不会抖动解冻 | `tests/world/test_city_soccer_ball_reset_contract.gd`、`tests/world/test_city_soccer_venue_ambient_freeze_contract.gd`、`tests/world/test_city_soccer_venue_ambient_freeze_hysteresis_contract.gd`、`tests/world/test_city_soccer_venue_radio_survives_ambient_freeze.gd`、`tests/e2e/test_city_soccer_minigame_goal_flow.gd` | done |
| M4 guard verification | `v25` 足球交互、`v24` radio、landmark、streaming、profiling guard | 受影响旧测试继续通过；如触及 mount/tick/HUD，profiling 三件套 fresh rerun 过线 | 受影响 world/e2e tests + profiling 三件套 | done |

## 计划索引

- [v26-soccer-minigame-venue-foundation.md](./v26-soccer-minigame-venue-foundation.md)

## 追溯矩阵

| Req ID | v26 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0016-001 | `v26-soccer-minigame-venue-foundation.md` | `tests/world/test_city_scene_minigame_venue_registry_runtime.gd` | `--script res://tests/world/test_city_scene_minigame_venue_registry_runtime.gd` | [v26-m4-verification-2026-03-18.md](./v26-m4-verification-2026-03-18.md) | done |
| REQ-0016-002 | `v26-soccer-minigame-venue-foundation.md` | `tests/world/test_city_soccer_minigame_venue_manifest_contract.gd`、`tests/world/test_city_soccer_pitch_play_surface_contract.gd` | `--script res://tests/world/test_city_soccer_pitch_play_surface_contract.gd` | [v26-m4-verification-2026-03-18.md](./v26-m4-verification-2026-03-18.md) | done |
| REQ-0016-003 | `v26-soccer-minigame-venue-foundation.md` | `tests/world/test_city_soccer_goal_detection_contract.gd`、`tests/world/test_city_soccer_scoreboard_contract.gd`、`tests/world/test_city_soccer_scoreboard_visual_contract.gd` | `--script res://tests/e2e/test_city_soccer_minigame_goal_flow.gd` | [v26-m4-verification-2026-03-18.md](./v26-m4-verification-2026-03-18.md) | done |
| REQ-0016-004 | `v26-soccer-minigame-venue-foundation.md` | `tests/world/test_city_soccer_ball_reset_contract.gd` | `--script res://tests/e2e/test_city_soccer_minigame_goal_flow.gd` | [v26-m4-verification-2026-03-18.md](./v26-m4-verification-2026-03-18.md) | done |
| REQ-0016-005 | `v26-soccer-minigame-venue-foundation.md` | 受影响 `v25` 足球交互与 mount tests | `--script res://tests/e2e/test_city_soccer_minigame_goal_flow.gd` + 受影响回归 | [v26-m4-verification-2026-03-18.md](./v26-m4-verification-2026-03-18.md) | done |
| REQ-0016-006 | `v26-soccer-minigame-venue-foundation.md` | `tests/world/test_city_soccer_venue_ambient_freeze_contract.gd`、`tests/world/test_city_soccer_venue_ambient_freeze_hysteresis_contract.gd`、`tests/world/test_city_soccer_venue_radio_survives_ambient_freeze.gd` | `--script res://tests/e2e/test_city_soccer_minigame_goal_flow.gd` | [v26-m4-verification-2026-03-18.md](./v26-m4-verification-2026-03-18.md) | done |

## ECN 索引

- [ECN-0025 V26 Scoreboard And Ambient Freeze](../ecn/ECN-0025-v26-scoreboard-and-ambient-freeze.md)

## 差异列表

- `v26` 不包含门将、队友、对手、裁判、越位、犯规、角球与完整比赛规则。
- `v26` 不包含小地图/大地图 pin、任务接入、联网或本地多人。
- `v26` 只冻结足球 minigame 场馆基础版；更接近正式比赛的内容进入后续版本。
