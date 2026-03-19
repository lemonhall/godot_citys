# V27 Index

## 愿景

PRD 入口：[PRD-0017 Soccer 5v5 Match](../prd/PRD-0017-soccer-5v5-match.md)

设计入口：[2026-03-18-v27-soccer-5v5-match-design.md](../plans/2026-03-18-v27-soccer-5v5-match-design.md)

依赖入口：

- [PRD-0015 Soccer Ball Interactive Prop](../prd/PRD-0015-soccer-ball-interactive-prop.md)
- [PRD-0016 Soccer Minigame Venue Foundation](../prd/PRD-0016-soccer-minigame-venue-foundation.md)
- [v25-index.md](./v25-index.md)
- [v26-index.md](./v26-index.md)

`v27` 的目标是把 `v26` 的自由足球场馆推进成真正能开赛的 `5v5` 小场比赛。推荐路线不是把素体模型塞进 ambient pedestrians，也不是新造一套 task runtime 来冒充比赛，而是继续沿 `v26` 的同一座 `scene_minigame_venue` 场馆扩展：把用户提供的 `Animated Human.glb` 归置到足球专用资产域，在球场上 author 红蓝两队各 `5` 名球员和记分牌旁的开赛圈，比赛启动后 HUD 显示 `5:00` 倒计时，AI 围绕同一颗正式足球对抗，时间归零即结算胜负；若玩家离开冻结/释放圈，则整场比赛归位并清零。

当前状态：`M0-M3` 的文档、资产、开赛、HUD、终场与 reset 主链已经落地，也有对应 fresh rerun 证据见 [v27-m3-verification-2026-03-18.md](./v27-m3-verification-2026-03-18.md)。`M4` 曾在 [v27-m4-verification-2026-03-18.md](./v27-m4-verification-2026-03-18.md) 留下过一轮功能通过快照，之后又因为用户手测观察到一边倒比分与 keeper live-play 失真而 reopen；但到了 `2026-03-19`，用户在自行回滚到一版“已经可以玩儿”的实现后，明确接受当前可玩状态，并要求停止继续把 `v27` 打磨成“专业足球游戏”，改为直接执行一次 `M5` profiling rerun 后关闭版本。对应 fresh profiling 证据见 [v27-m5-verification-2026-03-19.md](./v27-m5-verification-2026-03-19.md)：其中 `chunk setup` 与 `warm runtime` 通过，`first-visit` 单次 run 仍轻微超线（`streaming_mount_setup_avg_usec = 5705`，门槛 `<= 5500`），但该结果已按用户要求如实记录，且不再继续为 `v27` 投入额外实现时间。`M4` 的金标准与设计约束仍作为本版本功能收口依据保留如下：

- 金标准 1：正式 `5:00` 自主比赛里，红蓝 AI 必须靠真实物理活球与正式 goal detection 自己踢出至少 `1` 个进球；不得靠 debug 注球、直接改比分或隐藏球作弊。
- 金标准 2：同一套环境、策略、物理和球员参数下做 `10` 场采样，最终比分结果不能 `10/10` 完全一致；若 `10` 场比分全同，则视为策略、环境或参数设计仍然过于镜像/僵死，不能验收。
- 金标准 3：完整 `5:00` 比赛与 `10` 场采样里，任一队单场得分不得达到两位数（`>= 10`），且任一场分差不得超过 `6` 球；若出现超高比分或过于悬殊比分，则视为节奏、物理或参数已被调到失真，不能验收。
- 设计约束 1：关键对抗行为必须允许进入受限随机区间，包括 keeper 抱球、对抗抢断、分球方向与 aggressiveness，而不是全程刚性脚本；但这些随机性必须进入正式 runtime 参数与 match seed，不得通过 hidden buff / 暗改比分作弊。
- 设计约束 2：体力必须同时作用于跑速、持续压迫意愿、护球稳定性与被抢断概率；跑得最多的人后续也必须承担更高的失误与被断风险。
- 设计约束 3：keeper 目标行为链是 `intercept -> secure -> distribute`，但成功率不能做成绝对开关，必须受来球速度、线路、门前中央性、门将体力与 match-seeded 行为扰动共同决定。

因此 `v27` 当前口径为：功能面按用户手测 acceptance 收口，`M5` profiling 证据已落档，版本关闭；剩余更偏音效、presentation polish 与“专业足球游戏化”增强项移出 `v27` 作用域。

## 决策冻结

