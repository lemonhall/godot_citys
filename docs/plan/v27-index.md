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

当前状态：`M0-M3` 的文档、资产、开赛、HUD、终场与 reset 主链已经落地，也有对应 fresh rerun 证据见 [v27-m3-verification-2026-03-18.md](./v27-m3-verification-2026-03-18.md)；但用户追加了更高且更真实的 `M4` 金标准，因此当前 closeout 口径不能只看“AI 会追球/会碰球/会结算”。`M4` 现在明确要求：

- 金标准 1：正式 `5:00` 自主比赛里，红蓝 AI 必须靠真实物理活球与正式 goal detection 自己踢出至少 `1` 个进球；不得靠 debug 注球、直接改比分或隐藏球作弊。
- 金标准 2：同一套环境、策略、物理和球员参数下做 `10` 场采样，最终比分结果不能 `10/10` 完全一致；若 `10` 场比分全同，则视为策略、环境或参数设计仍然过于镜像/僵死，不能验收。

因此当前 `M4` 不是只 blocked 在 profiling guard，也 blocked 在这两条 live-play gold standard 尚未通过。

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
| M4 live-play gold standard + guard verification | 自主比赛真实性、采样分布、回归与 profiling | 必须同时满足两条金标准：1）正式 `5:00` 自主比赛里，红蓝 AI 会围绕真实物理球自行推进并至少打进 `1` 球；2）同一实现做 `10` 场采样时，最终比分不能 `10/10` 完全一致。随后再补齐完整流程回归与 profiling guard | 新增自主进球 / 10 场采样统计测试（待实现） + `tests/e2e/test_city_soccer_5v5_match_flow.gd` + 受影响 `v25/v26` tests + profiling 三件套（如触及 mount/tick/HUD） | blocked |

## 计划索引

- [v27-soccer-5v5-match.md](./v27-soccer-5v5-match.md)

## 追溯矩阵

| Req ID | v27 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0017-001 | `v27-soccer-5v5-match.md` | `tests/world/test_city_soccer_match_asset_contract.gd` | `--script res://tests/world/test_city_soccer_match_asset_contract.gd` | [v27-m3-verification-2026-03-18.md](./v27-m3-verification-2026-03-18.md) | done |
| REQ-0017-002 | `v27-soccer-5v5-match.md` | `tests/world/test_city_soccer_match_start_contract.gd`、`tests/world/test_city_soccer_match_countdown_contract.gd` | `--script res://tests/e2e/test_city_soccer_5v5_match_flow.gd` | [v27-m3-verification-2026-03-18.md](./v27-m3-verification-2026-03-18.md) | done |
| REQ-0017-003 | `v27-soccer-5v5-match.md` | `tests/world/test_city_soccer_match_roster_contract.gd` | `--script res://tests/world/test_city_soccer_match_roster_contract.gd` | [v27-m3-verification-2026-03-18.md](./v27-m3-verification-2026-03-18.md) | done |
| REQ-0017-004 | `v27-soccer-5v5-match.md` | `tests/world/test_city_soccer_match_ai_kick_contract.gd` | `--script res://tests/e2e/test_city_soccer_5v5_match_flow.gd` | [v27-m3-verification-2026-03-18.md](./v27-m3-verification-2026-03-18.md) | done |
| REQ-0017-005 | `v27-soccer-5v5-match.md` | `tests/world/test_city_soccer_match_final_scoreboard_contract.gd`、`tests/world/test_city_soccer_match_reset_on_exit_contract.gd` | `--script res://tests/e2e/test_city_soccer_5v5_match_flow.gd` | [v27-m3-verification-2026-03-18.md](./v27-m3-verification-2026-03-18.md) | done |
| REQ-0017-006 | `v27-soccer-5v5-match.md` | 受影响 `v25/v26` 足球与场馆 tests | `--script res://tests/e2e/test_city_soccer_5v5_match_flow.gd` + 受影响回归 + profiling 三件套（如适用） | [v27-m3-verification-2026-03-18.md](./v27-m3-verification-2026-03-18.md) | blocked |

## ECN 索引

- 当前无

## 差异列表

- `v27` 不包含完整规则裁判系统、观众、联网或本地多人。
- `v27` 不包含复杂球员身体对抗、抢断物理或专门射门动画。
- `v27` 只冻结 `5v5` 基础比赛态；更复杂球队策略与比赛系统进入后续版本。