- `v27` 不新增新的 world feature family，继续扩展 `venue:v26:soccer_pitch:chunk_129_139`。
- 用户提供的 `Animated Human.glb` 必须迁移到足球比赛专用资产域，不得进入 `city_game/assets/pedestrians/civilians/`。
- 比赛正式赛制冻结为 `5:00` 倒计时；时间归零时比分高者获胜，同分 `draw`。
- 红队与蓝队各 `5` 人，每队 `1` 名 `goalkeeper` + `4` 名 `field_player`。
- 开赛前与终场后，球员统一 Idle。
- 记分牌旁的开赛圈只复用 shared world ring marker 视觉 family，不接 task runtime。
- 玩家离开足球场冻结/释放圈时，整场比赛必须复位到 `0:0 / 05:00 / 中圈开球 / 双方回站位`。
- 终场时胜方比分外画红圈；平局不高亮。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | `PRD-0017`、design、`v27-index`、`v27` plan、traceability | 4 份文档全部落地且 `REQ-0017-*` 可追溯 | `rg -n "REQ-0017" docs/prd/PRD-0017-soccer-5v5-match.md docs/plan/v27-index.md docs/plan/v27-soccer-5v5-match.md` | done |
| M1 asset + roster mount | 素体资产归置、球员 wrapper、`10` 人阵容节点、角色 contract | 素体不进入 `civilians`；场馆 mounted 后有红蓝两队各 `5` 名球员与稳定角色语义 | `tests/world/test_city_soccer_match_asset_contract.gd`、`tests/world/test_city_soccer_match_roster_contract.gd` | done |
| M2 match start + HUD timer | start ring、比赛启动、HUD `05:00`、倒计时推进 | Player 进入 start ring 后比赛启动；HUD 显示 `05:00` 并递减 | `tests/world/test_city_soccer_match_start_contract.gd`、`tests/world/test_city_soccer_match_countdown_contract.gd` | done |
| M3 AI + final/reset loop | 简单 AI、守门员角色、终场胜负、出圈归零 | AI 会追球并影响同一颗正式足球；时间归零能结算；出圈会整场清零复位 | `tests/world/test_city_soccer_match_ai_kick_contract.gd`、`tests/world/test_city_soccer_match_final_scoreboard_contract.gd`、`tests/world/test_city_soccer_match_reset_on_exit_contract.gd` | done |
| M4 live-play gold standard | 自主比赛真实性、采样分布、现实比分护栏、回归 | 以用户最新手测 acceptance 为准，当前实现已达到“可以玩、动作真实、无需继续往专业足球游戏打磨”的收口口径；历史验证与 reopen 过程保留在 M4 verification 文档 | [v27-m4-verification-2026-03-18.md](./v27-m4-verification-2026-03-18.md) | done |
| M5 profiling rerun + closeout | profiling 三件套证据、版本关闭说明、剩余工作移出作用域 | ordered profiling three-piece 已 fresh rerun 并落档；其中 `first-visit` 单次 run 轻微超线，但结果已如实记录，且用户明确要求关闭 `v27` 不再继续投入实现时间 | `tests/world/test_city_chunk_setup_profile_breakdown.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd`、`tests/e2e/test_city_runtime_performance_profile.gd` | closed_by_user |

## 计划索引

- [v27-soccer-5v5-match.md](./v27-soccer-5v5-match.md)

## 追溯矩阵

| Req ID | v27 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0017-001 | `v27-soccer-5v5-match.md` | `tests/world/test_city_soccer_match_asset_contract.gd` | `--script res://tests/world/test_city_soccer_match_asset_contract.gd` | [v27-m3-verification-2026-03-18.md](./v27-m3-verification-2026-03-18.md) | done |
| REQ-0017-002 | `v27-soccer-5v5-match.md` | `tests/world/test_city_soccer_match_start_contract.gd`、`tests/world/test_city_soccer_match_countdown_contract.gd` | `--script res://tests/e2e/test_city_soccer_5v5_match_flow.gd` | [v27-m3-verification-2026-03-18.md](./v27-m3-verification-2026-03-18.md) | done |
| REQ-0017-003 | `v27-soccer-5v5-match.md` | `tests/world/test_city_soccer_match_roster_contract.gd` | `--script res://tests/world/test_city_soccer_match_roster_contract.gd` | [v27-m3-verification-2026-03-18.md](./v27-m3-verification-2026-03-18.md) | done |
| REQ-0017-004 | `v27-soccer-5v5-match.md` | `tests/world/test_city_soccer_match_ai_kick_contract.gd`、`tests/e2e/test_city_soccer_5v5_full_match_score_contract.gd` | `--script res://tests/e2e/test_city_soccer_5v5_match_flow.gd` | [v27-m4-verification-2026-03-18.md](./v27-m4-verification-2026-03-18.md) | done |
| REQ-0017-005 | `v27-soccer-5v5-match.md` | `tests/world/test_city_soccer_match_final_scoreboard_contract.gd`、`tests/world/test_city_soccer_match_reset_on_exit_contract.gd` | `--script res://tests/e2e/test_city_soccer_5v5_match_flow.gd` | [v27-m4-verification-2026-03-18.md](./v27-m4-verification-2026-03-18.md) | done |
| REQ-0017-006 | `v27-soccer-5v5-match.md` | `tests/e2e/test_city_soccer_5v5_score_sampling_contract.gd` + profiling 三件套（如适用） | `--script res://tests/world/test_city_chunk_setup_profile_breakdown.gd`、`--script res://tests/e2e/test_city_first_visit_performance_profile.gd`、`--script res://tests/e2e/test_city_runtime_performance_profile.gd` | [v27-m4-verification-2026-03-18.md](./v27-m4-verification-2026-03-18.md)、[v27-m5-verification-2026-03-19.md](./v27-m5-verification-2026-03-19.md) | closed_by_user |

## ECN 索引

- 当前无

## 差异列表

- `v27` 不包含完整规则裁判系统、观众、联网或本地多人。
- `v27` 不包含复杂球员身体对抗、抢断物理或专门射门动画。
- `v27` 不继续承接专业化足球 presentation polish；音效、氛围反馈与更高规格比赛包装移出本版本。
- `v27` 只冻结 `5v5` 基础比赛态；更复杂球队策略与比赛系统进入后续版本。
